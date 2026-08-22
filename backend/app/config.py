from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    APP_NAME: str = "AshtaRide"
    DEBUG: bool = False
    SECRET_KEY: str = "ashtaride-super-secret-key-change-in-production"

    DATABASE_URL: str = "postgresql://postgres:ashta1234@localhost:5432/ashtaride_db"

    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080

    OTP_EXPIRE_MINUTES: int = 5
    OTP_DEV_MODE: bool = True
    OTP_DEV_CODE: str = "1234"

    MSG91_API_KEY: Optional[str] = None
    MSG91_SENDER_ID: str = "ASHTAR"
    MSG91_TEMPLATE_ID: Optional[str] = None

    FIREBASE_CREDENTIALS_PATH: Optional[str] = None

    CLOUDINARY_CLOUD_NAME: Optional[str] = None
    CLOUDINARY_API_KEY: Optional[str] = None
    CLOUDINARY_API_SECRET: Optional[str] = None

    BASE_FARE: float = 20.0
    PER_KM_FARE: float = 8.0
    WAITING_FARE_PER_MIN: float = 1.0

    RIDER_SEARCH_RADIUS_KM: float = 5.0
    RIDE_REQUEST_EXPIRE_MINUTES: int = 2

    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()