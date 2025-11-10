import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:vdp_poc_new/utils/ble_util.dart';
import 'package:vdp_poc_new/utils/web_api_brain.dart';

class ConnectedScreenUnlockCard extends StatefulWidget {
  final IconData lockIcon;
  final Color lockedIconColor;
  final String statusTag;
  final Function() onUnlock;

  const ConnectedScreenUnlockCard({
    super.key,
    required this.lockIcon,
    required this.lockedIconColor,
    required this.statusTag,
    required this.onUnlock,
  });

  @override
  State<ConnectedScreenUnlockCard> createState() => _ConnectedScreenUnlockCardState();
}

class _ConnectedScreenUnlockCardState extends State<ConnectedScreenUnlockCard> {
  BleUtil bleUtil= BleUtil();
  WebApi webApi = WebApi();

  @override
  Widget build(BuildContext context) {
    final macAddress = Provider.of<LoaderProvider>(context).macAddress;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 4.0,
        child: Padding(
          padding: const EdgeInsets.only(
              left: 20.0, right: 20.0, bottom: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(vertical: 5.0),
                  width: 160,
                  color: Colors.grey,
                  child: const Text(
                    'Tap to Unlock',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(
                height: 20.0,
              ),
              GestureDetector(
                  onTap: widget.onUnlock,
                child: Center(
                  child: Container(
                    width: 200.0,
                    height: 200.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.lockedIconColor,
                        width: 2.5,
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      radius: 100.0,
                      child: Container(
                        width: 165,
                        height: 165,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.lockedIconColor,
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 90.0,
                          backgroundColor: widget.lockedIconColor,
                          child: Icon(
                            widget.lockIcon,
                            size: 120,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 25,
              ),
              Center(
                child: Text(
                  widget.statusTag,
                  style: TextStyle(
                    fontSize: 20,
                    color: widget.lockedIconColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
               Center(
                child: GestureDetector(
                  onTap: ()async{
                    await webApi.sendNotification(context);
                  },
                  child: Text(
                    'Auto - Locked',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
