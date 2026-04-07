/// Maps notification `source` values to the parameters needed by
/// LandingScreen and LoaderProvider.
///
/// Usage:
///   final config = NotificationDeviceMap.lookup('advantis_iot9');
///   if (config != null) { /* navigate */ }

class DeviceConfig {
  final String title;
  final String fbPath;
  final int streamId;
  final String logPath;
  final String deviceName;

  const DeviceConfig({
    required this.title,
    required this.fbPath,
    required this.streamId,
    required this.logPath,
    required this.deviceName,
  });
}

class NotificationDeviceMap {
  static const Map<String, DeviceConfig> _map = {
    'advantis_iot9': DeviceConfig(
      title: 'Advantis IoT9',
      fbPath: 'dev_env',
      streamId: 7,
      logPath: 'logs',
      deviceName: 'Advantis IoT9',
    ),
    'gsld1': DeviceConfig(
      title: 'Advantis GSLD1',
      fbPath: 'gsld1_vdb_env',
      streamId: 8,
      logPath: 'gsld1_vdb_env',
      deviceName: 'Advantis GSLD1',
    ),
    'standard_vdb': DeviceConfig(
      title: 'Standard VDB',
      fbPath: 'standard_vdb_env',
      streamId: 9,
      logPath: 'standard_vdb_env',
      deviceName: 'Standard VDB',
    ),
    'dev_vdb_1': DeviceConfig(
      title: 'Dev VDB Module 1',
      fbPath: 'dev_vdb_env1',
      streamId: 10,
      logPath: 'dev_vdb_env1',
      deviceName: 'Dev VDB Module 1',
    ),
    'dev_vdb_2': DeviceConfig(
      title: 'Dev VDB Module 2',
      fbPath: 'dev_vdb_env2',
      streamId: 11,
      logPath: 'dev_vdb_env2',
      deviceName: 'Dev VDB Module 2',
    ),
  };

  /// Returns the device config for the given [deviceType], or null if unknown.
  static DeviceConfig? lookup(String? deviceType) {
    if (deviceType == null || deviceType.isEmpty) return null;
    return _map[deviceType.toLowerCase()];
  }
}
