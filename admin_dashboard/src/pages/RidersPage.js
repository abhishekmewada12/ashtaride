import React, { useState, useEffect } from 'react';
import { getPendingRiders, getAllRiders, approveRider, rejectRider, blockRider, unblockRider } from '../services/api';
import { CheckCircle, XCircle, User, Phone, FileText, RefreshCw, ShieldAlert, ShieldCheck, Search, Eye } from 'lucide-react';

export default function RidersPage() {
  const [activeTab, setActiveTab] = useState('pending'); // 'pending' or 'all'
  const [riders, setRiders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(null);
  
  // Search & Filter
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  // Modals
  const [selectedRider, setSelectedRider] = useState(null); // Detail Modal
  const [rejectModal, setRejectModal] = useState(null);
  const [rejectReason, setRejectReason] = useState('');
  const [blockModal, setBlockModal] = useState(null);
  const [blockReason, setBlockReason] = useState('');

  const fetchRiders = async () => {
    setLoading(true);
    try {
      if (activeTab === 'pending') {
        const res = await getPendingRiders();
        setRiders(res.data.riders || []);
      } else {
        const res = await getAllRiders(statusFilter, search);
        setRiders(res.data.riders || []);
      }
    } catch (err) {
      console.error(err);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchRiders();
  }, [activeTab, statusFilter]);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    fetchRiders();
  };

  const handleApprove = async (riderId, riderName) => {
    setActionLoading(riderId);
    try {
      await approveRider(riderId);
      fetchRiders();
      alert(`✅ ${riderName} approved!`);
    } catch (err) {
      alert('Error approving rider');
    }
    setActionLoading(null);
  };

  const handleReject = async () => {
    if (!rejectReason.trim()) return alert('Please enter rejection reason');
    setActionLoading(rejectModal.id);
    try {
      await rejectRider(rejectModal.id, rejectReason);
      setRejectModal(null);
      setRejectReason('');
      fetchRiders();
      alert('❌ Rider verification rejected');
    } catch (err) {
      alert('Error rejecting rider');
    }
    setActionLoading(null);
  };

  const handleBlock = async () => {
    if (!blockReason.trim()) return alert('Please enter block reason');
    setActionLoading(blockModal.id);
    try {
      await blockRider(blockModal.id, blockReason);
      setBlockModal(null);
      setBlockReason('');
      fetchRiders();
      alert(`🚫 Rider blocked successfully!`);
    } catch (err) {
      alert('Error blocking rider');
    }
    setActionLoading(null);
  };

  const handleUnblock = async (riderId, riderName) => {
    if (!window.confirm(`Are you sure you want to unblock ${riderName}?`)) return;
    setActionLoading(riderId);
    try {
      await unblockRider(riderId);
      fetchRiders();
      alert(`✅ ${riderName} unblocked successfully!`);
    } catch (err) {
      alert('Error unblocking rider');
    }
    setActionLoading(null);
  };

  return (
    <div>
      {/* Header & Tabs */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Rider Management</h1>
          <p className="text-gray-500 text-sm mt-1">Manage verifications, view A-Z details, and take actions</p>
        </div>

        <div className="flex gap-2 bg-gray-200 p-1 rounded-xl">
          <button
            onClick={() => setActiveTab('pending')}
            className={`px-4 py-2 rounded-lg text-sm font-semibold transition-all ${
              activeTab === 'pending' ? 'bg-yellow-400 text-gray-900 shadow' : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            ⏳ Pending Verification
          </button>
          <button
            onClick={() => setActiveTab('all')}
            className={`px-4 py-2 rounded-lg text-sm font-semibold transition-all ${
              activeTab === 'all' ? 'bg-yellow-400 text-gray-900 shadow' : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            👥 All Riders Directory
          </button>
        </div>
      </div>

      {/* Search & Filter Bar (Only in 'All' tab) */}
      {activeTab === 'all' && (
        <div className="bg-white p-4 rounded-2xl mb-6 shadow-sm border border-gray-100 flex flex-col sm:flex-row gap-3">
          <form onSubmit={handleSearchSubmit} className="flex-1 flex gap-2">
            <div className="relative flex-1">
              <Search size={18} className="absolute left-3 top-3 text-gray-400" />
              <input
                type="text"
                placeholder="Search by name or mobile number..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:border-yellow-400"
              />
            </div>
            <button type="submit" className="bg-yellow-400 text-gray-900 px-4 py-2 rounded-xl text-sm font-semibold hover:bg-yellow-300">
              Search
            </button>
          </form>

          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-yellow-400 bg-white"
          >
            <option value="all">All Status</option>
            <option value="verified">✅ Verified Only</option>
            <option value="pending">⏳ Pending Only</option>
            <option value="blocked">🚫 Blocked Only</option>
          </select>

          <button onClick={fetchRiders} className="p-2 border border-gray-200 rounded-xl hover:bg-gray-50 text-gray-600">
            <RefreshCw size={18} />
          </button>
        </div>
      )}

      {/* Rider Cards Grid */}
      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin w-10 h-10 border-4 border-yellow-400 border-t-transparent rounded-full" />
        </div>
      ) : riders.length === 0 ? (
        <div className="bg-white rounded-2xl p-12 text-center shadow-sm border border-gray-100">
          <CheckCircle size={48} className="text-green-400 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-gray-900">No Riders Found</h3>
          <p className="text-gray-500 mt-2">No records match the current criteria.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {riders.map((rider) => (
            <div key={rider.id} className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 relative">
              {/* Rider Header */}
              <div className="flex items-start gap-4 mb-4">
                <div className="w-14 h-14 bg-yellow-100 rounded-xl flex items-center justify-center flex-shrink-0">
                  <User size={28} className="text-yellow-600" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <h3 className="font-bold text-gray-900 text-lg">{rider.full_name}</h3>
                    {rider.is_blocked ? (
                      <span className="bg-red-100 text-red-600 text-xs font-bold px-2.5 py-0.5 rounded-full">BLOCKED</span>
                    ) : rider.verification_status === 'approved' ? (
                      <span className="bg-green-100 text-green-700 text-xs font-bold px-2.5 py-0.5 rounded-full">VERIFIED</span>
                    ) : (
                      <span className="bg-orange-100 text-orange-600 text-xs font-bold px-2.5 py-0.5 rounded-full">PENDING</span>
                    )}
                  </div>
                  <div className="flex items-center gap-2 text-gray-500 text-sm mt-1">
                    <Phone size={14} />
                    <span>+91 {rider.mobile_number}</span>
                  </div>
                </div>
              </div>

              {/* Block Alert if blocked */}
              {rider.is_blocked && (
                <div className="bg-red-50 border border-red-200 rounded-xl p-3 mb-4 text-xs text-red-800">
                  <p><strong>Block Reason:</strong> {rider.block_reason || 'Policy violation'}</p>
                  {rider.unlock_request_message && (
                    <p className="mt-1 text-orange-800">
                      <strong>Appeal from Rider:</strong> "{rider.unlock_request_message}"
                    </p>
                  )}
                </div>
              )}

              {/* Stats & Vehicle Info */}
              <div className="bg-gray-50 rounded-xl p-3 mb-4 text-xs text-gray-700 grid grid-cols-2 sm:grid-cols-4 gap-2">
                <div>
                  <span className="text-gray-400">Total Rides:</span>
                  <p className="font-bold text-sm text-gray-900">{rider.total_rides || 0}</p>
                </div>
                <div>
                  <span className="text-gray-400">Earnings:</span>
                  <p className="font-bold text-sm text-green-600">₹{rider.total_earnings || 0}</p>
                </div>
                <div>
                  <span className="text-gray-400">Rating:</span>
                  <p className="font-bold text-sm text-yellow-600">⭐ {rider.average_rating || '5.0'}</p>
                </div>
                <div>
                  <span className="text-gray-400">Vehicle:</span>
                  <p className="font-bold text-sm text-gray-900">{rider.vehicle?.plate_number || 'N/A'}</p>
                </div>
              </div>

              {/* Actions Toolbar */}
              <div className="flex gap-2 pt-2 border-t border-gray-100">
                {/* View Details Modal Button */}
                <button
                  onClick={() => setSelectedRider(rider)}
                  className="flex-1 flex items-center justify-center gap-1.5 py-2.5 bg-gray-100 hover:bg-gray-200 text-gray-800 rounded-xl text-sm font-semibold transition-colors"
                >
                  <Eye size={16} /> A-Z Details
                </button>

                {/* Approve/Reject (For Pending) */}
                {rider.verification_status === 'pending' && (
                  <>
                    <button
                      onClick={() => handleApprove(rider.id, rider.full_name)}
                      disabled={actionLoading === rider.id}
                      className="flex-1 py-2.5 bg-green-500 hover:bg-green-600 text-white rounded-xl text-sm font-semibold transition-colors"
                    >
                      Approve
                    </button>
                    <button
                      onClick={() => setRejectModal(rider)}
                      disabled={actionLoading === rider.id}
                      className="flex-1 py-2.5 bg-red-500 hover:bg-red-600 text-white rounded-xl text-sm font-semibold transition-colors"
                    >
                      Reject
                    </button>
                  </>
                )}

                {/* Block / Unblock (For Verified / Active Riders) */}
                {rider.verification_status === 'approved' && (
                  rider.is_blocked ? (
                    <button
                      onClick={() => handleUnblock(rider.id, rider.full_name)}
                      disabled={actionLoading === rider.id}
                      className="flex-1 flex items-center justify-center gap-1.5 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-xl text-sm font-semibold"
                    >
                      <ShieldCheck size={16} /> Unblock
                    </button>
                  ) : (
                    <button
                      onClick={() => setBlockModal(rider)}
                      disabled={actionLoading === rider.id}
                      className="flex-1 flex items-center justify-center gap-1.5 py-2.5 bg-red-600 hover:bg-red-700 text-white rounded-xl text-sm font-semibold"
                    >
                      <ShieldAlert size={16} /> Block Rider
                    </button>
                  )
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* 🔍 A to Z Details Modal */}
      {selectedRider && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl p-6 w-full max-w-lg shadow-xl max-h-[85vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <h3 className="font-bold text-xl text-gray-900">Rider Full Details (A-Z)</h3>
              <button onClick={() => setSelectedRider(null)} className="text-gray-400 hover:text-gray-600 text-lg font-bold">✖</button>
            </div>
            
            <div className="space-y-3 text-sm">
              <div className="p-3 bg-gray-50 rounded-xl">
                <p><strong>Full Name:</strong> {selectedRider.full_name}</p>
                <p><strong>Mobile:</strong> +91 {selectedRider.mobile_number}</p>
                <p><strong>Joined:</strong> {new Date(selectedRider.created_at).toLocaleString('en-IN')}</p>
                <p><strong>Status:</strong> {selectedRider.is_blocked ? '🚫 Blocked' : selectedRider.verification_status}</p>
              </div>

              <h4 className="font-bold text-gray-900 mt-3">Vehicle Information</h4>
              <div className="p-3 bg-gray-50 rounded-xl">
                <p><strong>Type:</strong> {selectedRider.vehicle?.vehicle_type || 'N/A'}</p>
                <p><strong>Brand & Model:</strong> {selectedRider.vehicle?.brand} {selectedRider.vehicle?.model}</p>
                <p><strong>Plate Number:</strong> {selectedRider.vehicle?.plate_number || 'N/A'}</p>
              </div>

              <h4 className="font-bold text-gray-900 mt-3">Government Documents</h4>
              <div className="grid grid-cols-2 gap-2">
                <a
                  href={selectedRider.aadhaar_doc_url || '#'}
                  target="_blank"
                  rel="noreferrer"
                  className="p-3 bg-blue-50 text-blue-600 rounded-xl text-center font-semibold text-xs border border-blue-200"
                >
                  Aadhaar Card Preview 🔍
                </a>
                <a
                  href={selectedRider.driving_license_url || '#'}
                  target="_blank"
                  rel="noreferrer"
                  className="p-3 bg-green-50 text-green-600 rounded-xl text-center font-semibold text-xs border border-green-200"
                >
                  Driving License Preview 🔍
                </a>
              </div>
            </div>

            <button
              onClick={() => setSelectedRider(null)}
              className="mt-6 w-full py-3 bg-gray-900 text-white rounded-xl font-semibold"
            >
              Close
            </button>
          </div>
        </div>
      )}

      {/* 🚫 Block Modal */}
      {blockModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-xl">
            <h3 className="font-bold text-lg text-red-600 mb-2">🚫 Block Rider Account</h3>
            <p className="text-gray-600 text-sm mb-4">
              Blocking <strong>{blockModal.full_name}</strong> (+91 {blockModal.mobile_number}). Rider ko ye reason app mein dikhega.
            </p>
            <textarea
              value={blockReason}
              onChange={(e) => setBlockReason(e.target.value)}
              placeholder="e.g. Customer misbehaviour complaint on ride #24..."
              rows={3}
              className="w-full border border-gray-200 rounded-xl p-3 text-sm focus:outline-none focus:border-red-400 resize-none"
            />
            <div className="flex gap-3 mt-4">
              <button onClick={() => { setBlockModal(null); setBlockReason(''); }} className="flex-1 py-3 border border-gray-200 rounded-xl font-semibold text-gray-600">
                Cancel
              </button>
              <button onClick={handleBlock} className="flex-1 py-3 bg-red-600 text-white rounded-xl font-semibold hover:bg-red-700">
                Confirm Block
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ❌ Reject Modal */}
      {rejectModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-xl">
            <h3 className="font-bold text-lg text-gray-900 mb-2">Reject Rider Verification</h3>
            <textarea
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              placeholder="Enter rejection reason..."
              rows={3}
              className="w-full border border-gray-200 rounded-xl p-3 text-sm focus:outline-none focus:border-yellow-400 resize-none"
            />
            <div className="flex gap-3 mt-4">
              <button onClick={() => { setRejectModal(null); setRejectReason(''); }} className="flex-1 py-3 border border-gray-200 rounded-xl font-semibold">Cancel</button>
              <button onClick={handleReject} className="flex-1 py-3 bg-red-500 text-white rounded-xl font-semibold hover:bg-red-600">Confirm Reject</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}