from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timezone, timedelta
import random

from app.database import get_db
from app.models import Rider, Ride, RideRequest, Payment, Vehicle, User
from app.auth import get_current_rider

router = APIRouter()

def to_naive_utc(dt):
    if dt is None:
        return None
    if hasattr(dt, "tzinfo") and dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt

class LocationUpdate(BaseModel):
    latitude: float
    longitude: float
    speed: Optional[float] = None
    heading: Optional[float] = None

@router.get("/profile")
def get_rider_profile(current_rider: Rider = Depends(get_current_rider)):
    return {
        "id": str(current_rider.id),
        "full_name": current_rider.full_name,
        "mobile_number": current_rider.mobile_number,
        "profile_photo": current_rider.profile_photo,
        "verification_status": current_rider.verification_status,
        "rejection_reason": current_rider.rejection_reason,
        "is_blocked": current_rider.is_blocked,
        "block_reason": current_rider.block_reason,
        "is_online": current_rider.is_online,
        "total_rides": current_rider.total_rides,
        "total_earnings": float(current_rider.total_earnings or 0),
        "average_rating": float(current_rider.average_rating or 0),
        "total_ratings": current_rider.total_ratings
    }

@router.post("/toggle-online")
def toggle_online_status(current_rider: Rider = Depends(get_current_rider), db: Session = Depends(get_db)):
    if current_rider.is_blocked:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Your account has been blocked by Admin.")
    if current_rider.verification_status != "approved":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Your account is not approved yet.")
    current_rider.is_online = not current_rider.is_online
    db.commit()
    return {
        "is_online": current_rider.is_online,
        "message": "You are now Online! Ready to accept rides." if current_rider.is_online else "You are now Offline."
    }

@router.post("/location")
def update_location(location: LocationUpdate, current_rider: Rider = Depends(get_current_rider), db: Session = Depends(get_db)):
    current_rider.last_location_lat = location.latitude
    current_rider.last_location_lng = location.longitude
    current_rider.last_location_updated = datetime.utcnow()
    db.commit()
    return {"message": "Location updated", "timestamp": datetime.utcnow().isoformat()}

@router.get("/available-rides")
def get_available_rides(current_rider: Rider = Depends(get_current_rider), db: Session = Depends(get_db)):
    if current_rider.is_blocked:
        return {"rides": [], "message": "Your account is blocked."}
    if not current_rider.is_online:
        return {"rides": [], "message": "You are offline. Go online to see rides."}
    if current_rider.verification_status != "approved":
        return {"rides": [], "message": "Account not verified yet."}

    # Return ride requests currently offered to this rider within 30s window OR unassigned
    now = datetime.utcnow()
    requests = db.query(RideRequest).filter(
        and_(
            or_(
                RideRequest.current_offered_rider_id == current_rider.id,
                and_(
                    RideRequest.status.in_(["SEARCHING", "OFFERED", "searching"]),
                    RideRequest.current_offered_rider_id == None
                )
            ),
            RideRequest.status.in_(["OFFERED", "SEARCHING", "searching"]),
            or_(RideRequest.expires_at == None, RideRequest.expires_at > now)
        )
    ).order_by(RideRequest.created_at.desc()).limit(5).all()

    valid_offers = []
    for r in requests:
        remaining_sec = 30
        if r.offer_expires_at:
            exp = to_naive_utc(r.offer_expires_at)
            remaining_sec = max(0, int((exp - now).total_seconds()))
            if remaining_sec == 0:
                continue  # expired
        valid_offers.append({
            "request_id": str(r.id),
            "pickup_address": r.pickup_address,
            "pickup_lat": float(r.pickup_lat),
            "pickup_lng": float(r.pickup_lng),
            "destination_address": r.destination_address,
            "destination_lat": float(r.destination_lat),
            "destination_lng": float(r.destination_lng),
            "vehicle_type": r.vehicle_type or "bike",
            "payment_method": r.payment_method or "cash",
            "estimated_fare": float(r.estimated_fare or 0),
            "estimated_distance": float(r.estimated_distance or 0),
            "expires_in_seconds": remaining_sec
        })

    return {"rides": valid_offers}

@router.post("/rides/{request_id}/reject")
def reject_ride(
    request_id: str,
    current_rider: Rider = Depends(get_current_rider),
    db: Session = Depends(get_db)
):
    from app.routers.rides import offer_ride_to_next_candidate
    ride_request = db.query(RideRequest).filter(
        RideRequest.id == request_id,
        RideRequest.status.in_(["OFFERED", "SEARCHING", "searching"]),
        RideRequest.expires_at > datetime.utcnow()
    ).first()

    if not ride_request:
        raise HTTPException(status_code=404, detail="Ride request not found or already closed")

    rejected = list(ride_request.rejected_rider_ids or [])
    if current_rider.id not in rejected:
        rejected.append(current_rider.id)
    ride_request.rejected_rider_ids = rejected
    db.commit()

    # Immediately advance to next nearest driver candidate
    offer_ride_to_next_candidate(db, ride_request)

    return {"message": "Ride rejected. Finding next driver."}

