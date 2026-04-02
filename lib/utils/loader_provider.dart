import 'package:flutter/material.dart';

class LoaderProvider with ChangeNotifier {
  bool _isLoading = false;
  bool _otpSent = false;
  bool _isStreamSubscribed = false;
  bool _survailanceModeEnabled = false;
  bool _wifiState = false;

  String _macAddress = '';
  String _ip = '';
  String _fcmToken = '';
  String _selectedUserName = '';
  String? _selectedUserId;
  String _phoneNumber = '';
  String _accessToekn = '';
  String _refreshToken = '';
  String _lockID = '';
  String _deviceName = '';
  String _firebasePath = '';

  dynamic _otp ;

  bool get otpSent => _otpSent;
  bool get isLoading => _isLoading;
  bool get survailanceModeEnabled => _survailanceModeEnabled;
  bool get isStreamSubscribed => _isStreamSubscribed;
  bool get wifiState => _wifiState;

  String get macAddress => _macAddress;
  String get ip => _ip;
  String get fcmToken => _fcmToken;
  String get selectedUserName => _selectedUserName;
  String? get selectedUserId => _selectedUserId;
  String get phoneNumber => _phoneNumber;
  String get accessToken => _accessToekn;
  String get refreshToken => _refreshToken;
  String get lockID => _lockID;
  String get deviceName => _deviceName;
  String get firebasePath => _firebasePath;

  dynamic get otp => _otp;

  void setStreamSubscribed(bool value) {
    _isStreamSubscribed = value;
    notifyListeners();
  }

  void setSurvailanceMode(bool value) {
    _survailanceModeEnabled = value;
    notifyListeners();
  }

  void setWifiState(bool newValue) {
    _wifiState = newValue;
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

  set lockID(String newValue) {
    _lockID = newValue;
    notifyListeners();
  }

  void setDeviceName(String newValue) {
    _deviceName = newValue;
    notifyListeners();
  }

  void setFirebasePath(String newValue){
    _firebasePath = newValue;
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

  void setSelectedUser(String userId, String userName) {
    _selectedUserId = userId;
    _selectedUserName = userName;
    notifyListeners();
  }

  void clearSelection() {
    _selectedUserId = null;
    _selectedUserName = '';
    notifyListeners();
  }

  set otpSent(bool newValue) {
    _otpSent = newValue;
    notifyListeners();
  }

  set otp(dynamic newValue) {
    _otp = newValue;
    notifyListeners();
  }

  set phoneNumber(String newValue) {
    _phoneNumber = newValue;
    notifyListeners();
  }

  set accessToken(String newValue) {
    _accessToekn = newValue;
    notifyListeners();
  }

  set refreshToken(String newValue) {
    _refreshToken = newValue;
    notifyListeners();
  }
}



