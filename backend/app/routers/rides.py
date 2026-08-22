from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import and_
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timedelta
import math

from app.database import get_db
from app.models import User, Rider, Ride, RideRequest, Payment, Rating
from app.auth import get_current_user, get_current_rider
from app.config import settings

router = APIRouter()

class BookRideRequest(BaseModel):
    pickup_lat: float
    pickup_lng: float
    pickup_address: str
    destination_lat: float
    destination_lng: float
    destination_address: str

class FareEstimateRequest(BaseModel):
    pickup_lat: float
    pickup_lng: float
    destination_lat: float
    destination_lng: float

class RatingRequest(BaseModel):
    rating: int
    feedback: Optional[str] = None
    tags: Optional[List[str]] = None

def calculate_distance(lat1, lng1, lat2, lng2) -> float:
    R = 6371
    lat1, lng1, lat2, lng2 = map(math.radians, [lat1, lng1, lat2, lng2])
    dlat = lat2 - lat1
    dlng = lng2 - lng1
    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng/2)**2
    c = 2 * math.asin(math.sqrt(a))
    return R * c

def calculate_fare(distance_km: float, waiting_minutes: int = 0) -> dict:
    base_fare = settings.BASE_FARE
    distance_fare = round(distance_km * settings.PER_KM_FARE, 2)
    waiting_fare = round(waiting_minutes * settings.WAITING_FARE_PER_MIN, 2)
    total = round(base_fare + distance_fare + waiting_fare, 2)
    return {
        "base_fare": base_fare,
        "distance_km": round(distance_km, 2),
        "distance_fare": distance_fare,
        "waiting_minutes": waiting_minutes,
        "waiting_fare": waiting_fare,
        "total_fare": total
    }

def find_nearby_riders(db: Session, lat: float, lng: float, radius_km: float = 5.0):
    lat_diff = radius_km / 111.0
    lng_diff = radius_km / (111.0 * math.cos(math.radians(lat)))

    riders = db.query(Rider).filter(
        and_(
            Rider.is_online == True,
            Rider.verification_status == "approved",
            Rider.is_active == True,
            Rider.is_blocked == False,
            Rider.last_location_lat.between(lat - lat_diff, lat + lat_diff),
            Rider.last_location_lng.between(lng - lng_diff, lng + lng_diff)
        )
    ).all()

    nearby = []
    for rider in riders:
        if rider.last_location_lat and rider.last_location_lng:
            dist = calculate_distance(lat, lng, float(rider.last_location_lat), float(rider.last_location_lng))
            if dist <= radius_km:
                nearby.append((rider, dist))

    nearby.sort(key=lambda x: x[1])
    return nearby

@router.post("/estimate")
def get_fare_estimate(request: FareEstimateRequest, current_user: User = Depends(get_current_user)):
    distance = calculate_distance(request.pickup_lat, request.pickup_lng, request.destination_lat, request.destination_lng)
    fare = calculate_fare(distance)
    estimated_time = int(distance * 3)
    return {**fare, "estimated_time_minutes": estimated_time, "currency": "INR"}

