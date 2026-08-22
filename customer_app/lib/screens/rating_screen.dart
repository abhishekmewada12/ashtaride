import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RatingScreen extends StatefulWidget {
  final String rideId;
  const RatingScreen({super.key, required this.rideId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 0;
  String? _selectedTag;
  final _feedbackController = TextEditingController();
  bool _loading = false;
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));

  final List<Map<String, dynamic>> _tags = [
    {'label': '👍 Safe Driving', 'value': 'safe_driving'},
    {'label': '⏰ On Time', 'value': 'on_time'},
    {'label': '😊 Friendly', 'value': 'friendly'},
    {'label': '🛵 Clean Bike', 'value': 'clean_bike'},
  ];

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      await _dio.post(
        '/api/v1/rides/${widget.rideId}/rate',
        data: {
          'rating': _rating,
          'feedback': _feedbackController.text.isEmpty ? null : _feedbackController.text,
          'tags': _selectedTag != null ? [_selectedTag] : [],
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (e) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Success Icon
              FadeInDown(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD000),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(Icons.check, size: 55, color: Color(0xFF1A1A1A)),
                ),
              ),

              const SizedBox(height: 24),

              FadeInUp(
                child: Text(
                  'Ride Completed! 🎉',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'Rate your experience',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                ),
              ),

              const SizedBox(height: 32),

              // Stars
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () => setState(() => _rating = index + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFFD000),
                          size: 48,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 24),

              // Tags
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) {
                    final selected = _selectedTag == tag['value'];
                    return GestureDetector(
                      onTap: () => setState(() =>
                          _selectedTag = selected ? null : tag['value']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFFFD000)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFFFD000)
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          tag['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            color: selected
                                ? const Color(0xFF1A1A1A)
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // Feedback
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: TextField(
                  controller: _feedbackController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Any feedback? (Optional)',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFD000), width: 2),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Submit Button
              FadeInUp(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submitRating,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD000),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Color(0xFF1A1A1A))
                        : Text(
                            'Submit Rating',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Skip
              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (route) => false),
                child: Text(
                  'Skip for now',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}