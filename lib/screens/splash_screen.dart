import 'package:flutter/material.dart';
import 'package:another_flutter_splash_screen/another_flutter_splash_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vdp_poc_new/screens/home_screen.dart';
import 'package:vdp_poc_new/screens/onboarding_screen.dart';
import 'package:vdp_poc_new/screens/connected_screen.dart';
import 'package:vdp_poc_new/screens/landing_screen.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:vdp_poc_new/utils/web_api_brain.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Widget? _nextScreen;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Load tokens from shared preferences
    final tokenData = await WebApi.loadTokensFromPreferences();
    final accessToken = tokenData['accessToken'];
    final refreshToken = tokenData['refreshToken'];
    final refreshTokenExpired = tokenData['refreshTokenExpired'] ?? false;
    final accessTokenExpired = tokenData['accessTokenExpired'] ?? false;

    if (!mounted) return;

    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);

    // Check if refresh token expired
    if (refreshTokenExpired) {
      print('Refresh token expired - redirecting to onboarding');
      setState(() {
        _nextScreen = OnboardingScreen();
        _isInitialized = true;
      });
      return;
    }

    // Check if we have a valid refresh token
    if (refreshToken != null && refreshToken.isNotEmpty) {
      // User was previously logged in
      loaderProvider.refreshToken = refreshToken;
      print('Refresh token loaded from shared preferences');

      if (accessToken != null && accessToken.isNotEmpty) {
        // Access token is still valid (less than 24 hours)
        loaderProvider.accessToken = accessToken;
        print('Access token loaded from shared preferences (valid)');
      } else {
        // Access token expired or missing, will need to refresh
        print('Access token expired or missing - will refresh automatically');
        // The landing screen will handle the refresh automatically
      }

      setState(() {
        _nextScreen = const LandingScreen();
        _isInitialized = true;
      });
    } else {
      // No valid tokens found, user needs to login
      print('No valid tokens found - redirecting to onboarding');
      setState(() {
        _nextScreen = OnboardingScreen();
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Show loading while checking tokens
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.blueAccent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'images/gnb_new_logo_.svg',
                color: Colors.white,
                height: 100,
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'Initializing...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FlutterSplashScreen.fadeIn(
      backgroundColor: Colors.blueAccent,
      onInit: () {
        debugPrint("On Init");
      },
      onEnd: () {
        debugPrint("On End");
      },
      childWidget: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.blueAccent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: SvgPicture.asset(
          'images/gnb_new_logo_.svg',
          color: Colors.white,
          height: 100,
        ),
      ),
      onAnimationEnd: () => debugPrint("On Fade Ins End"),
      nextScreen: _nextScreen!,
    );
  }
}