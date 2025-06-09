import 'package:flutter/material.dart';

class HomeScreenFuncButton extends StatelessWidget {
  final String btnLabel;
  final IconData iconData;
  final GestureTapCallback callBack;

  const HomeScreenFuncButton(
      {super.key,
        required this.btnLabel,
        required this.iconData,
        required this.callBack});

  @override
  Widget build( contxt) {
    return GestureDetector(
      onTap: callBack,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          gradient: const LinearGradient(
            colors: [Colors.blue, Colors.lightBlueAccent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        padding: EdgeInsets.all(10.0),
        child: Column(
          children: [
            SizedBox(
              width: 60,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  iconData,
                  size: 30,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              btnLabel,
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
