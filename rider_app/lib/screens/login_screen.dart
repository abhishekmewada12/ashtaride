import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));

  Future<void> _sendOTP() async {
    if (_mobileController.text.length != 10) {
      _showSnack('Please enter valid 10 digit mobile number');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await _dio.post('/api/v1/auth/send-otp', data: {
        'mobile_number': _mobileController.text,
        'user_type': 'rider',
      });
      setState(() => _otpSent = true);
      _showSnack('OTP sent! Dev OTP: ${res.data['dev_otp']}');
    } catch (e) {
      _showSnack('Error sending OTP. Try again.');
    }
    setState(() => _loading = false);
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 4) {
      _showSnack('Please enter valid OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await _dio.post('/api/v1/auth/verify-otp', data: {
        'mobile_number': _mobileController.text,
        'otp_code': _otpController.text,
        'user_type': 'rider',
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rider_token', res.data['access_token']);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
  if (e is DioException) {
    final detail = e.response?.data['detail'] ?? '';
    if (detail.contains('not registered')) {
      _showSnack('Not registered. Please register first.');
    } else {
      _showSnack('Invalid OTP. Try again.');
    }
  } else {
    _showSnack('Error. Try again.');
  }
}
    setState(() => _loading = false);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: SingleChildScrollView(
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
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD000).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.electric_bike,
                        size: 50, color: Color(0xFF1A1A1A)),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              FadeInLeft(
                child: Text(
                  'Rider Login 🏍️',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              FadeInLeft(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'Ashta ki Apni Ride',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Mobile Field
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mobile Number',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white70)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      enabled: !_otpSent,
                      style: const TextStyle(color: Colors.white),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: InputDecoration(
                        hintText: 'Enter 10 digit mobile number',
                        hintStyle:
                            const TextStyle(color: Colors.white38),
                        prefixText: '+91 ',
                        prefixStyle: const TextStyle(
                            color: Color(0xFFFFD000),
                            fontWeight: FontWeight.bold),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFFFD000), width: 2),
                        ),
                        filled: true,
                        fillColor: _otpSent
                            ? Colors.white10
                            : Colors.white10,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (_otpSent) ...[
                FadeInUp(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enter OTP',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.white70)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        style: const TextStyle(color: Colors.white),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          hintText: 'Enter 4 digit OTP',
                          hintStyle:
                              const TextStyle(color: Colors.white38),
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.white24),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFFFD000), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() => _otpSent = false);
                          _otpController.clear();
                        },
                        child: Text(
                          'Change mobile number?',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFFD000),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Button
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : (_otpSent ? _verifyOTP : _sendOTP),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD000),
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                  Color(0xFF1A1A1A)),
                            ),
                          )
                        : Text(
                            _otpSent ? 'Verify OTP' : 'Send OTP',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Register Link
              Center(
                child: FadeInUp(
                  delay: const Duration(milliseconds: 500),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        text: 'New Rider? ',
                        style: GoogleFonts.poppins(
                            color: Colors.white38, fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Register Here',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFFD000),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
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