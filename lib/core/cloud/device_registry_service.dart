import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:stellar_pos/core/cloud/cloud_identity_store.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class DeviceDescriptor {
  final String deviceId;
  final String platform;
  final String osVersion;
  final String manufacturer;
  final String model;
  final String appVersion;

  const DeviceDescriptor({
    required this.deviceId,
    required this.platform,
    required this.osVersion,
    required this.manufacturer,
    required this.model,
    required this.appVersion,
  });
}

class DeviceRegistryService {
  final DeviceInfoPlugin _deviceInfo;
  final CloudIdentityStore identityStore;

  DeviceRegistryService({
    DeviceInfoPlugin? deviceInfo,
    CloudIdentityStore? identityStore,
  })  : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        identityStore = identityStore ?? CloudIdentityStore();

  Future<DeviceDescriptor> describeCurrentDevice() async {
    final deviceId = await identityStore.getOrCreateDeviceId();
    var platform = 'unknown';
    var osVersion = 'unknown';
    var manufacturer = 'unknown';
    var model = 'unknown';

    if (kIsWeb) {
      final info = await _deviceInfo.webBrowserInfo;
      platform = 'web';
      osVersion = info.platform ?? 'unknown';
      manufacturer = 'browser';
      model = info.browserName.name;
    } else if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      platform = 'android';
      osVersion = info.version.release;
      manufacturer = info.manufacturer;
      model = info.model;
    } else if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      platform = 'ios';
      osVersion = info.systemVersion;
      manufacturer = 'Apple';
      model = info.model;
    } else if (Platform.isMacOS) {
      final info = await _deviceInfo.macOsInfo;
      platform = 'macos';
      osVersion = info.osRelease;
      manufacturer = 'Apple';
      model = info.model;
    } else if (Platform.isWindows) {
      final info = await _deviceInfo.windowsInfo;
      platform = 'windows';
      osVersion = info.displayVersion;
      manufacturer = 'Microsoft';
      model = info.computerName;
    } else if (Platform.isLinux) {
      final info = await _deviceInfo.linuxInfo;
      platform = 'linux';
      osVersion = info.version ?? 'unknown';
      manufacturer = 'Linux';
      model = info.prettyName;
    }

    final package = await PackageInfo.fromPlatform();

    return DeviceDescriptor(
      deviceId: deviceId,
      platform: platform,
      osVersion: osVersion,
      manufacturer: manufacturer,
      model: model,
      appVersion: package.version,
    );
  }

  static String newUserId() => IdGenerator.newId();
}
