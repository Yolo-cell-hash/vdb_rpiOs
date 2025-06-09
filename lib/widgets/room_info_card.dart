import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:vdp_poc_new/screens/connected_screen.dart';
import 'package:vdp_poc_new/screens/landing_screen.dart';

class RoomInfoCard extends StatefulWidget {

  @override
  State<RoomInfoCard> createState() => _RoomInfoCardState();
}

class _RoomInfoCardState extends State<RoomInfoCard> {

  @override
  Widget build(BuildContext context) {


    return GestureDetector(
      onTap: () async{
        print('Some button clicked');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
            const ConnectedScreen(),
          ),
        );
      },
      child: Card(
        elevation: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.45), BlendMode.darken),
                      child: Image.asset('images/room_image.jpg'),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 10,
                  child: Text(
                    "The Carnival",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      // backgroundColor: Colors.black54,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Text(
                    'Main Door',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      // backgroundColor: Colors.black54,
                    ),
                  ),
                ),
                Positioned(
                  top: 1,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5.0, vertical: 1.0),
                    color: Colors.black.withOpacity(0.7),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_open_rounded,
                          color:Colors.green,
                        ),
                        Text(
                          'Unlocked',
                          style: TextStyle(
                            color:Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 15.0,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stay Duration',
                    textAlign: TextAlign.left,
                    style: TextStyle(color: Colors.blue),
                  ),
                  Text(
                    'checkIn - Checkout',
                    style: const TextStyle(color: Colors.black),
                    textAlign: TextAlign.left,
                  )
                ],
              ),
            ),
            const SizedBox(
              height: 15.0,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Check In Time',
                        textAlign: TextAlign.left,
                        style: TextStyle(color: Colors.blue),
                      ),
                      Text(
                        'checkInTime',
                        style: const TextStyle(color: Colors.black),
                        textAlign: TextAlign.left,
                      )
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Check Out Time',
                        textAlign: TextAlign.left,
                        style: TextStyle(color: Colors.blue),
                      ),
                      Text(
                        'checkOutTime',
                        style: const TextStyle(color: Colors.black),
                        textAlign: TextAlign.left,
                      )
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20,)
          ],
        ),
      ),
    );
  }
}
