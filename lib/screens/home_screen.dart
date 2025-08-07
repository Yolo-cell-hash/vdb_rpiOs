import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/ble_util.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vdp_poc_new/widgets/scan_card.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BleUtil bleUtil = BleUtil();

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<LoaderProvider>(context).isLoading;

    return FadeIn(
      child: ModalProgressHUD(
        inAsyncCall: isLoading,
        child: Scaffold(
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
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                  ),
            ),
            title: Text(
              'Godrej VDB',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            centerTitle: true,
          ),
          floatingActionButton: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.lightBlueAccent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.circular(10), // Match button's shape
            ),
            child: FloatingActionButton.extended(
              backgroundColor: Colors.transparent,
      
              // backgroundColor: Colors.lightBlueAccent,
              onPressed: () async {
                bleUtil.getPermissions();
                bleUtil.findBleState();
                bleUtil.startScan();
              },
              extendedPadding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 16,
              ),
              label: const Text('Scan', style: TextStyle(color: Colors.white, fontSize: 20),),
            ),
          ),
          body: StreamBuilder<List<ScanResult>>(
            stream: bleUtil.scanedDevices(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No Devices found'));
              } else {
                final devices = snapshot.data!;
                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ScanCard(device: device);
                  },
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
