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
  BleUtil bleUtil = BleUtil();
  final String deviceName = 'My Pi';

  // Computed property instead of state variable
  bool get isDeviceFound => widget.device.device.name == deviceName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          gradient: isDeviceFound
              ? LinearGradient(
            colors: [Colors.lightBlueAccent, Colors.blue],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          )
              : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: !isDeviceFound ? Colors.white : Colors.transparent,
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
              final navigator = Navigator.of(context);
              final loaderProvider = Provider.of<LoaderProvider>(
                context,
                listen: false,
              );
              final macAddressProvider = Provider.of<LoaderProvider>(
                context,
                listen: false,
              );

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
                      builder: (context) =>
                          WifiConfigurationScreen(device: widget.device),
                    ),
                  );
                } else {
                  print('Connection failed');
                  // Consider showing an error dialog here
                }
              } catch (e) {
                print('Error connecting to device: $e');
                // Consider showing an error dialog here
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