@router.post("/rides/{request_id}/accept")
def accept_ride(request_id: str, current_rider: Rider = Depends(get_current_rider), db: Session = Depends(get_db)):
    ride_request = db.query(RideRequest).filter(
        RideRequest.id == request_id,
        RideRequest.status.in_(["OFFERED", "SEARCHING", "searching"]),
        RideRequest.expires_at > datetime.utcnow()
    ).first()

    if not ride_request:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Ride request not available or expired")

    ride_request.status = "ASSIGNED"
    ride_request.accepted_by_rider = current_rider.id
    ride_request.accepted_at = datetime.utcnow()

    # Generate 4-digit safety OTP for passenger pickup
    otp = ''.join([str(random.randint(0, 9)) for _ in range(4)])

    vehicle = db.query(Vehicle).filter(Vehicle.rider_id == current_rider.id).first()

    ride = Ride(
        request_id=ride_request.id,
        user_id=ride_request.user_id,
        rider_id=current_rider.id,
        vehicle_id=vehicle.id if vehicle else None,
        vehicle_type=ride_request.vehicle_type or "bike",
        payment_method=ride_request.payment_method or "cash",
        payment_status="pending",
        pickup_lat=ride_request.pickup_lat,
        pickup_lng=ride_request.pickup_lng,
        pickup_address=ride_request.pickup_address,
        destination_lat=ride_request.destination_lat,
        destination_lng=ride_request.destination_lng,
        destination_address=ride_request.destination_address,
        status="ASSIGNED",
        estimated_fare=ride_request.estimated_fare,
        base_fare=20.0 if (ride_request.vehicle_type or "bike") == "bike" else 30.0,
        distance_km=ride_request.estimated_distance,
        distance_fare=float(ride_request.estimated_fare or 0) - (20.0 if (ride_request.vehicle_type or "bike") == "bike" else 30.0),
        total_fare=ride_request.estimated_fare,
        ride_otp=otp,
        otp_verified=False,
    )
    db.add(ride)
    db.commit()
    db.refresh(ride)

    user = db.query(User).filter(User.id == ride_request.user_id).first()

    return {
        "message": "Ride accepted! Navigate to customer pickup location.",
        "ride_id": str(ride.id),
        "status": "ASSIGNED",
        "customer_name": user.full_name if user else "Customer",
        "customer_mobile": user.mobile_number if user else "",
        "pickup_address": ride.pickup_address,
        "pickup_lat": float(ride.pickup_lat),
        "pickup_lng": float(ride.pickup_lng),
        "destination_address": ride.destination_address,
        "destination_lat": float(ride.destination_lat),
        "destination_lng": float(ride.destination_lng),
        "fare": float(ride.total_fare or 0),
        "payment_method": ride.payment_method
    }

@router.post("/rides/{ride_id}/arrived")
def mark_arrived(ride_id: str, current_rider: Rider = Depends(get_current_rider), db: Session = Depends(get_db)):
    ride = db.query(Ride).filter(
        Ride.id == ride_id,
        Ride.rider_id == current_rider.id,
        Ride.status.in_(["ASSIGNED", "DRIVER_ARRIVING", "accepted", "rider_arriving"])
    ).first()
    if not ride:
        raise HTTPException(status_code=404, detail="Active ride not found")
    
    ride.status = "DRIVER_ARRIVED"
    ride.rider_arrived_at = datetime.utcnow()
    db.commit()
    return {"message": "Marked as arrived at pickup location. Please ask customer for 4-digit OTP."}

@router.post("/rides/{ride_id}/start")
def start_ride(
    ride_id: str,
    otp: str,
    current_rider: Rider = Depends(get_current_rider),
    db: Session = Depends(get_db)
):
    """Verify 4-digit OTP and transition to IN_PROGRESS"""
    ride = db.query(Ride).filter(
        Ride.id == ride_id,
        Ride.rider_id == current_rider.id,
        Ride.status.in_(["DRIVER_ARRIVED", "ASSIGNED", "rider_arriving", "accepted"])
    ).first()

    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found or already started")

    # OTP verification
    if ride.ride_otp != otp.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid 4-digit OTP. Please ask customer for the correct OTP."
        )

    ride.status = "IN_PROGRESS"
    ride.ride_started_at = datetime.utcnow()
    ride.otp_verified = True
    db.commit()

    return {
        "message": "OTP Verified! Ride started. Navigate to destination.",
        "status": "IN_PROGRESS",
        "destination_address": ride.destination_address,
        "destination_lat": float(ride.destination_lat),
        "destination_lng": float(ride.destination_lng)
    }

