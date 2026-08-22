import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'booking_screen.dart';
import 'ride_active_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(22.9734, 76.6178);
  LatLng _pickupLocation = const LatLng(22.9734, 76.6178);
  String _pickupAddress = 'Getting location...';
  bool _locationLoading = true;
  bool _changingPickup = false;
  bool _checkingRide = true;
  Map<String, dynamic>? _activeRide;
  String _greeting = '';
  final _dio = Dio(BaseOptions(baseUrl: 'https://ashtaride.onrender.com'));

  @override
  void initState() {
    super.initState();
    _setGreeting();
    _getCurrentLocation();
    _checkActiveRide();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning! 🌅';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon! ☀️';
    } else {
      _greeting = 'Good Evening! 🌙';
    }
  }

  Future<void> _checkActiveRide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        setState(() => _checkingRide = false);
        return;
      }
      final res = await _dio.get(
        '/api/v1/rides/active',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _activeRide = res.data['active_ride'];
        _checkingRide = false;
      });
    } catch (e) {
      setState(() => _checkingRide = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        final loc = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLocation = loc;
          _pickupLocation = loc;
          _locationLoading = false;
        });
        _mapController.move(loc, 15);
        await _getAddressFromLatLng(loc);
      }
    } catch (e) {
      setState(() => _locationLoading = false);
      _pickupAddress = 'Ashta, Madhya Pradesh';
    }
  }

  Future<void> _getAddressFromLatLng(LatLng loc) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _pickupAddress =
              '${p.street ?? ''}, ${p.subLocality ?? ''}, ${p.locality ?? ''}'
                  .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
                  .trim();
        });
      }
    } catch (e) {
      setState(() => _pickupAddress = 'Ashta, Madhya Pradesh');
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) async {
    if (_changingPickup) {
      setState(() {
        _pickupLocation = point;
        _pickupAddress = 'Getting address...';
      });
      await _getAddressFromLatLng(point);
      setState(() => _changingPickup = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ashtaride.customer',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                    ),
                  ),
                  Marker(
                    point: _pickupLocation,
                    width: 50,
                    height: 50,
                    child: FadeIn(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD000),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: Color(0xFF1A1A1A),
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Change Pickup Hint
          if (_changingPickup)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    'Tap on map to set pickup location',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),

          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: FadeInDown(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD000),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.electric_bike,
                            color: Color(0xFF1A1A1A), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600])),
                            Text('AshtaRide',
                                style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1A1A))),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout,
                            color: Color(0xFF1A1A1A)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeInUp(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: _checkingRide
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFFFD000)))
                    : _activeRide != null
                        ? _buildActiveRideCard()
                        : _buildBookingCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Active Ride Card
  Widget _buildActiveRideCard() {
    final status = _activeRide!['status'];
    final statusText = {
      'accepted': 'Rider is coming to you',
      'rider_arriving': 'Rider has arrived!',
      'ride_started': 'Ride in progress',
    }[status] ?? 'Ride in progress';

    final statusColor = {
      'accepted': Colors.blue,
      'rider_arriving': Colors.orange,
      'ride_started': Colors.green,
    }[status] ?? Colors.green;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Active Ride Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.electric_bike,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ride Active!',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      statusText,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${_activeRide!['fare']}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // View Ride Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RideActiveScreen(
                    rideId: _activeRide!['ride_id'],
                    riderName: _activeRide!['rider']['name'],
                    riderMobile: _activeRide!['rider']['mobile'],
                    riderRating:
                        _activeRide!['rider']['rating'].toString(),
                    totalFare: _activeRide!['fare'].toString(),
                    destination: _activeRide!['destination_address'],
                  ),
                ),
              ).then((_) => _checkActiveRide());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD000),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Track My Ride',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Normal Booking Card
  Widget _buildBookingCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Where do you want to go?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),

        // Pickup
        GestureDetector(
          onTap: () => setState(() => _changingPickup = !_changingPickup),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _changingPickup
                  ? const Color(0xFFFFD000).withOpacity(0.1)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _changingPickup
                    ? const Color(0xFFFFD000)
                    : Colors.grey[200]!,
                width: _changingPickup ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location,
                    color: Color(0xFFFFD000), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: _locationLoading
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                              height: 14, color: Colors.white),
                        )
                      : Text(
                          _pickupAddress,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1A1A1A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const SizedBox(width: 8),
                Text(
                  _changingPickup ? 'Cancel' : 'Change',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFFFD000),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Destination
        GestureDetector(
          onTap: () {
            if (!_changingPickup) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingScreen(
                    currentLocation: _pickupLocation,
                    pickupAddress: _pickupAddress,
                  ),
                ),
              ).then((_) => _checkActiveRide());
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on,
                    color: Colors.red, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Where to?',
                    style: GoogleFonts.poppins(
                        color: Colors.grey[400], fontSize: 14),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}