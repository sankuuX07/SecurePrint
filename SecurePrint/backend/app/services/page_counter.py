import os
from pypdf import PdfReader
from fastapi import UploadFile

async def count_pages(file: UploadFile, temp_file_path: str) -> int:
    """
    Counts the pages in the uploaded document.
    PDFs are parsed using pypdf.
    Images (jpg, jpeg, png) return 1.
    Raises ValueError for unsupported types or corrupted PDFs.
    """
    filename = file.filename.lower()
    
    if filename.endswith(".pdf"):
        try:
            reader = PdfReader(temp_file_path)
            return len(reader.pages)
        except Exception as e:
            raise ValueError(f"Failed to parse PDF page count: {e}")
            
    elif filename.endswith((".jpg", ".jpeg", ".png")):
        return 1
        
    raise ValueError("Unsupported file type. Only PDF, JPG, and PNG are supported.")
