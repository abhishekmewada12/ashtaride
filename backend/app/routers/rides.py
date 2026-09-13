from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timedelta
import math
import random

from app.database import get_db
from app.models import User, Rider, Ride, RideRequest, Payment, Rating, Vehicle
from app.auth import get_current_user, get_current_rider
from app.config import settings

router = APIRouter()

# ================= FARE CONFIGURATION =================
FARE_CONFIG = {
    "bike": {
        "base_fare": 20.0,
        "per_km_fare": 8.0,
        "waiting_fare_per_min": 1.0,
        "label": "Bike",
        "speed_km_per_min": 0.45  # ~27 km/h in city
    },
    "auto": {
        "base_fare": 30.0,
        "per_km_fare": 12.0,
        "waiting_fare_per_min": 1.5,
        "label": "Auto",
        "speed_km_per_min": 0.35  # ~21 km/h in city
    }
}

class BookRideRequest(BaseModel):
    pickup_lat: float
    pickup_lng: float
    pickup_address: str
    destination_lat: float
    destination_lng: float
    destination_address: str
    vehicle_type: Optional[str] = "bike"
    payment_method: Optional[str] = "cash"

class FareEstimateRequest(BaseModel):
    pickup_lat: float
    pickup_lng: float
    destination_lat: float
    destination_lng: float
    vehicle_type: Optional[str] = None  # None returns both bike & auto

class RatingRequest(BaseModel):
    rating: int
    feedback: Optional[str] = None
    tags: Optional[List[str]] = None

def calculate_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    R = 6371.0
    lat1_r, lng1_r, lat2_r, lng2_r = map(math.radians, [lat1, lng1, lat2, lng2])
    dlat = lat2_r - lat1_r
    dlng = lng2_r - lng1_r
    a = math.sin(dlat/2)**2 + math.cos(lat1_r) * math.cos(lat2_r) * math.sin(dlng/2)**2
    c = 2 * math.asin(math.sqrt(a))
    return round(R * c, 2)

def calculate_vehicle_fare(distance_km: float, vehicle_type: str = "bike", waiting_minutes: int = 0) -> dict:
    config = FARE_CONFIG.get(vehicle_type.lower(), FARE_CONFIG["bike"])
    base_fare = config["base_fare"]
    distance_fare = round(distance_km * config["per_km_fare"], 2)
    waiting_fare = round(waiting_minutes * config["waiting_fare_per_min"], 2)
    total = round(base_fare + distance_fare + waiting_fare, 2)
    eta_mins = max(2, int(distance_km / config["speed_km_per_min"]))
    
    return {
        "vehicle_type": vehicle_type.lower(),
        "label": config["label"],
        "base_fare": base_fare,
        "distance_km": round(distance_km, 2),
        "distance_fare": distance_fare,
        "waiting_minutes": waiting_minutes,
        "waiting_fare": waiting_fare,
        "total_fare": total,
        "estimated_time_minutes": eta_mins,
        "currency": "INR"
    }

