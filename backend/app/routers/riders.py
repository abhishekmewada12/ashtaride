from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timedelta
import random

from app.database import get_db
from app.models import Rider, Ride, RideRequest, Payment
from app.auth import get_current_rider

router = APIRouter()

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
        "is_blocked": current_rider.is_blocked,             # <--- Ye line add karein
        "block_reason": current_rider.block_reason,         # <--- Ye line add karein
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

    requests = db.query(RideRequest).filter(
        RideRequest.status == "searching",
        RideRequest.expires_at > datetime.utcnow()
    ).order_by(RideRequest.created_at.desc()).limit(10).all()

    return {
        "rides": [
            {
                "request_id": str(r.id),
                "pickup_address": r.pickup_address,
                "destination_address": r.destination_address,
                "estimated_fare": float(r.estimated_fare or 0),
                "estimated_distance": float(r.estimated_distance or 0),
                "expires_in_seconds": max(0, int((r.expires_at - datetime.utcnow()).total_seconds()))
            }
            for r in requests
        ]
    }

@router.post("/rides/{request_id}/reject")
def reject_ride(
    request_id: str,
    current_rider: Rider = Depends(get_current_rider),
    db: Session = Depends(get_db)
):
    ride_request = db.query(RideRequest).filter(
        RideRequest.id == request_id,
        RideRequest.status == "searching",
        RideRequest.expires_at > datetime.utcnow()
    ).first()

    if not ride_request:
        raise HTTPException(status_code=404, detail="Ride request not found")

    notified = list(ride_request.notified_riders or [])
    notified.append(current_rider.id)
    ride_request.notified_riders = notified
    db.commit()

    return {"message": "Ride rejected successfully"}

@router.post("/rides/{request_id}/accept")
def accept_ride(request_id: str, current_rider: Rider = Depends(get_current_rider), db: Session = Depends(get_db)):
    ride_request = db.query(RideRequest).filter(
        RideRequest.id == request_id,
        RideRequest.status == "searching",
        RideRequest.expires_at > datetime.utcnow()
    ).first()

    if not ride_request:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Ride request not available or expired")

    ride_request.status = "accepted"
    ride_request.accepted_by_rider = current_rider.id
    ride_request.accepted_at = datetime.utcnow()

    # OTP generate karo
    otp = ''.join([str(random.randint(0, 9)) for _ in range(4)])

    ride = Ride(
        request_id=ride_request.id,
        user_id=ride_request.user_id,
        rider_id=current_rider.id,
        pickup_lat=ride_request.pickup_lat,
        pickup_lng=ride_request.pickup_lng,
        pickup_address=ride_request.pickup_address,
        destination_lat=ride_request.destination_lat,
        destination_lng=ride_request.destination_lng,
        destination_address=ride_request.destination_address,
        status="accepted",
        estimated_fare=ride_request.estimated_fare,
        base_fare=20.0,
        distance_km=ride_request.estimated_distance,
        distance_fare=float(ride_request.estimated_distance or 0) * 8,
        total_fare=ride_request.estimated_fare,
        ride_otp=otp,
        otp_verified=False,
    )
    db.add(ride)
    db.commit()
    db.refresh(ride)

    return {
        "message": "Ride accepted! Navigate to pickup location.",
        "ride_id": str(ride.id),
        "pickup_address": ride.pickup_address,
        "pickup_lat": float(ride.pickup_lat),
        "pickup_lng": float(ride.pickup_lng),
        "destination_address": ride.destination_address,
        "fare": float(ride.total_fare or 0)
    }

@router.post("/rides/{ride_id}/arrived")
def mark_arrived(ride_id: str, current_rider: Rider = Depends(get_current_rider), db: Session = Depends(get_db)):
    ride = db.query(Ride).filter(Ride.id == ride_id, Ride.rider_id == current_rider.id, Ride.status == "accepted").first()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")
    ride.status = "rider_arriving"
    ride.rider_arrived_at = datetime.utcnow()
    db.commit()
    return {"message": "Marked as arrived at pickup location"}

@router.post("/rides/{ride_id}/start")
def start_ride(
    ride_id: str,
    otp: str,
    current_rider: Rider = Depends(get_current_rider),
    db: Session = Depends(get_db)
):
    """OTP verify karke ride start karo"""
    ride = db.query(Ride).filter(
        Ride.id == ride_id,
        Ride.rider_id == current_rider.id,
        Ride.status == "rider_arriving"
    ).first()

    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")

    # OTP verify karo
    if ride.ride_otp != otp:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid OTP. Please ask customer for correct OTP."
        )

    ride.status = "ride_started"
    ride.ride_started_at = datetime.utcnow()
    ride.otp_verified = True
    db.commit()

    return {
        "message": "Ride started! Navigate to destination.",
        "destination_address": ride.destination_address,
        "destination_lat": float(ride.destination_lat),
        "destination_lng": float(ride.destination_lng)
    }

@router.post("/rides/{ride_id}/complete")
def complete_ride(ride_id: str, current_rider: Rider = Depends(get_current_rider), db: Session = Depends(get_db)):
    ride = db.query(Ride).filter(Ride.id == ride_id, Ride.rider_id == current_rider.id, Ride.status == "ride_started").first()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")

    ride.status = "completed"
    ride.ride_ended_at = datetime.utcnow()

    if ride.rider_arrived_at and ride.ride_started_at:
        waiting_minutes = int((ride.ride_started_at - ride.rider_arrived_at).total_seconds() / 60)
        ride.waiting_minutes = waiting_minutes
        ride.waiting_fare = waiting_minutes * 1.0
        ride.total_fare = float(ride.base_fare or 20) + float(ride.distance_fare or 0) + float(ride.waiting_fare or 0)

    payment = Payment(
        ride_id=ride.id,
        user_id=ride.user_id,
        rider_id=current_rider.id,
        amount=ride.total_fare,
        payment_method="cash",
        payment_status="completed",
        paid_at=datetime.utcnow()
    )
    db.add(payment)

    current_rider.total_rides += 1
    current_rider.total_earnings = float(current_rider.total_earnings or 0) + float(ride.total_fare or 0)
    db.commit()

    return {
        "message": "Ride completed successfully!",
        "ride_summary": {
            "distance_km": float(ride.distance_km or 0),
            "base_fare": float(ride.base_fare or 20),
            "distance_fare": float(ride.distance_fare or 0),
            "waiting_fare": float(ride.waiting_fare or 0),
            "total_fare": float(ride.total_fare or 0),
            "payment_method": "cash"
        }
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