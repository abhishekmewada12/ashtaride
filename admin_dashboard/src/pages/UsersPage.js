import React, { useState, useEffect } from 'react';
import { getAllUsers, blockUser } from '../services/api';
import { User, Phone, Bike, Ban, CheckCircle, RefreshCw, Search } from 'lucide-react';

export default function UsersPage() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(null);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const res = await getAllUsers(page);
      setUsers(res.data.users || []);
    } catch (err) {
      console.error(err);
    }
    setLoading(false);
  };

  useEffect(() => { fetchUsers(); }, [page]);

  const handleBlock = async (userId, userName, isBlocked) => {
    setActionLoading(userId);
    try {
      await blockUser(userId);
      setUsers(prev => prev.map(u =>
        u.id === userId ? { ...u, is_blocked: !u.is_blocked } : u
      ));
    } catch (err) {
      alert('Error updating user status');
    }
    setActionLoading(null);
  };

  const filteredUsers = users.filter(u =>
    u.full_name?.toLowerCase().includes(search.toLowerCase()) ||
    u.mobile_number?.includes(search)
  );

  return (
    <div>
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Users</h1>
          <p className="text-gray-500 text-sm mt-1">
            {users.length} total users
          </p>
        </div>
        <button
          onClick={fetchUsers}
          className="flex items-center gap-2 bg-yellow-400 text-gray-900 px-4 py-2 rounded-xl font-semibold hover:bg-yellow-300 transition-colors"
        >
          <RefreshCw size={16} />
          Refresh
        </button>
      </div>

      {/* Search */}
      <div className="relative mb-6">
        <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by name or mobile..."
          className="w-full bg-white border border-gray-200 rounded-xl pl-11 pr-4 py-3 focus:outline-none focus:border-yellow-400 transition-colors"
        />
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin w-10 h-10 border-4 border-yellow-400 border-t-transparent rounded-full" />
        </div>
      ) : (
        <>
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <table className="w-full">
              <thead>
                <tr className="bg-gray-50 border-b border-gray-100">
                  <th className="text-left px-6 py-4 text-sm font-semibold text-gray-600">User</th>
                  <th className="text-left px-6 py-4 text-sm font-semibold text-gray-600">Mobile</th>
                  <th className="text-left px-6 py-4 text-sm font-semibold text-gray-600">Rides</th>
                  <th className="text-left px-6 py-4 text-sm font-semibold text-gray-600">Status</th>
                  <th className="text-left px-6 py-4 text-sm font-semibold text-gray-600">Joined</th>
                  <th className="text-left px-6 py-4 text-sm font-semibold text-gray-600">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {filteredUsers.map((user) => (
                  <tr key={user.id} className="hover:bg-gray-50 transition-colors">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 bg-yellow-100 rounded-xl flex items-center justify-center">
                          <User size={18} className="text-yellow-600" />
                        </div>
                        <span className="font-medium text-gray-900">
                          {user.full_name || 'No Name'}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2 text-gray-600 text-sm">
                        <Phone size={14} />
                        +91 {user.mobile_number}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2 text-gray-600 text-sm">
                        <Bike size={14} />
                        {user.total_rides} rides
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`text-xs font-semibold px-3 py-1 rounded-full ${
                        user.is_blocked
                          ? 'bg-red-100 text-red-600'
                          : 'bg-green-100 text-green-600'
                      }`}>
                        {user.is_blocked ? 'Blocked' : 'Active'}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-500">
                      {new Date(user.created_at).toLocaleDateString('en-IN')}
                    </td>
                    <td className="px-6 py-4">
                      <button
                        onClick={() => handleBlock(user.id, user.full_name, user.is_blocked)}
                        disabled={actionLoading === user.id}
                        className={`flex items-center gap-2 px-3 py-2 rounded-xl text-sm font-semibold transition-colors disabled:opacity-50 ${
                          user.is_blocked
                            ? 'bg-green-100 text-green-600 hover:bg-green-200'
                            : 'bg-red-100 text-red-600 hover:bg-red-200'
                        }`}
                      >
                        {user.is_blocked
                          ? <><CheckCircle size={14} /> Unblock</>
                          : <><Ban size={14} /> Block</>
                        }
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            {filteredUsers.length === 0 && (
              <div className="text-center py-12 text-gray-400">
                No users found
              </div>
            )}
          </div>

          {/* Pagination */}
          <div className="flex items-center justify-between mt-4">
            <button
              onClick={() => setPage(p => Math.max(1, p - 1))}
              disabled={page === 1}
              className="px-4 py-2 bg-white border border-gray-200 rounded-xl text-sm font-semibold disabled:opacity-50 hover:bg-gray-50"
            >
              ← Previous
            </button>
            <span className="text-sm text-gray-500">Page {page}</span>
            <button
              onClick={() => setPage(p => p + 1)}
              disabled={users.length < 20}
              className="px-4 py-2 bg-white border border-gray-200 rounded-xl text-sm font-semibold disabled:opacity-50 hover:bg-gray-50"
            >
              Next →
            </button>
          </div>
        </>
      )}
    </div>
  );
}