import 'package:flutter/material.dart';
import 'package:vdp_poc_new/screens/logs_screen.dart';
import 'package:vdp_poc_new/widgets/config_tiles.dart';
import 'package:animate_do/animate_do.dart';
import 'package:vdp_poc_new/screens/users_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return FadeIn(
      child: ListView(
        children: [
          ConfigTiles(
            title: 'User Management',
            subtitle: 'Collaborate and provide fine-grained access',
            voidCallbackFunc: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UsersScreen()),
              );
            },
            tileIcon: Icons.person,
          ),
          ConfigTiles(
            title: 'Stream Management',
            subtitle: 'View and manage your streams',
            voidCallbackFunc: () {
              print('User clicked on stream management');
            },
            tileIcon: Icons.video_call,
          ),
          ConfigTiles(
            title: 'Logs',
            subtitle: 'Manage your & view your logs',
            voidCallbackFunc: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogsScreen()),
              );
            },
            tileIcon: Icons.history,
          ),
          ConfigTiles(
            title: 'Logout',
            subtitle: 'Logout from the application',
            voidCallbackFunc: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            tileIcon: Icons.logout,
          ),
        ],
      ),
    );
  }
}