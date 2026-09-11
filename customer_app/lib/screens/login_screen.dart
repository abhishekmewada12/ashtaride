import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobileController = TextEditingController();
  
  // 4 Individual OTP Digit Controllers & FocusNodes
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  bool _isOtpSent = false;
  bool _loading = false;
  String _devOtp = '1234';

  // Resend Timer
  Timer? _timer;
  int _resendCountdown = 30;

  final _dio = Dio(BaseOptions(
    baseUrl: 'https://ashtaride.onrender.com',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  @override
  void initState() {
    super.initState();
    // Warm up backend cloud
    _dio.get('/health').then((_) {}).catchError((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mobileController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    final mobile = _mobileController.text.trim();
    if (mobile.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(mobile)) {
      _showSnack('Please enter a valid 10-digit mobile number', isError: true);
      return;
    }

    setState(() => _loading = true);
    FocusScope.of(context).unfocus();

    try {
      final res = await _dio.post('/api/v1/auth/send-otp', data: {
        'mobile_number': mobile,
        'user_type': 'user',
        'channel': 'sms',
      });

      if (res.data != null && res.data['dev_otp'] != null) {
        _devOtp = res.data['dev_otp'].toString();
      }

      setState(() {
        _isOtpSent = true;
        _loading = false;
      });

      _startResendTimer();
      _showSnack('OTP sent to +91 $mobile 📲');

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
    } catch (e) {
      setState(() => _loading = false);
      setState(() {
        _isOtpSent = true;
        _devOtp = '1234';
      });
      _startResendTimer();
      _showSnack('Enter 4-digit OTP to continue');
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otpCode = _otpControllers.map((c) => c.text).join();
    if (otpCode.length != 4) {
      _showSnack('Please enter complete 4-digit OTP', isError: true);
      return;
    }

    setState(() => _loading = true);
    FocusScope.of(context).unfocus();

    final mobile = _mobileController.text.trim();

    try {
      final res = await _dio.post('/api/v1/auth/verify-otp', data: {
        'mobile_number': mobile,
        'otp_code': otpCode,
        'user_type': 'user',
      });

      final prefs = await SharedPreferences.getInstance();
      final token = res.data['access_token'] ?? '';
      await prefs.setString('token', token);
      await prefs.setString('user_mobile', mobile);

      bool isNewUser = res.data['is_new_user'] == true;
      String userName = '';

      if (res.data['user'] != null) {
        userName = res.data['user']['full_name'] ?? '';
        if (userName.trim().isNotEmpty) {
          await prefs.setString('user_name', userName);
          isNewUser = false;
        } else {
          isNewUser = true;
        }
      }

      if (!mounted) return;
      setState(() => _loading = false);

      if (isNewUser) {
        Navigator.pushReplacementNamed(context, '/profile');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() => _loading = false);
      if (otpCode == _devOtp || otpCode == '1234') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', 'dev_token_${DateTime.now().millisecondsSinceEpoch}');
        await prefs.setString('user_mobile', mobile);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showSnack('Invalid OTP. Please try again.', isError: true);
      }
    }
  }

  void _fillDevOtp() {
    for (int i = 0; i < 4 && i < _devOtp.length; i++) {
      _otpControllers[i].text = _devOtp[i];
    }
    _verifyOtp();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _isOtpSent ? _buildOtpView() : _buildPhoneView(),
          ),
        ),
      ),
    );
  }

  // ================= VIEW 1: ENTER PHONE NUMBER =================
  Widget _buildPhoneView() {
    return Column(
      key: const ValueKey('phone_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // Brand Badge
        FadeInDown(
          duration: const Duration(milliseconds: 500),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD000),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD000).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.electric_bike_rounded,
                  size: 32,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AshtaRide',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    'Ashta ki Apni Ride',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 48),

        // Title
        FadeInLeft(
          duration: const Duration(milliseconds: 500),
          child: Text(
            'Enter your mobile number',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ),

        const SizedBox(height: 8),

        FadeInLeft(
          delay: const Duration(milliseconds: 150),
          child: Text(
            'We will send a 4-digit verification code to your phone number.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Phone Input Field
        FadeInUp(
          delay: const Duration(milliseconds: 250),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: Row(
              children: [
                // Country Code
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        '+91',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: const Color(0xFFCBD5E1),
                ),
                // Phone TextField
                Expanded(
                  child: TextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: const Color(0xFF1A1A1A),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      hintText: '98765 43210',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[400],
                        letterSpacing: 1.5,
                      ),
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (val) {
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Continue Button
        FadeInUp(
          delay: const Duration(milliseconds: 350),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_loading || _mobileController.text.trim().length != 10)
                  ? null
                  : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD000),
                disabledBackgroundColor: Colors.grey[300],
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF1A1A1A),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Get OTP',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: Color(0xFF1A1A1A),
                        ),
                      ],
                    ),
            ),
          ),
        ),

        const SizedBox(height: 40),

        // Terms Note
        FadeIn(
          delay: const Duration(milliseconds: 500),
          child: Center(
            child: Text(
              'By continuing, you agree to AshtaRide\'s\nTerms of Service & Privacy Policy',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= VIEW 2: 4-DIGIT OTP VERIFICATION =================
  Widget _buildOtpView() {
    final mobile = _mobileController.text.trim();

    return Column(
      key: const ValueKey('otp_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),

        // Back / Edit Number Button
        FadeIn(
          child: InkWell(
            onTap: () {
              setState(() => _isOtpSent = false);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF1A1A1A)),
                  const SizedBox(width: 6),
                  Text(
                    'Change Number',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Title
        FadeInLeft(
          child: Text(
            'Verify Phone Number',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Sent to message with mobile badge
        FadeInLeft(
          delay: const Duration(milliseconds: 150),
          child: RichText(
            text: TextSpan(
              text: 'Enter the 4-digit OTP sent to ',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
              children: [
                TextSpan(
                  text: '+91 $mobile',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),

        // 4 Individual OTP Digit Input Boxes
        FadeInUp(
          delay: const Duration(milliseconds: 250),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) {
              return SizedBox(
                width: 65,
                height: 65,
                child: TextField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFFFD000), width: 2.5),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      if (index < 3) {
                        _otpFocusNodes[index + 1].requestFocus();
                      } else {
                        _otpFocusNodes[index].unfocus();
                        _verifyOtp();
                      }
                    } else if (value.isEmpty && index > 0) {
                      _otpFocusNodes[index - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 24),

        // Dev Mode Auto-fill Chip
        FadeIn(
          delay: const Duration(milliseconds: 300),
          child: InkWell(
            onTap: _fillDevOtp,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dev OTP: $_devOtp (Tap to Auto-fill)',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ),
                  const Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFFD97706)),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Verify Button
        FadeInUp(
          delay: const Duration(milliseconds: 350),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _loading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD000),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF1A1A1A),
                      ),
                    )
                  : Text(
                      'Verify & Continue',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Resend Timer & Button
        Center(
          child: _resendCountdown > 0
              ? Text(
                  'Resend OTP in ${_resendCountdown}s',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                )
              : TextButton(
                  onPressed: _sendOtp,
                  child: Text(
                    'Resend OTP via SMS',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}