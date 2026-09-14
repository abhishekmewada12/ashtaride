from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.database import get_db
from app.models import User
from app.auth import get_current_user

router = APIRouter()

class UpdateProfileRequest(BaseModel):
    full_name: str

@router.get("/profile")
@router.get("/me")
def get_user_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return {
        "id": str(current_user.id),
        "mobile_number": current_user.mobile_number,
        "full_name": current_user.full_name or "Ashta User",
        "rating": current_user.rating,
        "total_rides": current_user.total_rides,
        "created_at": current_user.created_at.isoformat() if current_user.created_at else None,
    }

@router.put("/profile")
def update_user_profile(
    request: UpdateProfileRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    current_user.full_name = request.full_name.strip()
    db.commit()
    return {"message": "Profile updated successfully", "full_name": current_user.full_name}
