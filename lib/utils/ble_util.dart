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

  // Add scan state management
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;
  Timer? _scanTimeoutTimer;

  void getPermissions() async {
    List<Permission> permissions = [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.location,
      Permission.storage,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // Log permission status for debugging
    statuses.forEach((permission, status) {
      print('${permission.toString()}: ${status.toString()}');
    });
  }

  // Optimized permission and state check
  Future<bool> checkBluetoothReady() async {
    try {
      // Check location permission
      var locationStatus = await Permission.location.status;
      if (locationStatus.isDenied) {
        locationStatus = await Permission.location.request();
        if (locationStatus.isDenied) {
          print('Location permission denied');
          return false;
        }
      }

      // Check if location service is enabled
      bool locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationServiceEnabled) {
        print('Location service is not enabled');
        await Geolocator.openLocationSettings();
        return false;
      }

      // Check Bluetooth adapter state
      BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        if (Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
            // Wait a bit for Bluetooth to turn on
            await Future.delayed(Duration(seconds: 2));
            return true;
          } catch (e) {
            print('Failed to turn on Bluetooth: $e');
            return false;
          }
        }
        print('Bluetooth is not enabled');
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking Bluetooth ready state: $e');
      return false;
    }
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

  // Optimized scan function with better state management
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      // Stop any existing scan first
      if (_isScanning) {
        print('Scan already in progress, stopping it first...');
        await stopScan();
        await Future.delayed(Duration(milliseconds: 500));
      }

      // Check if Bluetooth is ready
      bool isReady = await checkBluetoothReady();
      if (!isReady) {
        print('Bluetooth is not ready. Cannot start scan.');
        return;
      }

      // Clear previous results
      uniqueResultsSet.clear();
      _isScanning = true;

      print('Starting BLE scan for ${timeout.inSeconds} seconds...');

      await FlutterBluePlus.startScan(
        androidUsesFineLocation: true,
        timeout: timeout,
        continuousUpdates: true,
        androidScanMode: AndroidScanMode.lowLatency,
        removeIfGone: Duration(seconds: 5), // Remove devices if not seen for 5 seconds
      );

      // Set a safety timeout
      _scanTimeoutTimer = Timer(timeout + Duration(seconds: 2), () {
        if (_isScanning) {
          print('Scan timeout reached, stopping scan...');
          stopScan();
        }
      });

      print('Scan started successfully');
    } catch (e) {
      print("Error starting scan: $e");
      _isScanning = false;
    }
  }

  // Optimized stop scan with cleanup
  Future<void> stopScan() async {
    try {
      if (_isScanning) {
        await FlutterBluePlus.stopScan();
        _isScanning = false;
        _scanTimeoutTimer?.cancel();
        _scanTimeoutTimer = null;
        print("Scan stopped successfully");
      }
    } catch (e) {
      print("Error stopping scan: $e");
      _isScanning = false;
    }
  }

  // Optimized scanned devices stream with filtering
  Stream<List<ScanResult>> scanedDevices({
    String? nameFilter,
    int? rssiThreshold,
  }) async* {
    uniqueResultsSet = {};

    await for (var results in FlutterBluePlus.onScanResults) {
      if (results.isNotEmpty) {
        for (var result in results) {
          // Apply filters
          bool shouldAdd = result.device.name != null &&
              result.device.name.isNotEmpty &&
              result.advertisementData.connectable;

          // Optional name filter
          if (shouldAdd && nameFilter != null) {
            shouldAdd = result.device.name.contains(nameFilter);
          }

          // Optional RSSI threshold filter
          if (shouldAdd && rssiThreshold != null) {
            shouldAdd = result.rssi >= rssiThreshold;
          }

          if (shouldAdd) {
            uniqueResultsSet.add(result);
          }
        }

        yield uniqueResultsSet.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi)); // Sort by signal strength
      } else {
        yield [];
      }
    }
  }

  // Enhanced device connection with retry logic and timeout
  Future<bool> connectToDevice(
      String bleAddress, {
        Duration timeout = const Duration(seconds: 15),
        int maxRetries = 3,
        bool autoConnect = false,
      }) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final device = BluetoothDevice(remoteId: DeviceIdentifier(bleAddress));

        // Check if already connected
        bool alreadyConnected = await isDeviceConnected(bleAddress);
        if (alreadyConnected) {
          print('Device $bleAddress is already connected');
          return true;
        }

        print('Attempting to connect to $bleAddress (Attempt ${retryCount + 1}/$maxRetries)');

        // Stop scanning before connecting for better reliability
        if (_isScanning) {
          await stopScan();
          await Future.delayed(Duration(milliseconds: 300));
        }

        // Connect with timeout
        await device.connect(
          timeout: timeout,
          autoConnect: autoConnect,
        ).timeout(
          timeout,
          onTimeout: () {
            throw TimeoutException('Connection timeout after ${timeout.inSeconds} seconds');
          },
        );

        // Wait a bit for connection to stabilize
        await Future.delayed(Duration(milliseconds: 500));

        // Verify connection
        bool isConnected = await isDeviceConnected(bleAddress);
        if (isConnected) {
          print('Successfully connected to $bleAddress');

          // Discover services immediately after connection
          await device.discoverServices();
          print('Services discovered for $bleAddress');

          return true;
        } else {
          throw Exception('Connection verification failed');
        }

      } on TimeoutException catch (e) {
        print('Connection timeout: $e');
        retryCount++;
        if (retryCount < maxRetries) {
          print('Retrying connection in 2 seconds...');
          await Future.delayed(Duration(seconds: 2));
        }
      } catch (e) {
        print('Error connecting to device (attempt ${retryCount + 1}): $e');
        retryCount++;
        if (retryCount < maxRetries) {
          print('Retrying connection in 2 seconds...');
          await Future.delayed(Duration(seconds: 2));
        }
      }
    }

    print('Failed to connect to $bleAddress after $maxRetries attempts');
    return false;
  }

  // Optimized device connection check
  Future<bool> isDeviceConnected(String bleAddress) async {
    try {
      final device = BluetoothDevice(remoteId: DeviceIdentifier(bleAddress));

      // Check connection state
      var connectionState = await device.connectionState.first
          .timeout(Duration(seconds: 2), onTimeout: () => BluetoothConnectionState.disconnected);

      return connectionState == BluetoothConnectionState.connected;
    } catch (e) {
      print('Error checking connection status: $e');
      return false;
    }
  }

  // Enhanced disconnect with cleanup
  Future<void> disconnectFromDevice(String bleAddress) async {
    try {
      final device = BluetoothDevice(remoteId: DeviceIdentifier(bleAddress));

      bool isConnected = await isDeviceConnected(bleAddress);
      if (!isConnected) {
        print('Device $bleAddress is not connected');
        return;
      }

      print('Disconnecting from $bleAddress...');
      await device.disconnect();

      // Wait for disconnection to complete
      await Future.delayed(Duration(milliseconds: 500));

      print('Successfully disconnected from $bleAddress');
    } catch (e) {
      print('Error disconnecting from device: $e');
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

  // Cleanup method - call this when disposing
  Future<void> dispose() async {
    await stopScan();
    _scanTimeoutTimer?.cancel();
    _scanSubscription?.cancel();
    uniqueResultsSet.clear();
  }
}