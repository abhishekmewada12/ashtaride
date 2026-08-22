from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta

from app.database import get_db
from app.models import User, Rider, Ride, Payment, AdminUser, SOSAlert
from app.auth import get_current_admin

router = APIRouter()

@router.get("/dashboard")
def get_dashboard(current_admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    total_users      = db.query(User).count()
    total_riders     = db.query(Rider).count()
    verified_riders  = db.query(Rider).filter(Rider.verification_status == "approved").count()
    pending_riders   = db.query(Rider).filter(Rider.verification_status == "pending").count()
    rejected_riders  = db.query(Rider).filter(Rider.verification_status == "rejected").count()
    active_riders    = db.query(Rider).filter(Rider.is_online == True).count()
    
    total_rides      = db.query(Ride).count()
    active_rides     = db.query(Ride).filter(Ride.status.in_(["accepted", "rider_arriving", "ride_started"])).count()

    today = datetime.utcnow().replace(hour=0, minute=0, second=0)
    today_revenue = db.query(func.sum(Payment.amount)).filter(Payment.payment_status == "completed", Payment.paid_at >= today).scalar() or 0
    total_revenue = db.query(func.sum(Payment.amount)).filter(Payment.payment_status == "completed").scalar() or 0
    active_sos = db.query(SOSAlert).filter(SOSAlert.status == "active").count()

    return {
        "users": {"total": total_users},
        "riders": {
            "total": total_riders,
            "verified": verified_riders,
            "pending_verification": pending_riders,
            "rejected": rejected_riders,
            "active_online": active_riders
        },
        "rides": {"total": total_rides, "active": active_rides},
        "revenue": {"today": float(today_revenue), "total": float(total_revenue)},
        "alerts": {"active_sos": active_sos}
    }

@router.get("/riders/pending")
def get_pending_riders(current_admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    riders = db.query(Rider).filter(Rider.verification_status == "pending").order_by(Rider.created_at.desc()).all()
    
    result = []
    for r in riders:
        vehicle_info = None
        if r.vehicle:
            vehicle_info = {
                "plate_number": r.vehicle.plate_number,
                "vehicle_type": r.vehicle.vehicle_type,
                "brand": r.vehicle.brand,
                "model": r.vehicle.model,
                "rc_doc_url": r.vehicle.rc_doc_url
            }
        
        result.append({
            "id": str(r.id),
            "full_name": r.full_name,
            "mobile_number": r.mobile_number,
            "profile_photo": r.profile_photo,
            "aadhaar_number": r.aadhaar_number,
            "aadhaar_doc_url": r.aadhaar_doc_url,
            "driving_license_number": r.driving_license_number,
            "driving_license_url": r.driving_license_url,
            "vehicle": vehicle_info,
            "created_at": r.created_at.isoformat() if r.created_at else None
        })

    return {"riders": result}

@router.post("/riders/{rider_id}/approve")
def approve_rider(rider_id: str, current_admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    rider = db.query(Rider).filter(Rider.id == rider_id).first()
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found")
    rider.verification_status = "approved"
    rider.verified_at = datetime.utcnow()
    rider.verified_by = current_admin.id
    db.commit()
    return {"message": f"Rider {rider.full_name} approved successfully"}

@router.post("/riders/{rider_id}/reject")
def reject_rider(rider_id: str, reason: str, current_admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    rider = db.query(Rider).filter(Rider.id == rider_id).first()
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found")
    rider.verification_status = "rejected"
    rider.rejection_reason = reason
    rider.verified_by = current_admin.id
    db.commit()
    return {"message": f"Rider {rider.full_name} rejected"}

@router.get("/rides/active")
def get_active_rides(current_admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    rides = db.query(Ride).filter(Ride.status.in_(["accepted", "rider_arriving", "ride_started"])).order_by(Ride.created_at.desc()).all()
    return {
        "rides": [
            {"ride_id": str(r.id), "status": r.status, "pickup": r.pickup_address, "destination": r.destination_address, "fare": float(r.total_fare or 0), "started_at": r.ride_started_at.isoformat() if r.ride_started_at else None}
            for r in rides
        ]
    }

@router.get("/users")
def get_all_users(page: int = 1, limit: int = 20, current_admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    offset = (page - 1) * limit
    users = db.query(User).order_by(User.created_at.desc()).offset(offset).limit(limit).all()
    return {
        "users": [
            {"id": str(u.id), "full_name": u.full_name, "mobile_number": u.mobile_number, "total_rides": u.total_rides, "is_blocked": u.is_blocked, "created_at": u.created_at.isoformat()}
            for u in users
        ]
    }

@router.post("/users/{user_id}/block")
def block_user(user_id: str, current_admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_blocked = not user.is_blocked
    db.commit()
    action = "blocked" if user.is_blocked else "unblocked"
    return {"message": f"User {action} successfully"}

# 1. Get ALL Riders (with search and status filter)
@router.get("/riders/all")
def get_all_riders(
    status_filter: str = "all",
    search: str = "",
    current_admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    query = db.query(Rider)

    if status_filter == "blocked":
        query = query.filter(Rider.is_blocked == True)
    elif status_filter == "verified":
        query = query.filter(Rider.verification_status == "approved", Rider.is_blocked == False)
    elif status_filter == "pending":
        query = query.filter(Rider.verification_status == "pending")

    if search:
        search_fmt = f"%{search.strip()}%"
        query = query.filter((Rider.full_name.ilike(search_fmt)) | (Rider.mobile_number.ilike(search_fmt)))

    riders = query.order_by(Rider.created_at.desc()).all()

    return {
        "riders": [
            {
                "id": str(r.id),
                "full_name": r.full_name,
                "mobile_number": r.mobile_number,
                "profile_photo": r.profile_photo,
                "verification_status": r.verification_status,
                "is_blocked": r.is_blocked,
                "block_reason": r.block_reason,
                "unlock_request_message": r.unlock_request_message,
                "is_online": r.is_online,
                "total_rides": r.total_rides,
                "total_earnings": float(r.total_earnings or 0),
                "average_rating": float(r.average_rating or 0),
                "aadhaar_number": r.aadhaar_number,
                "aadhaar_doc_url": r.aadhaar_doc_url,
                "driving_license_number": r.driving_license_number,
                "driving_license_url": r.driving_license_url,
                "vehicle": {
                    "plate_number": r.vehicle.plate_number,
                    "brand": r.vehicle.brand,
                    "model": r.vehicle.model,
                    "vehicle_type": r.vehicle.vehicle_type
                } if r.vehicle else None,
                "created_at": r.created_at.isoformat() if r.created_at else None
            }
            for r in riders
        ]
    }

# 2. Block Rider with Reason
@router.post("/riders/{rider_id}/block")
def block_rider(
    rider_id: str,
    reason: str,
    current_admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    rider = db.query(Rider).filter(Rider.id == rider_id).first()
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found")
    
    rider.is_blocked = True
    rider.block_reason = reason
    rider.is_online = False # Block hone par offline kar do
    rider.unlock_request_message = None # Reset previous unlock request
    db.commit()
    return {"message": f"Rider {rider.full_name} has been blocked", "reason": reason}

# 3. Unblock Rider
@router.post("/riders/{rider_id}/unblock")
def unblock_rider(
    rider_id: str,
    current_admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    rider = db.query(Rider).filter(Rider.id == rider_id).first()
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found")
    
    rider.is_blocked = False
    rider.block_reason = None
    rider.unlock_request_message = None
    db.commit()
    return {"message": f"Rider {rider.full_name} has been unblocked successfully"}