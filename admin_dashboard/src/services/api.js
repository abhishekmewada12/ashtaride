import axios from 'axios';

const API_BASE_URL = 'http://localhost:8000';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor - token automatically add karta hai
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('admin_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor - 401 pe logout
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('admin_token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// Auth APIs
export const adminLogin = (email, password) =>
  api.post('/api/v1/auth/admin/login', { email, password });

// Dashboard APIs
export const getDashboard = () =>
  api.get('/api/v1/admin/dashboard');

// Rider APIs
export const getPendingRiders = () =>
  api.get('/api/v1/admin/riders/pending');

export const getAllRiders = (statusFilter = 'all', search = '') =>
  api.get('/api/v1/admin/riders/all', { params: { status_filter: statusFilter, search } });

export const approveRider = (riderId) =>
  api.post(`/api/v1/admin/riders/${riderId}/approve`);

export const rejectRider = (riderId, reason) =>
  api.post(`/api/v1/admin/riders/${riderId}/reject`, null, {
    params: { reason }
  });

export const blockRider = (riderId, reason) =>
  api.post(`/api/v1/admin/riders/${riderId}/block`, null, { params: { reason } });

export const unblockRider = (riderId) =>
  api.post(`/api/v1/admin/riders/${riderId}/unblock`);

// Rides APIs
export const getActiveRides = () =>
  api.get('/api/v1/admin/rides/active');

// Users APIs
export const getAllUsers = (page = 1) =>
  api.get('/api/v1/admin/users', { params: { page } });

export const blockUser = (userId) =>
  api.post(`/api/v1/admin/users/${userId}/block`);

export default api;