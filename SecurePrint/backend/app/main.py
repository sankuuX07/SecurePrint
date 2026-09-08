from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .core.config import settings
from .core.database import engine, Base
from .routes import auth, users, admin, documents, shops, print_jobs, shop_document_access, shop_qr, payment

# Create tables (for development, use Alembic for production)
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"/api/v1/openapi.json"
)

# Set up CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # In production, replace with specific origins (like your Android app's domain if applicable or just the API consumer's IP)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(admin.router, prefix="/api/v1")
app.include_router(documents.router, prefix="/api/v1")
app.include_router(shops.router, prefix="/api/v1")
app.include_router(print_jobs.router, prefix="/api/v1")
app.include_router(shop_document_access.router, prefix="/api/v1")
app.include_router(shop_qr.router, prefix="/api/v1")
app.include_router(shop_qr.shop_action_router, prefix="/api/v1")
app.include_router(payment.router, prefix="/api/v1")

@app.get("/")
def root():
    return {"message": "Welcome to SecurePrint API"}
