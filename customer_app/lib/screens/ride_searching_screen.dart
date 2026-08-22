import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'ride_active_screen.dart';

class RideSearchingScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic>? fareEstimate;
  final String destination;

  const RideSearchingScreen({
    super.key,
    required this.requestId,
    required this.fareEstimate,
    required this.destination,
  });

  @override
  State<RideSearchingScreen> createState() => _RideSearchingScreenState();
}

class _RideSearchingScreenState extends State<RideSearchingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _statusTimer;
  String _status = 'searching';
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _startPolling();
  }

  void _startPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final res = await _dio.get(
        '/api/v1/rides/request/${widget.requestId}/status',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final status = res.data['status'];
      setState(() => _status = status);

      if (status == 'accepted' && res.data['ride'] != null) {
        _statusTimer?.cancel();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RideActiveScreen(
              rideId: res.data['ride']['ride_id'],
              riderName: res.data['ride']['rider_name'],
              riderMobile: res.data['ride']['rider_mobile'],
              riderRating: res.data['ride']['rider_rating'].toString(),
              totalFare: res.data['ride']['total_fare'].toString(),
              destination: widget.destination,
            ),
          ),
        );
      } else if (status == 'expired' || status == 'no_riders') {
        _statusTimer?.cancel();
        if (!mounted) return;
        _showNoRidersDialog();
      }
    } catch (e) {
      // Retry
    }
  }

  void _showNoRidersDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('No Riders Available', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'No riders available nearby right now. Please try again in a few minutes.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD000)),
            child: Text('OK', style: GoogleFonts.poppins(color: const Color(0xFF1A1A1A))),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRide() async {
    _statusTimer?.cancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),

            // Pulse Animation
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse
                    Container(
                      width: 160 + (_pulseController.value * 40),
                      height: 160 + (_pulseController.value * 40),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFD000).withOpacity(0.1 - (_pulseController.value * 0.1)),
                      ),
                    ),
                    // Middle pulse
                    Container(
                      width: 130 + (_pulseController.value * 20),
                      height: 130 + (_pulseController.value * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFD000).withOpacity(0.2 - (_pulseController.value * 0.1)),
                      ),
                    ),
                    // Center
                    Container(
                      width: 110,
                      height: 110,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFD000),
                      ),
                      child: const Icon(
                        Icons.electric_bike,
                        size: 55,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 40),

            FadeInUp(
              child: Text(
                'Finding your rider...',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),

            const SizedBox(height: 12),

            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Text(
                'Looking for nearby riders in Ashta',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Destination Card
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Destination', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                          Text(
                            widget.destination,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (widget.fareEstimate != null)
                      Text(
                        '₹${widget.fareEstimate!['total_fare']}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Cancel Button
            FadeInUp(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _cancelRide,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFF1A1A1A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Cancel Ride',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
                      ),
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