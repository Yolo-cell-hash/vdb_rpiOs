import 'package:flutter/material.dart';
import 'package:another_flutter_splash_screen/another_flutter_splash_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vdp_poc_new/screens/home_screen.dart';
import 'package:vdp_poc_new/screens/onboarding_screen.dart';
import 'package:vdp_poc_new/screens/connected_screen.dart';
import 'package:vdp_poc_new/screens/landing_screen.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import '../utils/web_api_brain.dart';

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
    final tokens = await WebApi.loadTokensFromPreferences();
    final accessToken = tokens['accessToken'];
    final refreshToken = tokens['refreshToken'];

    if (!mounted) return;

    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);

    // Check if we have tokens
    if (refreshToken != null) {
      // User was previously logged in
      loaderProvider.refreshToken = refreshToken;

      if (accessToken != null) {
        // Access token is still valid (less than 24 hours)
        loaderProvider.accessToken = accessToken;

        _checkAndRefreshToken();

        print('Access token loaded from shared preferences & refreshed');



      } else {
        // Access token expired, will need to refresh
        print('Access token expired, will need to refresh');
        // You can automatically refresh the token here if you want
      }

      setState(() {
        _nextScreen = const LandingScreen();
        _isInitialized = true;
      });
    } else {
      // No tokens found, user needs to login
      setState(() {
        _nextScreen = OnboardingScreen();
        _isInitialized = true;
      });
    }
  }


  Future<void> _checkAndRefreshToken() async {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);

    if (loaderProvider.refreshToken.isNotEmpty) {
      await WebApi().useRefreshTokenToGetAccessToken(context);
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
          child: SvgPicture.asset(
            'images/gnb_new_logo_.svg',
            color: Colors.white,
            height: 100,
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