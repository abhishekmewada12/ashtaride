import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _loading = false;
  final _dio = Dio(BaseOptions(baseUrl: 'https://ashtaride.onrender.com'));

  Future<void> _saveName() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      await _dio.put(
        '/api/v1/users/profile',
        data: {'full_name': _nameController.text.trim()},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      await prefs.setString('user_name', _nameController.text.trim());
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      // Even if API fails go to home
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              FadeInDown(
                child: Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD000),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              FadeInLeft(
                child: Text(
                  'What\'s your name? 👋',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              FadeInLeft(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'So we can personalize your experience',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    prefixIcon: const Icon(Icons.person_outline,
                        color: Color(0xFFFFD000)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFFFFD000), width: 2),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveName,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD000),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(
                            color: Color(0xFF1A1A1A))
                        : Text(
                            'Continue',
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

              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/home'),
                  child: Text(
                    'Skip for now',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}