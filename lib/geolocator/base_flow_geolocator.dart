import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as base_flow;

import '../logger/logger.dart';
import 'geolocator.dart';
import 'position.dart';

Future<base_flow.Position> requestLocationPermission() async {
  bool serviceEnabled;
  base_flow.LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await base_flow.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

  permission = await base_flow.Geolocator.checkPermission();
  if (permission == base_flow.LocationPermission.denied) {
    permission = await base_flow.Geolocator.requestPermission();
    if (permission == base_flow.LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == base_flow.LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
      'Location permissions are permanently denied, we cannot request permissions.',
    );
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await base_flow.Geolocator.getCurrentPosition(
    desiredAccuracy: base_flow.LocationAccuracy.best,
  );
}

class GeoLocatorError extends Error {
  final String message;
  GeoLocatorError(this.message);
}

class BaseFlowGeolocator implements GeoLocator {
  final Logger _logger = Logger();
  // late StreamController<base_flow.Position> _positionStreamController;
  late Stream<base_flow.Position> _positionStream;
  // StreamSubscription<Position>? _positionStreamSubscription;
  // late StreamController<base_flow.ServiceStatus> _statusStreamController;
  late Stream<base_flow.ServiceStatus> _statusStream;
  // StreamSubscription<base_flow.ServiceStatus>? _serviceStatusStreamSubscription;
  late base_flow.LocationSettings _locationSettings;

  @override
  final LocationAccuracy desiredAccuracy;

  @override
  final int duration;

  BaseFlowGeolocator({
    this.duration = 1,
    this.desiredAccuracy = LocationAccuracy.best,
  });

  @override
  requestPermissions() async {
    _logger.info('Requesting permissions');
    base_flow.Position position = await requestLocationPermission();
    _logger.info('Permission granted');
    _logger.info('Initial position: ${position.toString()}');
    _logger.info('Create position stream');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        _locationSettings = base_flow.AndroidSettings(
          accuracy: base_flow.LocationAccuracy.best,
          // distanceFilter: 100,
          intervalDuration: const Duration(seconds: 1),
          // avoid FusedLocationProviderClient
          forceLocationManager: true,
          //(Optional) Set foreground notification config to keep the app alive
          //when going to the background
          foregroundNotificationConfig:
              const base_flow.ForegroundNotificationConfig(
            notificationText: 'App keep tracking user location in background',
            notificationTitle: 'MylesVision tracker',
            enableWakeLock: true,
            enableWifiLock: true,
          ),
        );
        break;

      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        _locationSettings = base_flow.AppleSettings(
          accuracy: base_flow.LocationAccuracy.high,
          activityType: base_flow.ActivityType.fitness,
          // distanceFilter: 100,
          pauseLocationUpdatesAutomatically: true,
          // Only set to true if our app will be started up in the background.
          showBackgroundLocationIndicator: false,
        );
      default:
        _locationSettings = const base_flow.LocationSettings(
          accuracy: base_flow.LocationAccuracy.high,
          // distanceFilter: 100,
        );
    }
  }

  @override
  Future<String> getAccuracy() async {
    base_flow.LocationAccuracyStatus accuracy =
        await base_flow.Geolocator.getLocationAccuracy();
    return accuracy.toString();
  }

  @override
  Stream<Position> getPositionStream() {
    _connectToPositionStream();
    return _positionStream.map(
      (event) => Position(
        longitude: event.longitude,
        latitude: event.latitude,
        timestamp: event.timestamp,
        accuracy: event.accuracy,
        altitude: event.altitude,
        heading: event.heading,
        speed: event.speed,
        speedAccuracy: event.speedAccuracy,
        floor: event.floor,
        isMocked: event.isMocked,
      ),
    );
  }

  @override
  Stream<GeoLocationStatus> getStatusStream() {
    _connectToStatusStream();
    return _statusStream.map((event) {
      switch (event) {
        case base_flow.ServiceStatus.enabled:
          return GeoLocationStatus.enabled;
        case base_flow.ServiceStatus.disabled:
          return GeoLocationStatus.disabled;
        default:
          _logger.warn(
            'Unknown GeoLocationStatus in base_flow.ServiceStatus: $event',
          );
          return GeoLocationStatus.disabled;
      }
    });
  }

  bool _positionStreamConnected = false;
  _connectToPositionStream() {
    if (!_positionStreamConnected) {
      _positionStream = base_flow.Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      );
      // positionStream.pipe(_positionStreamController);
      _positionStreamConnected = true;
    }
  }

  bool _statusStreamConnected = false;
  _connectToStatusStream() {
    if (!_statusStreamConnected) {
      _statusStream = base_flow.Geolocator.getServiceStatusStream();
      // statusStream.pipe(_statusStreamController);
      _statusStreamConnected = true;
    }
  }
}
