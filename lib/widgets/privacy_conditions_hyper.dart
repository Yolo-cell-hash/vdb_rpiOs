import 'package:flutter/material.dart';
import 'package:vdp_poc_new/screens/home_screen.dart';
import 'package:vdp_poc_new/screens/connected_screen.dart';

class PrivacyConditionsHyper extends StatelessWidget {
  const PrivacyConditionsHyper({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20.0,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const SizedBox(
                width: 20.0,
              ),
              Column(
                children: [
                  const Text(
                    'By continuing you are agreeing to',
                    style: TextStyle(fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ConnectedScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Terms & Conditions | Policy',
                      style: TextStyle(
                          color: Colors.lightBlueAccent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
