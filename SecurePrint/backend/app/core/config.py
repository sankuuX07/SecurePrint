import os
from dotenv import load_dotenv
from pydantic_settings import BaseSettings

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOTENV_PATH = os.path.join(BACKEND_DIR, ".env")
load_dotenv(dotenv_path=DOTENV_PATH)

def resolve_database_url(raw_url: str | None) -> str:
    if not raw_url:
        raw_url = "sqlite:///./secureprint.db"
    if raw_url.startswith("sqlite:///"):
        sqlite_path = raw_url[len("sqlite:///"):]
        if sqlite_path == ":memory:":
            return raw_url
        if sqlite_path.startswith("./") or sqlite_path.startswith(".\\"):
            sqlite_path = sqlite_path[2:]
        # Check if already absolute: Windows (e.g. C:/) or POSIX (/...)
        is_abs = (len(sqlite_path) > 1 and sqlite_path[1] == ":") or sqlite_path.startswith("/") or sqlite_path.startswith("\\")
        if not is_abs:
            resolved = os.path.abspath(os.path.join(BACKEND_DIR, sqlite_path)).replace("\\", "/")
            return f"sqlite:///{resolved}"
    return raw_url

class Settings(BaseSettings):
    PROJECT_NAME: str = "SecurePrint"
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./secureprint.db")
    SECRET_KEY: str = os.getenv("SECRET_KEY")
    ALGORITHM: str = os.getenv("ALGORITHM", "HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))

    def model_post_init(self, __context):
        self.DATABASE_URL = resolve_database_url(self.DATABASE_URL)
        os.environ["DATABASE_URL"] = self.DATABASE_URL

settings = Settings()


