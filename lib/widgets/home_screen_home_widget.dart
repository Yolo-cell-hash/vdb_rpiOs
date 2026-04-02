import 'package:flutter/material.dart';
import 'package:vdp_poc_new/widgets/room_info_card.dart';
import 'package:animate_do/animate_do.dart';

class HomeScreenHomeWidget extends StatelessWidget {
  final String title;
  const HomeScreenHomeWidget({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return FadeIn(
      child: Padding(
        padding:  EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 20,
            ),
            title!=null?
              Text(
                'Welcome, \n $title',
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 20,
                ),
              ) :Text(
              'Welcome, \n User',
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 20,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            RoomInfoCard(),
          ],
        ),
      ),
    );
  }
}
