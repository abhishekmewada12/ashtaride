import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

class DocumentUploadScreen extends StatefulWidget {
  final String mobileNumber;
  const DocumentUploadScreen({super.key, required this.mobileNumber});

  @override
  State<DocumentUploadScreen> createState() =>
      _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final _aadhaarNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();

  String _vehicleType = 'bike';
  Uint8List? _aadhaarImageBytes;
  Uint8List? _licenseImageBytes;
  String? _aadhaarBase64;
  String? _licenseBase64;
  bool _loading = false;

  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
  final _picker = ImagePicker();

  Future<void> _pickImage(bool isAadhaar) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Image',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _PickOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.pop(context);
                      await _getImage(ImageSource.camera, isAadhaar);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.pop(context);
                      await _getImage(ImageSource.gallery, isAadhaar);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source, bool isAadhaar) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 800,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    setState(() {
      if (isAadhaar) {
        _aadhaarImageBytes = bytes;
        _aadhaarBase64 = base64Str;
      } else {
        _licenseImageBytes = bytes;
        _licenseBase64 = base64Str;
      }
    });
  }

  Future<void> _submit() async {
    if (_aadhaarNumberController.text.length != 12) {
      _showSnack('Please enter valid 12 digit Aadhaar number');
      return;
    }
    if (_aadhaarBase64 == null) {
      _showSnack('Please upload Aadhaar card photo');
      return;
    }
    if (_licenseNumberController.text.isEmpty) {
      _showSnack('Please enter Driving License number');
      return;
    }
    if (_licenseBase64 == null) {
      _showSnack('Please upload Driving License photo');
      return;
    }
    if (_plateNumberController.text.isEmpty) {
      _showSnack('Please enter vehicle plate number');
      return;
    }

    setState(() => _loading = true);
    try {
      await _dio.post(
        '/api/v1/auth/rider/upload-documents',
        data: jsonEncode({
          'mobile_number': widget.mobileNumber,
          'aadhaar_number': _aadhaarNumberController.text,
          'aadhaar_doc_base64': _aadhaarBase64,
          'driving_license_number': _licenseNumberController.text,
          'driving_license_base64': _licenseBase64,
          'vehicle_type': _vehicleType,
          'plate_number': _plateNumberController.text,
          'vehicle_brand': _brandController.text,
          'vehicle_model': _modelController.text,
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Documents Submitted! 🎉',
              style:
                  GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            'Your documents have been submitted!\n\nAdmin will verify and approve within 24 hours.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.popUntil(
                    context, (route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD000),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Go to Login',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF1A1A1A),
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnack('Error uploading documents. Try again.');
    }
    setState(() => _loading = false);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: const Color(0xFFFFD000),
        title: Text('Upload Documents',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFD000))),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD000).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          const Color(0xFFFFD000).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFFFFD000), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Upload your documents for verification.',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            _SectionTitle('Aadhaar Card'),
            const SizedBox(height: 12),

            _InputField(
              controller: _aadhaarNumberController,
              label: 'Aadhaar Number',
              hint: 'Enter 12 digit Aadhaar number',
              keyboardType: TextInputType.number,
              maxLength: 12,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly
              ],
            ),

            const SizedBox(height: 12),

            _PhotoUploadCard(
              label: 'Aadhaar Card Photo',
              imageBytes: _aadhaarImageBytes,
              onTap: () => _pickImage(true),
            ),

            const SizedBox(height: 24),

            _SectionTitle('Driving License'),
            const SizedBox(height: 12),

            _InputField(
              controller: _licenseNumberController,
              label: 'License Number',
              hint: 'Enter Driving License number',
              keyboardType: TextInputType.text,
            ),

            const SizedBox(height: 12),

            _PhotoUploadCard(
              label: 'Driving License Photo',
              imageBytes: _licenseImageBytes,
              onTap: () => _pickImage(false),
            ),

            const SizedBox(height: 24),

            _SectionTitle('Vehicle Details'),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _vehicleType,
                  dropdownColor: const Color(0xFF2A2A2A),
                  style:
                      GoogleFonts.poppins(color: Colors.white),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                        value: 'bike',
                        child: Text('Bike',
                            style: GoogleFonts.poppins(
                                color: Colors.white))),
                    DropdownMenuItem(
                        value: 'scooter',
                        child: Text('Scooter',
                            style: GoogleFonts.poppins(
                                color: Colors.white))),
                    DropdownMenuItem(
                        value: 'auto',
                        child: Text('Auto',
                            style: GoogleFonts.poppins(
                                color: Colors.white))),
                  ],
                  onChanged: (val) =>
                      setState(() => _vehicleType = val!),
                ),
              ),
            ),

            const SizedBox(height: 12),

            _InputField(
              controller: _plateNumberController,
              label: 'Plate Number',
              hint: 'e.g. MP09AB1234',
              keyboardType: TextInputType.text,
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _InputField(
                    controller: _brandController,
                    label: 'Brand',
                    hint: 'Honda, Hero...',
                    keyboardType: TextInputType.text,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InputField(
                    controller: _modelController,
                    label: 'Model',
                    hint: 'Splendor...',
                    keyboardType: TextInputType.text,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD000),
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(
                        color: Color(0xFF1A1A1A))
                    : Text(
                        'Submit Documents',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: const Color(0xFFFFD000),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.keyboardType,
    this.maxLength,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
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
    );
  }
}

class _PhotoUploadCard extends StatelessWidget {
  final String label;
  final Uint8List? imageBytes;
  final VoidCallback onTap;

  const _PhotoUploadCard({
    required this.label,
    required this.imageBytes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: imageBytes != null
                ? const Color(0xFFFFD000)
                : Colors.white24,
            width: imageBytes != null ? 2 : 1,
          ),
        ),
        child: imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.memory(imageBytes!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload_outlined,
                      color: Color(0xFFFFD000), size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Upload $label',
                    style: GoogleFonts.poppins(
                        color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Camera or Gallery',
                    style: GoogleFonts.poppins(
                        color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PickOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD000).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFFFD000).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFFD000), size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}