@router.post("/rides/{ride_id}/complete")
def complete_ride(ride_id: str, current_rider: Rider = Depends(get_current_rider), db: Session = Depends(get_db)):
    ride = db.query(Ride).filter(
        Ride.id == ride_id,
        Ride.rider_id == current_rider.id,
        Ride.status.in_(["IN_PROGRESS", "ride_started"])
    ).first()
    if not ride:
        raise HTTPException(status_code=404, detail="Active in-progress ride not found")

    ride.status = "COMPLETED"
    ride.ride_ended_at = datetime.utcnow()

    # Calculate waiting time fare if any
    if ride.rider_arrived_at and ride.ride_started_at:
        waiting_minutes = max(0, int((ride.ride_started_at - ride.rider_arrived_at).total_seconds() / 60))
        ride.waiting_minutes = waiting_minutes
        ride.waiting_fare = waiting_minutes * (1.0 if (ride.vehicle_type or "bike") == "bike" else 1.5)
        ride.total_fare = float(ride.base_fare or 20) + float(ride.distance_fare or 0) + float(ride.waiting_fare or 0)

    db.commit()

    return {
        "message": "Destination reached! Please collect payment.",
        "status": "COMPLETED",
        "total_fare": float(ride.total_fare or 0),
        "payment_method": ride.payment_method or "cash",
        "payment_status": ride.payment_status or "pending",
        "ride_summary": {
            "distance_km": float(ride.distance_km or 0),
            "base_fare": float(ride.base_fare or 20),
            "waiting_minutes": ride.waiting_minutes or 0,
            "total_fare": float(ride.total_fare or 0)
        }
    }

@router.post("/rides/{ride_id}/confirm-payment")
def confirm_payment(ride_id: str, current_rider: Rider = Depends(get_current_rider), db: Session = Depends(get_db)):
    ride = db.query(Ride).filter(
        Ride.id == ride_id,
        Ride.rider_id == current_rider.id,
        Ride.status.in_(["COMPLETED", "completed"])
    ).first()
    if not ride:
        raise HTTPException(status_code=404, detail="Completed ride not found")

    ride.payment_status = "completed"
    ride.status = "PAYMENT_COMPLETED"

    # Record Payment entry
    payment = db.query(Payment).filter(Payment.ride_id == ride.id).first()
    if not payment:
        payment = Payment(
            ride_id=ride.id,
            user_id=ride.user_id,
            rider_id=current_rider.id,
            amount=ride.total_fare or 0,
            payment_method=ride.payment_method or "cash",
            payment_status="completed",
            paid_at=datetime.utcnow()
        )
        db.add(payment)
    else:
        payment.payment_status = "completed"
        payment.paid_at = datetime.utcnow()

    # Update driver lifetime stats
    current_rider.total_rides = (current_rider.total_rides or 0) + 1
    current_rider.total_earnings = float(current_rider.total_earnings or 0) + float(ride.total_fare or 0)
    db.commit()

    return {
        "message": "Payment confirmed! Ready for next ride.",
        "status": "PAYMENT_COMPLETED",
        "amount_collected": float(ride.total_fare or 0)
    }

@router.get("/earnings")
def get_earnings(period: str = "today", current_rider: Rider = Depends(get_current_rider), db: Session = Depends(get_db)):
    now = datetime.utcnow()
    if period == "today":
        start_date = now.replace(hour=0, minute=0, second=0)
    elif period == "week":
        start_date = now - timedelta(days=7)
    elif period == "month":
        start_date = now - timedelta(days=30)
    else:
        start_date = now.replace(hour=0, minute=0, second=0)

    rides = db.query(Ride).filter(
        Ride.rider_id == current_rider.id,
        Ride.status == "completed",
        Ride.ride_ended_at >= start_date
    ).all()

    total_earnings = sum(float(r.total_fare or 0) for r in rides)
    total_rides = len(rides)

    return {
        "period": period,
        "total_earnings": round(total_earnings, 2),
        "total_rides": total_rides,
        "average_per_ride": round(total_earnings / total_rides, 2) if total_rides > 0 else 0,
        "all_time_earnings": float(current_rider.total_earnings or 0),
        "all_time_rides": current_rider.total_rides
    }

@router.get("/ride-history")
def get_ride_history(page: int = 1, limit: int = 10, current_rider: Rider = Depends(get_current_rider), db: Session = Depends(get_db)):
    offset = (page - 1) * limit
    rides = db.query(Ride).filter(Ride.rider_id == current_rider.id, Ride.status == "completed").order_by(Ride.created_at.desc()).offset(offset).limit(limit).all()
    return {
        "rides": [{"ride_id": str(r.id), "pickup": r.pickup_address, "destination": r.destination_address, "fare": float(r.total_fare or 0), "distance": float(r.distance_km or 0), "date": r.created_at.isoformat()} for r in rides],
        "page": page, "limit": limit
    }

class UnlockAppealRequest(BaseModel):
    message: str

@router.post("/request-unlock")
def request_account_unlock(
    request: UnlockAppealRequest,
    current_rider: Rider = Depends(get_current_rider),
    db: Session = Depends(get_db)
):
    if not current_rider.is_blocked:
        raise HTTPException(status_code=400, detail="Your account is not blocked.")
    
    current_rider.unlock_request_message = request.message
    db.commit()
    return {"message": "Unlock appeal submitted to Admin successfully."}