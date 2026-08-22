import uuid
from sqlalchemy import (
    Column, String, Boolean, Integer, Text,
    DateTime, Numeric, ForeignKey, ARRAY
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from .base import Base, TimestampMixin


class AdminUser(Base, TimestampMixin):
    __tablename__ = "admin_users"
    id            = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    full_name     = Column(String(100), nullable=False)
    email         = Column(String(150), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role          = Column(String(50), default="admin")
    is_active     = Column(Boolean, default=True)
    last_login    = Column(DateTime(timezone=True))


class User(Base, TimestampMixin):
    __tablename__ = "users"
    id            = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    full_name     = Column(String(100))
    mobile_number = Column(String(15), unique=True, nullable=False)
    profile_photo = Column(String(500))
    is_active     = Column(Boolean, default=True)
    is_blocked    = Column(Boolean, default=False)
    total_rides   = Column(Integer, default=0)
    rides         = relationship("Ride", back_populates="user", foreign_keys="Ride.user_id")
    ratings       = relationship("Rating", back_populates="user")
    sos_alerts    = relationship("SOSAlert", back_populates="user")


class OTPRecord(Base):
    __tablename__ = "otp_records"
    id            = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    mobile_number = Column(String(15), nullable=False)
    otp_code      = Column(String(6), nullable=False)
    otp_type      = Column(String(20), nullable=False)
    is_used       = Column(Boolean, default=False)
    expires_at    = Column(DateTime(timezone=True), nullable=False)
    created_at    = Column(DateTime(timezone=True), server_default=func.now())


class Rider(Base, TimestampMixin):
    __tablename__ = "riders"
    id                     = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    full_name              = Column(String(100), nullable=False)
    mobile_number          = Column(String(15), unique=True, nullable=False)
    profile_photo          = Column(String(500))
    aadhaar_number         = Column(String(20))
    aadhaar_doc_url        = Column(String(500))
    driving_license_number = Column(String(30))
    driving_license_url    = Column(String(500))
    verification_status    = Column(String(20), default="pending")
    rejection_reason       = Column(Text)
    verified_at            = Column(DateTime(timezone=True))
    verified_by            = Column(UUID(as_uuid=True), ForeignKey("admin_users.id"))
    is_online              = Column(Boolean, default=False)
    last_location_lat      = Column(Numeric(10, 8))
    last_location_lng      = Column(Numeric(11, 8))
    last_location_updated  = Column(DateTime(timezone=True))
    total_rides            = Column(Integer, default=0)
    total_earnings         = Column(Numeric(10, 2), default=0.00)
    average_rating         = Column(Numeric(3, 2), default=0.00)
    total_ratings          = Column(Integer, default=0)
    is_active              = Column(Boolean, default=True)
    is_blocked             = Column(Boolean, default=False)
    block_reason           = Column(Text, nullable=True)
    unlock_request_message = Column(Text, nullable=True)
    vehicle                = relationship("Vehicle", back_populates="rider", uselist=False)
    rides                  = relationship("Ride", back_populates="rider", foreign_keys="Ride.rider_id")
    ratings                = relationship("Rating", back_populates="rider")


class Vehicle(Base, TimestampMixin):
    __tablename__ = "vehicles"
    id             = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    rider_id       = Column(UUID(as_uuid=True), ForeignKey("riders.id", ondelete="CASCADE"), nullable=False)
    vehicle_type   = Column(String(30), default="bike")
    brand          = Column(String(50))
    model          = Column(String(50))
    color          = Column(String(30))
    year           = Column(Integer)
    plate_number   = Column(String(20), unique=True, nullable=False)
    rc_doc_url     = Column(String(500))
    rc_expiry_date = Column(DateTime)
    is_verified    = Column(Boolean, default=False)
    rider          = relationship("Rider", back_populates="vehicle")


class RideRequest(Base, TimestampMixin):
    __tablename__ = "ride_requests"
    id                  = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id             = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    pickup_lat          = Column(Numeric(10, 8), nullable=False)
    pickup_lng          = Column(Numeric(11, 8), nullable=False)
    pickup_address      = Column(Text, nullable=False)
    destination_lat     = Column(Numeric(10, 8), nullable=False)
    destination_lng     = Column(Numeric(11, 8), nullable=False)
    destination_address = Column(Text, nullable=False)
    estimated_distance  = Column(Numeric(8, 2))
    estimated_fare      = Column(Numeric(8, 2))
    status              = Column(String(20), default="searching")
    notified_riders     = Column(ARRAY(UUID(as_uuid=True)))
    accepted_by_rider   = Column(UUID(as_uuid=True), ForeignKey("riders.id"))
    accepted_at         = Column(DateTime(timezone=True))
    expires_at          = Column(DateTime(timezone=True))


class Ride(Base, TimestampMixin):
    __tablename__ = "rides"
    id                  = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    request_id          = Column(UUID(as_uuid=True), ForeignKey("ride_requests.id"), unique=True)
    user_id             = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    rider_id            = Column(UUID(as_uuid=True), ForeignKey("riders.id"), nullable=False)
    vehicle_id          = Column(UUID(as_uuid=True), ForeignKey("vehicles.id"))
    pickup_lat          = Column(Numeric(10, 8), nullable=False)
    pickup_lng          = Column(Numeric(11, 8), nullable=False)
    pickup_address      = Column(Text, nullable=False)
    destination_lat     = Column(Numeric(10, 8), nullable=False)
    destination_lng     = Column(Numeric(11, 8), nullable=False)
    destination_address = Column(Text, nullable=False)
    status              = Column(String(20), default="accepted")
    rider_arrived_at    = Column(DateTime(timezone=True))
    ride_started_at     = Column(DateTime(timezone=True))
    ride_ended_at       = Column(DateTime(timezone=True))
    estimated_fare      = Column(Numeric(8, 2))
    base_fare           = Column(Numeric(8, 2), default=20.00)
    distance_km         = Column(Numeric(8, 2))
    distance_fare       = Column(Numeric(8, 2))
    waiting_minutes     = Column(Integer, default=0)
    waiting_fare        = Column(Numeric(8, 2), default=0)
    total_fare          = Column(Numeric(8, 2))
    ride_otp            = Column(String(4))
    otp_verified        = Column(Boolean, default=False)
    cancelled_by        = Column(String(10))
    cancellation_reason = Column(Text)
    cancelled_at        = Column(DateTime(timezone=True))
    user                = relationship("User", back_populates="rides", foreign_keys=[user_id])
    rider               = relationship("Rider", back_populates="rides", foreign_keys=[rider_id])
    payment             = relationship("Payment", back_populates="ride", uselist=False)
    rating              = relationship("Rating", back_populates="ride", uselist=False)
    sos_alerts          = relationship("SOSAlert", back_populates="ride")


class Payment(Base, TimestampMixin):
    __tablename__ = "payments"
    id             = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    ride_id        = Column(UUID(as_uuid=True), ForeignKey("rides.id"), unique=True, nullable=False)
    user_id        = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    rider_id       = Column(UUID(as_uuid=True), ForeignKey("riders.id"), nullable=False)
    amount         = Column(Numeric(8, 2), nullable=False)
    payment_method = Column(String(30), default="cash")
    payment_status = Column(String(20), default="pending")
    transaction_id = Column(String(100))
    upi_ref        = Column(String(100))
    paid_at        = Column(DateTime(timezone=True))
    ride           = relationship("Ride", back_populates="payment")


class Rating(Base):
    __tablename__ = "ratings"
    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    ride_id    = Column(UUID(as_uuid=True), ForeignKey("rides.id"), unique=True, nullable=False)
    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    rider_id   = Column(UUID(as_uuid=True), ForeignKey("riders.id"), nullable=False)
    rating     = Column(Integer, nullable=False)
    feedback   = Column(Text)
    tags       = Column(ARRAY(String(50)))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    ride       = relationship("Ride", back_populates="rating")
    user       = relationship("User", back_populates="ratings")
    rider      = relationship("Rider", back_populates="ratings")


class Notification(Base):
    __tablename__ = "notifications"
    id                = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    recipient_type    = Column(String(10), nullable=False)
    recipient_id      = Column(UUID(as_uuid=True), nullable=False)
    fcm_token         = Column(String(500))
    title             = Column(String(200), nullable=False)
    body              = Column(Text, nullable=False)
    data              = Column(JSONB)
    is_sent           = Column(Boolean, default=False)
    is_read           = Column(Boolean, default=False)
    sent_at           = Column(DateTime(timezone=True))
    notification_type = Column(String(50))
    created_at        = Column(DateTime(timezone=True), server_default=func.now())


class FCMToken(Base, TimestampMixin):
    __tablename__ = "fcm_tokens"
    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_type  = Column(String(10), nullable=False)
    owner_id    = Column(UUID(as_uuid=True), nullable=False)
    fcm_token   = Column(String(500), nullable=False)
    device_type = Column(String(20))
    is_active   = Column(Boolean, default=True)


class SOSAlert(Base):
    __tablename__ = "sos_alerts"
    id           = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    ride_id      = Column(UUID(as_uuid=True), ForeignKey("rides.id"), nullable=False)
    user_id      = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    rider_id     = Column(UUID(as_uuid=True), ForeignKey("riders.id"), nullable=False)
    sos_lat      = Column(Numeric(10, 8))
    sos_lng      = Column(Numeric(11, 8))
    status       = Column(String(20), default="active")
    resolved_by  = Column(UUID(as_uuid=True), ForeignKey("admin_users.id"))
    resolved_at  = Column(DateTime(timezone=True))
    notes        = Column(Text)
    triggered_at = Column(DateTime(timezone=True), server_default=func.now())
    created_at   = Column(DateTime(timezone=True), server_default=func.now())
    ride         = relationship("Ride", back_populates="sos_alerts")
    user         = relationship("User", back_populates="sos_alerts")


class RiderLocationHistory(Base):
    __tablename__ = "rider_location_history"
    id          = Column(Integer, primary_key=True, autoincrement=True)
    rider_id    = Column(UUID(as_uuid=True), ForeignKey("riders.id"), nullable=False)
    ride_id     = Column(UUID(as_uuid=True), ForeignKey("rides.id"))
    latitude    = Column(Numeric(10, 8), nullable=False)
    longitude   = Column(Numeric(11, 8), nullable=False)
    speed       = Column(Numeric(5, 2))
    heading     = Column(Numeric(5, 2))
    recorded_at = Column(DateTime(timezone=True), server_default=func.now())