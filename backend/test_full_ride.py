import httpx
import json
import time

BASE_URL = 'https://ashtaride.onrender.com'
print('=== EXECUTING COMPLETE RIDE LIFECYCLE SIMULATION ===\n')

client = httpx.Client(timeout=30.0)

# 1. Rider Login & Go Online
print('[1/6] Rider (7697665224) Logging In...')
r_otp = client.post(f'{BASE_URL}/api/v1/auth/send-otp', json={'mobile_number': '7697665224', 'user_type': 'rider', 'channel': 'sms'}).json()
r_login = client.post(f'{BASE_URL}/api/v1/auth/verify-otp', json={'mobile_number': '7697665224', 'otp_code': r_otp.get('dev_otp', '1234'), 'user_type': 'rider'}).json()
rider_token = r_login['access_token']

# Set location and ensure Online
client.post(f'{BASE_URL}/api/v1/riders/location', json={'lat': 23.0225, 'lng': 76.7170}, headers={'Authorization': f'Bearer {rider_token}'})
r_toggle = client.post(f'{BASE_URL}/api/v1/riders/toggle-online', headers={'Authorization': f'Bearer {rider_token}'}).json()
if not r_toggle.get('is_online'):
    r_toggle = client.post(f'{BASE_URL}/api/v1/riders/toggle-online', headers={'Authorization': f'Bearer {rider_token}'}).json()
print(f'Rider Online: {r_toggle["is_online"]}')

# 2. Customer Login & Book Ride
print('\n[2/6] Customer (9516792364) Logging In...')
u_otp = client.post(f'{BASE_URL}/api/v1/auth/send-otp', json={'mobile_number': '9516792364', 'user_type': 'user', 'channel': 'sms'}).json()
u_login = client.post(f'{BASE_URL}/api/v1/auth/verify-otp', json={'mobile_number': '9516792364', 'otp_code': u_otp.get('dev_otp', '1234'), 'user_type': 'user'}).json()
user_token = u_login['access_token']

print('\n[3/6] Customer Booking Ride: Ashta Bus Stand -> Krishi Upaj Mandi...')
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
req_id = book_res['ride_request_id']
print(f'Booking Created: Request ID = {req_id}, Status = {book_res["status"]}, Offered to Driver = {book_res["is_driver_offered"]}')

# 3. Rider Fetches Available Rides
print('\n[4/6] Rider Polling Incoming Rides...')
avail_res = client.get(f'{BASE_URL}/api/v1/riders/available-rides', headers={'Authorization': f'Bearer {rider_token}'}).json()
print('Incoming Rides on Driver Screen:', json.dumps(avail_res, indent=2))

# 4. Rider Accepts Ride
print(f'\n[5/6] Rider Accepting Request ID: {req_id}...')
accept_res = client.post(f'{BASE_URL}/api/v1/riders/rides/{req_id}/accept', headers={'Authorization': f'Bearer {rider_token}'}).json()
ride_id = accept_res['ride_id']
print('RIDE ACCEPTED BY RIDER!')
print(f'Ride ID = {ride_id}')
print(f'Customer Name = {accept_res.get("customer_name")}')
print(f'Pickup Address = {accept_res.get("pickup_address")}')
print(f'Total Fare = Rs {accept_res.get("fare")}')

# 5. Verify Ride Status from Customer End
print('\n[6/6] Checking Ride Status from Customer and Admin...')
status_res = client.get(f'{BASE_URL}/api/v1/rides/request/{req_id}/status', headers={'Authorization': f'Bearer {user_token}'}).json()
print('Customer Active Ride Details:\n', json.dumps(status_res, indent=2))

# Admin View
from app.database import SessionLocal
from app.models import Ride, User, Rider
db = SessionLocal()
saved_ride = db.query(Ride).filter(Ride.id == ride_id).first()
if saved_ride:
    u = db.query(User).filter(User.id == saved_ride.user_id).first()
    r = db.query(Rider).filter(Rider.id == saved_ride.rider_id).first()
    print('\n=============================================')
    print('SUCCESS! RIDE RECORDED IN DATABASE & ADMIN DASHBOARD:')
    print(f'- Ride ID: {saved_ride.id}')
    print(f'- Customer: {u.mobile_number} ({u.full_name or "Customer"})')
    print(f'- Driver: {r.mobile_number} ({r.full_name or "Driver"})')
    print(f'- Pickup: {saved_ride.pickup_address}')
    print(f'- Destination: {saved_ride.destination_address}')
    print(f'- Fare: Rs {saved_ride.total_fare}')
    print(f'- Ride Safety OTP: {saved_ride.ride_otp}')
    print(f'- Status: {saved_ride.status}')
    print('=============================================')
db.close()
