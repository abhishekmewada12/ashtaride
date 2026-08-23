import React from 'react';

const PrivacyPolicyPage = () => {
  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#0f172a', color: '#f8fafc', padding: '40px 20px', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <div style={{ maxWidth: '800px', margin: '0 auto', backgroundColor: '#1e293b', borderRadius: '16px', padding: '36px', boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.5)' }}>
        
        <div style={{ textAlign: 'center', marginBottom: '32px', borderBottom: '1px solid #334155', paddingBottom: '24px' }}>
          <h1 style={{ color: '#fbbf24', fontSize: '32px', fontWeight: 'bold', margin: '0 0 8px 0' }}>AshtaRide</h1>
          <p style={{ color: '#94a3b8', fontSize: '15px', margin: 0 }}>Privacy Policy & Terms of Service</p>
          <p style={{ color: '#64748b', fontSize: '13px', marginTop: '6px' }}>Last Updated: August 2026 | Ashta, Madhya Pradesh, India</p>
        </div>

        <div style={{ lineHeight: '1.7', fontSize: '15px', color: '#cbd5e1' }}>
          <h2 style={{ color: '#f8fafc', fontSize: '20px', marginTop: '24px', marginBottom: '12px' }}>1. Introduction</h2>
          <p>Welcome to <strong>AshtaRide</strong>. We are dedicated to providing reliable, affordable, and safe local ride-hailing services in Ashta, Madhya Pradesh. This policy explains how we handle customer and partner data.</p>

          <h2 style={{ color: '#f8fafc', fontSize: '20px', marginTop: '24px', marginBottom: '12px' }}>2. Information We Collect</h2>
          <ul>
            <li><strong>Personal Information:</strong> Mobile phone number, full name, and profile details for account authentication.</li>
            <li><strong>Location Data:</strong> Real-time precise GPS location while the app is in use to calculate pickup points, road distance, navigation routes, and live ride tracking.</li>
            <li><strong>Rider Verification Documents:</strong> Aadhaar Card, Driving License, and Vehicle registration details for rider security verification before platform onboarding.</li>
          </ul>

          <h2 style={{ color: '#f8fafc', fontSize: '20px', marginTop: '24px', marginBottom: '12px' }}>3. How We Use Your Information</h2>
          <ul>
            <li>To match customers with nearby available riders in Ashta.</li>
            <li>To calculate fair, transparent fares based on road distance.</li>
            <li>To verify safety through 4-digit ride start OTP verification.</li>
            <li>To ensure community safety through driver document approvals.</li>
          </ul>

          <h2 style={{ color: '#f8fafc', fontSize: '20px', marginTop: '24px', marginBottom: '12px' }}>4. Data Protection & Security</h2>
          <p>We do not sell, rent, or trade your personal data to any third-party advertisers. All documents and credentials are encrypted and stored securely.</p>

          <h2 style={{ color: '#f8fafc', fontSize: '20px', marginTop: '24px', marginBottom: '12px' }}>5. Contact Us</h2>
          <p>If you have any questions or safety inquiries regarding AshtaRide, please contact our support team:</p>
          <p style={{ color: '#fbbf24', fontWeight: 'bold' }}>📍 AshtaRide Operations Office, Ashta, Dist. Sehore, Madhya Pradesh - 466116<br/>📧 Email: support@ashtaride.com</p>
        </div>

        <div style={{ textAlign: 'center', marginTop: '40px', paddingTop: '20px', borderTop: '1px solid #334155' }}>
          <a href="/login" style={{ color: '#38bdf8', textDecoration: 'none', fontWeight: 'bold' }}>← Back to AshtaRide Admin Portal</a>
        </div>
      </div>
    </div>
  );
};

export default PrivacyPolicyPage;
