import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/websocket_util.dart';
import 'package:vdp_poc_new/widgets/menu_widget.dart';
import 'package:vdp_poc_new/widgets/home_screen_home_widget.dart';
import 'package:vdp_poc_new/screens/settings_screen.dart';
import 'package:vdp_poc_new/screens/wifi_disconnected_screen.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  WebSocketSingleton webSocketSingleton = WebSocketSingleton();

  @override
  void dispose() {
    webSocketSingleton.close();
    super.dispose();
  }

  int _selectedIndex = 0;
  late bool isWifiConnected;
  bool isCheckingWifi = true; // Start as true to show loading initially
  bool _didChangeDependenciesRun = false;

  FbUtils fbUtils = FbUtils();

  Future<void> checkWifiConnection() async {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    FirebaseDatabase database = fbUtils.database;
    DatabaseReference wifiState = database.ref('/dev_env/wifi_state');

    setState(() {
      isCheckingWifi = true;
    });

    try {
      // Get current wifi_state value
      DataSnapshot snapshot = await wifiState.get();
      bool currentWifiState = snapshot.value as bool? ?? false;

      print('Current WiFi state: $currentWifiState');

      // If it's true, set it to false
      if (currentWifiState) {
        await wifiState.set(false);
        print('WiFi state set to false, waiting for device response...');
      }

      // Wait for up to 5 seconds for it to change back to true
      bool wifiConnected = false;
      DateTime startTime = DateTime.now();

      while (DateTime.now().difference(startTime).inSeconds < 5) {
        await Future.delayed(const Duration(milliseconds: 500));
        DataSnapshot checkSnapshot = await wifiState.get();
        bool currentState = checkSnapshot.value as bool? ?? false;

        if (currentState == true) {
          wifiConnected = true;
          print('WiFi state changed back to true - Device is connected!');
          break;
        }
      }

      // Update the provider with the final state
      loaderProvider.setWifiState(wifiConnected);

      if (!wifiConnected) {
        print('WiFi check timeout - Device did not respond');
        // Redirect to disconnected screen if WiFi is not connected
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const WifiDisconnectedScreen(),
            ),
          );
        }
      }
    } catch (e) {
      print('Error occurred in checking wifi state - $e');
      loaderProvider.setWifiState(false);
      // Redirect to disconnected screen on error
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const WifiDisconnectedScreen(),
          ),
        );
      }
    } finally {
      setState(() {
        isCheckingWifi = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didChangeDependenciesRun) {
      checkWifiConnection();
      _didChangeDependenciesRun = true;
    }
  }

  // Build the WiFi checking splash screen
  Widget _buildWifiCheckingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.lightBlueAccent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'images/gnb_new_logo_.svg',
              color: Colors.white,
              height: 120,
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 4,
            ),
            const SizedBox(height: 30),
            const Text(
              'Checking Device Connection...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please wait',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking WiFi
    if (isCheckingWifi) {
      return SafeArea(
        child: Scaffold(
          body: _buildWifiCheckingScreen(),
        ),
      );
    }

    // Show main app once WiFi check is complete
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: () {
                print('Checked Notifications');
              },
              icon: const Icon(
                Icons.notifications_none_outlined,
                color: Colors.white,
              ),
            ),
          ],
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
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          title: SvgPicture.asset(
            'images/gnb_new_logo_.svg',
            color: Colors.white,
            height: 50,
          ),
          centerTitle: true,
        ),
        drawer: const MenuWidget(),
        body: _selectedIndex == 0
            ? const HomeScreenHomeWidget()
            : SettingsScreen(),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
              backgroundColor: Colors.blue,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
              backgroundColor: Colors.blue,
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.white,
          onTap: _onItemTapped,
          backgroundColor: Colors.blue,
        ),
      ),
    );
  }
}