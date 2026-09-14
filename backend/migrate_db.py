from app.database import engine
from app.models.base import Base
from sqlalchemy import text
import app.models.models

def migrate():
    with engine.connect() as conn:
        print("Connected to database...")
        # OTP records
        conn.execute(text("ALTER TABLE otp_records ADD COLUMN IF NOT EXISTS attempts INTEGER DEFAULT 0;"))
        conn.execute(text("ALTER TABLE otp_records ADD COLUMN IF NOT EXISTS locked_until TIMESTAMP WITHOUT TIME ZONE;"))
        
        # Riders
        conn.execute(text("ALTER TABLE riders ADD COLUMN IF NOT EXISTS profile_photo_url VARCHAR;"))
        conn.execute(text("ALTER TABLE riders ADD COLUMN IF NOT EXISTS block_reason TEXT;"))
        conn.execute(text("ALTER TABLE riders ADD COLUMN IF NOT EXISTS unlock_request_message TEXT;"))
        
        # Ride Requests
        conn.execute(text("ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(30) DEFAULT 'bike';"))
        conn.execute(text("ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS payment_method VARCHAR(30) DEFAULT 'cash';"))
        conn.execute(text("ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS current_offered_rider_id UUID;"))
        conn.execute(text("ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS offer_expires_at TIMESTAMP WITH TIME ZONE;"))
        conn.execute(text("ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS notified_riders UUID[];"))
        conn.execute(text("ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS rejected_rider_ids UUID[];"))
        conn.execute(text("ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS accepted_by_rider UUID;"))
        conn.execute(text("ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMP WITH TIME ZONE;"))
        conn.execute(text("ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE;"))
        
        # Rides
        conn.execute(text("ALTER TABLE rides ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(30) DEFAULT 'bike';"))
        conn.execute(text("ALTER TABLE rides ADD COLUMN IF NOT EXISTS payment_method VARCHAR(30) DEFAULT 'cash';"))
        conn.execute(text("ALTER TABLE rides ADD COLUMN IF NOT EXISTS payment_status VARCHAR(30) DEFAULT 'pending';"))
        conn.execute(text("ALTER TABLE rides ADD COLUMN IF NOT EXISTS ride_otp VARCHAR(4);"))
        conn.execute(text("ALTER TABLE rides ADD COLUMN IF NOT EXISTS otp_verified BOOLEAN DEFAULT FALSE;"))
        conn.execute(text("ALTER TABLE rides ADD COLUMN IF NOT EXISTS cancelled_by VARCHAR(50);"))
        conn.execute(text("ALTER TABLE rides ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;"))
        conn.execute(text("ALTER TABLE rides ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP WITH TIME ZONE;"))
        
        conn.commit()
        print("All PostgreSQL schema columns migrated successfully.")

    Base.metadata.create_all(bind=engine)
    print("Database metadata verified!")

if __name__ == "__main__":
    migrate()
