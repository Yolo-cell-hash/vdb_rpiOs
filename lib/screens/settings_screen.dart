import 'package:flutter/material.dart';
import 'package:vdp_poc_new/widgets/config_tiles.dart';
import 'package:animate_do/animate_do.dart';

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
            title: 'Add Users',
            subtitle: 'Collaborate and provide fine-grained access',
            voidCallbackFunc: () {
              print('Pressed Some Button');
              print('Clicked Add New User');
            },
            tileIcon: Icons.person,
          ),
        ],
      ),
    );
  }
}
