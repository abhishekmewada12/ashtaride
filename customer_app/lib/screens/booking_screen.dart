import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/flutter_map.dart' show PolylineLayer, Polyline;
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ride_searching_screen.dart';

class BookingScreen extends StatefulWidget {
  final LatLng currentLocation;
  final String pickupAddress;
  const BookingScreen({
    super.key,
    required this.currentLocation,
    required this.pickupAddress,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _destinationController = TextEditingController();
  final MapController _mapController = MapController();
  LatLng? _destinationLocation;
  String _pickupAddress = '';
  Map<String, dynamic>? _fareEstimate;
  bool _loading = false;
  bool _fareLoading = false;
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  List<LatLng> _routePoints = [];

  final _dio = Dio(BaseOptions(baseUrl: 'https://ashtaride.onrender.com'));
  final _nominatimDio = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    headers: {'User-Agent': 'AshtaRide/1.0'},
  ));
  final _osrmDio = Dio(BaseOptions(
    baseUrl: 'https://router.project-osrm.org',
  ));

  @override
  void initState() {
    super.initState();
    _pickupAddress = widget.pickupAddress;
    _destinationController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _destinationController.removeListener(_onSearchChanged);
    _destinationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _destinationController.text.trim();
    if (query.length >= 3) {
      _searchLocations(query);
    } else {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }

  Future<void> _searchLocations(String query) async {
    try {
      final res = await _nominatimDio.get('/search', queryParameters: {
        'q': query,
        'format': 'json',
        'limit': 8,
        'countrycodes': 'in',
        'addressdetails': 1,
        'viewbox': '${widget.currentLocation.longitude - 0.1},${widget.currentLocation.latitude + 0.1},${widget.currentLocation.longitude + 0.1},${widget.currentLocation.latitude - 0.1}',
        'bounded': 1,
      });

      if (res.data is List && res.data.isNotEmpty) {
        setState(() {
          _suggestions = List<Map<String, dynamic>>.from(res.data);
          _showSuggestions = true;
        });
      } else {
        final res2 = await _nominatimDio.get('/search', queryParameters: {
          'q': '$query, Ashta, Madhya Pradesh',
          'format': 'json',
          'limit': 8,
          'countrycodes': 'in',
          'addressdetails': 1,
        });
        setState(() {
          _suggestions = List<Map<String, dynamic>>.from(res2.data);
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      setState(() => _showSuggestions = false);
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> place) async {
    final lat = double.parse(place['lat']);
    final lng = double.parse(place['lon']);
    final name = place['display_name'].toString().split(',').take(2).join(',');

    setState(() {
      _destinationLocation = LatLng(lat, lng);
      _destinationController.text = name;
      _showSuggestions = false;
      _fareLoading = true;
    });

    _mapController.move(LatLng(lat, lng), 14);
    await _getFareEstimate();
    await _getRoute();
  }

  Future<void> _getRoute() async {
    if (_destinationLocation == null) return;
    try {
      final pickup = widget.currentLocation;
      final dest = _destinationLocation!;
      final res = await _osrmDio.get(
        '/route/v1/driving/${pickup.longitude},${pickup.latitude};${dest.longitude},${dest.latitude}',
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
        },
      );

      if (res.data['routes'] != null && res.data['routes'].isNotEmpty) {
        final coords = res.data['routes'][0]['geometry']['coordinates'] as List;
        setState(() {
          _routePoints = coords
              .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
              .toList();
        });
      }
    } catch (e) {
      // Route fetch failed silently
    }
  }

  Future<void> _getFareEstimate() async {
    if (_destinationLocation == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final res = await _dio.post(
        '/api/v1/rides/estimate',
        data: {
          'pickup_lat': widget.currentLocation.latitude,
          'pickup_lng': widget.currentLocation.longitude,
          'destination_lat': _destinationLocation!.latitude,
          'destination_lng': _destinationLocation!.longitude,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _fareEstimate = res.data;
        _fareLoading = false;
      });
    } catch (e) {
      setState(() => _fareLoading = false);
    }
  }

  Future<void> _bookRide() async {
    if (_destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select destination')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final res = await _dio.post(
        '/api/v1/rides/book',
        data: {
          'pickup_lat': widget.currentLocation.latitude,
          'pickup_lng': widget.currentLocation.longitude,
          'pickup_address': _pickupAddress,
          'destination_lat': _destinationLocation!.latitude,
          'destination_lng': _destinationLocation!.longitude,
          'destination_address': _destinationController.text,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RideSearchingScreen(
            requestId: res.data['ride_request_id'],
            fareEstimate: _fareEstimate,
            destination: _destinationController.text,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error booking ride. Try again.')),
      );
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Book a Ride',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFFD000),
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Map
          SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.currentLocation,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ashtaride.customer',
                ),
                // Route Line
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4,
                        color: const Color(0xFFFFD000),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    // Pickup
                    Marker(
                      point: widget.currentLocation,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD000),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.my_location,
                            color: Color(0xFF1A1A1A), size: 20),
                      ),
                    ),
                    // Destination
                    if (_destinationLocation != null)
                      Marker(
                        point: _destinationLocation!,
                        width: 40,
                        height: 50,
                        child: const Icon(Icons.location_on,
                            color: Colors.red, size: 40),
                      ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pickup
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.my_location,
                            color: Color(0xFFFFD000), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pickupAddress,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Search field
                  TextField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      hintText: 'Search destination...',
                      prefixIcon: const Icon(Icons.search,
                          color: Color(0xFFFFD000)),
                      suffixIcon: _destinationController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _destinationController.clear();
                                setState(() {
                                  _destinationLocation = null;
                                  _fareEstimate = null;
                                  _routePoints = [];
                                  _suggestions = [];
                                  _showSuggestions = false;
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFFFD000), width: 2),
                      ),
                    ),
                  ),

                  // Search Suggestions
                  if (_showSuggestions && _suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey[100]),
                        itemBuilder: (context, index) {
                          final place = _suggestions[index];
                          final name = place['display_name']
                              .toString()
                              .split(',')
                              .take(3)
                              .join(',');
                          return ListTile(
                            leading: const Icon(Icons.location_on,
                                color: Color(0xFFFFD000)),
                            title: Text(
                              name,
                              style: GoogleFonts.poppins(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSuggestion(place),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Fare Estimate
                  if (_fareLoading)
                    const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFFFD000))),

                  if (_fareEstimate != null && !_fareLoading)
                    FadeInUp(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Fare Estimate',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 13)),
                                Text(
                                  '₹${_fareEstimate!['total_fare']}',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFFD000),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white24),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                _FareRow('Base Fare',
                                    '₹${_fareEstimate!['base_fare']}'),
                                _FareRow('Distance',
                                    '${_fareEstimate!['distance_km']} km'),
                                _FareRow('Time',
                                    '~${_fareEstimate!['estimated_time_minutes']} min'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Book Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _bookRide,
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
                        'Book Ride 🏍️',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
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

class _FareRow extends StatelessWidget {
  final String label;
  final String value;
  const _FareRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white54, fontSize: 11)),
        Text(value,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }
}