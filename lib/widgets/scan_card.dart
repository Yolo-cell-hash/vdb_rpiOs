import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/ble_util.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:vdp_poc_new/screens/wifi_configuration_screen.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';

class ScanCard extends StatefulWidget {
  final device;

  const ScanCard({required this.device, Key? key}) : super(key: key);

  @override
  State<ScanCard> createState() => _ScanCardState();
}

class _ScanCardState extends State<ScanCard> {
  @override
  bool isDeviceFound = false;
  BleUtil bleUtil = BleUtil();
  final String deviceName = 'GSLD1';
  bool isConnecting = false;

  Widget build(BuildContext context) {
    if (widget.device.device.name == deviceName) {
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
                  ? LinearGradient(
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
            borderRadius: BorderRadius.circular(
              20,
            ), // Match Container's border radius
          ),
          color:
              widget.device.device.name != deviceName
                  ? Colors.white
                  : Colors.transparent,
          child: ListTile(
            title: Text(
              "${widget.device.device.name}",
              style: TextStyle(
                color: isDeviceFound ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              'MAC: ${widget.device.device.id}',
              style: TextStyle(
                color: isDeviceFound ? Colors.white : Colors.black,
              ),
            ),
            trailing: Text(
              widget.device.rssi.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDeviceFound ? Colors.white : Colors.black,
              ),
            ),

            onTap: () async {
              final navigator = Navigator.of(
                context,
              ); // store the Navigator to avoid async context issues
              final loaderProvider = Provider.of<LoaderProvider>(
                context,
                listen: false,
              );
              final macAddressProvider = Provider.of<LoaderProvider>(context, listen: false);

              try {
                loaderProvider.showLoader();
                final String macAddress = widget.device.device.id.toString();

                macAddressProvider.setMacAddress(macAddress);

                bool connectionStatus = await bleUtil.connectToDevice(
                  macAddress,
                );
                if (connectionStatus) {
                  print("Connection status is $connectionStatus");
                  navigator.push(
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              WifiConfigurationScreen(device: widget.device),
                    ),
                  );
                } else {
                  print('Connection failed');
                }
              } catch (e) {
                print(e);
              } finally {
                loaderProvider.hideLoader();
              }
            },
          ),
        ),
      ),
    );
  }
}
