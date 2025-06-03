import 'package:flutter/material.dart';

class ScanCard extends StatefulWidget {
  final device;

  ScanCard({required this.device, Key? key}) : super(key: key);

  @override
  State<ScanCard> createState() => _ScanCardState();
}

class _ScanCardState extends State<ScanCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text("${widget.device.device.name}"),
        subtitle: Text('ID: ${widget.device.device.id}'),
        trailing: Text(
          widget.device.rssi.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: () {
          print("Tapped on device: ${widget.device.device.name}");
        },
      ),
    );
  }
}
