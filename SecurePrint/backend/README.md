# SecurePrint Backend

FastAPI backend for the SecurePrint application.

## Prerequisites

- Python 3.9+
- PostgreSQL

## Setup

1. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Configure environment variables:
   Update the `.env` file with your PostgreSQL credentials.

4. Run the server:
   ```bash
   uvicorn app.main:app --reload
   ```

## API Documentation

Once the server is running, you can access the interactive API docs at:
- Swagger UI: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- ReDoc: [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc)

## Features Implemented

- User Registration (Customer, Xerox Shop, Admin)
- JWT Authentication
- Role-based Access Control
- Admin Shop Approval Workflow
- Argon2id Password Hashing
