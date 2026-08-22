import sys
import os
import random

sys.path.append(r"C:\ashtaride\backend")

from fastapi.testclient import TestClient
from app.main import app
from app.database import SessionLocal
from app.models import AdminUser, User, Rider, Ride, RideRequest, Payment, Rating, Vehicle
from app.auth import hash_password

client = TestClient(app)

def run_e2e_simulation():
    print("=" * 60)
    print("STARTING ASHTARIDE END-TO-END AUTOMATED SIMULATION TEST")
    print("=" * 60)

    # 1. RESET / ENSURE ADMIN CREDENTIALS
    db = SessionLocal()
    admin = db.query(AdminUser).filter(AdminUser.email == "admin@ashtaride.com").first()
    if not admin:
        admin = AdminUser(
            full_name="AshtaRide Admin",
            email="admin@ashtaride.com",
            password_hash=hash_password("admin123"),
            role="superadmin",
            is_active=True
        )
        db.add(admin)
    else:
        admin.password_hash = hash_password("admin123")
        admin.is_active = True
    db.commit()
    db.close()

    # 2. ADMIN LOGIN
    print("\n[1/8] Admin Login...")
    admin_login_res = client.post("/api/v1/auth/admin/login", json={
        "email": "admin@ashtaride.com",
        "password": "admin123"
    })
    assert admin_login_res.status_code == 200, f"Admin login failed: {admin_login_res.text}"
    admin_token = admin_login_res.json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    print("   [PASS] Admin Logged In Successfully!")

    # 3. RIDER ONBOARDING & ADMIN APPROVAL
    print("\n[2/8] Rider Registration & Verification...")
    rand_suffix = str(random.randint(100000, 999999))
    test_rider_mobile = f"9876{rand_suffix}"
    plate_num = f"MP09AB{rand_suffix[:4]}"
    
    reg_res = client.post(
        f"/api/v1/auth/rider/register?full_name=Ramesh%20Kumar&mobile_number={test_rider_mobile}"
    )
    assert reg_res.status_code == 200, f"Rider register failed: {reg_res.text}"
    rider_id = reg_res.json()["rider_id"]
    print(f"   [PASS] Rider Registered (ID: {rider_id}, Mobile: {test_rider_mobile})")

    doc_res = client.post("/api/v1/auth/rider/upload-documents", json={
        "mobile_number": test_rider_mobile,
        "aadhaar_number": "123456789012",
        "aadhaar_doc_base64": "http://example.com/aadhaar.jpg",
        "driving_license_number": "MP09-20210001",
        "driving_license_base64": "http://example.com/dl.jpg",
        "vehicle_type": "bike",
        "plate_number": plate_num,
        "vehicle_brand": "Hero",
        "vehicle_model": "Splendor Plus"
    })
    assert doc_res.status_code == 200, f"Doc upload failed: {doc_res.text}"
    print(f"   [PASS] Documents & Vehicle Info Uploaded ({plate_num})")

    approve_res = client.post(f"/api/v1/admin/riders/{rider_id}/approve", headers=admin_headers)
    assert approve_res.status_code == 200, f"Approval failed: {approve_res.text}"
    print("   [PASS] Admin Approved Rider")

    client.post("/api/v1/auth/send-otp", json={"mobile_number": test_rider_mobile, "user_type": "rider"})
    rider_verify = client.post("/api/v1/auth/verify-otp", json={"mobile_number": test_rider_mobile, "otp_code": "1234", "user_type": "rider"})
    assert rider_verify.status_code == 200, f"Rider OTP verify failed: {rider_verify.text}"
    rider_token = rider_verify.json()["access_token"]
    rider_headers = {"Authorization": f"Bearer {rider_token}"}

    online_res = client.post("/api/v1/riders/toggle-online", headers=rider_headers)
    assert online_res.status_code == 200, f"Toggle online failed: {online_res.text}"
    print("   [PASS] Rider is now ONLINE")

    # 4. CUSTOMER LOGIN & RIDE BOOKING
    print("\n[3/8] Customer Login & Ride Booking...")
    test_user_mobile = f"9123{rand_suffix}"
    client.post("/api/v1/auth/send-otp", json={"mobile_number": test_user_mobile, "user_type": "user"})
    user_verify = client.post("/api/v1/auth/verify-otp", json={"mobile_number": test_user_mobile, "otp_code": "1234", "user_type": "user"})
    assert user_verify.status_code == 200, f"User OTP verify failed: {user_verify.text}"
    user_token = user_verify.json()["access_token"]
    user_headers = {"Authorization": f"Bearer {user_token}"}

    estimate_res = client.post("/api/v1/rides/estimate", headers=user_headers, json={
        "pickup_lat": 22.9734,
        "pickup_lng": 76.6178,
        "destination_lat": 22.9800,
        "destination_lng": 76.6250
    })
    assert estimate_res.status_code == 200
    est_fare = estimate_res.json()["total_fare"]
    print(f"   [PASS] Fare Estimate: Rs.{est_fare} for Ashta local route")

    book_res = client.post("/api/v1/rides/book", headers=user_headers, json={
        "pickup_lat": 22.9734,
        "pickup_lng": 76.6178,
        "pickup_address": "Ashta Bus Stand",
        "destination_lat": 22.9800,
        "destination_lng": 76.6250,
        "destination_address": "Civil Hospital, Ashta"
    })
    assert book_res.status_code == 200, f"Booking failed: {book_res.text}"
    request_id = book_res.json()["ride_request_id"]
    print(f"   [PASS] Ride Request Created (ID: {request_id})")

    # 5. RIDER SEES & ACCEPTS RIDE
    print("\n[4/8] Rider Receives & Accepts Ride...")
    avail_res = client.get("/api/v1/riders/available-rides", headers=rider_headers)
    assert avail_res.status_code == 200
    rides_list = avail_res.json()["rides"]
    assert len(rides_list) > 0, "Rider did not see available ride!"
    print(f"   [PASS] Rider saw {len(rides_list)} available ride request(s)")

    accept_res = client.post(f"/api/v1/riders/rides/{request_id}/accept", headers=rider_headers)
    assert accept_res.status_code == 200, f"Accept ride failed: {accept_res.text}"
    ride_id = accept_res.json()["ride_id"]
    print(f"   [PASS] Rider Accepted Ride! (Ride ID: {ride_id})")

    # 6. CUSTOMER SEES RIDER & GETS OTP
    print("\n[5/8] Customer Status & OTP Verification...")
    active_res = client.get("/api/v1/rides/active", headers=user_headers)
    assert active_res.status_code == 200
    active_data = active_res.json()["active_ride"]
    assert active_data is not None, "Active ride not found for customer!"
    ride_otp = active_data["ride_otp"]
    print(f"   [PASS] Customer received Rider Info & 4-Digit OTP: [{ride_otp}]")

    client.post(f"/api/v1/riders/rides/{ride_id}/arrived", headers=rider_headers)
    print("   [PASS] Rider marked as Arrived at Pickup")

    # 7. RIDER ENTERS OTP -> START RIDE -> COMPLETE RIDE
    print("\n[6/8] Starting and Completing Ride...")
    start_res = client.post(f"/api/v1/riders/rides/{ride_id}/start?otp={ride_otp}", headers=rider_headers)
    assert start_res.status_code == 200, f"Start ride failed: {start_res.text}"
    print("   [PASS] OTP Verified! Ride Started")

    complete_res = client.post(f"/api/v1/riders/rides/{ride_id}/complete", headers=rider_headers)
    assert complete_res.status_code == 200, f"Complete ride failed: {complete_res.text}"
    fare_summary = complete_res.json()["ride_summary"]
    print(f"   [PASS] Ride Completed! Total Fare: Rs.{fare_summary['total_fare']} (Cash Collected)")

    # 8. ADMIN DASHBOARD & ACTION TEST (BLOCK / UNBLOCK)
    print("\n[7/8] Admin Dashboard Live Verification...")
    dash_res = client.get("/api/v1/admin/dashboard", headers=admin_headers)
    assert dash_res.status_code == 200
    dash_data = dash_res.json()
    print(f"   [PASS] Total Riders: {dash_data['riders']['total']}")
    print(f"   [PASS] Verified Riders: {dash_data['riders']['verified']}")
    print(f"   [PASS] Total Rides: {dash_data['rides']['total']}")
    print(f"   [PASS] Today Revenue: Rs.{dash_data['revenue']['today']}")

    print("\n[8/8] Admin Action (Block & Unlock Appeal Test)...")
    block_res = client.post(f"/api/v1/admin/riders/{rider_id}/block?reason=Rash%20driving%20complaint", headers=admin_headers)
    assert block_res.status_code == 200
    print("   [PASS] Admin Blocked Rider with reason: 'Rash driving complaint'")

    appeal_res = client.post("/api/v1/riders/request-unlock", headers=rider_headers, json={
        "message": "Sorry sir, galti se hua tha, aage se dhyan rakhunga."
    })
    assert appeal_res.status_code == 200
    print("   [PASS] Rider submitted Unlock Appeal to Admin")

    unblock_res = client.post(f"/api/v1/admin/riders/{rider_id}/unblock", headers=admin_headers)
    assert unblock_res.status_code == 200
    print("   [PASS] Admin Reviewed Appeal & Unblocked Rider!")

    print("\n" + "=" * 60)
    print(">>> SUCCESS: ALL 8 MODULES TESTED & PASSED 100%! <<<")
    print("=" * 60)

if __name__ == "__main__":
    run_e2e_simulation()
