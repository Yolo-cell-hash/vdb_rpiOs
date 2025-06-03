import 'package:flutter/material.dart';
import 'package:another_flutter_splash_screen/another_flutter_splash_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vdp_poc_new/screens/onboarding_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      onAnimationEnd: () => debugPrint("On Fade In End"),
      nextScreen: OnboardingScreen(),
    );
  }
}
