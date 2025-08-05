import 'dart:typed_data';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


class ActivityLogCard extends StatefulWidget {
  late String activity, time;
  late int statusCode;
  final Uint8List? imageData;

  ActivityLogCard(
      {required this.activity, required this.time, required this.statusCode,required this.imageData});

  @override
  State<ActivityLogCard> createState() => _ActivityLogCardState();
}

class _ActivityLogCardState extends State<ActivityLogCard> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder:
              (context) => FadeIn(
            child: AlertDialog(
              title: Text(
                'activity',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              content: InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.memory(
                  widget.imageData!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        );
      },
      child: Column(
        children: [
          ListTile(
            title: Text(
              widget.activity,
              style: const TextStyle(
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              DateFormat('yyyy-MM-dd -- HH:mm').format(
                DateTime.parse(widget.time),
              ),
            ),
            trailing: widget.statusCode == 0
                ? Icon(
              const FaIcon(FontAwesomeIcons.circleExclamation).icon,
              color: Colors.red,
            )
                : widget.statusCode == 1
                ? Icon(
              const FaIcon(FontAwesomeIcons.doorOpen).icon,
              color: Colors.green,
            )
                : Icon(
              const FaIcon(FontAwesomeIcons.user).icon,
              color: Colors.blueAccent,
            ),
          ),
          const Divider(
            height: 5,
            color: Color(0xFF800055),
          )
        ],
      ),
    );
  }
}
