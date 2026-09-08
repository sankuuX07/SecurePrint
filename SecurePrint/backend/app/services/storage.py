import os
import uuid
import shutil
from fastapi import UploadFile, HTTPException

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "uploads")
ALLOWED_EXTENSIONS = {".pdf", ".jpg", ".jpeg", ".png"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB

if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR, exist_ok=True)

async def save_upload_file(upload_file: UploadFile) -> str:
    # Validate extension
    filename = upload_file.filename
    if not filename:
        raise HTTPException(status_code=400, detail="No filename provided")
        
    ext = os.path.splitext(filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"File extension {ext} not allowed")

    # Securely generate storage key
    storage_key = f"{uuid.uuid4().hex}{ext}"
    file_path = os.path.join(UPLOAD_DIR, storage_key)

    # Validate size and write file
    # We read in chunks to avoid loading large files in memory and check size limit
    size = 0
    with open(file_path, "wb") as buffer:
        while True:
            chunk = await upload_file.read(1024 * 1024)
            if not chunk:
                break
            size += len(chunk)
            if size > MAX_FILE_SIZE:
                os.remove(file_path)
                raise HTTPException(status_code=400, detail="File too large (max 10MB)")
            buffer.write(chunk)
            
    return storage_key

def get_file_path(storage_key: str) -> str:
    # Prevent path traversal by strictly joining with UPLOAD_DIR and verifying
    # In python, if storage_key is absolute, os.path.join discards UPLOAD_DIR, 
    # so we must secure it.
    if ".." in storage_key or "/" in storage_key or "\\" in storage_key:
        raise HTTPException(status_code=400, detail="Invalid storage key")
        
    path = os.path.join(UPLOAD_DIR, storage_key)
    if not os.path.abspath(path).startswith(os.path.abspath(UPLOAD_DIR)):
        raise HTTPException(status_code=400, detail="Invalid storage path")
    return path

def delete_file(storage_key: str):
    try:
        file_path = get_file_path(storage_key)
        if os.path.exists(file_path):
            os.remove(file_path)
    except Exception:
        # Avoid crashing if the file is already gone or access is denied
        pass
