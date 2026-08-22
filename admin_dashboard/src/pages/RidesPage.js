import React, { useState, useEffect } from 'react';
import { getActiveRides } from '../services/api';
import { MapPin, Clock, IndianRupee, RefreshCw, Bike } from 'lucide-react';

export default function RidesPage() {
  const [rides, setRides] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchRides = async () => {
    setLoading(true);
    try {
      const res = await getActiveRides();
      setRides(res.data.rides || []);
    } catch (err) {
      console.error(err);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchRides();
    const interval = setInterval(fetchRides, 10000);
    return () => clearInterval(interval);
  }, []);

  const getStatusColor = (status) => {
    switch (status) {
      case 'accepted': return 'bg-blue-100 text-blue-600';
      case 'rider_arriving': return 'bg-orange-100 text-orange-600';
      case 'ride_started': return 'bg-green-100 text-green-600';
      default: return 'bg-gray-100 text-gray-600';
    }
  };

  const getStatusLabel = (status) => {
    switch (status) {
      case 'accepted': return '✅ Accepted';
      case 'rider_arriving': return '🏍️ Rider Arriving';
      case 'ride_started': return '🚀 In Progress';
      default: return status;
    }
  };

  return (
    <div>
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Active Rides</h1>
          <p className="text-gray-500 text-sm mt-1">
            {rides.length} rides happening right now • Auto refreshes every 10s
          </p>
        </div>
        <button
          onClick={fetchRides}
          className="flex items-center gap-2 bg-yellow-400 text-gray-900 px-4 py-2 rounded-xl font-semibold hover:bg-yellow-300 transition-colors"
        >
          <RefreshCw size={16} />
          Refresh
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin w-10 h-10 border-4 border-yellow-400 border-t-transparent rounded-full" />
        </div>
      ) : rides.length === 0 ? (
        <div className="bg-white rounded-2xl p-12 text-center shadow-sm border border-gray-100">
          <Bike size={48} className="text-gray-300 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-gray-900">No Active Rides</h3>
          <p className="text-gray-500 mt-2">No rides happening right now</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {rides.map((ride) => (
            <div
              key={ride.ride_id}
              className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100"
            >
              {/* Status Badge */}
              <div className="flex items-center justify-between mb-4">
                <span className={`text-xs font-semibold px-3 py-1 rounded-full ${getStatusColor(ride.status)}`}>
                  {getStatusLabel(ride.status)}
                </span>
                <div className="flex items-center gap-1 text-gray-400 text-sm">
                  <Clock size={14} />
                  <span>
                    {ride.started_at
                      ? new Date(ride.started_at).toLocaleTimeString('en-IN')
                      : 'Just started'}
                  </span>
                </div>
              </div>

              {/* Locations */}
              <div className="space-y-3 mb-4">
                <div className="flex items-start gap-3">
                  <div className="w-8 h-8 bg-yellow-100 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5">
                    <MapPin size={14} className="text-yellow-600" />
                  </div>
                  <div>
                    <p className="text-xs text-gray-400">Pickup</p>
                    <p className="text-sm font-medium text-gray-900 line-clamp-1">
                      {ride.pickup}
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="w-8 h-8 bg-red-100 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5">
                    <MapPin size={14} className="text-red-500" />
                  </div>
                  <div>
                    <p className="text-xs text-gray-400">Destination</p>
                    <p className="text-sm font-medium text-gray-900 line-clamp-1">
                      {ride.destination}
                    </p>
                  </div>
                </div>
              </div>

              {/* Fare */}
              <div className="flex items-center justify-between pt-4 border-t border-gray-100">
                <div className="flex items-center gap-2">
                  <IndianRupee size={16} className="text-green-500" />
                  <span className="font-bold text-gray-900 text-lg">
                    ₹{ride.fare}
                  </span>
                  <span className="text-gray-400 text-sm">• Cash</span>
                </div>
                <span className="text-xs text-gray-400 font-mono">
                  #{ride.ride_id?.slice(-8)}
                </span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}