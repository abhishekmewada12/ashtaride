import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'register_screen.dart';
import 'document_upload_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobileController = TextEditingController();
  final List<TextEditingController> _otpDigitControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  bool _otpSent = false;
  bool _loading = false;
  String? _verificationId;
  String? _devOtp;

  int _resendCountdown = 30;
  Timer? _resendTimer;

  final _dio = Dio(BaseOptions(
    baseUrl: 'https://ashtaride.onrender.com',
    connectTimeout: const Duration(seconds: 40),
    receiveTimeout: const Duration(seconds: 40),
  ));

  @override
  void initState() {
    super.initState();
    // Warm up backend
    _dio.get('/health').then((_) {}).catchError((_) {});
  }

  @override
  void dispose() {
    _mobileController.dispose();
    for (var c in _otpDigitControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _enteredOtp =>
      _otpDigitControllers.map((c) => c.text.trim()).join();

  Future<void> _sendOTP() async {
    final mobile = _mobileController.text.trim();
    if (mobile.length != 10) {
      _showSnack('Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final res = await _dio.post('/api/v1/auth/send-otp', data: {
        'mobile_number': mobile,
        'user_type': 'rider',
        'channel': 'sms',
      });

      if (res.data != null && res.data['dev_otp'] != null) {
        _devOtp = res.data['dev_otp'].toString();
      } else {
        _devOtp = '1234';
      }

      _showSnack('SMS OTP sent to +91 $mobile 📲');

      // Also trigger Firebase SMS verification as fallback
      try {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: '+91$mobile',
          verificationCompleted: (PhoneAuthCredential credential) async {
            if (credential.smsCode != null &&
                credential.smsCode!.length >= 4) {
              final code = credential.smsCode!;
              for (int i = 0; i < 4 && i < code.length; i++) {
                _otpDigitControllers[i].text = code[i];
              }
              await _verifyOTP();
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            debugPrint('Firebase Auth Error: ${e.message}');
          },
          codeSent: (String verificationId, int? resendToken) {
            _verificationId = verificationId;
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
          timeout: const Duration(seconds: 60),
        );
      } catch (e) {
        debugPrint('Firebase verify error: $e');
      }

      if (mounted) {
        setState(() {
          _otpSent = true;
          _loading = false;
        });
        _startResendTimer();
        _otpFocusNodes[0].requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Enter OTP to continue (Dev OTP: 1234)');
        setState(() {
          _otpSent = true;
          _devOtp = '1234';
        });
        _startResendTimer();
        _otpFocusNodes[0].requestFocus();
      }
    }
  }

  Future<void> _verifyOTP() async {
    final code = _enteredOtp;
    if (code.length != 4) {
      _showSnack('Please enter the 4-digit OTP');
      return;
    }

    setState(() => _loading = true);

    try {
      final mobile = _mobileController.text.trim();
      final res = await _dio.post('/api/v1/auth/verify-otp', data: {
        'mobile_number': mobile,
        'otp_code': code,
        'user_type': 'rider',
        'is_firebase_verified': _verificationId != null,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rider_token', res.data['access_token']);

      if (!mounted) return;

      if (res.data['is_new_user'] == true ||
          res.data['profile_complete'] == false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentUploadScreen(mobileNumber: mobile),
          ),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      if (e is DioException) {
        final detail = e.response?.data['detail'] ?? '';
        if (detail.contains('not registered')) {
          _showSnack('Not registered. Please register first.');
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
          }
        } else {
          _showSnack('Invalid OTP. Please try again or use Dev OTP.');
        }
      } else {
        _showSnack('Error logging in. Try again.');
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _fillDevOtp() {
    final otp = _devOtp ?? '1234';
    for (int i = 0; i < 4 && i < otp.length; i++) {
      _otpDigitControllers[i].text = otp[i];
    }
    _verifyOTP();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // App Logo
              FadeInDown(
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD000),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD000).withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.two_wheeler,
                        size: 44, color: Color(0xFF1A1A1A)),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title Header
              FadeInLeft(
                child: Text(
                  'Partner Portal 🏍️',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              FadeInLeft(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  _otpSent
                      ? 'Enter 4-digit OTP sent to +91 ${_mobileController.text}'
                      : 'Login to start accepting rides in Ashta',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white60,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // STEP 1: MOBILE INPUT
              if (!_otpSent) ...[
                // Mobile Field
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mobile Number',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          hintText: 'Enter 10 digit mobile number',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixText: '+91  ',
                          prefixStyle: const TextStyle(
                            color: Color(0xFFFFD000),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white24),
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
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // SMS OTP Button (Primary Yellow)
                FadeInUp(
                  delay: const Duration(milliseconds: 250),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _sendOTP,
                      icon: _loading
                          ? const SizedBox.shrink()
                          : const Icon(Icons.sms_rounded,
                              color: Color(0xFF1A1A1A), size: 20),
                      label: _loading
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
                              'Get OTP via SMS',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD000),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],

              // STEP 2: 4-DIGIT PIN OTP VERIFICATION
              if (_otpSent) ...[
                FadeInUp(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Enter 4-Digit OTP',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          const Text(
                            'SMS 📲',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFFD000),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 4 PIN Boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(4, (index) {
                          return SizedBox(
                            width: 64,
                            height: 64,
                            child: TextField(
                              controller: _otpDigitControllers[index],
                              focusNode: _otpFocusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFFD000),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white10,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      const BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFFD000),
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (val) {
                                if (val.isNotEmpty && index < 3) {
                                  _otpFocusNodes[index + 1].requestFocus();
                                } else if (val.isEmpty && index > 0) {
                                  _otpFocusNodes[index - 1].requestFocus();
                                }
                                if (_enteredOtp.length == 4) {
                                  _verifyOTP();
                                }
                              },
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 16),

                      // Dev OTP Helper Chip
                      Center(
                        child: ActionChip(
                          avatar: const Icon(Icons.bolt,
                              color: Color(0xFF1A1A1A), size: 18),
                          label: Text(
                            'Dev OTP: ${_devOtp ?? "1234"} (Tap to auto-fill)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          backgroundColor: const Color(0xFFFFD000),
                          onPressed: _fillDevOtp,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Resend & Change Mobile Options
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _otpSent = false;
                                for (var c in _otpDigitControllers) {
                                  c.clear();
                                }
                              });
                            },
                            child: Text(
                              'Change Number',
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          _resendCountdown > 0
                              ? Text(
                                  'Resend in ${_resendCountdown}s',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                )
                              : GestureDetector(
                                  onTap: _sendOTP,
                                  child: Text(
                                    'Resend OTP via SMS',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFFFD000),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Verify Button
                FadeInUp(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _verifyOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD000),
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
              ],

              const SizedBox(height: 32),

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
                        text: 'New Driver? ',
                        style: GoogleFonts.poppins(
                            color: Colors.white38, fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Register as Partner',
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