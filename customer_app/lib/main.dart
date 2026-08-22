import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Status bar color
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const AshtaRideApp());
}

class AshtaRideApp extends StatelessWidget {
  const AshtaRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AshtaRide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Yellow + Black Theme
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD000),
          primary: const Color(0xFFFFD000),
          secondary: const Color(0xFF1A1A1A),
        ),
        primaryColor: const Color(0xFFFFD000),
        scaffoldBackgroundColor: Colors.white,
        
        // Google Fonts
        textTheme: GoogleFonts.poppinsTextTheme(),
        
        // AppBar Theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFD000),
          foregroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          centerTitle: true,
        ),
        
        // Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD000),
            foregroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}