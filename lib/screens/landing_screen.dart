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
import 'package:vdp_poc_new/utils/web_api_brain.dart';

class LandingScreen extends StatefulWidget {
  final String? title, fb_path;
  const LandingScreen({super.key,  this.title, this.fb_path});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin{
  WebSocketSingleton webSocketSingleton = WebSocketSingleton();

  @override
  void dispose() {
    webSocketSingleton.close();
    _animationController?.dispose();
    super.dispose();
  }

  int _selectedIndex = 0;


  FbUtils fbUtils = FbUtils();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.elasticOut),
    );
    // Check token validity and refresh if needed
    _checkTokenValidity();
  }

  Future<void> _checkTokenValidity() async {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);

    // Check if access token exists
    if (loaderProvider.accessToken.isEmpty && loaderProvider.refreshToken.isNotEmpty) {
      print('Access token missing, attempting to refresh...');
      await WebApi().useRefreshTokenToGetAccessToken(context);
    } else if (loaderProvider.refreshToken.isEmpty) {
      print('No refresh token - logging out');
      await WebApi.logoutUser(context);
    }
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }



  late bool isWifiConnected;
  bool isCheckingWifi = true; // Start as true to show loading initially
  bool showSuccessAnimation = false; // Flag for success animation
  bool showFailureAnimation = false; // Flag for failure animation
  bool _didChangeDependenciesRun = false;
  bool _isSkipped = false; // Flag to track if user skipped the check
  bool _isCancelled = false; // Flag to cancel ongoing check

  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;



  Future<void> checkWifiConnection() async {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    FirebaseDatabase database = fbUtils.database;
    DatabaseReference wifiState = database.ref('/${widget.fb_path}/wifi_state');

    setState(() {
      isCheckingWifi = true;
      showSuccessAnimation = false;
      showFailureAnimation = false;
      _isCancelled = false;
    });

    try {
      DataSnapshot snapshot = await wifiState.get();

      if (_isCancelled || _isSkipped) {
        print('WiFi check cancelled by user');
        return;
      }

      bool currentWifiState = snapshot.value as bool? ?? false;

      print('Current WiFi state: $currentWifiState');

      if (currentWifiState) {
        await wifiState.set(false);
        print('WiFi state set to false, waiting for device response...');
      }

      bool wifiConnected = false;
      DateTime startTime = DateTime.now();

      while (DateTime.now().difference(startTime).inSeconds < 5) {
        if (_isCancelled || _isSkipped) {
          print('WiFi check cancelled by user during polling');
          return;
        }

        await Future.delayed(const Duration(milliseconds: 500));
        DataSnapshot checkSnapshot = await wifiState.get();
        bool currentState = checkSnapshot.value as bool? ?? false;

        if (currentState == true) {
          wifiConnected = true;
          print('WiFi state changed back to true - Device is connected!');
          break;
        }
      }

      if (_isCancelled || _isSkipped) {
        print('WiFi check cancelled before final steps');
        return;
      }

      loaderProvider.setWifiState(wifiConnected);

      if (!wifiConnected) {
        print('WiFi check timeout - Device did not respond');

        if (mounted && !_isCancelled && !_isSkipped) {
          setState(() {
            showFailureAnimation = true;
          });

          _animationController!.forward();

          await Future.delayed(const Duration(milliseconds: 1500));

          if (mounted && !_isCancelled && !_isSkipped) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (context) => WifiDisconnectedScreen(
                  onRetry: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LandingScreen(),
                      ),
                    );
                  },
                  onSkip: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LandingScreen(),
                      ),
                    ).then((_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _isSkipped = true;
                            isCheckingWifi = false;
                            showSuccessAnimation = false;
                            showFailureAnimation = false;
                          });
                        }
                      });
                    });
                  },
                ),
              ),
            );
          }
        }
      } else {
        if (mounted && !_isCancelled && !_isSkipped) {
          setState(() {
            showSuccessAnimation = true;
          });

          _animationController!.forward();
          await Future.delayed(const Duration(milliseconds: 1500));

          if (mounted && !_isCancelled && !_isSkipped) {
            setState(() {
              isCheckingWifi = false;
              showSuccessAnimation = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error occurred in checking wifi state - $e');
      if (_isCancelled || _isSkipped) {
        print('WiFi check cancelled during error handling');
        return;
      }

      loaderProvider.setWifiState(false);
      if (mounted && !_isCancelled && !_isSkipped) {
        setState(() {
          showFailureAnimation = true;
        });

        _animationController!.forward();

        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted && !_isCancelled && !_isSkipped) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) => WifiDisconnectedScreen(
                onRetry: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LandingScreen(),
                    ),
                  );
                },
                onSkip: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LandingScreen(),
                    ),
                  ).then((_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _isSkipped = true;
                          isCheckingWifi = false;
                          showSuccessAnimation = false;
                          showFailureAnimation = false;
                        });
                      }
                    });
                  });
                },
              ),
            ),
          );
        }
      }
    }
  }

  void _skipWifiCheck() {
    setState(() {
      _isSkipped = true;
      _isCancelled = true;
      isCheckingWifi = false;
      showSuccessAnimation = false;
      showFailureAnimation = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didChangeDependenciesRun && !_isSkipped) {
      checkWifiConnection();
      _didChangeDependenciesRun = true;
    }
  }

  Widget _buildWifiCheckingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.lightBlueAccent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'images/gnb_new_logo_.svg',
                  color: Colors.white,
                  height: 120,
                ),
                const SizedBox(height: 50),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (
                      Widget child,
                      Animation<double> animation,
                      ) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child:
                  showSuccessAnimation
                      ? ScaleTransition(
                    key: const ValueKey('success'),
                    scale: _scaleAnimation!,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.green,
                        size: 50,
                      ),
                    ),
                  )
                      : showFailureAnimation
                      ? ScaleTransition(
                    key: const ValueKey('failure'),
                    scale: _scaleAnimation!,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  )
                      : const SizedBox(
                    key: ValueKey('loading'),
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                      strokeWidth: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    showSuccessAnimation
                        ? 'Connected Successfully!'
                        : showFailureAnimation
                        ? 'Connection Failed!'
                        : 'Checking Device Connection...',
                    key: ValueKey(
                      '$showSuccessAnimation-$showFailureAnimation',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (!showSuccessAnimation && !showFailureAnimation)
                  const Text(
                    'Please wait',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  )
                else if (showFailureAnimation)
                  const Text(
                    'Unable to reach device',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _skipWifiCheck,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isCheckingWifi) {
      return SafeArea(child: Scaffold(body: _buildWifiCheckingScreen()));
    }
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
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
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
        body: _selectedIndex == 0
            ?  HomeScreenHomeWidget(title: widget.title!,)
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