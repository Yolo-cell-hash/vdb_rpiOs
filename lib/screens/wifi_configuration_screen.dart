import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/ble_util.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:vdp_poc_new/widgets/brand_logo_name.dart';
import 'package:vdp_poc_new/widgets/privacy_conditions_hyper.dart';
import 'package:vdp_poc_new/widgets/ble_prompt_stack.dart';
import 'package:vdp_poc_new/widgets/wifi_credentials_form.dart';

class WifiConfigurationScreen extends StatefulWidget {
  final device;

  const WifiConfigurationScreen({super.key, required this.device});
  @override
  State<WifiConfigurationScreen> createState() =>
      _WifiConfigurationScreenState();
}

class _WifiConfigurationScreenState extends State<WifiConfigurationScreen> {
  @override
  BleUtil bleUtil = BleUtil();

  Widget build(BuildContext context) {
    final isLoading = Provider.of<LoaderProvider>(context).isLoading;

    return FadeIn(
      child: SafeArea(
        child: ModalProgressHUD(
          inAsyncCall: isLoading,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              toolbarHeight: 90,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.lightBlueAccent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              leading: Builder(
                builder:
                    (context) => IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () async {
                        final String macAddress =
                            widget.device.device.id.toString();
                        try {
                          await bleUtil.disconnectFromDevice(macAddress);
                          Navigator.pop(context);
                        } catch (e) {
                          print(e);
                        }
                      },
                    ),
              ),
              title: Text(
                'Godrej VDB',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              centerTitle: true,
            ),
            body: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    WifiCredentialsForm(device: widget.device,),
                    Center(child: const PrivacyConditionsHyper()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
