import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/screens/landing_screen.dart';
import 'package:vdp_poc_new/screens/wifi_disconnected_screen.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:vdp_poc_new/widgets/config_tiles.dart';

import '../utils/loader_provider.dart';

class DevicesListScreen extends StatefulWidget {
  const DevicesListScreen({super.key});

  @override
  State<DevicesListScreen> createState() => _DevicesListScreenState();
}

class _DevicesListScreenState extends State<DevicesListScreen>
     {

  FbUtils fbUtils = FbUtils();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
        body: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [SizedBox(height: 25.0,),
              ConfigTiles(
                title: "Advantis Iot9 VDB",
                id: 7,
                fb_path : 'dev_env',
                subtitle: 'VDB Configured with Advantis IoT9',
                tileIcon: Icons.video_camera_back,
                voidCallbackFunc: () {
                  print('Advantis IoT9 VDB Clicked');
                  Provider.of<LoaderProvider>(context, listen: false).setDeviceName('Advantis IoT9');
                  Provider.of<LoaderProvider>(context, listen: false).setFirebasePath('dev_env');

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LandingScreen(title: 'Advantis IoT9 VDB',fb_path: 'dev_env',),
                    ),
                  );
                },
              ),
              SizedBox(height: 25.0,),
              ConfigTiles(
                title: "GSLD1 VDB",
                fb_path: 'gsld1_env',
                id: 8,
                subtitle: 'VDB Configured with Advantis GSLD1',
                tileIcon: Icons.video_camera_back,
                voidCallbackFunc: () {
                  Provider.of<LoaderProvider>(context, listen: false).setDeviceName('Advantis GSLD1');
                  Provider.of<LoaderProvider>(context, listen: false).setFirebasePath('gsld1_vdb_env');
                  print('GSLD1 VDB Clicked');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LandingScreen(title: 'Advantis GSLD1 VDB', fb_path: 'gsld1_vdb_env',),
                    ),
                  );
                },
              ),
              SizedBox(height: 25.0,),
              ConfigTiles(
                title: "VDB Module",
                id: 9,
                fb_path: 'standard_vdb_env',
                subtitle: 'Standard VDB Module',
                tileIcon: Icons.video_camera_back,
                voidCallbackFunc: () {
                  print('VDB Module Clicked');
                  Provider.of<LoaderProvider>(context, listen: false).setDeviceName('Standard VDB');
                  Provider.of<LoaderProvider>(context, listen: false).setFirebasePath('standard_vdb_env');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LandingScreen(title: 'Standard VDB', fb_path: 'standard_vdb_env',),
                    ),
                  );
                },
              ),
              SizedBox(height: 25.0,),
              ConfigTiles(
                title: "Dev VDB Module",
                id: 10,
                fb_path: 'dev_vdb_env1',
                subtitle: 'Standard Dev Module',
                tileIcon: Icons.video_camera_back,
                voidCallbackFunc: () {
                  print('Dev VDB Module 1 Clicked');
                  Provider.of<LoaderProvider>(context, listen: false).setDeviceName('Dev VDB Module 1');
                  Provider.of<LoaderProvider>(context, listen: false).setFirebasePath('dev_vdb_env1');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LandingScreen(title: 'Dev VDB Module 1', fb_path: 'dev_vdb_env1',),
                    ),
                  );
                },
              ),
              SizedBox(height: 25.0,),
              ConfigTiles(
                title: "Dev VDB Module",
                id: 11,
                fb_path: 'dev_vdb_env2',
                subtitle: 'Standard Dev Module',
                tileIcon: Icons.video_camera_back,
                voidCallbackFunc: () {
                  print('Dev VDB Module 2 Clicked');
                  Provider.of<LoaderProvider>(context, listen: false).setDeviceName('Dev VDB Module 2');
                  Provider.of<LoaderProvider>(context, listen: false).setFirebasePath('dev_vdb_env2');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LandingScreen(title: 'Dev VDB Module 2', fb_path: 'dev_vdb_env2',),
                    ),
                  );
                },
              ),
              SizedBox(height: 25.0,),
            ],
          ),
        ),
      ),
    );
  }
}
