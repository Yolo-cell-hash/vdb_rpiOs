import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/web_api_brain.dart';
import 'package:vdp_poc_new/widgets/brand_logo_name.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:vdp_poc_new/widgets/ip_port_textfield.dart';
import 'package:vdp_poc_new/widgets/privacy_conditions_hyper.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  dynamic response = '';
  dynamic weather = ' ';
  bool showResponse = false;
  late AnimationController controller;
  bool showWeather = false;
  String tokenType = "Bearer";
  dynamic otp;
  dynamic lockID;
  bool spinner = false;
  dynamic tokens;
  String? _token;
  dynamic dbResponse1;
  late DatabaseReference _dbRef;
  StreamSubscription<DatabaseEvent>? _dbSubscription, _dbSubscription1;
  WebApi webApi = WebApi();
  late Future<FirebaseApp> _initialization;

  final buttonStyleEnabled = ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    minimumSize: const Size(double.infinity, 50),
  );

  @override
  void initState() {
    super.initState();
    _initialization = Firebase.initializeApp();

    _initialization.then((firebaseApp) {
      // Ensure Firebase is initialized
      FirebaseDatabase database = FirebaseDatabase.instanceFor(
        app: firebaseApp,
        databaseURL:
        'https://advantis-smartlocks-uat-iot9-default-rtdb.asia-southeast1.firebasedatabase.app/',
      );
      _dbRef = database.ref("vdb_poc");
    });
  }

  @override
  void dispose() {
    controller.dispose();
    _dbSubscription?.cancel();
    _dbSubscription1?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder(
        future: _initialization,
        builder: (context, snapshot) {
          String phoneNumber = Provider.of<LoaderProvider>(context).phoneNumber;
          bool wasOtpSent = Provider.of<LoaderProvider>(context).otpSent;
          dynamic typedOTP = Provider.of<LoaderProvider>(context).otp;
          final isLoading = Provider.of<LoaderProvider>(context).isLoading;

          if (snapshot.hasError) {
            return Scaffold(body: Center(child: Text('Something Went Wrong!')));
          }

          if (snapshot.connectionState == ConnectionState.done) {
            FirebaseApp firebaseApp = Firebase.app();
            FirebaseDatabase database = FirebaseDatabase.instanceFor(
              app: firebaseApp,
              databaseURL:
              'https://advantis-smartlocks-uat-iot9-default-rtdb.asia-southeast1.firebasedatabase.app/',
            );
            DatabaseReference ref = FirebaseDatabase.instance.ref();

            return Scaffold(
              resizeToAvoidBottomInset: false,
              body: ModalProgressHUD(
                inAsyncCall: isLoading,
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const BrandLogoName(),
                        const PrivacyConditionsHyper(),
                      ],
                    ),
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.18,
                      left: 0,
                      right: 0,
                      child: IpPortTextfield(
                        onChanged:
                        !wasOtpSent
                            ? (() async => await webApi.requestOTP(context))
                            : (() async =>
                        await webApi.verifyOTP(context, typedOTP)),
                        label: !wasOtpSent ? 'Phone Number' : 'OTP',
                        btnLabel: !wasOtpSent ? 'Request OTP' : 'Verify OTP',
                      ),
                    ),

                    Visibility(
                      visible: wasOtpSent,
                      child: Positioned(
                        left: 0,
                        right: 0,
                        bottom: MediaQuery.of(context).size.height * 0.35,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              Provider.of<LoaderProvider>(context, listen: false)
                                  .otpSent = false;
                            },
                            child: Text(
                              'Change Number',
                              style: TextStyle(color: Colors.blueAccent),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      ),
    );
  }
}