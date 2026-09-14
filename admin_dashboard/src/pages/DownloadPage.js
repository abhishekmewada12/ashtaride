import React from 'react';
import { Download, Smartphone, Bike, ShieldCheck, CheckCircle2, ArrowRight } from 'lucide-react';

export default function DownloadPage() {
  return (
    <div className="min-h-screen bg-gray-900 text-white flex flex-col justify-between selection:bg-yellow-400 selection:text-gray-900 font-sans">
      {/* Top Header / Nav */}
      <header className="px-6 py-5 border-b border-gray-800 flex items-center justify-between max-w-5xl mx-auto w-full">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-yellow-400 rounded-xl flex items-center justify-center font-black text-gray-900 text-xl shadow-lg shadow-yellow-400/20">
            A
          </div>
          <div>
            <h1 className="font-extrabold text-xl tracking-tight text-white">AshtaRide</h1>
            <p className="text-xs text-yellow-400 font-medium">Ashta Ki Apni Ride 🚖</p>
          </div>
        </div>
        <a
          href="/login"
          className="text-xs font-semibold px-4 py-2 bg-gray-800 hover:bg-gray-700 text-gray-300 rounded-lg transition-all"
        >
          Admin Portal
        </a>
      </header>

      {/* Main Hero & Download Section */}
      <main className="max-w-4xl mx-auto px-4 py-12 flex-1 flex flex-col items-center text-center">
        {/* Badge */}
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-yellow-400/10 border border-yellow-400/30 text-yellow-400 text-xs font-semibold mb-6">
          <span className="w-2 h-2 rounded-full bg-yellow-400 animate-pulse" />
          Official Android Apps Ready for Download
        </div>

        <h2 className="text-3xl sm:text-5xl font-black tracking-tight text-white mb-4 leading-tight">
          Download <span className="text-yellow-400">AshtaRide</span> Apps
        </h2>
        <p className="text-gray-400 text-sm sm:text-base max-w-xl mb-10">
          Book fast, affordable bike and auto rides anywhere in Ashta, or join as a Rider Partner to start earning today.
        </p>

        {/* Download Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 w-full max-w-3xl mb-12">
          {/* Card 1: Customer App */}
          <div className="bg-gray-800/80 backdrop-blur-sm border border-gray-700 rounded-3xl p-6 sm:p-8 flex flex-col justify-between text-left hover:border-yellow-400/50 transition-all shadow-xl hover:shadow-yellow-400/5 group">
            <div>
              <div className="flex items-center justify-between mb-6">
                <div className="w-14 h-14 rounded-2xl bg-yellow-400/10 border border-yellow-400/20 flex items-center justify-center text-yellow-400 group-hover:scale-110 transition-transform">
                  <Smartphone size={28} />
                </div>
                <span className="text-xs font-bold px-3 py-1 bg-yellow-400 text-gray-900 rounded-full">
                  v1.0.0
                </span>
              </div>

              <h3 className="text-xl font-bold text-white mb-2">Customer App</h3>
              <p className="text-gray-400 text-xs sm:text-sm mb-6 leading-relaxed">
                Ride booking, live rider tracking, transparent pricing, 4-digit safety OTP & instant cash/UPI payments.
              </p>

              <div className="space-y-2 mb-8 text-xs text-gray-300">
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={16} className="text-yellow-400" />
                  <span>Ultra-lightweight: <strong>18.5 MB</strong></span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={16} className="text-yellow-400" />
                  <span>Supports Android 6.0 to 15.0</span>
                </div>
              </div>
            </div>

            <a
              href="/customer.apk"
              download="AshtaRide_Customer.apk"
              className="w-full py-4 bg-yellow-400 hover:bg-yellow-300 text-gray-900 font-bold rounded-2xl flex items-center justify-center gap-2 shadow-lg shadow-yellow-400/20 transition-all group-hover:gap-3"
            >
              <Download size={20} />
              <span>Download Customer APK</span>
              <ArrowRight size={16} />
            </a>
          </div>

          {/* Card 2: Rider Partner App */}
          <div className="bg-gray-800/80 backdrop-blur-sm border border-gray-700 rounded-3xl p-6 sm:p-8 flex flex-col justify-between text-left hover:border-yellow-400/50 transition-all shadow-xl hover:shadow-yellow-400/5 group">
            <div>
              <div className="flex items-center justify-between mb-6">
                <div className="w-14 h-14 rounded-2xl bg-green-500/10 border border-green-500/20 flex items-center justify-center text-green-400 group-hover:scale-110 transition-transform">
                  <Bike size={28} />
                </div>
                <span className="text-xs font-bold px-3 py-1 bg-green-500 text-gray-900 rounded-full">
                  Partner
                </span>
              </div>

              <h3 className="text-xl font-bold text-white mb-2">Driver Partner App</h3>
              <p className="text-gray-400 text-xs sm:text-sm mb-6 leading-relaxed">
                30-sec ride alert with loud ringtone, turn-by-turn navigation, daily earnings dashboard & direct calling.
              </p>

              <div className="space-y-2 mb-8 text-xs text-gray-300">
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={16} className="text-green-400" />
                  <span>Ultra-lightweight: <strong>18.8 MB</strong></span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={16} className="text-green-400" />
                  <span>Quick KYC & Selfie Upload</span>
                </div>
              </div>
            </div>

            <a
              href="/driver.apk"
              download="AshtaRide_Partner.apk"
              className="w-full py-4 bg-gray-700 hover:bg-gray-600 text-white font-bold rounded-2xl flex items-center justify-center gap-2 border border-gray-600 transition-all group-hover:gap-3"
            >
              <Download size={20} />
              <span>Download Driver Partner APK</span>
              <ArrowRight size={16} />
            </a>
          </div>
        </div>

        {/* Installation Instructions */}
        <div className="bg-gray-800/50 border border-gray-700/60 rounded-2xl p-6 text-left w-full max-w-3xl">
          <div className="flex items-center gap-2 mb-3 text-yellow-400 font-bold text-sm">
            <ShieldCheck size={18} />
            <span>How to install on Android:</span>
          </div>
          <ol className="text-xs sm:text-sm text-gray-300 space-y-2 list-decimal list-inside leading-relaxed">
            <li>Click on the <strong>Download APK</strong> button above.</li>
            <li>When your browser shows <em>"File might be harmful"</em>, tap <strong>"Download anyway"</strong>.</li>
            <li>Open the downloaded APK and tap <strong>Install</strong> (Allow <em>Install Unknown Apps</em> if prompted).</li>
          </ol>
        </div>
      </main>

      {/* Footer */}
      <footer className="px-6 py-6 border-t border-gray-800 text-center text-xs text-gray-500">
        <p>© {new Date().getFullYear()} AshtaRide Technologies. Made with ❤️ for Ashta, Madhya Pradesh.</p>
        <p className="mt-1">
          <a href="/privacy-policy" className="hover:text-yellow-400 underline">Privacy Policy</a>
        </p>
      </footer>
    </div>
  );
}
