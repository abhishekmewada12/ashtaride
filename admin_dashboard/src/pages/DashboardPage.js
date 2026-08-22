import React, { useState, useEffect } from 'react';
import { getDashboard } from '../services/api';
import { Users, Bike, MapPin, IndianRupee, TrendingUp, AlertCircle, RefreshCw } from 'lucide-react';

const StatCard = ({ icon: Icon, label, value, sub, color }) => (
  <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
    <div className="flex items-center justify-between mb-4">
      <div className={`w-12 h-12 ${color} rounded-xl flex items-center justify-center`}>
        <Icon size={24} className="text-white" />
      </div>
    </div>
    <p className="text-gray-500 text-sm">{label}</p>
    <p className="text-3xl font-bold text-gray-900 mt-1">{value}</p>
    {sub && <p className="text-sm text-gray-400 mt-1">{sub}</p>}
  </div>
);

export default function DashboardPage() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState(null);

  const fetchData = async () => {
    try {
      const res = await getDashboard();
      setData(res.data);
      setLastUpdated(new Date().toLocaleTimeString());
    } catch (err) {
      console.error('Dashboard error:', err);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 30000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-10 h-10 border-4 border-yellow-400 border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
          <p className="text-gray-500 text-sm mt-1">Last updated: {lastUpdated}</p>
        </div>
        <button onClick={fetchData} className="flex items-center gap-2 bg-yellow-400 text-gray-900 px-4 py-2 rounded-xl font-semibold hover:bg-yellow-300 transition-colors">
          <RefreshCw size={16} />
          Refresh
        </button>
      </div>

            {/* Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4 mb-8">
        <StatCard icon={Users} label="Total Users" value={data?.users?.total || 0} color="bg-blue-500" />
        <StatCard icon={Bike} label="Total Riders" value={data?.riders?.total || 0} sub={`${data?.riders?.active_online || 0} online now`} color="bg-gray-700" />
        <StatCard icon={Bike} label="Verified Riders" value={data?.riders?.verified || 0} sub="Approved & active" color="bg-green-500" />
        <StatCard icon={MapPin} label="Total Rides" value={data?.rides?.total || 0} sub={`${data?.rides?.active || 0} active now`} color="bg-purple-500" />
        <StatCard icon={IndianRupee} label="Today Revenue" value={`₹${data?.revenue?.today || 0}`} sub={`Total: ₹${data?.revenue?.total || 0}`} color="bg-yellow-500" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-8">
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 bg-orange-100 rounded-xl flex items-center justify-center">
              <AlertCircle size={20} className="text-orange-500" />
            </div>
            <h3 className="font-semibold text-gray-900">Pending Verifications</h3>
          </div>
          <p className="text-4xl font-bold text-orange-500">{data?.riders?.pending_verification || 0}</p>
          <p className="text-gray-400 text-sm mt-2">Riders waiting for approval</p>
          <a href="/riders" className="mt-4 inline-block text-sm text-yellow-600 font-semibold hover:text-yellow-700">
            Review Now
          </a>
        </div>

        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 bg-green-100 rounded-xl flex items-center justify-center">
              <TrendingUp size={20} className="text-green-500" />
            </div>
            <h3 className="font-semibold text-gray-900">Active Rides</h3>
          </div>
          <p className="text-4xl font-bold text-green-500">{data?.rides?.active || 0}</p>
          <p className="text-gray-400 text-sm mt-2">Rides happening right now</p>
          <a href="/rides" className="mt-4 inline-block text-sm text-yellow-600 font-semibold hover:text-yellow-700">
            Monitor
          </a>
        </div>

        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 bg-red-100 rounded-xl flex items-center justify-center">
              <AlertCircle size={20} className="text-red-500" />
            </div>
            <h3 className="font-semibold text-gray-900">SOS Alerts</h3>
          </div>
          <p className="text-4xl font-bold text-red-500">{data?.alerts?.active_sos || 0}</p>
          <p className="text-gray-400 text-sm mt-2">Active emergency alerts</p>
          {data?.alerts?.active_sos > 0 && (
            <span className="mt-4 inline-block text-sm text-red-600 font-semibold animate-pulse">
              Immediate attention required!
            </span>
          )}
        </div>
      </div>

      <div className="bg-gray-900 rounded-2xl p-6 text-white">
        <h3 className="font-bold text-lg mb-4 text-yellow-400">AshtaRide Quick Stats</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div>
            <p className="text-gray-400 text-sm">Online Riders</p>
            <p className="text-2xl font-bold text-white">{data?.riders?.active_online || 0}</p>
          </div>
          <div>
            <p className="text-gray-400 text-sm">Total Revenue</p>
            <p className="text-2xl font-bold text-yellow-400">Rs.{data?.revenue?.total || 0}</p>
          </div>
          <div>
            <p className="text-gray-400 text-sm">Today Revenue</p>
            <p className="text-2xl font-bold text-green-400">Rs.{data?.revenue?.today || 0}</p>
          </div>
          <div>
            <p className="text-gray-400 text-sm">Pending Riders</p>
            <p className="text-2xl font-bold text-orange-400">{data?.riders?.pending_verification || 0}</p>
          </div>
        </div>
      </div>
    </div>
  );
}