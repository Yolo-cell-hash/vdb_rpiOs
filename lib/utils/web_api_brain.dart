import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:flutter/material.dart';
import 'package:vdp_poc_new/screens/landing_screen.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebApi {
  static const String apiKey = 'e8q0y264i3nxjw2pn9p2pxtbo0ub4n3b';
  static const String baseUrl = 'https://hmut-api-gdb2c.binary-labs.in';
  dynamic response = '';
  dynamic tokens;

  // Shared Preferences keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenTimestampKey = 'token_timestamp';

  Future<void> requestOTP(BuildContext context) async {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    String phoneNumber =
        Provider.of<LoaderProvider>(context, listen: false).phoneNumber;

    loaderProvider.showLoader();
    Map<String, String> requestBody = {
      'countryCode': '+91', // Dummy country code
      'phoneNumber': phoneNumber,
    };

    String jsonBody = jsonEncode(requestBody);

    print('Clicked');
    try {
      response = await http.post(
        Uri.parse('$baseUrl/integrators/v1/auth/request-otp'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonBody,
      );
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        Provider.of<LoaderProvider>(context, listen: false).otpSent = true;
      }

      print('Response body: ${response.body}');
    } catch (e) {
      print('Error making POST request: $e');
      // Handle error appropriately, e.g., show a message to the user
    } finally {
      // Ensure spinner is always turned off, even if an error occurs
      loaderProvider.hideLoader();
    }
  }

  Future<void> verifyOTP(BuildContext context, dynamic otp) async {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    String phoneNumber =
        Provider.of<LoaderProvider>(context, listen: false).phoneNumber;
    loaderProvider.showLoader();
    Map<String, dynamic> requestBody = {
      'countryCode': '+91',
      'phoneNumber': phoneNumber,
      'otp': otp,
    };

    String jsonBody = jsonEncode(requestBody);

    try {
      response = await http.post(
        Uri.parse('$baseUrl/integrators/v1/auth/verify-otp'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonBody,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      loaderProvider.hideLoader();
      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = jsonDecode(response.body);
        String? extractedAccessToken = responseData['accessToken'];
        String? extractedRefreshToken = responseData['refreshToken'];

        if (extractedAccessToken != null && extractedRefreshToken != null) {
          // Store in provider
          Provider.of<LoaderProvider>(context, listen: false).accessToken =
              extractedAccessToken;

          Provider.of<LoaderProvider>(context, listen: false).refreshToken =
              extractedRefreshToken;

          // Store tokens in shared preferences with timestamp
          await _saveTokensToPreferences(
            extractedAccessToken,
            extractedRefreshToken,
          );

          try {
            FirebaseDatabase database = FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL:
              'https://vdb-poc-default-rtdb.asia-southeast1.firebasedatabase.app/',
            );
            DatabaseReference tokenRef = database.ref("dev_env/accessToken");

            await tokenRef.set(extractedAccessToken);

            DatabaseReference refreshToken = database.ref(
              "dev_env/refresh_token",
            );

            await refreshToken.set(extractedRefreshToken);

            print(
              'Access Token successfully stored in Firebase at /updates/accessToken',
            );
          } catch (e) {
            print('Error storing access token in Firebase: $e');
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LandingScreen()),
          );

          Provider.of<LoaderProvider>(context, listen: false).otpSent = false;
        } else {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: 'Error',
            text: "Access token not found in response.",
            confirmBtnColor: Colors.red,
          );
        }
      } else {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Error',
          text: "Invalid OTP",
          confirmBtnColor: Colors.red,
        );
      }
    } catch (e) {
      print('Error making POST request: $e');
      loaderProvider.hideLoader();
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Error',
        text: e.toString(),
      );
    }
  }

  // Save tokens to shared preferences with current timestamp
  Future<void> _saveTokensToPreferences(
      String accessToken,
      String refreshToken,
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, accessToken);
      await prefs.setString(_refreshTokenKey, refreshToken);
      await prefs.setInt(
        _tokenTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      print('Tokens saved to shared preferences successfully');
    } catch (e) {
      print('Error saving tokens to shared preferences: $e');
    }
  }

  // Load tokens from shared preferences
  static Future<Map<String, String?>> loadTokensFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_tokenTimestampKey);
      String? accessToken = prefs.getString(_accessTokenKey);
      String? refreshToken = prefs.getString(_refreshTokenKey);

      // Check if 1 day (24 hours) has passed
      if (timestamp != null) {
        final savedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final currentTime = DateTime.now();
        final difference = currentTime.difference(savedTime);

        if (difference.inHours >= 24) {
          // Clear access token after 1 day
          await prefs.remove(_accessTokenKey);
          accessToken = null;
          print('Access token cleared after 24 hours');
        }
      }

      return {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
    } catch (e) {
      print('Error loading tokens from shared preferences: $e');
      return {
        'accessToken': null,
        'refreshToken': null,
      };
    }
  }

  // Clear all tokens from shared preferences
  static Future<void> clearTokensFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_tokenTimestampKey);
      print('All tokens cleared from shared preferences');
    } catch (e) {
      print('Error clearing tokens from shared preferences: $e');
    }
  }

  Future<void> getLockList(BuildContext context) async {
    {
      String accessToken =
          Provider.of<LoaderProvider>(context, listen: false).accessToken;

      try {
        response = await http.get(
          Uri.parse('$baseUrl/integrators/v1/lock/list'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (response.statusCode == 200) {
          List<dynamic> responseData = jsonDecode(response.body);
          Map<String, dynamic> lockId = responseData[0];
          String? _lockId = lockId['lockId'];
          print(
            'Lock ID is ------------------- $_lockId --------------------------',
          );

          Provider.of<LoaderProvider>(context, listen: false).lockID = _lockId!;
        }

        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
      } catch (e) {
        print('Error making GET request: $e');
      }
    }
  }

  Future<int> unlockDoor(BuildContext context) async {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    loaderProvider.showLoader();
    String lockID = Provider.of<LoaderProvider>(context, listen: false).lockID;
    String tokens =
        Provider.of<LoaderProvider>(context, listen: false).accessToken;

    print(lockID);
    Map<String, dynamic> requestBody = {'LOCK_ID': lockID.toString()};

    String jsonBody = jsonEncode(requestBody);

    try {
      response = await http.post(
        // Changed from http.get to http.post
        Uri.parse('$baseUrl/integrators/v1/lock/${lockID}/unlock-request'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'Authorization': 'Bearer $tokens',
          'LOCK_ID': lockID,
        },
        body: jsonBody, // Add the encoded body here
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('Lock Unlocked Successfully !!!');
        return 200;
        loaderProvider.hideLoader();
      } else {
        loaderProvider.hideLoader();
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Error',
          text: "Failed to open the door",
          confirmBtnColor: Colors.red,
        );
        return response.statusCode;
      }
    } catch (e) {
      print('Error making POST request: $e');
      loaderProvider.hideLoader();
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Error',
        text: e.toString(),
        confirmBtnColor: Colors.red,
      );
      return 500;
    }
  }

  Future<void> sendNotification(BuildContext context) async {
    String lockID = Provider.of<LoaderProvider>(context, listen: false).lockID;
    String tokens =
        Provider.of<LoaderProvider>(context, listen: false).accessToken;

    Map<String, dynamic> requestBody = {'LOCK_ID': lockID.toString()};

    String jsonBody = jsonEncode(requestBody);

    try {
      response = await http.post(
        // Changed from http.get to http.post
        Uri.parse(
          '$baseUrl/integrators/v1/lock/${lockID}/emergency-alert?type=DOORBELL',
        ),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'Authorization': 'Bearer $tokens',
          'LOCK_ID': lockID,
        },
        body: jsonBody, // Add the encoded body here
      );

      if (response.statusCode == 200) {
        print('Notification Sent Successfully !!!');
      } else {
        print('Notification Could not be sent!!!');
      }
    } catch (e) {
      print('Internal Error Occured - $e');
    }
  }

  Future<void> useRefreshTokenToGetAccessToken(BuildContext context) async {
    String refreshToken =
        Provider.of<LoaderProvider>(context, listen: false).refreshToken;

    Map<String, dynamic> requestBody = {'refreshToken': refreshToken};
    String jsonBody = jsonEncode(requestBody);

    try {
      response = await http.post(
        Uri.parse('$baseUrl/integrators/v1/auth/generate-token'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonBody,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = jsonDecode(response.body);
        String? extractedAccessToken = responseData['accessToken'];

        if (extractedAccessToken != null) {
          Provider.of<LoaderProvider>(context, listen: false).accessToken =
              extractedAccessToken;

          // Update access token in shared preferences with new timestamp
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_accessTokenKey, extractedAccessToken);
          await prefs.setInt(
            _tokenTimestampKey,
            DateTime.now().millisecondsSinceEpoch,
          );

          try {
            FirebaseDatabase database = FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL:
              'https://vdb-poc-default-rtdb.asia-southeast1.firebasedatabase.app/',
            );
            DatabaseReference tokenRef = database.ref("dev_env/accessToken");

            await tokenRef.set(extractedAccessToken);

            print(
              'Access Token successfully stored in Firebase at /updates/accessToken',
            );
          } catch (e) {
            print('Error storing access token in Firebase: $e');
          }
          Provider.of<LoaderProvider>(context, listen: false).otpSent = false;
        } else {
          print('Access Token is empty');
        }
      } else {
        print('Failed to get new access token - ${response.statusCode}');
      }
    } catch (e) {
      print('Error making POST request: $e');
    }
  }
}