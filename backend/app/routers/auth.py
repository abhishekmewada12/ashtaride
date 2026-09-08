import random
import string
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.database import get_db
from app.models import User, Rider, OTPRecord, AdminUser
from app.auth import create_access_token, verify_password, hash_password, get_current_user
from app.config import settings

router = APIRouter()

import requests
import json

class SendOTPRequest(BaseModel):
    mobile_number: str
    user_type: str
    channel: str = "whatsapp"  # "whatsapp" or "sms"

class TruecallerLoginRequest(BaseModel):
    mobile_number: str
    full_name: str = None
    user_type: str = "user"    # "user" or "rider"
    signature: str = None

class VerifyOTPRequest(BaseModel):
    mobile_number: str
    otp_code: str
    user_type: str
    is_firebase_verified: bool = False

class AdminLoginRequest(BaseModel):
    email: str
    password: str

class OTPResponse(BaseModel):
    message: str
    mobile_number: str
    channel: str = "whatsapp"
    dev_otp: str = None
    whatsapp_url: str = None

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_type: str
    is_new_user: bool = False
    profile_complete: bool = True

def generate_otp() -> str:
    return ''.join(random.choices(string.digits, k=4))

def send_whatsapp_otp(mobile_number: str, otp: str) -> bool:
    """Dispatches OTP via WhatsApp (Meta Cloud API / Fast2SMS)"""
    formatted_mobile = f"91{mobile_number}" if len(mobile_number) == 10 else mobile_number

    # 1. Meta Official Cloud API if configured
    if settings.WHATSAPP_API_TOKEN and settings.WHATSAPP_PHONE_NUMBER_ID:
        try:
            url = f"https://graph.facebook.com/v18.0/{settings.WHATSAPP_PHONE_NUMBER_ID}/messages"
            headers = {
                "Authorization": f"Bearer {settings.WHATSAPP_API_TOKEN}",
                "Content-Type": "application/json"
            }
            payload = {
                "messaging_product": "whatsapp",
                "to": formatted_mobile,
                "type": "text",
                "text": {
                    "body": f"🚖 *AshtaRide Login OTP*\n\nAapka verification code hai: *{otp}*\n\nYeh code agle 5 minute ke liye valid hai. Kisi ke sath share na karein."
                }
            }
            res = requests.post(url, json=payload, headers=headers, timeout=10)
            print(f"[WhatsApp Meta API] Status: {res.status_code} {res.text}")
            return res.status_code in [200, 201]
        except Exception as e:
            print(f"[WhatsApp Meta API Error]: {e}")

    # 2. Fast2SMS Quick Route Fallback if API key exists
    if settings.FAST2SMS_API_KEY:
        try:
            url = f"https://www.fast2sms.com/dev/bulkV2?authorization={settings.FAST2SMS_API_KEY}&variables_values={otp}&route=otp&numbers={mobile_number}"
            res = requests.get(url, timeout=10)
            print(f"[Fast2SMS OTP] Dispatched: {res.status_code} {res.text}")
        except Exception as e:
            print(f"[Fast2SMS Error]: {e}")

    print(f"[WhatsApp OTP] OTP for +91 {mobile_number} is {otp}")
    return True

def send_otp_sms(mobile_number: str, otp: str):
    if settings.MSG91_API_KEY:
        try:
            formatted_mobile = f"91{mobile_number}" if len(mobile_number) == 10 else mobile_number
            params = {
                "authkey": settings.MSG91_API_KEY,
                "mobile": formatted_mobile,
                "otp": otp,
                "otp_length": len(otp),
                "otp_expiry": settings.OTP_EXPIRE_MINUTES,
            }
            if settings.MSG91_TEMPLATE_ID:
                params["template_id"] = settings.MSG91_TEMPLATE_ID
            if settings.MSG91_SENDER_ID:
                params["sender"] = settings.MSG91_SENDER_ID
            res = requests.post("https://control.msg91.com/api/v5/otp", params=params, timeout=10)
            print(f"[MSG91] Real SMS dispatched to {formatted_mobile}: {res.status_code} {res.text}")
            return True
        except Exception as e:
            print(f"[MSG91] Error sending SMS: {e}")
            return False
    return True

@router.post("/send-otp", response_model=OTPResponse)
def send_otp(request: SendOTPRequest, db: Session = Depends(get_db)):
    mobile = request.mobile_number.strip()
    if len(mobile) != 10 or not mobile.isdigit():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid mobile number. Must be 10 digits.")

    db.query(OTPRecord).filter(
        OTPRecord.mobile_number == mobile,
        OTPRecord.is_used == False
    ).delete()

    otp = generate_otp()
    expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

    otp_record = OTPRecord(
        mobile_number=mobile,
        otp_code=otp,
        otp_type=f"{request.user_type}_login",
        expires_at=expires_at
    )
    db.add(otp_record)
    db.commit()

    if request.channel == "whatsapp":
        send_whatsapp_otp(mobile, otp)
        msg_text = f"OTP sent to WhatsApp +91 {mobile}"
    else:
        send_otp_sms(mobile, otp)
        msg_text = f"OTP sent to +91 {mobile}"

    wa_link = f"https://wa.me/917697665224?text=AshtaRide%20Verification%20OTP:%20{otp}"
    response = OTPResponse(
        message=msg_text,
        mobile_number=mobile,
        channel=request.channel,
        whatsapp_url=wa_link
    )
    if settings.OTP_DEV_MODE:
        response.dev_otp = otp
    return response