# ================= SMART SEQUENTIAL DRIVER MATCHING =================
def offer_ride_to_next_candidate(db: Session, ride_request: RideRequest) -> Optional[Rider]:
    """
    Finds the closest available driver who hasn't rejected this ride request yet,
    sets a 30-second exclusive offer window, and sets status to OFFERED.
    """
    radius_km = settings.RIDER_SEARCH_RADIUS_KM or 5.0
    lat = float(ride_request.pickup_lat)
    lng = float(ride_request.pickup_lng)
    
    lat_diff = radius_km / 111.0
    lng_diff = radius_km / (111.0 * math.cos(math.radians(lat)))

    rejected_ids = ride_request.rejected_rider_ids or []

    # 1. Query online, approved, active, unblocked riders
    query = db.query(Rider).filter(
        and_(
            Rider.is_online == True,
            Rider.verification_status == "approved",
            Rider.is_active == True,
            Rider.is_blocked == False,
            Rider.last_location_lat.between(lat - lat_diff, lat + lat_diff),
            Rider.last_location_lng.between(lng - lng_diff, lng + lng_diff),
            ~Rider.id.in_(rejected_ids) if rejected_ids else True
        )
    )
    riders = query.all()

    # 2. Filter out drivers currently occupied with an active ongoing ride
    active_busy_rider_ids = [
        r[0] for r in db.query(Ride.rider_id).filter(
            Ride.status.in_(["ASSIGNED", "DRIVER_ARRIVING", "DRIVER_ARRIVED", "IN_PROGRESS", "accepted", "rider_arriving", "ride_started"])
        ).all()
    ]

    candidates = []
    for rider in riders:
        if rider.id in active_busy_rider_ids:
            continue
        if rider.last_location_lat and rider.last_location_lng:
            dist = calculate_distance(lat, lng, float(rider.last_location_lat), float(rider.last_location_lng))
            if dist <= radius_km:
                candidates.append((rider, dist))

    # Sort candidates by nearest distance to customer
    candidates.sort(key=lambda x: x[1])

    if not candidates:
        # No more candidate drivers available
        ride_request.status = "CANCELLED_NO_DRIVER"
        ride_request.current_offered_rider_id = None
        ride_request.offer_expires_at = None
        db.commit()
        return None

    # Offer to the closest candidate driver
    best_rider, dist_to_pickup = candidates[0]
    ride_request.current_offered_rider_id = best_rider.id
    ride_request.offer_expires_at = datetime.utcnow() + timedelta(seconds=30)
    ride_request.status = "OFFERED"
    
    notified = list(ride_request.notified_riders or [])
    if best_rider.id not in notified:
        notified.append(best_rider.id)
    ride_request.notified_riders = notified
    
    db.commit()
    db.refresh(ride_request)
    return best_rider

# ================= REST ENDPOINTS =================

@router.post("/estimate")
def get_fare_estimate(request: FareEstimateRequest, current_user: User = Depends(get_current_user)):
    distance = calculate_distance(request.pickup_lat, request.pickup_lng, request.destination_lat, request.destination_lng)
    
    if request.vehicle_type:
        fare = calculate_vehicle_fare(distance, request.vehicle_type)
        return fare
    else:
        # Return both Bike and Auto estimates
        bike_fare = calculate_vehicle_fare(distance, "bike")
        auto_fare = calculate_vehicle_fare(distance, "auto")
        return {
            "distance_km": distance,
            "options": [bike_fare, auto_fare]
        }

