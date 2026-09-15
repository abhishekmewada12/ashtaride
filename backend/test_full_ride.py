import httpx
import json
import time

BASE_URL = 'https://ashtaride.onrender.com'
print('Waking up server...')
client = httpx.Client(timeout=60.0)

# 0. Warm up
for _ in range(3):
    try:
        hw = client.get(f'{BASE_URL}/health')
        if hw.status_code == 200:
            print('Server is Awake and Healthy!')
            break
    except Exception:
        print('Waiting for server warm up...')
        time.sleep(3)

print('=== STARTING LIVE RIDE TEST ===')

# ================= STEP 1: LOGIN RIDER & GO ONLINE =================
print('\n[1/5] Logging in Rider (7697665224)...')
r_otp = client.post(f'{BASE_URL}/api/v1/auth/send-otp', json={'mobile_number': '7697665224', 'user_type': 'rider', 'channel': 'sms'}).json()
otp_code = r_otp.get('dev_otp', '1234')
r_login = client.post(f'{BASE_URL}/api/v1/auth/verify-otp', json={'mobile_number': '7697665224', 'otp_code': otp_code, 'user_type': 'rider'}).json()
rider_token = r_login['access_token']
print('Rider Logged in successfully!')

# Send GPS Location (Ashta Bus Stand)
client.post(f'{BASE_URL}/api/v1/riders/location', json={'lat': 23.0225, 'lng': 76.7170}, headers={'Authorization': f'Bearer {rider_token}'})

# Toggle Online (ensure is_online is True)
r_toggle = client.post(f'{BASE_URL}/api/v1/riders/toggle-online', headers={'Authorization': f'Bearer {rider_token}'}).json()
if not r_toggle.get('is_online'):
    r_toggle = client.post(f'{BASE_URL}/api/v1/riders/toggle-online', headers={'Authorization': f'Bearer {rider_token}'}).json()
print(f'Rider Online Status: {r_toggle}')

# ================= STEP 2: LOGIN CUSTOMER & BOOK RIDE =================
print('\n[2/5] Logging in Customer (9516792364)...')
u_otp = client.post(f'{BASE_URL}/api/v1/auth/send-otp', json={'mobile_number': '9516792364', 'user_type': 'user', 'channel': 'sms'}).json()
u_login = client.post(f'{BASE_URL}/api/v1/auth/verify-otp', json={'mobile_number': '9516792364', 'otp_code': u_otp.get('dev_otp', '1234'), 'user_type': 'user'}).json()
user_token = u_login['access_token']
print('Customer Logged in successfully!')

print('\n[3/5] Customer Booking Ride: Ashta Bus Stand -> Krishi Upaj Mandi...')
booking_payload = {
    'pickup_lat': 23.0225,
    'pickup_lng': 76.7170,
    'pickup_address': 'Ashta Bus Stand, Old NH86, Ashta',
    'destination_lat': 23.0280,
    'destination_lng': 76.7280,
    'destination_address': 'Krishi Upaj Mandi, Ashta',
    'vehicle_type': 'bike',
    'payment_method': 'cash'
}
book_res = client.post(f'{BASE_URL}/api/v1/rides/book', json=booking_payload, headers={'Authorization': f'Bearer {user_token}'}).json()
print('Ride Booked! Response:\n', json.dumps(book_res, indent=2))
req_id = book_res['ride_request_id']

# ================= STEP 3: RIDER ACCEPTS RIDE =================
print(f'\n[4/5] Rider fetching incoming available rides...')
avail_res = client.get(f'{BASE_URL}/api/v1/riders/available-rides', headers={'Authorization': f'Bearer {rider_token}'}).json()
print('Incoming Rides on Driver Screen:\n', json.dumps(avail_res, indent=2))

print(f'\n[5/5] Rider Accepting Request ID: {req_id}...')
accept_res = client.post(f'{BASE_URL}/api/v1/riders/rides/{req_id}/accept', headers={'Authorization': f'Bearer {rider_token}'}).json()
print('RIDE ACCEPTED BY RIDER! Result:\n', json.dumps(accept_res, indent=2))

print('\n=== VERIFYING IN DATABASE & ADMIN DASHBOARD ===')
from app.database import SessionLocal
from app.models import Ride, RideRequest
db = SessionLocal()
active_ride = db.query(Ride).filter(Ride.request_id == req_id).first()
if active_ride:
    print(f'CONFIRMED IN DATABASE: Ride ID = {active_ride.id}, Status = {active_ride.status}, Fare = Rs {active_ride.total_fare}, OTP = {active_ride.ride_otp}')
db.close()
