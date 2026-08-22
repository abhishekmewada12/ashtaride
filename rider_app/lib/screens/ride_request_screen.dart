import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'active_ride_screen.dart';

class RideRequestScreen extends StatefulWidget {
  final String requestId;
  final String pickupAddress;
  final String destinationAddress;
  final String estimatedFare;
  final String estimatedDistance;

  const RideRequestScreen({
    super.key,
    required this.requestId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.estimatedFare,
    required this.estimatedDistance,
  });

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
  bool _loading = false;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('rider_token');
  }

  Future<void> _acceptRide() async {
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
            rideId: res.data['ride_id'],
            pickupAddress: res.data['pickup_address'],
            destinationAddress: res.data['destination_address'],
            fare: res.data['fare'].toString(),
            pickupLat: res.data['pickup_lat'],
            pickupLng: res.data['pickup_lng'],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride no longer available!')),
      );
      Navigator.pop(context);
    }
    setState(() => _loading = false);
  }

  Future<void> _rejectRide() async {
  try {
    final token = await _getToken();
    await _dio.post(
      '/api/v1/riders/rides/${widget.requestId}/reject',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  } catch (e) {
    // Silent fail
  }
  if (!mounted) return;
  Navigator.pop(context);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            FadeInDown(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: const Color(0xFFFFD000),
                child: Column(
                  children: [
                    Text(
                      'New Ride Request! 🏍️',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Accept quickly before it expires!',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF1A1A1A).withOpacity(0.7),
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
                    // Fare Card
                    FadeInUp(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ride Fare',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white54, fontSize: 13)),
                                Text(
                                  '₹${widget.estimatedFare}',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFFD000),
                                    fontSize: 32,
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
                                        color: Colors.white54, fontSize: 13)),
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

                    const SizedBox(height: 20),

                    // Location Card
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
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
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD000)
                                        .withOpacity(0.2),
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
                                      Text('Pickup',
                                          style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[500])),
                                      Text(
                                        widget.pickupAddress,
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 18, top: 4, bottom: 4),
                              child: Container(
                                  width: 2, height: 20, color: Colors.grey[300]),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
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
                                      Text('Destination',
                                          style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[500])),
                                      Text(
                                        widget.destinationAddress,
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
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

                    const SizedBox(height: 20),

                    // Payment info
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.payments,
                                color: Colors.green, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Cash Payment — ₹${widget.estimatedFare}',
                              style: GoogleFonts.poppins(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
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
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Reject
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _rejectRide,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Reject ❌',
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
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
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Color(0xFF1A1A1A))
                            : Text(
                                'Accept ✅',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: const Color(0xFF1A1A1A),
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