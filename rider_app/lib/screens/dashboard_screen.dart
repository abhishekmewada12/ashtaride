import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'ride_request_screen.dart';
import 'document_upload_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dio = Dio(BaseOptions(baseUrl: 'https://ashtaride.onrender.com'));
  Map<String, dynamic>? _profile;
  List<dynamic> _availableRides = [];
  bool _isOnline = false;
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('rider_token');
  }

  Future<void> _loadProfile() async {
    try {
      final token = await _getToken();
      final res = await _dio.get(
        '/api/v1/riders/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _profile = res.data;
        _isOnline = res.data['is_online'] ?? false;
        _loading = false;
      });
      if (_isOnline) _startPolling();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleOnline() async {
    try {
      final token = await _getToken();
      final res = await _dio.post(
        '/api/v1/riders/toggle-online',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _isOnline = res.data['is_online']);
      if (_isOnline) {
        _startPolling();
        _showSnack('You are Online! 🟢 Ready to accept rides.');
      } else {
        _pollTimer?.cancel();
        setState(() => _availableRides = []);
        _showSnack('You are Offline 🔴');
      }
    } catch (e) {
      _showSnack('Account not verified yet. Contact admin.');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _fetchAvailableRides();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchAvailableRides();
    });
  }

  Future<void> _fetchAvailableRides() async {
    try {
      final token = await _getToken();
      final res = await _dio.get(
        '/api/v1/riders/available-rides',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _availableRides = res.data['rides'] ?? []);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _rejectRide(String requestId) async {
    try {
      final token = await _getToken();
      await _dio.post(
        '/api/v1/riders/rides/$requestId/reject',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      // Silent fail
    }
    await _fetchAvailableRides();
  }

  Future<void> _logout() async {
    _pollTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  // --- ADD THIS HERE ---
  Future<void> _submitUnlockAppeal(String appealMessage) async {
    try {
      final token = await _getToken();
      await _dio.post(
        '/api/v1/riders/request-unlock',
        data: {'message': appealMessage},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      _showSnack('Appeal submitted! Admin will review your request.');
    } catch (e) {
      _showSnack('Error submitting appeal.');
    }
  }

  void _showAppealDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Appeal for Unlock', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Admin ko batayein ki aapka account kyu unlock kiya jaye:', style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Write your message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.trim().isNotEmpty) {
                _submitUnlockAppeal(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD000)),
            child: Text('Submit Appeal', style: GoogleFonts.poppins(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  // --- END OF METHODS ---

  
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD000)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD000),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.person,
                              color: Color(0xFF1A1A1A), size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _profile?['full_name'] ?? 'Rider',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star,
                                      color: Color(0xFFFFD000), size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_profile?['average_rating'] ?? '0.0'} rating',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout,
                              color: Colors.white54),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Online Toggle
                    GestureDetector(
                      onTap: _toggleOnline,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 20),
                        decoration: BoxDecoration(
                          color: _isOnline
                              ? const Color(0xFFFFD000)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isOnline
                                ? const Color(0xFFFFD000)
                                : Colors.white24,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isOnline
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: _isOnline
                                  ? const Color(0xFF1A1A1A)
                                  : Colors.white54,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isOnline
                                  ? '🟢 You are ONLINE'
                                  : '🔴 You are OFFLINE',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _isOnline
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white54,
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
                        // 🚫 Blocked Rider Banner (ADD THIS)
            if (_profile?['is_blocked'] == true) ...[
              FadeInDown(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.block, color: Colors.white, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Account Blocked by Admin',
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reason: ${_profile?['block_reason'] ?? 'Misbehaviour / Policy Violation'}',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showAppealDialog,
                          icon: const Icon(Icons.mail_outline, size: 18),
                          label: Text('Request Account Unlock', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red.shade900,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Verification Status Banners
            if (_profile?['verification_status'] == 'rejected') ...[
            // Verification Status Banners
            if (_profile?['verification_status'] == 'rejected') ...[
              FadeInDown(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade300, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cancel, color: Colors.red, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Verification Rejected',
                            style: GoogleFonts.poppins(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reason: ${_profile?['rejection_reason'] ?? 'Invalid documents submitted.'}',
                        style: GoogleFonts.poppins(
                          color: Colors.red.shade900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          
onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DocumentUploadScreen(
        mobileNumber: _profile?['mobile_number'] ?? '',
      ),
    ),
  );
},
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(
                            'Re-upload Documents',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_profile?['verification_status'] == 'pending') ...[
              FadeInDown(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top, color: Colors.orange, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your documents are under review by Admin.',
                          style: GoogleFonts.poppins(
                            color: Colors.orange.shade900,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            // Stats
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _StatCard(
                      icon: Icons.electric_bike,
                      label: 'Total Rides',
                      value: '${_profile?['total_rides'] ?? 0}',
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.currency_rupee,
                      label: 'Total Earnings',
                      value: '₹${_profile?['total_earnings'] ?? 0}',
                    ),
                  ],
                ),
              ),
            ),

            // Available Rides
            Expanded(
              child: _isOnline
                  ? _availableRides.isEmpty
                      ? FadeIn(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search,
                                    size: 60, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  'Waiting for rides...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'New rides will appear here',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _availableRides.length,
                          itemBuilder: (context, index) {
                            final ride = _availableRides[index];
                            return FadeInUp(
                              delay:
                                  Duration(milliseconds: index * 100),
                              child: _RideCard(
                                ride: ride,
                                onAccept: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RideRequestScreen(
                                        requestId: ride['request_id'],
                                        pickupAddress:
                                            ride['pickup_address'],
                                        destinationAddress:
                                            ride['destination_address'],
                                        estimatedFare: ride[
                                                'estimated_fare']
                                            .toString(),
                                        estimatedDistance: ride[
                                                'estimated_distance']
                                            .toString(),
                                      ),
                                    ),
                                  ).then((_) => _fetchAvailableRides());
                                },
                                onReject: () =>
                                    _rejectRide(ride['request_id']),
                              ),
                            );
                          },
                        )
                  : FadeIn(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.power_settings_new,
                                  size: 60,
                                  color: Colors.grey),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'You are Offline',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the button above to go online\nand start accepting rides!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD000).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(icon, color: const Color(0xFF1A1A1A), size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[500])),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RideCard({
    required this.ride,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD000).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.electric_bike,
                    color: Color(0xFF1A1A1A), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${ride['estimated_fare']}',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      '${ride['estimated_distance']} km',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${ride['expires_in_seconds']}s',
                  style: GoogleFonts.poppins(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LocationRow(
              icon: Icons.my_location,
              color: const Color(0xFFFFD000),
              text: ride['pickup_address']),
          const SizedBox(height: 6),
          _LocationRow(
              icon: Icons.location_on,
              color: Colors.red,
              text: ride['destination_address']),
          const SizedBox(height: 14),

          // Reject + Accept
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD000),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Accept ✅',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _LocationRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style:
                GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}