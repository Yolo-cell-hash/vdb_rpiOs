import 'package:flutter/material.dart';

class ScanCard extends StatefulWidget {
  final device;

  ScanCard({required this.device, Key? key}) : super(key: key);

  @override
  State<ScanCard> createState() => _ScanCardState();
}

class _ScanCardState extends State<ScanCard> {
  @override

  bool isDeviceFound = false;
  final String deviceName = 'Airdopes Flex 454 ANC-GFP';

  Widget build(BuildContext context) {

    if(widget.device.device.name == deviceName) {
      setState(() {
        isDeviceFound = true;
      });
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          gradient:
              widget.device.device.name == deviceName
                  ?  LinearGradient(
                    colors: [Colors.lightBlueAccent, Colors.blue],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  )
                  : null,
          borderRadius: BorderRadius.circular(20), // Match Card's border radius

        ),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Match Container's border radius
          ),
          color: widget.device.device.name != deviceName ? Colors.white : Colors.transparent,
          child: ListTile(
            title: Text("${widget.device.device.name}", style: TextStyle(color: isDeviceFound ? Colors.white : Colors.black),),
            subtitle: Text('MAC: ${widget.device.device.id}', style: TextStyle(color: isDeviceFound ? Colors.white : Colors.black),),
            trailing: Text(
              widget.device.rssi.toString(),
              style:  TextStyle(fontWeight: FontWeight.bold,color: isDeviceFound ? Colors.white: Colors.black),
            ),
            onTap: () {
              print("Tapped on device: ${widget.device.device.name}");
            },
          ),
        ),
      ),
    );
  }
}
