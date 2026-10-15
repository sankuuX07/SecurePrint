import os
import sys
import argparse
import getpass
from dotenv import load_dotenv

# Ensure the backend directory is in the Python search path
BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

# Load environment variables
load_dotenv(dotenv_path=os.path.join(BACKEND_DIR, ".env"))

from app.core.database import SessionLocal
from app.models.user import User, UserRole
from app.core.security import get_password_hash


def validate_password(password: str, confirm_password: str) -> None:
    """
    Validates password complexity against SecurePrint project standards.
    Raises ValueError with a descriptive message if validation fails.
    """
    if not password:
        raise ValueError("Password cannot be empty.")
    if password != confirm_password:
        raise ValueError("Passwords do not match.")
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters long.")
    if password.strip() != password:
        raise ValueError("Password must not have leading or trailing whitespace.")
    
    # Check for basic complexity (letters and numbers/symbols)
    has_letter = any(c.isalpha() for c in password)
    has_digit_or_symbol = any(not c.isalpha() for c in password)
    if not (has_letter and has_digit_or_symbol):
        raise ValueError("Password should contain a mixture of letters and numbers/symbols.")


def reset_admin_password(target_email: str) -> None:
    """
    Safely resets the password of an existing administrator account.
    Enforces strict role checks, interactive hidden input, transaction safety,
    and explicit user confirmation.
    """
    db = SessionLocal()
    try:
        # 1. Fetch user by email
        user = db.query(User).filter(User.email == target_email).first()
        if not user:
            print(f"[ERROR] User with email '{target_email}' does not exist.")
            return

        # 2. Strict Role Safeguard: ensure the account is an ADMIN
        if user.role != UserRole.ADMIN:
            print(
                f"[SECURITY REJECTION] Account '{target_email}' has role '{user.role.value}', "
                f"not '{UserRole.ADMIN.value}'. This utility can only reset administrator credentials."
            )
            return

        # 3. Display non-sensitive account confirmation details
        print("\n=======================================================")
        print("          SecurePrint Administrator Target Verified     ")
        print("=======================================================")
        print(f"  User ID    : {user.id}")
        print(f"  Name       : {user.name}")
        print(f"  Email      : {user.email}")
        print(f"  Role       : {user.role.value}")
        print(f"  Status     : {user.status.value}")
        print(f"  Created At : {user.created_at}")
        print("=======================================================\n")

        # 4. Prompt for new password using getpass (hidden input)
        try:
            new_password = getpass.getpass("Enter new administrator password: ")
            confirm_password = getpass.getpass("Confirm new administrator password: ")
        except (KeyboardInterrupt, EOFError):
            print("\n[CANCELLED] Input aborted by user.")
            return

        # 5. Validate password standards
        try:
            validate_password(new_password, confirm_password)
        except ValueError as e:
            print(f"\n[VALIDATION FAILED] {e}")
            return

        # 6. Explicit confirmation prompt
        print("\nWarning: This action will replace the existing password hash for this administrator.")
        confirmation = input(f"Type 'yes' to confirm password reset for '{user.email}': ").strip()
        if confirmation.lower() != "yes":
            print("[CANCELLED] Confirmation not received. No changes were made.")
            return

        # 7. Hash password using existing Argon2id utility and update hash only
        hashed_password = get_password_hash(new_password)
        user.password_hash = hashed_password

        # 8. Commit transaction
        db.commit()
        print(f"\n[SUCCESS] Administrator password for '{user.email}' has been successfully updated.")
        print("[INFO] You can now authenticate via 'POST /api/v1/auth/login' using this administrator account.")

    except Exception as exc:
        db.rollback()
        print(f"\n[FAILURE] An unexpected database error occurred. Transaction rolled back: {exc}")
        raise
    finally:
        db.close()


def main():
    parser = argparse.ArgumentParser(
        description="One-time utility to reset administrator password for SecurePrint."
    )
    default_email = os.getenv("ADMIN_EMAIL", "admin@secureprint.com")
    parser.add_argument(
        "--email",
        default=default_email,
        help=f"Email address of the administrator account to reset (default: {default_email})",
    )
    args = parser.parse_args()

    print("=======================================================")
    print("      SecurePrint Admin Password Recovery Utility       ")
    print("=======================================================")
    reset_admin_password(args.email.strip())


if __name__ == "__main__":
    main()
