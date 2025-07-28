import 'package:flutter/material.dart';

class LoaderProvider with ChangeNotifier {
  bool _isLoading = false;

  String _macAddress = '';
  String _ip = '';
  String _fcmToken = '';


  bool get isLoading => _isLoading;
  String get macAddress => _macAddress;
  String get ip => _ip;
  String get fcmToken => _fcmToken;

  bool _isStreamSubscribed = false;

  bool get isStreamSubscribed => _isStreamSubscribed;
  void setStreamSubscribed(bool value) {
    _isStreamSubscribed = value;
    notifyListeners();
  }

  void showLoader() {
    _isLoading = true;
    notifyListeners();
  }

  void hideLoader() {
    _isLoading = false;
    notifyListeners();
  }

  void setMacAddress(String macAddress) {
    _macAddress = macAddress;
    notifyListeners();
  }

  void setIp(String ip) {
    _ip = ip;
    notifyListeners();
  }

  void setFcmToken(String fcmToken) {
    _fcmToken = fcmToken;
    notifyListeners();
  }
}