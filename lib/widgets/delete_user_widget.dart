import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:vdp_poc_new/widgets/delete_users_dropdown_widget.dart';

class DeleteUserWidget extends StatefulWidget {
  const DeleteUserWidget({super.key});

  @override
  State<DeleteUserWidget> createState() => _DeleteUserWidgetState();
}

class _DeleteUserWidgetState extends State<DeleteUserWidget> {
  late String name;
  FbUtils fbUtils = FbUtils();

  @override
  Widget build(BuildContext context) {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    FirebaseDatabase database = fbUtils.database;
    final selectedUserProvider = Provider.of<LoaderProvider>(context);
    name = selectedUserProvider.selectedUserName;


    return Column(
      children: [
        DeleteUsersDropdownWidget(),
        GestureDetector(
          onTap: () async {
            loaderProvider.showLoader();
            setState(() {
              name = selectedUserProvider.selectedUserName;
            });
            try {
              DatabaseReference deleteUsers = database.ref(
                '/dev_env/deleteUsers',
              );
              await deleteUsers.set(name);

              DatabaseReference ack = database.ref('/dev_env/ack');
              final DatabaseEvent event = await ack.onValue.skip(1).first;

              final DataSnapshot snapshot = event.snapshot;

              if (snapshot.exists) {
                var data = snapshot.value.toString();
                if (data.isNotEmpty && data.contains('Success')) {
                  loaderProvider.hideLoader();
                  QuickAlert.show(
                    context: context,
                    type: QuickAlertType.success,
                    title: 'Success',
                    text: data.toString(),
                    confirmBtnText: 'OK',
                    onConfirmBtnTap: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                  );
                } else if (data.isNotEmpty && data.contains('Error')) {
                  loaderProvider.hideLoader();
                  QuickAlert.show(
                    context: context,
                    type: QuickAlertType.error,
                    title: 'Error',
                    text: data.toString(),
                    confirmBtnText: 'OK',
                    onConfirmBtnTap: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                  );
                }
              } else {
                print('No valid ACK received.');
              }

              loaderProvider.hideLoader();
            } catch (e) {
              loaderProvider.hideLoader();
              QuickAlert.show(
                context: context,
                type: QuickAlertType.error,
                title: 'Error',
                text: e.toString(),
                confirmBtnColor: const Color(0xFFE30A17),
              );
            }
          },
          child: Container(
            width: double.infinity,
            height: 50,
            margin: const EdgeInsets.only(top: 25, bottom: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.lightBlueAccent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              'Delete User',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}
