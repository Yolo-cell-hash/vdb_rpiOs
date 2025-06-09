import 'package:flutter/material.dart';


class ConfigTiles extends StatelessWidget {

  dynamic title, subtitle;
  dynamic voidCallbackFunc;
  IconData tileIcon;

  ConfigTiles({this.title,this.subtitle,required this.tileIcon,this.voidCallbackFunc});


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          borderRadius: BorderRadius.circular(15),
          elevation: 3.0,
          child: ListTile(
            title:  Text(
              title,
              style: const TextStyle(fontSize: 18.0),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(fontSize: 12.0),
            ),
            leading:  Icon(tileIcon,size: 32.0,),
            // tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              //<-- SEE HERE
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: Colors.black),
            ),

            onTap: voidCallbackFunc,
          ),
        ),
      ],
    );
  }
}