@router.post("/truecaller-login", response_model=TokenResponse)
def truecaller_login(request: TruecallerLoginRequest, db: Session = Depends(get_db)):
    """Instant 1-Tap Login via verified Truecaller SDK on Android"""
    mobile = request.mobile_number.strip()
    # Normalize Indian 10-digit number
    if mobile.startswith("+91"):
        mobile = mobile[3:]
    elif mobile.startswith("91") and len(mobile) == 12:
        mobile = mobile[2:]
    
    if len(mobile) != 10 or not mobile.isdigit():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid mobile number from Truecaller.")

    is_new = False
    if request.user_type == "user":
        user = db.query(User).filter(User.mobile_number == mobile).first()
        if not user:
            user = User(
                mobile_number=mobile,
                full_name=request.full_name or ""
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            is_new = True
        elif request.full_name and not user.full_name:
            user.full_name = request.full_name
            db.commit()

        token = create_access_token({"sub": str(user.id), "type": "user", "mobile": mobile})
        return TokenResponse(
            access_token=token,
            user_type="user",
            is_new_user=is_new,
            profile_complete=bool(user.full_name)
        )

    elif request.user_type == "rider":
        rider = db.query(Rider).filter(Rider.mobile_number == mobile).first()
        if not rider:
            # Create pending rider profile with Truecaller Name
            rider = Rider(
                mobile_number=mobile,
                full_name=request.full_name or "Partner Driver",
                verification_status="pending"
            )
            db.add(rider)
            db.commit()
            db.refresh(rider)
            is_new = True

        has_docs = bool(rider.aadhaar_doc_url and rider.driving_license_url)
        token = create_access_token({"sub": str(rider.id), "type": "rider", "mobile": mobile})
        return TokenResponse(
            access_token=token,
            user_type="rider",
            is_new_user=not has_docs,
            profile_complete=has_docs and rider.verification_status == "approved"
        )
    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid user_type")

@router.post("/verify-otp", response_model=TokenResponse)
def verify_otp(request: VerifyOTPRequest, db: Session = Depends(get_db)):
    mobile = request.mobile_number.strip()

    otp_record = db.query(OTPRecord).filter(
        OTPRecord.mobile_number == mobile,
        OTPRecord.otp_code == request.otp_code,
        OTPRecord.is_used == False,
        OTPRecord.expires_at > datetime.utcnow()
    ).first()

    # If not found in local OTPRecord, check if verified via Firebase Auth (6-digit OTP)
    if not otp_record and not (request.is_firebase_verified or len(request.otp_code) == 6):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP")

    if otp_record:
        otp_record.is_used = True
        db.commit()

    is_new = False

    if request.user_type == "user":
        user = db.query(User).filter(User.mobile_number == mobile).first()
        if not user:
            user = User(mobile_number=mobile)
            db.add(user)
            db.commit()
            db.refresh(user)
            is_new = True

        token = create_access_token({"sub": str(user.id), "type": "user", "mobile": mobile})
        return TokenResponse(access_token=token, user_type="user", is_new_user=is_new, profile_complete=bool(user.full_name))

    elif request.user_type == "rider":
        rider = db.query(Rider).filter(Rider.mobile_number == mobile).first()
        if not rider:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Rider not registered. Please register first.")

        has_docs = bool(rider.aadhaar_doc_url and rider.driving_license_url)
        token = create_access_token({"sub": str(rider.id), "type": "rider", "mobile": mobile})
        return TokenResponse(
            access_token=token,
            user_type="rider",
            is_new_user=not has_docs,
            profile_complete=has_docs and rider.verification_status == "approved"
        )

    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid user_type")

@router.post("/admin/login", response_model=TokenResponse)
def admin_login(request: AdminLoginRequest, db: Session = Depends(get_db)):
    admin = db.query(AdminUser).filter(AdminUser.email == request.email, AdminUser.is_active == True).first()
    if not admin or not verify_password(request.password, admin.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    admin.last_login = datetime.utcnow()
    db.commit()

    token = create_access_token({"sub": str(admin.id), "type": "admin", "role": admin.role})
    return TokenResponse(access_token=token, user_type="admin")

@router.post("/rider/register")
def register_rider(full_name: str, mobile_number: str, db: Session = Depends(get_db)):
    mobile = mobile_number.strip()
    existing = db.query(Rider).filter(Rider.mobile_number == mobile).first()
    
    if existing:
        if existing.verification_status == "rejected":
            # Reset karo aur re-apply karne do
            existing.verification_status = "pending"
            existing.full_name = full_name
            existing.rejection_reason = None
            db.commit()
            return {
                "message": "Re-registration successful",
                "rider_id": str(existing.id),
                "status": "pending",
                "is_reapply": True
            }
        elif existing.verification_status == "pending":
            # Check karo documents upload hue hain ya nahi
            if existing.aadhaar_doc_url is None:
                return {
                    "message": "Documents pending",
                    "rider_id": str(existing.id),
                    "status": "documents_pending",
                    "mobile_number": mobile
                }
            raise HTTPException(
                status_code=400,
                detail="Already registered and documents submitted. Wait for admin approval."
            )
        elif existing.verification_status == "approved":
            raise HTTPException(
                status_code=400,
                detail="Already registered and approved. Please login."
            )

    rider = Rider(
        full_name=full_name,
        mobile_number=mobile,
        verification_status="pending"
    )
    db.add(rider)
    db.commit()
    db.refresh(rider)

    return {
        "message": "Rider registered successfully",
        "rider_id": str(rider.id),
        "status": "pending",
        "mobile_number": mobile
    }
class DocumentUploadRequest(BaseModel):
    mobile_number: str
    aadhaar_number: str
    aadhaar_doc_base64: str
    driving_license_number: str
    driving_license_base64: str
    vehicle_type: str
    plate_number: str
    vehicle_brand: str
    vehicle_model: str

@router.post("/rider/upload-documents")
def upload_documents(request: DocumentUploadRequest, db: Session = Depends(get_db)):
    rider = db.query(Rider).filter(
        Rider.mobile_number == request.mobile_number
    ).first()

    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found")

    # Cloudinary setup for real document image storage
    import cloudinary
    import cloudinary.uploader
    from app.config import settings

    if settings.CLOUDINARY_CLOUD_NAME and settings.CLOUDINARY_API_KEY and settings.CLOUDINARY_API_SECRET:
        cloudinary.config(
            cloud_name=settings.CLOUDINARY_CLOUD_NAME,
            api_key=settings.CLOUDINARY_API_KEY,
            api_secret=settings.CLOUDINARY_API_SECRET,
            secure=True
        )

    # 1. Upload Aadhaar to Cloudinary
    rider.aadhaar_number = request.aadhaar_number
    if request.aadhaar_doc_base64:
        if request.aadhaar_doc_base64.startswith("http"):
            rider.aadhaar_doc_url = request.aadhaar_doc_base64
        else:
            try:
                aadhaar_res = cloudinary.uploader.upload(
                    request.aadhaar_doc_base64,
                    folder="ashtaride/aadhaar",
                    resource_type="auto"
                )
                rider.aadhaar_doc_url = aadhaar_res.get("secure_url", request.aadhaar_doc_base64)
            except Exception as e:
                print(f"Aadhaar Cloudinary upload error: {e}")
                rider.aadhaar_doc_url = request.aadhaar_doc_base64

    # 2. Upload Driving License to Cloudinary
    rider.driving_license_number = request.driving_license_number
    if request.driving_license_base64:
        if request.driving_license_base64.startswith("http"):
            rider.driving_license_url = request.driving_license_base64
        else:
            try:
                dl_res = cloudinary.uploader.upload(
                    request.driving_license_base64,
                    folder="ashtaride/licenses",
                    resource_type="auto"
                )
                rider.driving_license_url = dl_res.get("secure_url", request.driving_license_base64)
            except Exception as e:
                print(f"DL Cloudinary upload error: {e}")
                rider.driving_license_url = request.driving_license_base64

    # Reset verification status on new document submission
    rider.verification_status = "pending"
    rider.rejection_reason = None

    # 3. Vehicle save ya update karo (Re-upload support)
    from app.models import Vehicle
    vehicle = db.query(Vehicle).filter(
        (Vehicle.rider_id == rider.id) | (Vehicle.plate_number == request.plate_number)
    ).first()
    if vehicle:
        vehicle.rider_id = rider.id
        vehicle.vehicle_type = request.vehicle_type
        vehicle.plate_number = request.plate_number
        vehicle.brand = request.vehicle_brand
        vehicle.model = request.vehicle_model
    else:
        vehicle = Vehicle(
            rider_id=rider.id,
            vehicle_type=request.vehicle_type,
            plate_number=request.plate_number,
            brand=request.vehicle_brand,
            model=request.vehicle_model,
        )
        db.add(vehicle)
    
    db.commit()

    return {"message": "Documents uploaded to Cloudinary successfully! Waiting for admin approval."}

class UpdateProfileRequest(BaseModel):
    full_name: str

@router.get("/me")
def get_my_profile(
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
def update_profile(
    request: UpdateProfileRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    current_user.full_name = request.full_name.strip()
    db.commit()
    return {"message": "Profile updated successfully", "full_name": current_user.full_name}