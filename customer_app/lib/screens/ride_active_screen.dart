import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'rating_screen.dart';

class RideActiveScreen extends StatefulWidget {
  final String rideId;
  final String riderName;
  final String riderMobile;
  final String riderRating;
  final String totalFare;
  final String destination;

  const RideActiveScreen({
    super.key,
    required this.rideId,
    required this.riderName,
    required this.riderMobile,
    required this.riderRating,
    required this.totalFare,
    required this.destination,
  });

  @override
  State<RideActiveScreen> createState() => _RideActiveScreenState();
}

class _RideActiveScreenState extends State<RideActiveScreen> {
  String _rideStatus = 'accepted';
  String? _rideOtp;
  Timer? _statusTimer;
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));

  final Map<String, Map<String, dynamic>> _statusInfo = {
    'accepted': {
      'title': 'Rider is Coming! 🏍️',
      'subtitle': 'Rider is on the way to pickup',
      'color': Colors.blue,
      'icon': Icons.electric_bike,
    },
    'rider_arriving': {
      'title': 'Rider has Arrived! 📍',
      'subtitle': 'Share OTP with rider to start ride',
      'color': Colors.orange,
      'icon': Icons.location_on,
    },
    'ride_started': {
      'title': 'Ride in Progress! 🚀',
      'subtitle': 'Enjoy your ride to destination',
      'color': Colors.green,
      'icon': Icons.directions,
    },
    'completed': {
      'title': 'Ride Completed! ✅',
      'subtitle': 'Hope you had a great ride!',
      'color': Colors.green,
      'icon': Icons.check_circle,
    },
  };

  @override
  void initState() {
    super.initState();
    _startStatusPolling();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusPolling() {
    _checkRideStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkRideStatus();
    });
  }

  Future<void> _checkRideStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final res = await _dio.get(
        '/api/v1/rides/active',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final activeRide = res.data['active_ride'];

      if (activeRide == null) {
        _statusTimer?.cancel();
        setState(() => _rideStatus = 'completed');
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RatingScreen(rideId: widget.rideId),
          ),
        );
      } else {
        setState(() {
          _rideStatus = activeRide['status'];
          _rideOtp = activeRide['ride_otp'];
        });
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _callRider() async {
    final uri = Uri.parse('tel:${widget.riderMobile}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _triggerSOS() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('SOS Alert',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Send SOS alert?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SOS Alert sent!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Send SOS',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusData = _statusInfo[_rideStatus] ?? _statusInfo['accepted']!;
    final statusColor = statusData['color'] as Color;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Status Header
            FadeInDown(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: statusColor,
                child: Column(
                  children: [
                    Icon(statusData['icon'] as IconData,
                        color: Colors.white, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      statusData['title'] as String,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusData['subtitle'] as String,
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 13),
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
                    // OTP Card — Rider arriving pe dikhao
                    if (_rideStatus == 'rider_arriving' && _rideOtp != null)
                      FadeInDown(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.orange.withOpacity(0.5),
                                width: 2),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lock,
                                      color: Colors.orange, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Share this OTP with Rider',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[800],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: _rideOtp!.split('').map((digit) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    width: 56,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        digit,
                                        style: GoogleFonts.poppins(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Rider will enter this OTP to start your ride',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Rider Card
                    FadeInUp(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD000),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(Icons.person,
                                  size: 35, color: Color(0xFF1A1A1A)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.riderName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.star,
                                          color: Color(0xFFFFD000),
                                          size: 16),
                                      const SizedBox(width: 4),
                                      Text(widget.riderRating,
                                          style: GoogleFonts.poppins(
                                              fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _callRider,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.phone,
                                    color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Fare Card
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Total Fare',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 13)),
                                Text(
                                  '₹${widget.totalFare}',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFFD000),
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Cash Payment',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Status Steps
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _StatusStep(
                              icon: Icons.check_circle,
                              label: 'Ride Accepted',
                              done: true,
                            ),
                            _StatusStep(
                              icon: Icons.electric_bike,
                              label: 'Rider Arriving',
                              done: _rideStatus == 'rider_arriving' ||
                                  _rideStatus == 'ride_started' ||
                                  _rideStatus == 'completed',
                            ),
                            _StatusStep(
                              icon: Icons.directions,
                              label: 'Ride Started',
                              done: _rideStatus == 'ride_started' ||
                                  _rideStatus == 'completed',
                            ),
                            _StatusStep(
                              icon: Icons.flag,
                              label: 'Completed',
                              done: _rideStatus == 'completed',
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // SOS Button
            FadeInUp(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _triggerSOS,
                    icon: const Icon(Icons.sos, color: Colors.red),
                    label: Text('SOS Emergency',
                        style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  final bool isLast;

  const _StatusStep({
    required this.icon,
    required this.label,
    required this.done,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Icon(icon,
                color: done
                    ? const Color(0xFFFFD000)
                    : Colors.grey[300],
                size: 24),
            if (!isLast)
              Container(
                  width: 2,
                  height: 30,
                  color: done
                      ? const Color(0xFFFFD000)
                      : Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: done ? const Color(0xFF1A1A1A) : Colors.grey[400],
            fontWeight: done ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}