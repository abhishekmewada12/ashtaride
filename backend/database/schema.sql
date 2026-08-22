-- ============================================================
-- AshtaRide - Complete PostgreSQL Database Schema
-- "Ashta ki Apni Ride"
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- Enable PostGIS for geolocation queries

-- ============================================================
-- 1. ADMIN USERS TABLE
-- Platform administrators who manage the app
-- ============================================================
CREATE TABLE admin_users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(150) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,         -- bcrypt hashed
    role            VARCHAR(50) DEFAULT 'admin',   -- admin / superadmin
    is_active       BOOLEAN DEFAULT TRUE,
    last_login      TIMESTAMP,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- Index for fast email lookup during login
CREATE INDEX idx_admin_email ON admin_users(email);


-- ============================================================
-- 2. USERS TABLE
-- Customers who book rides
-- ============================================================
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_name       VARCHAR(100),
    mobile_number   VARCHAR(15) UNIQUE NOT NULL,   -- +91XXXXXXXXXX format
    profile_photo   VARCHAR(500),                  -- Cloudinary URL
    is_active       BOOLEAN DEFAULT TRUE,
    is_blocked      BOOLEAN DEFAULT FALSE,
    total_rides     INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- Index for mobile number lookup (used in OTP login)
CREATE INDEX idx_users_mobile ON users(mobile_number);
CREATE INDEX idx_users_active ON users(is_active, is_blocked);


-- ============================================================
-- 3. OTP TABLE
-- Store OTPs for mobile login (both users and riders)
-- ============================================================
CREATE TABLE otp_records (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mobile_number   VARCHAR(15) NOT NULL,
    otp_code        VARCHAR(6) NOT NULL,
    otp_type        VARCHAR(20) NOT NULL,          -- user_login / rider_login
    is_used         BOOLEAN DEFAULT FALSE,
    expires_at      TIMESTAMP NOT NULL,            -- OTP valid for 5 mins
    created_at      TIMESTAMP DEFAULT NOW()
);

-- Index for fast OTP verification
CREATE INDEX idx_otp_mobile ON otp_records(mobile_number, is_used);
CREATE INDEX idx_otp_expires ON otp_records(expires_at);


-- ============================================================
-- 4. RIDERS TABLE
-- Bike riders / drivers on the platform
-- ============================================================
CREATE TABLE riders (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_name               VARCHAR(100) NOT NULL,
    mobile_number           VARCHAR(15) UNIQUE NOT NULL,
    profile_photo           VARCHAR(500),              -- Cloudinary URL
    aadhaar_number          VARCHAR(20),               -- Encrypted
    aadhaar_doc_url         VARCHAR(500),              -- Cloudinary URL (encrypted)
    driving_license_number  VARCHAR(30),
    driving_license_url     VARCHAR(500),              -- Cloudinary URL
    
    -- Verification Status
    verification_status     VARCHAR(20) DEFAULT 'pending',
    -- Values: pending / approved / rejected
    rejection_reason        TEXT,
    verified_at             TIMESTAMP,
    verified_by             UUID REFERENCES admin_users(id),
    
    -- Online Status (for ride matching)
    is_online               BOOLEAN DEFAULT FALSE,
    last_location_lat       DECIMAL(10, 8),            -- Real-time lat
    last_location_lng       DECIMAL(11, 8),            -- Real-time lng
    last_location_updated   TIMESTAMP,
    
    -- Stats
    total_rides             INTEGER DEFAULT 0,
    total_earnings          DECIMAL(10, 2) DEFAULT 0.00,
    average_rating          DECIMAL(3, 2) DEFAULT 0.00,
    total_ratings           INTEGER DEFAULT 0,
    
    is_active               BOOLEAN DEFAULT TRUE,
    is_blocked              BOOLEAN DEFAULT FALSE,
    created_at              TIMESTAMP DEFAULT NOW(),
    updated_at              TIMESTAMP DEFAULT NOW()
);

-- Indexes for rider queries
CREATE INDEX idx_riders_mobile ON riders(mobile_number);
CREATE INDEX idx_riders_status ON riders(verification_status, is_active);
CREATE INDEX idx_riders_online ON riders(is_online, verification_status);

-- PostGIS index for geolocation queries (finding nearest riders)



-- ============================================================
-- 5. VEHICLES TABLE
-- Vehicle details linked to each rider
-- ============================================================
CREATE TABLE vehicles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id        UUID NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
    
    vehicle_type    VARCHAR(30) DEFAULT 'bike',    -- bike / scooter / auto
    brand           VARCHAR(50),                   -- Honda, Hero, Bajaj etc
    model           VARCHAR(50),                   -- Splendor, Activa etc
    color           VARCHAR(30),
    year            INTEGER,
    
    -- Registration
    plate_number    VARCHAR(20) UNIQUE NOT NULL,   -- MP09AB1234
    rc_doc_url      VARCHAR(500),                  -- RC document URL
    rc_expiry_date  DATE,
    
    -- Insurance
    insurance_doc_url   VARCHAR(500),
    insurance_expiry    DATE,
    
    is_verified     BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_vehicles_rider ON vehicles(rider_id);
