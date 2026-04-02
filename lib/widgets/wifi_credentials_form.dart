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

  // Initialize with empty strings instead of late
  String ssid = '';
  String password = '';
  bool _obscurePassword = true; // For password visibility toggle

  // Computed property for button enable state
  bool get _isFormValid => ssid.trim().isNotEmpty && password.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      child: Padding(
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
                          border: Border.all(
                            color: ssid.isEmpty ? Colors.blue : Colors.green,
                          ),
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
                          border: Border.all(
                            color: password.isEmpty ? Colors.blue : Colors.green,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: TextFormField(
                            obscureText: _obscurePassword,
                            autofocus: false,
                            onChanged: (value) {
                              setState(() {
                                password = value;
                              });
                              print("Password length: ${password.length}");
                            },
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              hintText: 'WiFi Password',
                              enabled: true,
                              hintStyle: const TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
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
                child: Opacity(
                  opacity: _isFormValid ? 1.0 : 0.5,
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
                      onPressed: _isFormValid ? () async {
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
                            ssid.trim(),
                            password.trim(),
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
                                    builder: (context) => const LandingScreen(title: "User",),
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
                      } : null, // Disable button when form is invalid
                      child: const Text(
                        'Configure WiFi Credentials',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}