from app.database import engine
from app.models.base import Base
from sqlalchemy import text
import app.models.models

def migrate():
    with engine.connect() as conn:
        print("Connected to database...")
        conn.execute(text("ALTER TABLE otp_records ADD COLUMN IF NOT EXISTS attempts INTEGER DEFAULT 0;"))
        conn.execute(text("ALTER TABLE otp_records ADD COLUMN IF NOT EXISTS locked_until TIMESTAMP WITHOUT TIME ZONE;"))
        conn.execute(text("ALTER TABLE riders ADD COLUMN IF NOT EXISTS profile_photo_url VARCHAR;"))
        conn.commit()
        print("Columns migrated successfully.")

    Base.metadata.create_all(bind=engine)
    print("All tables and columns verified in PostgreSQL database!")

if __name__ == "__main__":
    migrate()
