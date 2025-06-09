import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:quickalert/quickalert.dart';
import 'package:vdp_poc_new/utils/ble_util.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:vdp_poc_new/screens/landing_screen.dart';

class WifiCredentialsForm extends StatefulWidget {
  final device;

  const WifiCredentialsForm({super.key, required this.device});

  @override
  State<WifiCredentialsForm> createState() => _WifiCredentialsFormState();
}

class _WifiCredentialsFormState extends State<WifiCredentialsForm> {
  @override
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
                    final ipProvider = Provider.of<LoaderProvider>(context, listen: false);
                    final currCtxt = context;
                    final loaderProvider = Provider.of<LoaderProvider>(
                      context,
                      listen: false,
                    );

                    final String macAddress =
                        widget.device.device.id.toString();
                    final navigator = Navigator.of(context);
                    try {
                      loaderProvider.showLoader();
                      await bleUtil.connectToDevice(macAddress);

                      final device = BluetoothDevice(
                        remoteId: DeviceIdentifier(macAddress),
                      );

                      bool connectionStatus = await bleUtil.isDeviceConnected(
                        macAddress,
                      );

                      if (connectionStatus) {
                        await bleUtil.sendData(device, ssid);
                        await Future.delayed(const Duration(seconds: 1));
                        await bleUtil.sendData(device, password);
                        await Future.delayed(const Duration(seconds: 1));

                        print('---------------------------READING DATA----------------------------------------');
                        bleUtil.readData(device);
                        ipProvider.setIp("192.168.27.212:8080");


                        QuickAlert.show(
                          context: currCtxt,
                          type: QuickAlertType.success,
                          title: 'Success',
                          text: 'Configuration Successful',
                          confirmBtnColor: Colors.green,
                          onConfirmBtnTap: () {
                            try {
                              navigator.pop();
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (context) => LandingScreen(),
                                ),
                              );
                            } catch (e) {
                              print(e);
                            }
                          },
                        );
                      }
                    } catch (e) {
                      QuickAlert.show(
                        context: context,
                        type: QuickAlertType.error,
                        title: 'Oops...',
                        text: e.toString(),
                        confirmBtnColor: const Color(0xFFE30A17),
                      );
                    } finally {
                      loaderProvider.hideLoader();
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
