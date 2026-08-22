import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class ActiveRideScreen extends StatefulWidget {
  final String rideId;
  final String pickupAddress;
  final String destinationAddress;
  final String fare;
  final double pickupLat;
  final double pickupLng;

  const ActiveRideScreen({
    super.key,
    required this.rideId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.fare,
    required this.pickupLat,
    required this.pickupLng,
  });

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
  final MapController _mapController = MapController();
  final _otpController = TextEditingController();
  String _rideStatus = 'accepted';
  LatLng _currentLocation = const LatLng(22.9734, 76.6178);
  Timer? _locationTimer;
  bool _loading = false;
  bool _showOtpDialog = false;

  final Map<String, Map<String, dynamic>> _statusInfo = {
    'accepted': {
      'title': 'Navigate to Pickup',
      'subtitle': 'Go to customer pickup location',
      'buttonText': 'I\'ve Arrived at Pickup',
      'buttonColor': const Color(0xFFFFD000),
    },
    'rider_arriving': {
      'title': 'Enter Customer OTP',
      'subtitle': 'Ask customer for OTP to start ride',
      'buttonText': 'Enter OTP & Start Ride',
      'buttonColor': Colors.green,
    },
    'ride_started': {
      'title': 'Ride in Progress',
      'subtitle': 'Navigate to destination',
      'buttonText': 'Complete Ride',
      'buttonColor': Colors.blue,
    },
  };

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('rider_token');
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentLocation, 15);
    } catch (e) {
      // Use default
    }
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        final token = await _getToken();
        await _dio.post(
          '/api/v1/riders/location',
          data: {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } catch (e) {
        // Silent
      }
    });
  }

  Future<void> _markArrived() async {
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      await _dio.post(
        '/api/v1/riders/rides/${widget.rideId}/arrived',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _rideStatus = 'rider_arriving');
    } catch (e) {
      _showSnack('Error updating status');
    }
    setState(() => _loading = false);
  }

  Future<void> _startRideWithOtp() async {
    if (_otpController.text.length != 4) {
      _showSnack('Please enter 4 digit OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      await _dio.post(
        '/api/v1/riders/rides/${widget.rideId}/start',
        queryParameters: {'otp': _otpController.text},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _rideStatus = 'ride_started';
        _showOtpDialog = false;
      });
      Navigator.pop(context); // Close dialog
      _showSnack('Ride started! Navigate to destination.');
    } catch (e) {
      _showSnack('Invalid OTP! Ask customer for correct OTP.');
    }
    setState(() => _loading = false);
  }

  Future<void> _completeRide() async {
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      await _dio.post(
        '/api/v1/riders/rides/${widget.rideId}/complete',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      _locationTimer?.cancel();
      _showCompletionDialog();
    } catch (e) {
      _showSnack('Error completing ride');
    }
    setState(() => _loading = false);
  }

  void _showOtpInputDialog() {
    _otpController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Enter Customer OTP',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ask customer for their 4 digit OTP',
              style: GoogleFonts.poppins(
                  color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '0000',
                hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[300], fontSize: 28),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFFFFD000), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFFFFD000), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: _loading ? null : _startRideWithOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD000),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Color(0xFF1A1A1A), strokeWidth: 2),
                  )
                : Text('Start Ride',
                    style: GoogleFonts.poppins(
                        color: const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Ride Completed! 🎉',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD000).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Fare Collected:',
                      style: GoogleFonts.poppins(color: Colors.grey[600])),
                  Text('₹${widget.fare}',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: const Color(0xFF1A1A1A))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Collect cash from customer',
                style:
                    GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                  context, '/dashboard', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD000),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Done',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF1A1A1A),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _openNavigation(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleAction() {
    if (_rideStatus == 'accepted') {
      _markArrived();
    } else if (_rideStatus == 'rider_arriving') {
      _showOtpInputDialog();
    } else if (_rideStatus == 'ride_started') {
      _completeRide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusData = _statusInfo[_rideStatus]!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Status Header
          FadeInDown(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              color: const Color(0xFF1A1A1A),
              child: Column(
                children: [
                  Text(
                    statusData['title'] as String,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFD000),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusData['subtitle'] as String,
                    style: GoogleFonts.poppins(
                        color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          // Map
          SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD000),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.electric_bike,
                            color: Color(0xFF1A1A1A), size: 28),
                      ),
                    ),
                    Marker(
                      point: LatLng(widget.pickupLat, widget.pickupLng),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.person_pin_circle,
                          color: Colors.green, size: 40),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Location info
                  FadeInUp(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.my_location,
                                  color: Color(0xFFFFD000), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.pickupAddress,
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _openNavigation(
                                    widget.pickupLat, widget.pickupLng),
                                icon: const Icon(Icons.navigation,
                                    color: Color(0xFFFFD000)),
                              ),
                            ],
                          ),
                          Divider(color: Colors.grey[200]),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: Colors.red, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.destinationAddress,
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Fare
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Fare',
                              style: GoogleFonts.poppins(
                                  color: Colors.white54)),
                          Text(
                            '₹${widget.fare}',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFFD000),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Cash',
                                style: GoogleFonts.poppins(
                                    color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Button
          FadeInUp(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusData['buttonColor'] as Color,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : Text(
                          statusData['buttonText'] as String,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}