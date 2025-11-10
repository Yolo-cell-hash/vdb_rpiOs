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

class WebApi {
  static const String apiKey = 'e8q0y264i3nxjw2pn9p2pxtbo0ub4n3b';
  static const String baseUrl = 'https://hmut-api-gdb2c.binary-labs.in';
  dynamic response = '';
  dynamic tokens;

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
      'countryCode': '+91', // Dummy country code
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

        if (extractedAccessToken != null) {
          Provider.of<LoaderProvider>(context, listen: false).accessToken =
              extractedAccessToken;
          try {
            FirebaseDatabase database = FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL:
                  'https://advantis-smartlocks-uat-iot9-default-rtdb.asia-southeast1.firebasedatabase.app/',
            );
            DatabaseReference tokenRef = database.ref("vdb_poc/accessToken");

            await tokenRef.set(extractedAccessToken);
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
}
