import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'document_upload_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  bool _loading = false;
  final _dio = Dio(BaseOptions(baseUrl: 'https://ashtaride.onrender.com'));

  Future<void> _register() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Please enter your full name');
      return;
    }
    if (_mobileController.text.length != 10) {
      _showSnack('Please enter valid 10 digit mobile number');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await _dio.post(
        '/api/v1/auth/rider/register',
        queryParameters: {
          'full_name': _nameController.text.trim(),
          'mobile_number': _mobileController.text.trim(),
        },
      );

      final status = res.data['status'];
      final mobile = _mobileController.text.trim();

      if (!mounted) return;

      if (status == 'documents_pending') {
        // Documents upload pending hai
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text('Documents Pending! 📄',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: Text(
              'You are already registered but documents are pending.\n\nPlease upload your documents to complete registration.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentUploadScreen(
                          mobileNumber: mobile),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD000),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Upload Documents',
                    style: GoogleFonts.poppins(
                        color: const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        // New registration or re-apply
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(
              status == 'pending' && res.data['is_reapply'] == true
                  ? 'Re-application Submitted! 🔄'
                  : 'Registration Submitted! 🎉',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Now please upload your documents to complete registration.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentUploadScreen(
                          mobileNumber: mobile),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD000),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Upload Documents Now',
                    style: GoogleFonts.poppins(
                        color: const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (e is DioException) {
        final detail = e.response?.data['detail'] ?? '';
        if (detail.contains('rejected')) {
          _showSnack('Your application was rejected. Please try again.');
        } else if (detail.contains('approved')) {
          _showSnack('Already approved! Please login.');
        } else if (detail.contains('documents submitted')) {
          _showSnack('Documents already submitted. Wait for admin approval.');
        } else {
          _showSnack('Error registering. Try again.');
        }
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              const SizedBox(height: 20),

              // Back Button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 20),
                ),
              ),

              const SizedBox(height: 32),

              // Logo
              FadeInDown(
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD000),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD000).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.electric_bike,
                        size: 45, color: Color(0xFF1A1A1A)),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              FadeInLeft(
                child: Text(
                  'Become a Rider! 🏍️',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              FadeInLeft(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'Register to start earning with AshtaRide',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Name Field
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Full Name',
                        style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter your full name',
                        hintStyle:
                            const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.person_outline,
                            color: Color(0xFFFFD000)),
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
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Mobile Field
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mobile Number',
                        style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
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
                        fillColor: Colors.white10,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Register Button
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
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
                            'Register Now',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Info Box
              FadeInUp(
                delay: const Duration(milliseconds: 600),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('After Registration:',
                          style: GoogleFonts.poppins(
                              color: const Color(0xFFFFD000),
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(height: 8),
                      _InfoRow('Admin will verify your details'),
                      _InfoRow('You will be approved within 24 hours'),
                      _InfoRow('Then you can login and start earning!'),
                    ],
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

class _InfoRow extends StatelessWidget {
  final String text;
  const _InfoRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              color: Color(0xFFFFD000), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(
                    color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}