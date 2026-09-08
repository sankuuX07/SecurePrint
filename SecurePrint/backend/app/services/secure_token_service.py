import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session
from fastapi import HTTPException

from ..models.secure_token import SecureAccessToken, SecureTokenStatus
from ..models.print_job import PrintJob, PrintJobStatus
from ..models.document import Document, DocumentStatus
from ..models.shop import Shop
from ..models.user import User, UserRole
from ..models.audit_log import AuditLog
from .temporary_access_service import TemporaryDocumentAccessService

SECURE_ACCESS_TOKEN_TTL_MINUTES = 15

class SecureTokenService:

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

    @staticmethod
    def _hash_token(raw_token: str) -> str:
        return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()

    @classmethod
    def create_token(cls, db: Session, print_job_id: int, customer_user: User):
        if customer_user.role != UserRole.CUSTOMER:
            raise HTTPException(status_code=403, detail="Only customers can generate secure access tokens.")

        job = db.query(PrintJob).filter(PrintJob.id == print_job_id).first()
        if not job:
            raise HTTPException(status_code=404, detail="PrintJob not found.")

        if job.customer_id != customer_user.id:
            raise HTTPException(status_code=403, detail="You do not own this PrintJob.")

        if job.status not in [PrintJobStatus.ACCEPTED, PrintJobStatus.PRINTING]:
            cls._log_event(db, "SECURE_ACCESS_TOKEN_VALIDATION_FAILED", user_id=customer_user.id, print_job_id=job.id, extra_metadata=f"Invalid job state: {job.status}")
            raise HTTPException(status_code=400, detail=f"Cannot generate token for job in state: {job.status.name}")

        doc = db.query(Document).filter(Document.id == job.document_id).first()
        if not doc or doc.status in [DocumentStatus.DELETED, DocumentStatus.EXPIRED, DocumentStatus.FAILED]:
            raise HTTPException(status_code=400, detail="Document is unavailable.")

        shop = db.query(Shop).filter(Shop.id == job.shop_id).first()
        if not shop:
            raise HTTPException(status_code=400, detail="Shop not found.")

        # Revoke previous active tokens for this job
        cls.revoke_tokens_for_job(db, job.id, log=False)

        # Generate new cryptographically secure token
        raw_token = f"SP-ACCESS-{secrets.token_urlsafe(32)}"
        token_hash = cls._hash_token(raw_token)

        now = datetime.now(timezone.utc)
        expires_at = now + timedelta(minutes=SECURE_ACCESS_TOKEN_TTL_MINUTES)

        new_token = SecureAccessToken(
            print_job_id=job.id,
            document_id=doc.id,
            shop_id=shop.id,
            token_hash=token_hash,
            status=SecureTokenStatus.ACTIVE,
            expires_at=expires_at
        )

        db.add(new_token)
        cls._log_event(db, "SECURE_ACCESS_TOKEN_CREATED", user_id=customer_user.id, document_id=doc.id, print_job_id=job.id)
        db.commit()

        # The raw token is returned only once
        return {
            "token": raw_token,
            "expires_at": expires_at,
            "print_job_id": job.id,
            "document_id": doc.id,
            "shop_id": shop.id
        }

    @classmethod
    def validate_token(cls, db: Session, raw_token: str, shop_user: User):
        if shop_user.role != UserRole.SHOP:
            raise HTTPException(status_code=403, detail="Only shops can scan secure access tokens.")

        shop = db.query(Shop).filter(Shop.owner_id == shop_user.id).first()
        if not shop:
            raise HTTPException(status_code=403, detail="Shop profile not found.")

        token_hash = cls._hash_token(raw_token)
        token_record = db.query(SecureAccessToken).filter(SecureAccessToken.token_hash == token_hash).first()

        if not token_record:
            cls._log_event(db, "SECURE_ACCESS_TOKEN_VALIDATION_FAILED", user_id=shop_user.id, extra_metadata="INVALID_TOKEN")
            raise HTTPException(status_code=404, detail="Secure access credential is invalid or unavailable.")

        # Check status and expiry
        now = datetime.now(timezone.utc)
        if token_record.status == SecureTokenStatus.REVOKED:
            cls._log_event(db, "SECURE_ACCESS_TOKEN_VALIDATION_FAILED", user_id=shop_user.id, print_job_id=token_record.print_job_id, extra_metadata="REVOKED_TOKEN")
            raise HTTPException(status_code=403, detail="Secure access credential is invalid or unavailable.")

        if token_record.expires_at.replace(tzinfo=timezone.utc) < now:
            if token_record.status == SecureTokenStatus.ACTIVE:
                token_record.status = SecureTokenStatus.EXPIRED
                cls._log_event(db, "SECURE_ACCESS_TOKEN_EXPIRED", print_job_id=token_record.print_job_id)
                db.commit()
            cls._log_event(db, "SECURE_ACCESS_TOKEN_VALIDATION_FAILED", user_id=shop_user.id, print_job_id=token_record.print_job_id, extra_metadata="EXPIRED_TOKEN")
            raise HTTPException(status_code=403, detail="Secure access credential is invalid or unavailable.")

        # Enforce binding relationships
        if token_record.shop_id != shop.id:
            cls._log_event(db, "SECURE_ACCESS_TOKEN_VALIDATION_FAILED", user_id=shop_user.id, print_job_id=token_record.print_job_id, extra_metadata="WRONG_SHOP")
            raise HTTPException(status_code=403, detail="Secure access credential is invalid or unavailable.")

        job = db.query(PrintJob).filter(PrintJob.id == token_record.print_job_id).first()
        if not job or job.shop_id != shop.id or job.document_id != token_record.document_id:
            cls._log_event(db, "SECURE_ACCESS_TOKEN_VALIDATION_FAILED", user_id=shop_user.id, print_job_id=token_record.print_job_id, extra_metadata="RELATIONSHIP_MISMATCH")
            raise HTTPException(status_code=403, detail="Secure access credential is invalid or unavailable.")

        if job.status not in [PrintJobStatus.ACCEPTED, PrintJobStatus.PRINTING]:
            cls._log_event(db, "SECURE_ACCESS_TOKEN_VALIDATION_FAILED", user_id=shop_user.id, print_job_id=token_record.print_job_id, extra_metadata="INVALID_JOB_STATE")
            raise HTTPException(status_code=403, detail="Secure access credential is invalid or unavailable.")

        doc = db.query(Document).filter(Document.id == token_record.document_id).first()
        if not doc or doc.status in [DocumentStatus.DELETED, DocumentStatus.EXPIRED, DocumentStatus.FAILED]:
            cls._log_event(db, "SECURE_ACCESS_TOKEN_VALIDATION_FAILED", user_id=shop_user.id, print_job_id=token_record.print_job_id, extra_metadata="DOCUMENT_UNAVAILABLE")
            raise HTTPException(status_code=403, detail="Secure access credential is invalid or unavailable.")

        # All checks passed, log validation
        cls._log_event(db, "SECURE_ACCESS_TOKEN_VALIDATED", user_id=shop_user.id, print_job_id=job.id, document_id=doc.id)

        # Trigger TemporaryDocumentAccess
        temp_access = TemporaryDocumentAccessService.grant_access(db, job.id, shop_user)
        
        return {
            "access_id": temp_access.id,
            "status": "AUTHORIZED",
            "expires_at": temp_access.expires_at,
            "print_job_id": job.id,
            "document_id": doc.id
        }

    @classmethod
    def revoke_tokens_for_job(cls, db: Session, print_job_id: int, log: bool = True):
        tokens = db.query(SecureAccessToken).filter(
            SecureAccessToken.print_job_id == print_job_id,
            SecureAccessToken.status == SecureTokenStatus.ACTIVE
        ).all()
        
        if not tokens:
            return

        now = datetime.now(timezone.utc)
        for token in tokens:
            token.status = SecureTokenStatus.REVOKED
            token.revoked_at = now
            if log:
                cls._log_event(db, "SECURE_ACCESS_TOKEN_REVOKED", print_job_id=print_job_id)

        db.commit()
