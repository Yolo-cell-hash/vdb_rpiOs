import 'package:flutter/material.dart';

class PrivacyConditionsHyper extends StatelessWidget {
  const PrivacyConditionsHyper({super.key});

  @override
  Widget build(BuildContext context) {
    return const Expanded(
      flex: 2,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20.0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            SizedBox(
              width: 20.0,
            ),
            Column(
              children: [
                Text(
                  'By continuing you are agreeing to',
                  style: TextStyle(fontSize: 13),
                ),
                Text(
                  'Terms & Conditions | Policy',
                  style: TextStyle(
                      color: Colors.lightBlueAccent, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