@router.post("/book")
def book_ride(request: BookRideRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    v_type = (request.vehicle_type or "bike").lower()
    p_method = (request.payment_method or "cash").lower()
    
    distance = calculate_distance(request.pickup_lat, request.pickup_lng, request.destination_lat, request.destination_lng)
    fare = calculate_vehicle_fare(distance, v_type)

    ride_request = RideRequest(
        user_id=current_user.id,
        pickup_lat=request.pickup_lat,
        pickup_lng=request.pickup_lng,
        pickup_address=request.pickup_address,
        destination_lat=request.destination_lat,
        destination_lng=request.destination_lng,
        destination_address=request.destination_address,
        vehicle_type=v_type,
        payment_method=p_method,
        estimated_distance=distance,
        estimated_fare=fare["total_fare"],
        status="SEARCHING",
        rejected_rider_ids=[],
        notified_riders=[],
        expires_at=datetime.utcnow() + timedelta(minutes=settings.RIDE_REQUEST_EXPIRE_MINUTES)
    )
    db.add(ride_request)
    db.commit()
    db.refresh(ride_request)

    # Immediately offer to the nearest candidate driver
    offered_rider = offer_ride_to_next_candidate(db, ride_request)

    return {
        "ride_request_id": str(ride_request.id),
        "status": ride_request.status,
        "vehicle_type": v_type,
        "payment_method": p_method,
        "fare_estimate": fare,
        "is_driver_offered": offered_rider is not None,
        "message": "Finding closest available driver in Ashta...",
        "expires_at": ride_request.expires_at.isoformat() if ride_request.expires_at else None
    }

@router.get("/request/{request_id}/status")
def get_request_status(request_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    ride_request = db.query(RideRequest).filter(RideRequest.id == request_id, RideRequest.user_id == current_user.id).first()
    if not ride_request:
        raise HTTPException(status_code=404, detail="Ride request not found")

    # Check 30s offer expiry: if current offered driver timed out, advance to next candidate
    if ride_request.status in ["OFFERED", "SEARCHING"] and ride_request.offer_expires_at:
        if datetime.utcnow() > ride_request.offer_expires_at:
            rejected = list(ride_request.rejected_rider_ids or [])
            if ride_request.current_offered_rider_id and ride_request.current_offered_rider_id not in rejected:
                rejected.append(ride_request.current_offered_rider_id)
            ride_request.rejected_rider_ids = rejected
            db.commit()
            offer_ride_to_next_candidate(db, ride_request)
            db.refresh(ride_request)

    response = {
        "request_id": str(ride_request.id),
        "status": ride_request.status,
        "vehicle_type": ride_request.vehicle_type,
        "payment_method": ride_request.payment_method,
        "estimated_fare": float(ride_request.estimated_fare or 0),
    }

    # If assigned / accepted, attach full ride and driver info
    if ride_request.status in ["ASSIGNED", "accepted"] or ride_request.accepted_by_rider:
        ride = db.query(Ride).filter(Ride.request_id == ride_request.id).first()
        if ride:
            rider = db.query(Rider).filter(Rider.id == ride.rider_id).first()
            vehicle = db.query(Vehicle).filter(Vehicle.rider_id == rider.id).first() if rider else None
            response["ride"] = {
                "ride_id": str(ride.id),
                "ride_status": ride.status,
                "ride_otp": ride.ride_otp,
                "total_fare": float(ride.total_fare or ride.estimated_fare or 0),
                "payment_method": ride.payment_method,
                "payment_status": ride.payment_status,
                "rider": {
                    "id": str(rider.id) if rider else None,
                    "name": rider.full_name if rider else "Ashta Rider",
                    "mobile": rider.mobile_number if rider else "",
                    "photo": rider.profile_photo if rider else None,
                    "rating": float(rider.average_rating or 5.0) if rider else 5.0,
                    "current_lat": float(rider.last_location_lat or 0) if rider else 0.0,
                    "current_lng": float(rider.last_location_lng or 0) if rider else 0.0,
                    "vehicle_type": vehicle.vehicle_type if vehicle else (ride.vehicle_type or "bike"),
                    "vehicle_plate": vehicle.plate_number if vehicle else "MP-04-XX-0000",
                    "vehicle_model": f"{vehicle.brand or ''} {vehicle.model or ''}".strip() if vehicle else "Hero Splendor"
                }
            }
    return response

@router.get("/active")
def get_active_ride(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    active_statuses = [
        "ASSIGNED", "DRIVER_ARRIVING", "DRIVER_ARRIVED", "IN_PROGRESS",
        "COMPLETED", "PAYMENT_PENDING",
        "accepted", "rider_arriving", "ride_started"
    ]
    
    ride = db.query(Ride).filter(
        Ride.user_id == current_user.id,
        Ride.status.in_(active_statuses)
    ).order_by(Ride.created_at.desc()).first()

    if not ride:
        return {"active_ride": None}

    rider = db.query(Rider).filter(Rider.id == ride.rider_id).first()
    vehicle = db.query(Vehicle).filter(Vehicle.rider_id == rider.id).first() if rider else None

    return {
        "active_ride": {
            "ride_id": str(ride.id),
            "status": ride.status,
            "vehicle_type": ride.vehicle_type or "bike",
            "payment_method": ride.payment_method or "cash",
            "payment_status": ride.payment_status or "pending",
            "pickup_address": ride.pickup_address,
            "pickup_lat": float(ride.pickup_lat),
            "pickup_lng": float(ride.pickup_lng),
            "destination_address": ride.destination_address,
            "destination_lat": float(ride.destination_lat),
            "destination_lng": float(ride.destination_lng),
            "distance_km": float(ride.distance_km or 0),
            "fare": float(ride.total_fare or ride.estimated_fare or 0),
            "ride_otp": ride.ride_otp,
            "rider": {
                "id": str(rider.id) if rider else None,
                "name": rider.full_name if rider else "Ashta Rider",
                "mobile": rider.mobile_number if rider else "",
                "photo": rider.profile_photo if rider else None,
                "rating": float(rider.average_rating or 5.0) if rider else 5.0,
                "current_lat": float(rider.last_location_lat or 0) if rider else 0.0,
                "current_lng": float(rider.last_location_lng or 0) if rider else 0.0,
                "vehicle_type": vehicle.vehicle_type if vehicle else (ride.vehicle_type or "bike"),
                "vehicle_plate": vehicle.plate_number if vehicle else "MP-04-XX-0000",
                "vehicle_model": f"{vehicle.brand or ''} {vehicle.model or ''}".strip() if vehicle else "Hero Splendor"
            }
        }
    }

@router.get("/history")
def get_ride_history(page: int = 1, limit: int = 10, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    offset = (page - 1) * limit
    completed_statuses = ["COMPLETED", "PAYMENT_COMPLETED", "RATED", "completed"]
    rides = db.query(Ride).filter(
        Ride.user_id == current_user.id,
        Ride.status.in_(completed_statuses)
    ).order_by(Ride.created_at.desc()).offset(offset).limit(limit).all()

    return {
        "rides": [
            {
                "ride_id": str(r.id),
                "pickup": r.pickup_address,
                "destination": r.destination_address,
                "vehicle_type": r.vehicle_type,
                "payment_method": r.payment_method,
                "fare": float(r.total_fare or 0),
                "date": r.created_at.isoformat(),
                "status": r.status
            }
            for r in rides
        ],
        "page": page,
        "limit": limit
    }

@router.post("/{ride_id}/cancel")
def cancel_ride(ride_id: str, reason: str = "User cancelled", current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    cancellable_statuses = ["ASSIGNED", "DRIVER_ARRIVING", "DRIVER_ARRIVED", "accepted", "rider_arriving"]
    ride = db.query(Ride).filter(
        Ride.id == ride_id,
        Ride.user_id == current_user.id,
        Ride.status.in_(cancellable_statuses)
    ).first()
    
    if not ride:
        # Also check pending RideRequest if ride object not yet formed
        req = db.query(RideRequest).filter(
            RideRequest.id == ride_id,
            RideRequest.user_id == current_user.id,
            RideRequest.status.in_(["SEARCHING", "OFFERED", "searching"])
        ).first()
        if req:
            req.status = "CANCELLED_BY_CUSTOMER"
            db.commit()
            return {"message": "Ride request cancelled successfully"}
        raise HTTPException(status_code=404, detail="Active cancellable ride not found")

    ride.status = "CANCELLED_BY_CUSTOMER"
    ride.cancelled_by = "customer"
    ride.cancellation_reason = reason
    ride.cancelled_at = datetime.utcnow()
    db.commit()
    return {"message": "Ride cancelled successfully by customer"}

@router.post("/{ride_id}/rate")
def rate_ride(ride_id: str, request: RatingRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if request.rating < 1 or request.rating > 5:
        raise HTTPException(status_code=400, detail="Rating must be between 1 and 5 stars")

    ride = db.query(Ride).filter(
        Ride.id == ride_id,
        Ride.user_id == current_user.id,
        Ride.status.in_(["COMPLETED", "PAYMENT_COMPLETED", "completed"])
    ).first()
    
    if not ride:
        raise HTTPException(status_code=404, detail="Completed ride not found")

    existing = db.query(Rating).filter(Rating.ride_id == ride.id, Rating.user_id == current_user.id).first()
    if existing:
        raise HTTPException(status_code=400, detail="You have already rated this ride")

    rating = Rating(
        ride_id=ride.id,
        user_id=current_user.id,
        rider_id=ride.rider_id,
        rating=request.rating,
        feedback=request.feedback,
        tags=request.tags
    )
    db.add(rating)

    # Recalculate Driver cumulative average rating
    rider = db.query(Rider).filter(Rider.id == ride.rider_id).first()
    if rider:
        total = float(rider.average_rating or 0) * (rider.total_ratings or 0)
        rider.total_ratings = (rider.total_ratings or 0) + 1
        rider.average_rating = round((total + request.rating) / rider.total_ratings, 2)

    ride.status = "RATED"
    db.commit()
    return {"message": "Rating submitted successfully! Thank you for rating AshtaRide.", "rating": request.rating}