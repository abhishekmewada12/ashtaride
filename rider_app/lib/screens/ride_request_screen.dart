import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'active_ride_screen.dart';

class RideRequestScreen extends StatefulWidget {
  final String requestId;
  final String pickupAddress;
  final String destinationAddress;
  final String estimatedFare;
  final String estimatedDistance;
  final String vehicleType;
  final String paymentMethod;
  final int initialExpiresInSeconds;

  const RideRequestScreen({
    super.key,
    required this.requestId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.estimatedFare,
    required this.estimatedDistance,
    this.vehicleType = 'bike',
    this.paymentMethod = 'cash',
    this.initialExpiresInSeconds = 30,
  });

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  final _dio = Dio(BaseOptions(baseUrl: 'https://ashtaride.onrender.com'));
  bool _loading = false;
  late int _secondsRemaining;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.initialExpiresInSeconds > 0
        ? widget.initialExpiresInSeconds
        : 30;

    // Start loud incoming ride ringtone & vibration
    try {
      FlutterRingtonePlayer().play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.glass,
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
      HapticFeedback.vibrate();
    } catch (_) {}

    // Start 30s countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
        if (_secondsRemaining % 2 == 0) {
          try {
            HapticFeedback.selectionClick();
          } catch (_) {}
        }
      } else {
        timer.cancel();
        _autoExpireAndReject();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('rider_token');
  }

  Future<void> _autoExpireAndReject() async {
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
    try {
      final token = await _getToken();
      await _dio.post(
        '/api/v1/riders/rides/${widget.requestId}/reject',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Offer expired. Passing to next driver.',
            style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _acceptRide() async {
    _countdownTimer?.cancel();
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
    setState(() => _loading = true);

    try {
      final token = await _getToken();
      final res = await _dio.post(
        '/api/v1/riders/rides/${widget.requestId}/accept',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveRideScreen(
            rideId: res.data['ride_id'].toString(),
            pickupAddress: res.data['pickup_address'] ?? widget.pickupAddress,
            destinationAddress:
                res.data['destination_address'] ?? widget.destinationAddress,
            fare: (res.data['fare'] ?? widget.estimatedFare).toString(),
            pickupLat: (res.data['pickup_lat'] as num?)?.toDouble() ?? 22.9734,
            pickupLng: (res.data['pickup_lng'] as num?)?.toDouble() ?? 76.6178,
            destinationLat:
                (res.data['destination_lat'] as num?)?.toDouble() ?? 22.9780,
            destinationLng:
                (res.data['destination_lng'] as num?)?.toDouble() ?? 76.6230,
            customerName: res.data['customer_name'] ?? 'Customer',
            customerMobile: res.data['customer_mobile'] ?? '',
            vehicleType: widget.vehicleType,
            paymentMethod: widget.paymentMethod,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ride no longer available or already accepted.',
                style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFF1A1A1A),
          ),
        );
        Navigator.pop(context);
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _rejectRide() async {
    _countdownTimer?.cancel();
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
    try {
      final token = await _getToken();
      await _dio.post(
        '/api/v1/riders/rides/${widget.requestId}/reject',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isAuto = widget.vehicleType.toLowerCase() == 'auto';
    final progressVal = (_secondsRemaining / 30.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            FadeInDown(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isAuto ? Icons.local_taxi : Icons.two_wheeler,
                        color: const Color(0xFF1A1A1A),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAuto ? 'Ashta Auto Request 🛺' : 'Ashta Bike Request 🏍️',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Exclusive Offer (Nearest Driver)',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFFFFD000),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 30-Second Circular Countdown Timer
                    FadeInDown(
                      delay: const Duration(milliseconds: 100),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 110,
                              height: 110,
                              child: CircularProgressIndicator(
                                value: progressVal,
                                strokeWidth: 8,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _secondsRemaining <= 5
                                      ? Colors.red
                                      : const Color(0xFFFFD000),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$_secondsRemaining',
                                  style: GoogleFonts.poppins(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: _secondsRemaining <= 5
                                        ? Colors.red
                                        : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                Text(
                                  'sec left',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Fare & Distance Card
                    FadeInUp(
                      delay: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Driver Earnings',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white54, fontSize: 12)),
                                Text(
                                  '₹${widget.estimatedFare}',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFFD000),
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Distance',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white54, fontSize: 12)),
                                Text(
                                  '${widget.estimatedDistance} km',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Location Card
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD000)
                                        .withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.my_location,
                                      color: Color(0xFF1A1A1A), size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('PICKUP LOCATION',
                                          style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade500)),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.pickupAddress,
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: const Color(0xFF1A1A1A)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 18, top: 4, bottom: 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                    width: 2,
                                    height: 20,
                                    color: Colors.grey.shade300),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.location_on,
                                      color: Colors.red, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('DESTINATION DROP',
                                          style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade500)),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.destinationAddress,
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: const Color(0xFF1A1A1A)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Payment Method Card
                    FadeInUp(
                      delay: const Duration(milliseconds: 250),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.paymentMethod == 'upi'
                              ? Colors.purple.withValues(alpha: 0.08)
                              : Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.paymentMethod == 'upi'
                                ? Colors.purple.withValues(alpha: 0.3)
                                : Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.paymentMethod == 'upi'
                                  ? Icons.qr_code_scanner
                                  : Icons.payments,
                              color: widget.paymentMethod == 'upi'
                                  ? Colors.purple
                                  : Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              widget.paymentMethod == 'upi'
                                  ? 'Online / UPI Payment — ₹${widget.estimatedFare}'
                                  : 'Cash Payment — ₹${widget.estimatedFare}',
                              style: GoogleFonts.poppins(
                                color: widget.paymentMethod == 'upi'
                                    ? Colors.purple.shade700
                                    : Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            FadeInUp(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Reject
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _rejectRide,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Pass / Reject ❌',
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Accept
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _acceptRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD000),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
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
                                'ACCEPT RIDE ✅',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: const Color(0xFF1A1A1A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}