@router.post("/book")
def book_ride(request: BookRideRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    distance = calculate_distance(request.pickup_lat, request.pickup_lng, request.destination_lat, request.destination_lng)
    fare = calculate_fare(distance)

    ride_request = RideRequest(
        user_id=current_user.id,
        pickup_lat=request.pickup_lat,
        pickup_lng=request.pickup_lng,
        pickup_address=request.pickup_address,
        destination_lat=request.destination_lat,
        destination_lng=request.destination_lng,
        destination_address=request.destination_address,
        estimated_distance=distance,
        estimated_fare=fare["total_fare"],
        status="searching",
        expires_at=datetime.utcnow() + timedelta(minutes=settings.RIDE_REQUEST_EXPIRE_MINUTES)
    )
    db.add(ride_request)
    db.commit()
    db.refresh(ride_request)

    nearby_riders = find_nearby_riders(db, request.pickup_lat, request.pickup_lng)

    return {
        "ride_request_id": str(ride_request.id),
        "status": "searching",
        "fare_estimate": fare,
        "nearby_riders_count": len(nearby_riders),
        "message": "Searching for nearby riders...",
        "expires_at": ride_request.expires_at.isoformat()
    }

@router.get("/request/{request_id}/status")
def get_request_status(request_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    ride_request = db.query(RideRequest).filter(RideRequest.id == request_id, RideRequest.user_id == current_user.id).first()
    if not ride_request:
        raise HTTPException(status_code=404, detail="Ride request not found")

    response = {"request_id": str(ride_request.id), "status": ride_request.status}

    if ride_request.status == "accepted" and ride_request.accepted_by_rider:
        ride = db.query(Ride).filter(Ride.request_id == ride_request.id).first()
        if ride:
            rider = db.query(Rider).filter(Rider.id == ride.rider_id).first()
            response["ride"] = {
                "ride_id": str(ride.id),
                "rider_name": rider.full_name,
                "rider_mobile": rider.mobile_number,
                "rider_rating": float(rider.average_rating or 0),
                "ride_status": ride.status,
                "total_fare": float(ride.total_fare or ride.estimated_fare)
            }
    return response

@router.get("/active")
def get_active_ride(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    ride = db.query(Ride).filter(
        Ride.user_id == current_user.id,
        Ride.status.in_(["accepted", "rider_arriving", "ride_started"])
    ).first()

    if not ride:
        return {"active_ride": None}

    rider = db.query(Rider).filter(Rider.id == ride.rider_id).first()

    return {
        "active_ride": {
            "ride_id": str(ride.id),
            "status": ride.status,
            "pickup_address": ride.pickup_address,
            "destination_address": ride.destination_address,
            "ride_otp": ride.ride_otp,
            "rider": {
                "name": rider.full_name,
                "mobile": rider.mobile_number,
                "rating": float(rider.average_rating or 0),
                "current_lat": float(rider.last_location_lat or 0),
                "current_lng": float(rider.last_location_lng or 0),
            },
            "fare": float(ride.total_fare or ride.estimated_fare or 0)
        }
    }

@router.get("/history")
def get_ride_history(page: int = 1, limit: int = 10, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    offset = (page - 1) * limit
    rides = db.query(Ride).filter(Ride.user_id == current_user.id, Ride.status == "completed").order_by(Ride.created_at.desc()).offset(offset).limit(limit).all()
    return {
        "rides": [{"ride_id": str(r.id), "pickup": r.pickup_address, "destination": r.destination_address, "fare": float(r.total_fare or 0), "date": r.created_at.isoformat(), "status": r.status} for r in rides],
        "page": page, "limit": limit
    }

@router.post("/{ride_id}/cancel")
def cancel_ride(ride_id: str, reason: str = "User cancelled", current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    ride = db.query(Ride).filter(Ride.id == ride_id, Ride.user_id == current_user.id, Ride.status.in_(["accepted", "rider_arriving"])).first()
    if not ride:
        raise HTTPException(status_code=404, detail="Active ride not found")
    ride.status = "cancelled"
    ride.cancelled_by = "user"
    ride.cancellation_reason = reason
    ride.cancelled_at = datetime.utcnow()
    db.commit()
    return {"message": "Ride cancelled successfully"}

@router.post("/{ride_id}/rate")
def rate_ride(ride_id: str, request: RatingRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if request.rating < 1 or request.rating > 5:
        raise HTTPException(status_code=400, detail="Rating must be between 1 and 5")
    ride = db.query(Ride).filter(Ride.id == ride_id, Ride.user_id == current_user.id, Ride.status == "completed").first()
    if not ride:
        raise HTTPException(status_code=404, detail="Completed ride not found")
    existing = db.query(Rating).filter(Rating.ride_id == ride.id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Already rated this ride")
    rating = Rating(ride_id=ride.id, user_id=current_user.id, rider_id=ride.rider_id, rating=request.rating, feedback=request.feedback, tags=request.tags)
    db.add(rating)
    rider = db.query(Rider).filter(Rider.id == ride.rider_id).first()
    if rider:
        total = float(rider.average_rating or 0) * rider.total_ratings
        rider.total_ratings += 1
        rider.average_rating = round((total + request.rating) / rider.total_ratings, 2)
    db.commit()
    return {"message": "Rating submitted successfully", "rating": request.rating}