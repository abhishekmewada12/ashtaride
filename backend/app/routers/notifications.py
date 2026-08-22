from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Notification, User, Rider
from app.auth import get_current_user, get_current_rider

router = APIRouter()

@router.get("/user")
def get_user_notifications(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    notifications = db.query(Notification).filter(
        Notification.recipient_type == "user",
        Notification.recipient_id == current_user.id
    ).order_by(Notification.created_at.desc()).limit(20).all()

    return {
        "notifications": [
            {"id": str(n.id), "title": n.title, "body": n.body, "type": n.notification_type, "is_read": n.is_read, "created_at": n.created_at.isoformat()}
            for n in notifications
        ]
    }

@router.get("/rider")
def get_rider_notifications(current_rider: Rider = Depends(get_current_rider), db: Session = Depends(get_db)):
    notifications = db.query(Notification).filter(
        Notification.recipient_type == "rider",
        Notification.recipient_id == current_rider.id
    ).order_by(Notification.created_at.desc()).limit(20).all()

    return {
        "notifications": [
            {"id": str(n.id), "title": n.title, "body": n.body, "type": n.notification_type, "is_read": n.is_read, "created_at": n.created_at.isoformat()}
            for n in notifications
        ]
    }

@router.post("/{notification_id}/read")
def mark_read(notification_id: str, db: Session = Depends(get_db)):
    notification = db.query(Notification).filter(Notification.id == notification_id).first()
    if notification:
        notification.is_read = True
        db.commit()
    return {"message": "Marked as read"}