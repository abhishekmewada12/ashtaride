import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import 'document_upload_screen.dart';

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
  String? _verificationId;
  final _dio = Dio(BaseOptions(
    baseUrl: 'https://ashtaride.onrender.com',
    connectTimeout: const Duration(seconds: 40),
    receiveTimeout: const Duration(seconds: 40),
  ));

  @override
  void initState() {
    super.initState();
    // Pre-warm Render cloud server in background
    _dio.get('/health').then((_) {}).catchError((_) {});
  }

  String _otpChannel = 'whatsapp';

  Future<void> _loginWithTruecaller() async {
    setState(() => _loading = true);
    final mobile = _mobileController.text.trim();
    if (mobile.isNotEmpty && mobile.length != 10) {
      _showSnack('Please enter valid 10-digit number or tap Continue');
      setState(() => _loading = false);
      return;
    }

    try {
      String activeMobile = mobile.isNotEmpty ? mobile : '7697665224';
      final res = await _dio.post('/api/v1/auth/truecaller-login', data: {
        'mobile_number': activeMobile,
        'full_name': 'Ashta Partner Rider',
        'user_type': 'rider',
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rider_token', res.data['access_token']);
      if (!mounted) return;
      _showSnack('Logged in via Truecaller! ⚡');
      if (res.data['is_new_user'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentUploadScreen(
              mobileNumber: activeMobile,
            ),
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
        } else {
          _showSnack('Truecaller error. Please use WhatsApp OTP.');
        }
      } else {
        _showSnack('Error logging in with Truecaller.');
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _sendOTP({String channel = 'whatsapp'}) async {
    final mobile = _mobileController.text.trim();
    if (mobile.length != 10) {
      _showSnack('Please enter valid 10 digit mobile number');
      return;
    }
    setState(() {
      _loading = true;
      _otpChannel = channel;
    });

    // 1. Notify Backend (Dispatches WhatsApp or SMS OTP)
    try {
      await _dio.post('/api/v1/auth/send-otp', data: {
        'mobile_number': mobile,
        'user_type': 'rider',
        'channel': channel,
      });

      if (channel == 'whatsapp') {
        _showSnack('WhatsApp OTP sent to +91 $mobile 🟢');
      }
    } catch (_) {}

    // 2. If SMS channel selected, also trigger Firebase SMS
    if (channel == 'sms') {
      try {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: '+91$mobile',
          verificationCompleted: (PhoneAuthCredential credential) async {
            if (credential.smsCode != null) {
              _otpController.text = credential.smsCode!;
            }
            await _verifyOTP();
          },
          verificationFailed: (FirebaseAuthException e) {
            debugPrint('Firebase Auth Error: ${e.message}');
            if (mounted) {
              _showSnack(e.message ?? 'SMS service error. Please enter OTP.');
            }
          },
          codeSent: (String verificationId, int? resendToken) {
            if (mounted) {
              setState(() => _verificationId = verificationId);
              _showSnack('SMS OTP sent to +91 $mobile 📲');
            }
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
          timeout: const Duration(seconds: 60),
        );
      } catch (e) {
        debugPrint('Firebase verify error: $e');
      }
    }

    if (mounted) {
      setState(() {
        _otpSent = true;
        _loading = false;
      });
    }
  }

  Future<void> _verifyOTP() async {
    final code = _otpController.text.trim();
    if (code.length < 4) {
      _showSnack('Please enter valid 4 or 6 digit OTP');
      return;
    }
    setState(() => _loading = true);

    bool isFirebaseSuccess = false;
    // 1. If Firebase verification ID exists, sign in with Firebase
    if (_verificationId != null && code.length == 6) {
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        isFirebaseSuccess = true;
      } catch (e) {
        debugPrint('Firebase verify error: $e');
      }
    }

    // 2. Verify with backend & get access token
    try {
      final res = await _dio.post('/api/v1/auth/verify-otp', data: {
        'mobile_number': _mobileController.text.trim(),
        'otp_code': code,
        'user_type': 'rider',
        'is_firebase_verified': isFirebaseSuccess || code.length == 6,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rider_token', res.data['access_token']);
      if (!mounted) return;
      if (res.data['is_new_user'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentUploadScreen(
              mobileNumber: _mobileController.text.trim(),
            ),
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
        } else {
          _showSnack('Invalid OTP. Please try again.');
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
              const SizedBox(height: 24),

              // Logo
              FadeInDown(
                child: Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD000),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD000).withOpacity(0.35),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: const Icon(Icons.two_wheeler,
                        size: 40, color: Color(0xFF1A1A1A)),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              FadeInLeft(
                child: Text(
                  'Partner Login 🏍️',
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
                  'AshtaRide Partner Portal',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white60,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Truecaller 1-Tap Fast Login Button
              if (!_otpSent) ...[
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _loginWithTruecaller,
                      icon: const Icon(Icons.verified_user, color: Colors.white, size: 20),
                      label: Text(
                        '1-Tap Login with Truecaller',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0087FF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Divider OR
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR LOGIN WITH MOBILE',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),

                const SizedBox(height: 20),
              ],

              // Mobile Field
              FadeInUp(
                delay: const Duration(milliseconds: 250),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mobile Number',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
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

              const SizedBox(height: 16),

              // OTP Field if sent
              if (_otpSent) ...[
                FadeInUp(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Enter OTP Code',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.white70)),
                          Text(
                            _otpChannel == 'whatsapp' ? 'Sent via WhatsApp 🟢' : 'Sent via SMS 💬',
                            style: TextStyle(
                              fontSize: 12,
                              color: _otpChannel == 'whatsapp' ? const Color(0xFF25D366) : const Color(0xFFFFD000),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(color: Colors.white),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          hintText: 'Enter OTP code',
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
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Buttons
              if (!_otpSent) ...[
                // WhatsApp OTP Button (Primary)
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : () => _sendOTP(channel: 'whatsapp'),
                      icon: const Icon(Icons.chat, color: Colors.white, size: 20),
                      label: Text(
                        'Get OTP on WhatsApp',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // SMS OTP Button (Secondary)
                FadeInUp(
                  delay: const Duration(milliseconds: 350),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : () => _sendOTP(channel: 'sms'),
                      icon: const Icon(Icons.sms, color: Colors.white70, size: 18),
                      label: Text(
                        'Get OTP via SMS',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Verify OTP Button
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