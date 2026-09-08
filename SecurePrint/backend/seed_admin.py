import os
import sys
from dotenv import load_dotenv

# Load env before importing app modules
load_dotenv()

sys.path.insert(0, os.path.dirname(__file__))

from app.core.database import SessionLocal, engine, Base
from app.models.user import User, UserRole, UserStatus
from app.core.security import get_password_hash

def seed_admin():
    db = SessionLocal()
    
    # Check if admin already exists
    admin_exists = db.query(User).filter(User.role == UserRole.ADMIN).first()
    if admin_exists:
        print("Admin user already exists.")
        db.close()
        return

    admin_email = os.getenv("ADMIN_EMAIL", "admin@secureprint.com")
    admin_password = os.getenv("ADMIN_PASSWORD", "SuperSecureAdmin123!")

    admin_user = User(
        name="System Administrator",
        email=admin_email,
        phone="0000000000",
        password_hash=get_password_hash(admin_password),
        role=UserRole.ADMIN,
        status=UserStatus.ACTIVE
    )
    
    db.add(admin_user)
    db.commit()
    print(f"Successfully created admin user: {admin_email}")
    db.close()

if __name__ == "__main__":
    print("Bootstrapping Admin...")
    seed_admin()
