from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session
from fastapi import HTTPException
from ..models.temporary_access import TemporaryDocumentAccess, TemporaryAccessStatus
from ..models.print_job import PrintJob, PrintJobStatus
from ..models.document import Document, DocumentStatus
from ..models.shop import Shop
from ..models.user import User
from ..models.audit_log import AuditLog

# Configuration for TTL (time to live)
DOCUMENT_ACCESS_DURATION_MINUTES = 15

class TemporaryDocumentAccessService:
    
    @staticmethod
    def _log_event(db: Session, event_type: str, user_id: int = None, document_id: str = None, print_job_id: int = None, extra_metadata: str = None):
        log = AuditLog(
            event_type=event_type,
            user_id=user_id,
            document_id=document_id,
            print_job_id=print_job_id,
            extra_metadata=extra_metadata
        )
        db.add(log)

    @classmethod
    def grant_access(cls, db: Session, print_job_id: int, shop_user: User) -> TemporaryDocumentAccess:
        shop = db.query(Shop).filter(Shop.owner_id == shop_user.id).first()
        if not shop:
            cls._log_event(db, "DOCUMENT_ACCESS_DENIED", user_id=shop_user.id, print_job_id=print_job_id, extra_metadata="Shop profile not found")
            raise HTTPException(status_code=403, detail="Not authorized to access this print job.")
            
        # Shop must own the job
        job = db.query(PrintJob).filter(PrintJob.id == print_job_id, PrintJob.shop_id == shop.id).first()
        if not job:
            cls._log_event(db, "DOCUMENT_ACCESS_DENIED", user_id=shop_user.id, print_job_id=print_job_id, extra_metadata="Job not found or not owned by shop")
            raise HTTPException(status_code=403, detail="Not authorized to access this print job.")
            
        # Validate job status
        if job.status not in [PrintJobStatus.ACCEPTED, PrintJobStatus.PRINTING]:
            cls._log_event(db, "DOCUMENT_ACCESS_DENIED", user_id=shop_user.id, print_job_id=print_job_id, extra_metadata=f"Invalid job status: {job.status}")
            raise HTTPException(status_code=400, detail="Document access is only available for ACCEPTED or PRINTING jobs.")
            
        # Validate document exists and is not expired/deleted
        doc = db.query(Document).filter(Document.id == job.document_id).first()
        if not doc or doc.status in [DocumentStatus.EXPIRED, DocumentStatus.DELETED, DocumentStatus.FAILED]:
            cls._log_event(db, "DOCUMENT_ACCESS_DENIED", user_id=shop_user.id, document_id=job.document_id, extra_metadata="Document unavailable")
            raise HTTPException(status_code=404, detail="Document is no longer available.")

        # Create or update active access
        # If one already exists and is active, we can just return it or extend it. Let's create a new one or reuse.
        existing_access = db.query(TemporaryDocumentAccess).filter(
            TemporaryDocumentAccess.print_job_id == print_job_id,
            TemporaryDocumentAccess.shop_id == shop.id,
            TemporaryDocumentAccess.status == TemporaryAccessStatus.ACTIVE
        ).first()
        
        now = datetime.now(timezone.utc)
        expires_at = now + timedelta(minutes=DOCUMENT_ACCESS_DURATION_MINUTES)
        
        if existing_access:
            if existing_access.expires_at.replace(tzinfo=timezone.utc) > now:
                # Still valid, just extend it
                existing_access.expires_at = expires_at
                cls._log_event(db, "DOCUMENT_TEMP_ACCESS_GRANTED", user_id=shop_user.id, document_id=doc.id, print_job_id=job.id, extra_metadata=f"Extended access to {expires_at}")
                db.commit()
                db.refresh(existing_access)
                return existing_access
            else:
                # Expired, mark it so and create a new one
                existing_access.status = TemporaryAccessStatus.EXPIRED
        
        access = TemporaryDocumentAccess(
            print_job_id=job.id,
            document_id=doc.id,
            shop_id=shop.id,
            status=TemporaryAccessStatus.ACTIVE,
            expires_at=expires_at
        )
        db.add(access)
        cls._log_event(db, "DOCUMENT_TEMP_ACCESS_GRANTED", user_id=shop_user.id, document_id=doc.id, print_job_id=job.id, extra_metadata=f"Granted until {expires_at}")
        db.commit()
        db.refresh(access)
        return access

    @classmethod
    def validate_access(cls, db: Session, access_id: str, shop_user: User) -> TemporaryDocumentAccess:
        access = db.query(TemporaryDocumentAccess).filter(TemporaryDocumentAccess.id == access_id).first()
        if not access:
            cls._log_event(db, "DOCUMENT_ACCESS_DENIED", user_id=shop_user.id, extra_metadata="Access record not found")
            raise HTTPException(status_code=404, detail="Access not found.")
            
        shop = db.query(Shop).filter(Shop.owner_id == shop_user.id).first()
        if not shop or access.shop_id != shop.id:
            cls._log_event(db, "DOCUMENT_ACCESS_DENIED", user_id=shop_user.id, document_id=access.document_id, print_job_id=access.print_job_id, extra_metadata="Shop mismatch")
            raise HTTPException(status_code=403, detail="Not authorized.")
            
        # Dynamically check expiry
        now = datetime.now(timezone.utc)
        if access.status == TemporaryAccessStatus.ACTIVE and access.expires_at.replace(tzinfo=timezone.utc) < now:
            access.status = TemporaryAccessStatus.EXPIRED
            db.commit()
            
        if access.status == TemporaryAccessStatus.EXPIRED:
            cls._log_event(db, "DOCUMENT_TEMP_ACCESS_EXPIRED", user_id=shop_user.id, document_id=access.document_id, print_job_id=access.print_job_id)
            raise HTTPException(status_code=410, detail="Access has expired.")
            
        if access.status == TemporaryAccessStatus.REVOKED or access.revoked_at is not None:
            cls._log_event(db, "DOCUMENT_ACCESS_DENIED", user_id=shop_user.id, document_id=access.document_id, print_job_id=access.print_job_id, extra_metadata="Access was revoked")
            raise HTTPException(status_code=410, detail="Access has been revoked.")
            
        # Verify job and document relationships are still intact and valid
        job = db.query(PrintJob).filter(PrintJob.id == access.print_job_id).first()
        if not job or job.shop_id != access.shop_id or job.document_id != access.document_id:
            raise HTTPException(status_code=403, detail="Invalid relationship state.")
            
        if job.status not in [PrintJobStatus.ACCEPTED, PrintJobStatus.PRINTING]:
            cls._log_event(db, "DOCUMENT_ACCESS_DENIED", user_id=shop_user.id, document_id=access.document_id, print_job_id=access.print_job_id, extra_metadata=f"Job status changed to {job.status}")
            cls.revoke_access(db, access.print_job_id) # auto-revoke
            raise HTTPException(status_code=403, detail="Job is no longer in a printable state.")
            
        doc = db.query(Document).filter(Document.id == access.document_id).first()
        if not doc or doc.status in [DocumentStatus.EXPIRED, DocumentStatus.DELETED, DocumentStatus.FAILED]:
            cls._log_event(db, "DOCUMENT_ACCESS_DENIED", user_id=shop_user.id, document_id=access.document_id, print_job_id=access.print_job_id, extra_metadata="Document deleted")
            raise HTTPException(status_code=410, detail="Document is no longer available.")
            
        return access

    @classmethod
    def revoke_access(cls, db: Session, print_job_id: int):
        accesses = db.query(TemporaryDocumentAccess).filter(
            TemporaryDocumentAccess.print_job_id == print_job_id,
            TemporaryDocumentAccess.status == TemporaryAccessStatus.ACTIVE
        ).all()
        
        now = datetime.now(timezone.utc)
        for access in accesses:
            access.status = TemporaryAccessStatus.REVOKED
            access.revoked_at = now
            cls._log_event(db, "DOCUMENT_TEMP_ACCESS_REVOKED", document_id=access.document_id, print_job_id=access.print_job_id)
            
        db.commit()

    @classmethod
    def expire_access(cls, db: Session, access_id: str):
        access = db.query(TemporaryDocumentAccess).filter(TemporaryDocumentAccess.id == access_id).first()
        if access and access.status == TemporaryAccessStatus.ACTIVE:
            access.status = TemporaryAccessStatus.EXPIRED
            db.commit()

    @classmethod
    def record_access_usage(cls, db: Session, access: TemporaryDocumentAccess, shop_user: User):
        access.access_count += 1
        access.last_accessed_at = datetime.now(timezone.utc)
        cls._log_event(db, "DOCUMENT_TEMP_ACCESS_USED", user_id=shop_user.id, document_id=access.document_id, print_job_id=access.print_job_id)
        db.commit()
