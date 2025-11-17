import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:quickalert/quickalert.dart';
import 'package:vdp_poc_new/utils/ble_util.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:vdp_poc_new/screens/landing_screen.dart';
import 'package:vdp_poc_new/utils/websocket_util.dart';

class WifiCredentialsForm extends StatefulWidget {
  final device;

  const WifiCredentialsForm({super.key, required this.device});

  @override
  State<WifiCredentialsForm> createState() => _WifiCredentialsFormState();
}

class _WifiCredentialsFormState extends State<WifiCredentialsForm> {
  WebSocketSingleton webSocketSingleton = WebSocketSingleton();

  final buttonStyleEnabled = ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    minimumSize: const Size(double.infinity, 50),
  );

  BleUtil bleUtil = BleUtil();
  late String ssid;
  late String password;
  late final ip;

  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 60.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.all(15),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 8.0,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'Configure WiFi',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Provide the SSID and Password for the WiFi network you want to connect to',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: TextFormField(
                          autofocus: false,
                          onChanged: (value) {
                            setState(() {
                              ssid = value;
                            });
                            print("SSID is $ssid");
                          },
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            hintText: 'SSID',
                            enabled: true,
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: TextFormField(
                          obscureText: true,
                          autofocus: false,
                          onChanged: (value) {
                            setState(() {
                              password = value;
                            });
                            print(password);
                          },
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            hintText: 'WiFi Password',
                            enabled: true,
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.lightBlueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  style: buttonStyleEnabled,
                  onPressed: () async {
                    final currCtxt = context;
                    final loaderProvider = Provider.of<LoaderProvider>(
                      context,
                      listen: false,
                    );

                    final String macAddress =
                    widget.device.device.id.toString();
                    print("Mac Address is - $macAddress");

                    try {
                      loaderProvider.showLoader();
                      final device = BluetoothDevice(
                        remoteId: DeviceIdentifier(macAddress),
                      );

                      bool connectionStatus = await bleUtil.isDeviceConnected(
                        macAddress,
                      );

                      if (!connectionStatus) {
                        throw Exception('Device not connected');
                      }

                      print(
                        '-------------------------------------------------------------',
                      );
                      print('Sending WiFi credentials and waiting for device response...');

                      // Use the new method that handles everything properly
                      String? response = await bleUtil.sendWiFiCredentialsAndWaitForResponse(
                        device,
                        ssid,
                        password,
                      );

                      print('Final response received: $response');

                      loaderProvider.hideLoader();

                      if (!mounted) return;

                      if (response != null &&
                          (response.contains('Connected') ||
                              response.toLowerCase().contains('success'))) {
                        QuickAlert.show(
                          context: context,
                          type: QuickAlertType.success,
                          title: 'Success',
                          text: 'WiFi Credentials configured successfully',
                          onConfirmBtnTap: () async {
                            Navigator.pop(context); // Close alert
                            await bleUtil.disconnectFromDevice(macAddress);
                            if (!mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LandingScreen(),
                              ),
                            );
                          },
                        );
                      } else if (response != null && response.contains('Timeout')) {
                        QuickAlert.show(
                          context: context,
                          type: QuickAlertType.warning,
                          title: 'Timeout',
                          text: 'Device did not respond in time. Please check your WiFi credentials and try again.',
                          confirmBtnColor: Colors.orange,
                        );
                      } else {
                        throw Exception(
                          'Failed to connect to WiFi. Response: $response',
                        );
                      }
                    } catch (e) {
                      loaderProvider.hideLoader();

                      if (!mounted) return;

                      QuickAlert.show(
                        context: context,
                        type: QuickAlertType.error,
                        title: 'Oops...',
                        text: 'Connection failed: ${e.toString()}',
                        confirmBtnColor: const Color(0xFFE30A17),
                      );
                    }
                  },
                  child: const Text(
                    'Configure WiFi Credentials',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}