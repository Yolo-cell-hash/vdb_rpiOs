import 'dart:io';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class BleUtil {
  Set<ScanResult> uniqueResultsSet = {};
  bool deviceExists = false;
  String? deviceName, deviceID, deviceManufData;

  void getPermissions() async {
    List<Permission> permissions = [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.location,
      Permission.storage,
    ];
    await permissions.request();
  }

  void findBleState() async {
    var locationStatus = await Permission.location.status;
    if (locationStatus.isDenied) {
      await Permission.location.request();
    }
    var locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationServiceEnabled) {
      await Geolocator.openLocationSettings();
    }

    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) async {
      if (state == BluetoothAdapterState.on &&
          locationStatus.isGranted &&
          locationServiceEnabled) {
        print('Bluetooth is active');
        print('Scanning Status - ${FlutterBluePlus.isScanningNow}');
        startScan();
        scanedDevices();
      } else if (state == BluetoothAdapterState.off) {
        await _handleBluetoothOff(locationServiceEnabled);
      }
    });
  }

  Future<void> _handleBluetoothOff(bool locationServiceEnabled) async {
    print('Bluetooth & location is not active');
    if (Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
        print('Bluetooth & location turned on');
      } catch (e) {
        print('Error turning on Bluetooth: $e');
      }
      print('Bluetooth is now turned on!');
    }
  }

  Stream<List<ScanResult>> scanedDevices() async* {
    uniqueResultsSet = {};

    await for (var results in FlutterBluePlus.onScanResults) {
      if (results.isNotEmpty) {
        for (var result in results) {
          if (result.device.name != null &&
              result.device.name.isNotEmpty &&
              result.advertisementData.connectable) {
            uniqueResultsSet.add(result);
          }
        }

        yield uniqueResultsSet.toList();
      } else {
        yield [];
      }
    }
  }

  Future<bool> isDeviceConnected(String bleAddress) async {
    final device = BluetoothDevice(remoteId: DeviceIdentifier(bleAddress));
    try {
      List<BluetoothDevice> connectedDevices =
      await FlutterBluePlus.connectedDevices;
      for (BluetoothDevice connectedDevice in connectedDevices) {
        if (connectedDevice.remoteId == device.remoteId) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error checking connection status: $e');
      return false;
    }
  }

  void printUniqueResults() {
    for (var result in uniqueResultsSet) {
      if (result.device.name == "Advertising Communication") {
        deviceExists = true;
        deviceName = result.device.advName;
        deviceID = result.device.remoteId.toString();
        //deviceManufData = result.advertisementData.manufacturerData.values.toString();
        String hexString =
        result.advertisementData.manufacturerData.values
            .expand((list) => list)
            .map((value) => value.toRadixString(16).padLeft(2, '0'))
            .join();
        deviceManufData = String.fromCharCodes(
          List.generate(
            hexString.length ~/ 2,
                (i) => int.parse(hexString.substring(i * 2, i * 2 + 2), radix: 16),
          ),
        );
        break;
      }
    }
  }

  void startScan() {
    FlutterBluePlus.startScan(
      androidUsesFineLocation: true,
      timeout: Duration(seconds: 7),
      continuousUpdates: true,
      androidScanMode: AndroidScanMode.lowLatency,
    ).catchError((error) {
      print("Error starting scan: $error");
    });
  }

  void stopScan() {
    FlutterBluePlus.stopScan().catchError((error) {
      print("Error stopping scan: $error");
    });
  }

  Future<bool> connectToDevice(String bleAddress) async {
    try {
      final device = BluetoothDevice(remoteId: DeviceIdentifier(bleAddress));

      // Connect to the device
      await device.connect();
      print('Connected to $bleAddress');

      // readData(device);

      return true;
    } catch (e) {
      print('Error connecting to device: $e');
      return false;
    }
  }

  Future<void> disconnectFromDevice(String bleAddress) async {
    final device = BluetoothDevice(remoteId: DeviceIdentifier(bleAddress));
    try {
      await device.disconnect();
      print('Disconnected from $bleAddress');
    } catch (e) {
      print('Error disconnecting from device: $e');
    }
  }

  Future<void> sendData(BluetoothDevice device, dynamic data) async {
    try {
      dynamic dataToSend = data;
      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService service in services) {
        var characteristics = service.characteristics;
        for (BluetoothCharacteristic c in characteristics) {
          try {
            if (c.properties.write) {
              List<int> data = utf8.encode(dataToSend);
              await c.write(data, withoutResponse: false);
              print('Object written');
            }
          } catch (e) {
            print('$e during writing');
          }
        }
      }
    } catch (e) {
      print('Error occurred while writing - $e');
    }
  }

  void readData(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic
        in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            characteristic.onValueReceived.listen((value) {
              // Process and print the received data
              print("Read value: ${utf8.decode(value)}");
            });
          } else if (characteristic.properties.read) {
            try {
              List<int> value = await characteristic.read();
              print("Read value: ${utf8.decode(value)}");
            } catch (e) {
              print("Failed to read characteristic: $e");
            }
          }
        }
      }
    } catch (e) {
      print('Error occurred while reading - $e');
    }
  }

  // Modified method to wait for the SECOND notification (actual server response)
  Future<String?> sendWiFiCredentialsAndWaitForResponse(
      BluetoothDevice device,
      String ssid,
      String password,
      ) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? writeChar;
      BluetoothCharacteristic? notifyChar;

      // Find the write and notify characteristics
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.properties.write) {
            writeChar = c;
          }
          if (c.properties.notify || c.properties.indicate) {
            notifyChar = c;
          }
        }
      }

      if (writeChar == null || notifyChar == null) {
        print('Required characteristics not found');
        return null;
      }

      // Set up the notification listener FIRST
      final completer = Completer<String?>();
      await notifyChar.setNotifyValue(true);

      print('Notification enabled, starting to listen...');

      int notificationCount = 0;

      // Listen for the response - skip first, return second
      final subscription = notifyChar.lastValueStream.listen((value) {
        if (value.isNotEmpty && !completer.isCompleted) {
          notificationCount++;
          final result = utf8.decode(value);

          if (notificationCount == 1) {
            // First notification - this is the echo/acknowledgment
            print('Notification #1 (Echo/Acknowledgment): $result');
            print('Waiting for second notification (actual server response)...');
          } else if (notificationCount == 2) {
            // Second notification - this is the actual WiFi connection result
            print('Notification #2 (Server Response): $result');
            completer.complete(result);
          }
        }
      });

      // Small delay to ensure subscription is ready
      await Future.delayed(Duration(milliseconds: 300));

      // Send the WiFi credentials
      String combinedWifiCreds = "$ssid,$password";
      List<int> data = utf8.encode(combinedWifiCreds);
      await writeChar.write(data, withoutResponse: false);
      print('WiFi credentials sent: $combinedWifiCreds');
      print('Waiting for device to connect to WiFi (up to 15 seconds)...');

      // Wait for response with a 15-second timeout
      try {
        final result = await completer.future.timeout(
          Duration(seconds: 15),
          onTimeout: () {
            print('Timeout waiting for WiFi connection response (received $notificationCount notification(s))');
            if (notificationCount == 1) {
              return 'Timeout: Device acknowledged but no server response received';
            }
            return 'Timeout: No response from device';
          },
        );

        await subscription.cancel();
        return result;
      } catch (e) {
        await subscription.cancel();
        print('Error while waiting for response: $e');
        throw e;
      }
    } catch (e) {
      print('Error in sendWiFiCredentialsAndWaitForResponse: $e');
      return null;
    }
  }

  // Keep the old method for backward compatibility
  Future<String?> subscribeToChar(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic c in service.characteristics) {
          try {
            // Look for notify or indicate characteristics, not write!
            if (c.properties.notify || c.properties.indicate) {
              await c.setNotifyValue(true);

              final completer = Completer<String?>();

              // Use lastValueStream instead of value.listen
              final subscription = c.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  final result = utf8.decode(value);
                  print('Received command code - $result');
                  if (!completer.isCompleted) {
                    completer.complete(result);
                  }
                }
              });

              try {
                final result = await completer.future.timeout(
                  Duration(seconds: 30), // Increased timeout for WiFi connection
                  onTimeout: () => null,
                );
                await subscription.cancel();
                return result;
              } catch (e) {
                await subscription.cancel();
                throw e;
              }
            }
          } catch (e) {
            print('$e - during subscribing');
            continue; // Try next characteristic instead of returning
          }
        }
      }
    } catch (e) {
      print('Error occurred while subscribing - $e');
    }
    return null; // Return null if no suitable characteristic found
  }
}