CREATE INDEX idx_vehicles_plate ON vehicles(plate_number);


-- ============================================================
-- 6. RIDE REQUESTS TABLE
-- When customer books a ride — finding rider phase
-- ============================================================
CREATE TABLE ride_requests (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL REFERENCES users(id),
    
    -- Pickup Location
    pickup_lat          DECIMAL(10, 8) NOT NULL,
    pickup_lng          DECIMAL(11, 8) NOT NULL,
    pickup_address      TEXT NOT NULL,
    
    -- Destination
    destination_lat     DECIMAL(10, 8) NOT NULL,
    destination_lng     DECIMAL(11, 8) NOT NULL,
    destination_address TEXT NOT NULL,
    
    -- Fare Estimate
    estimated_distance  DECIMAL(8, 2),             -- in KM
    estimated_fare      DECIMAL(8, 2),             -- in ₹
    
    -- Request Status
    status              VARCHAR(20) DEFAULT 'searching',
    -- Values: searching / accepted / cancelled / expired / no_riders
    
    -- Which riders were notified
    notified_riders     UUID[],                    -- Array of rider IDs
    
    -- Accepted by
    accepted_by_rider   UUID REFERENCES riders(id),
    accepted_at         TIMESTAMP,
    
    -- Expiry (auto cancel if no rider accepts in 2 min)
    expires_at          TIMESTAMP DEFAULT (NOW() + INTERVAL '2 minutes'),
    
    created_at          TIMESTAMP DEFAULT NOW(),
    updated_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_ride_requests_user ON ride_requests(user_id);
CREATE INDEX idx_ride_requests_status ON ride_requests(status, expires_at);


-- ============================================================
-- 7. RIDES TABLE
-- Confirmed rides (after rider accepts)
-- ============================================================
CREATE TABLE rides (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id          UUID UNIQUE REFERENCES ride_requests(id),
    user_id             UUID NOT NULL REFERENCES users(id),
    rider_id            UUID NOT NULL REFERENCES riders(id),
    vehicle_id          UUID REFERENCES vehicles(id),
    
    -- Locations
    pickup_lat          DECIMAL(10, 8) NOT NULL,
    pickup_lng          DECIMAL(11, 8) NOT NULL,
    pickup_address      TEXT NOT NULL,
    destination_lat     DECIMAL(10, 8) NOT NULL,
    destination_lng     DECIMAL(11, 8) NOT NULL,
    destination_address TEXT NOT NULL,
    
    -- Ride Status
    status              VARCHAR(20) DEFAULT 'accepted',
    -- Values: accepted / rider_arriving / ride_started / completed / cancelled
    
    -- Timing
    rider_arrived_at    TIMESTAMP,                 -- Rider reached pickup
    ride_started_at     TIMESTAMP,                 -- Ride began
    ride_ended_at       TIMESTAMP,                 -- Ride completed
    
    -- Fare Details
    estimated_fare      DECIMAL(8, 2),
    base_fare           DECIMAL(8, 2) DEFAULT 20.00,
    distance_km         DECIMAL(8, 2),
    distance_fare       DECIMAL(8, 2),             -- distance_km * 8
    waiting_minutes     INTEGER DEFAULT 0,
    waiting_fare        DECIMAL(8, 2) DEFAULT 0,   -- waiting_minutes * 1
    total_fare          DECIMAL(8, 2),             -- Final amount
    
    -- Cancellation
    cancelled_by        VARCHAR(10),               -- user / rider
    cancellation_reason TEXT,
    cancelled_at        TIMESTAMP,
    
    created_at          TIMESTAMP DEFAULT NOW(),
    updated_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_rides_user ON rides(user_id, created_at DESC);
CREATE INDEX idx_rides_rider ON rides(rider_id, created_at DESC);
CREATE INDEX idx_rides_status ON rides(status);
CREATE INDEX idx_rides_date ON rides(created_at);


-- ============================================================
-- 8. PAYMENTS TABLE
-- Payment records for each completed ride
-- ============================================================
CREATE TABLE payments (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id             UUID UNIQUE NOT NULL REFERENCES rides(id),
    user_id             UUID NOT NULL REFERENCES users(id),
    rider_id            UUID NOT NULL REFERENCES riders(id),
    
    amount              DECIMAL(8, 2) NOT NULL,
    payment_method      VARCHAR(30) DEFAULT 'cash',
    -- Values: cash / upi / card (future)
    
    payment_status      VARCHAR(20) DEFAULT 'pending',
    -- Values: pending / completed / failed / refunded
    
    -- UPI details (future)
    transaction_id      VARCHAR(100),
    upi_ref             VARCHAR(100),
    
    paid_at             TIMESTAMP,
    created_at          TIMESTAMP DEFAULT NOW(),
    updated_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_payments_ride ON payments(ride_id);
CREATE INDEX idx_payments_user ON payments(user_id, created_at DESC);
CREATE INDEX idx_payments_rider ON payments(rider_id, created_at DESC);
CREATE INDEX idx_payments_status ON payments(payment_status);


-- ============================================================
-- 9. RATINGS TABLE
-- Customer rates rider after ride completion
-- ============================================================
CREATE TABLE ratings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id         UUID UNIQUE NOT NULL REFERENCES rides(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    rider_id        UUID NOT NULL REFERENCES riders(id),
    
    rating          INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    feedback        TEXT,                          -- Optional comment
    
    -- Tags (quick feedback options)
    tags            VARCHAR(50)[],
    -- Example: ['safe_driving', 'on_time', 'friendly']
    
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_ratings_rider ON ratings(rider_id);
CREATE INDEX idx_ratings_ride ON ratings(ride_id);


-- ============================================================
-- 10. NOTIFICATIONS TABLE
-- Push notification records
-- ============================================================
CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Recipient
    recipient_type  VARCHAR(10) NOT NULL,          -- user / rider / admin
    recipient_id    UUID NOT NULL,
    
    -- FCM Token
    fcm_token       VARCHAR(500),
    
    -- Content
    title           VARCHAR(200) NOT NULL,
    body            TEXT NOT NULL,
    data            JSONB,                         -- Extra data payload
    
    -- Status
    is_sent         BOOLEAN DEFAULT FALSE,
    is_read         BOOLEAN DEFAULT FALSE,
    sent_at         TIMESTAMP,
    
    -- Type
    notification_type VARCHAR(50),
    -- ride_request / ride_accepted / ride_started / ride_completed / sos_alert
    
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_notifications_recipient ON notifications(recipient_type, recipient_id, is_read);
CREATE INDEX idx_notifications_type ON notifications(notification_type);


-- ============================================================
-- 11. FCM TOKENS TABLE
-- Store device push notification tokens
-- ============================================================
CREATE TABLE fcm_tokens (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_type      VARCHAR(10) NOT NULL,          -- user / rider
    owner_id        UUID NOT NULL,
    fcm_token       VARCHAR(500) NOT NULL,
    device_type     VARCHAR(20),                   -- android / ios
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_fcm_owner ON fcm_tokens(owner_type, owner_id, is_active);


-- ============================================================
-- 12. SOS ALERTS TABLE
-- Emergency SOS triggered by customer during ride
-- ============================================================
CREATE TABLE sos_alerts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id         UUID NOT NULL REFERENCES rides(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    rider_id        UUID NOT NULL REFERENCES riders(id),
    
    -- Location when SOS triggered
    sos_lat         DECIMAL(10, 8),
    sos_lng         DECIMAL(11, 8),
    
    status          VARCHAR(20) DEFAULT 'active',  -- active / resolved / false_alarm
    resolved_by     UUID REFERENCES admin_users(id),
    resolved_at     TIMESTAMP,
    notes           TEXT,                          -- Admin notes
    
    triggered_at    TIMESTAMP DEFAULT NOW(),
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_sos_ride ON sos_alerts(ride_id);
CREATE INDEX idx_sos_status ON sos_alerts(status, triggered_at DESC);


-- ============================================================
-- 13. RIDER LOCATION HISTORY TABLE
-- Store rider location updates during active ride
-- (For live tracking feature)
-- ============================================================
CREATE TABLE rider_location_history (
    id              BIGSERIAL PRIMARY KEY,         -- BIGSERIAL for high volume
    rider_id        UUID NOT NULL REFERENCES riders(id),
    ride_id         UUID REFERENCES rides(id),
    
    latitude        DECIMAL(10, 8) NOT NULL,
    longitude       DECIMAL(11, 8) NOT NULL,
    speed           DECIMAL(5, 2),                -- km/h
    heading         DECIMAL(5, 2),                -- degrees 0-360
    
    recorded_at     TIMESTAMP DEFAULT NOW()
);

-- Only keep last 24 hours of location data (partition or cron job)
CREATE INDEX idx_location_history_rider ON rider_location_history(rider_id, recorded_at DESC);
CREATE INDEX idx_location_history_ride ON rider_location_history(ride_id, recorded_at DESC);


-- ============================================================
-- TRIGGERS — Auto update timestamps
-- ============================================================

-- Function to update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_riders_updated BEFORE UPDATE ON riders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_vehicles_updated BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_rides_updated BEFORE UPDATE ON rides
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_payments_updated BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_ride_requests_updated BEFORE UPDATE ON ride_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ============================================================
-- SEED DATA — Admin user for first login
-- ============================================================

INSERT INTO admin_users (full_name, email, password_hash, role)
VALUES (
    'AshtaRide Admin',
    'admin@ashtaride.com',
    -- Password: Admin@123 (change this immediately after first login!)
    '$2b$12$placeholder_change_this_hash',
    'superadmin'
);

-- ============================================================
-- END OF SCHEMA
-- ============================================================
