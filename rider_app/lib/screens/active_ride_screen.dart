import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class ActiveRideScreen extends StatefulWidget {
  final String rideId;
  final String pickupAddress;
  final String destinationAddress;
  final String fare;
  final double pickupLat;
  final double pickupLng;
  final double destinationLat;
  final double destinationLng;
  final String customerName;
  final String customerMobile;
  final String vehicleType;
  final String paymentMethod;

  const ActiveRideScreen({
    super.key,
    required this.rideId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.fare,
    required this.pickupLat,
    required this.pickupLng,
    this.destinationLat = 22.9780,
    this.destinationLng = 76.6230,
    this.customerName = 'Customer',
    this.customerMobile = '',
    this.vehicleType = 'bike',
    this.paymentMethod = 'cash',
  });

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  final _dio = Dio(BaseOptions(baseUrl: 'https://ashtaride.onrender.com'));
  final MapController _mapController = MapController();
  final List<TextEditingController> _otpDigitControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  String _rideStatus = 'ASSIGNED'; // ASSIGNED -> DRIVER_ARRIVED -> IN_PROGRESS -> COMPLETED -> PAYMENT_COMPLETED
  LatLng _currentLocation = const LatLng(22.9734, 76.6178);
  Timer? _locationTimer;
  bool _loading = false;
  Map<String, dynamic>? _rideSummary;

  @override
  void initState() {
    super.initState();
    _currentLocation = LatLng(widget.pickupLat, widget.pickupLng);
    _getCurrentLocation();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    for (var c in _otpDigitControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp =>
      _otpDigitControllers.map((c) => c.text.trim()).join();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('rider_token');
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_currentLocation, 16);
      }
    } catch (_) {}
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
        }
        final token = await _getToken();
        if (token != null) {
          await _dio.post(
            '/api/v1/riders/location',
            data: {
              'latitude': position.latitude,
              'longitude': position.longitude,
            },
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
        }
      } catch (_) {}
    });
  }

  // STEP 1: Mark Arrived at Pickup
  Future<void> _markArrived() async {
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      await _dio.post(
        '/api/v1/riders/rides/${widget.rideId}/arrived',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _rideStatus = 'DRIVER_ARRIVED');
      _showSnack('Arrived at Pickup! Please ask customer for 4-digit OTP.');
      _showOtpInputDialog();
    } catch (e) {
      _showSnack('Error updating status. Try again.');
    }
    setState(() => _loading = false);
  }

  // STEP 2: Verify 4-Digit Safety OTP & Start Ride
  Future<void> _startRideWithOtp() async {
    final otp = _enteredOtp;
    if (otp.length != 4) {
      _showSnack('Please enter full 4-digit safety OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      await _dio.post(
        '/api/v1/riders/rides/${widget.rideId}/start',
        queryParameters: {'otp': otp},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() => _rideStatus = 'IN_PROGRESS');
        Navigator.pop(context); // Close OTP Dialog
        _showSnack('OTP Verified! Ride started. Navigate to destination. 🚀');
        _mapController.move(
            LatLng(widget.destinationLat, widget.destinationLng), 16);
      }
    } catch (e) {
      _showSnack('Invalid OTP! Ask customer for their 4-digit pickup code.');
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  // STEP 3: Complete Trip at Destination
  Future<void> _completeRide() async {
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      final res = await _dio.post(
        '/api/v1/riders/rides/${widget.rideId}/complete',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      _locationTimer?.cancel();
      if (mounted) {
        setState(() {
          _rideStatus = 'COMPLETED';
          _rideSummary = res.data;
        });
        _showPaymentCollectionDialog();
      }
    } catch (e) {
      _showSnack('Error completing ride. Try again.');
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  // STEP 4: Confirm Payment & Close Ride
  Future<void> _confirmPayment() async {
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      await _dio.post(
        '/api/v1/riders/rides/${widget.rideId}/confirm-payment',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        Navigator.pop(context); // Close Payment Dialog
        Navigator.pushNamedAndRemoveUntil(
            context, '/dashboard', (route) => false);
      }
    } catch (e) {
      _showSnack('Error confirming payment.');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _callCustomer() async {
    if (widget.customerMobile.isEmpty) {
      _showSnack('Customer mobile number not available');
      return;
    }
    final uri = Uri.parse('tel:${widget.customerMobile}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnack('Could not launch phone dialer');
    }
  }

  Future<void> _openGoogleMapsNavigation(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not launch Google Maps');
    }
  }

  void _showOtpInputDialog() {
    for (var c in _otpDigitControllers) {
      c.clear();
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.security, color: Color(0xFFFFD000), size: 28),
              const SizedBox(width: 10),
              Text(
                'Enter Customer OTP',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ask the passenger for their 4-digit safety OTP code to begin the trip.',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (index) {
                  return SizedBox(
                    width: 52,
                    height: 56,
                    child: TextField(
                      controller: _otpDigitControllers[index],
                      focusNode: _otpFocusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFFFD000), width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty && index < 3) {
                          _otpFocusNodes[index + 1].requestFocus();
                        } else if (val.isEmpty && index > 0) {
                          _otpFocusNodes[index - 1].requestFocus();
                        }
                        if (_enteredOtp.length == 4) {
                          _startRideWithOtp();
                        }
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
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
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Color(0xFF1A1A1A),
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Verify & Start',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentCollectionDialog() {
    final isUpi = widget.paymentMethod == 'upi';
    final totalFare = _rideSummary?['total_fare'] ?? widget.fare;

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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isUpi
                    ? Colors.purple.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUpi
                      ? Colors.purple.withValues(alpha: 0.3)
                      : Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    isUpi ? 'COLLECT VIA UPI / ONLINE' : 'COLLECT CASH FROM PASSENGER',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isUpi ? Colors.purple.shade800 : Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹$totalFare',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 36,
                      color: isUpi ? Colors.purple.shade900 : Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isUpi
                  ? 'Ask customer to show UPI payment confirmation receipt.'
                  : 'Collect ₹$totalFare cash in full from the customer.',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _confirmPayment,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: Text(
                'Payment Received & Close',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isUpi ? Colors.purple : Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isArriving = _rideStatus == 'ASSIGNED';
    final bool isArrived = _rideStatus == 'DRIVER_ARRIVED';
    final bool isInProgress = _rideStatus == 'IN_PROGRESS';

    final targetLat = (isArriving || isArrived) ? widget.pickupLat : widget.destinationLat;
    final targetLng = (isArriving || isArrived) ? widget.pickupLng : widget.destinationLng;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Status Bar
            FadeInDown(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArriving
                              ? 'Navigate to Pickup 📍'
                              : isArrived
                                  ? 'Driver at Pickup 🏁'
                                  : 'Trip in Progress 🚀',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFFD000),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isArriving
                              ? 'Head towards customer location'
                              : isArrived
                                  ? 'Collect 4-digit OTP from passenger'
                                  : 'Drive safely to destination',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '₹${widget.fare}',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFFD000),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Map View
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  FlutterMap(
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
                          // Driver Current GPS Marker
                          Marker(
                            point: _currentLocation,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD000),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.two_wheeler,
                                  color: Color(0xFF1A1A1A), size: 26),
                            ),
                          ),
                          // Target Location Marker (Pickup or Destination)
                          Marker(
                            point: LatLng(targetLat, targetLng),
                            width: 44,
                            height: 44,
                            child: Icon(
                              (isArriving || isArrived)
                                  ? Icons.person_pin_circle
                                  : Icons.location_on,
                              color: (isArriving || isArrived)
                                  ? Colors.green
                                  : Colors.red,
                              size: 44,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Google Maps Turn-by-Turn Floating Button
                  Positioned(
                    top: 14,
                    right: 14,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _openGoogleMapsNavigation(targetLat, targetLng),
                      icon: const Icon(Icons.navigation, color: Colors.white, size: 18),
                      label: Text(
                        'Google Maps',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Customer Info & Navigation Panel
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Customer row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFFFD000).withValues(alpha: 0.2),
                        child: const Icon(Icons.person,
                            color: Color(0xFF1A1A1A), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.customerName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              widget.paymentMethod == 'upi'
                                  ? 'Payment: UPI Online'
                                  : 'Payment: Cash',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.customerMobile.isNotEmpty)
                        IconButton.filled(
                          onPressed: _callCustomer,
                          icon: const Icon(Icons.phone, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Address Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (isArriving || isArrived)
                              ? Icons.my_location
                              : Icons.location_on,
                          color: (isArriving || isArrived)
                              ? const Color(0xFFFFD000)
                              : Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (isArriving || isArrived)
                                ? widget.pickupAddress
                                : widget.destinationAddress,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Phase Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () {
                              if (isArriving) {
                                _markArrived();
                              } else if (isArrived) {
                                _showOtpInputDialog();
                              } else if (isInProgress) {
                                _completeRide();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isArriving
                            ? const Color(0xFFFFD000)
                            : isArrived
                                ? Colors.green
                                : const Color(0xFF0087FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Color(0xFF1A1A1A),
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              isArriving
                                  ? "I'VE ARRIVED AT PICKUP 📍"
                                  : isArrived
                                      ? 'ENTER CUSTOMER OTP 🔑'
                                      : 'COMPLETE TRIP 🏁',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isArriving
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}