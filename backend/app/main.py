from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, rides, riders, admin, notifications
from app.database import engine
from app.models import Base

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="AshtaRide API",
    description="Ashta ki Apni Ride - Ride Hailing Platform",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router,          prefix="/api/v1/auth",          tags=["Authentication"])
app.include_router(rides.router,         prefix="/api/v1/rides",         tags=["Rides"])
app.include_router(riders.router,        prefix="/api/v1/riders",        tags=["Riders"])
app.include_router(admin.router,         prefix="/api/v1/admin",         tags=["Admin"])
app.include_router(notifications.router, prefix="/api/v1/notifications", tags=["Notifications"])

@app.on_event("startup")
def startup_seed_admin():
    from app.database import SessionLocal
    from app.models import AdminUser
    from app.auth import hash_password
    db = SessionLocal()
    try:
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
            db.commit()
            print("Default admin created: admin@ashtaride.com / admin123")
    except Exception as e:
        print(f"Error seeding admin: {e}")
    finally:
        db.close()

@app.get("/")
def root():
    return {
        "app": "AshtaRide",
        "tagline": "Ashta ki Apni Ride",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}