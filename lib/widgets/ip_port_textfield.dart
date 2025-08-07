import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:vdp_poc_new/screens/home_screen.dart';
import 'package:quickalert/quickalert.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';


class IpPortTextfield extends StatefulWidget {

  final VoidCallback onChanged;
  final String label,btnLabel;

  IpPortTextfield({super.key,required this.onChanged, required this.label,required this.btnLabel});

  @override
  State<IpPortTextfield> createState() => _IpPortTextfieldState();
}

class _IpPortTextfieldState extends State<IpPortTextfield> {
  bool btnIsEnabled = true;
  String typed_value = '8806435774';


  final buttonStyleEnabled = ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    minimumSize: const Size(double.infinity, 50),
  );

  final buttonStyleDisabled = ElevatedButton.styleFrom(
    backgroundColor: Colors.grey,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    minimumSize: const Size(double.infinity, 50),
  );


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LoaderProvider>(context, listen: false).phoneNumber = typed_value;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool wasOtpSent = Provider.of<LoaderProvider>(context).otpSent;
    String accessToken = Provider.of<LoaderProvider>(context).accessToken;

    return FadeIn(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.all(15),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 20,
                    ),
                    const Center(
                      child: Text(
                        'Welcome!',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 28),
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    const Text(
                      'Use this application to gain access to your lock and secure your room safely',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Visibility(
                      visible: !wasOtpSent,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: TextFormField(
                                  autofocus: false,
                                  initialValue: typed_value,
                                  onChanged: (value) {
                                    typed_value = value;
                                    Provider.of<LoaderProvider>(context, listen: false).phoneNumber = typed_value;

                                  },
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: widget.label,
                                    enabled: true,
                                    hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Visibility(
                      visible: wasOtpSent,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: TextFormField(
                                  autofocus: false,
                                  onChanged: (value) {
                                    Provider.of<LoaderProvider>(context, listen: false).otp = value;
                                  },
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: widget.label,
                                    enabled: true,
                                    hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 35,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.lightBlueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  onPressed:widget.onChanged,
                  style: btnIsEnabled == true
                      ? buttonStyleEnabled
                      : buttonStyleDisabled,
                  child:  Text(
                    widget.btnLabel,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}