import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:vdp_poc_new/widgets/delete_users_dropdown_widget.dart';

class DeleteUserWidget extends StatefulWidget {
  const DeleteUserWidget({super.key});

  @override
  State<DeleteUserWidget> createState() => _DeleteUserWidgetState();
}

class _DeleteUserWidgetState extends State<DeleteUserWidget> {
  final FbUtils fbUtils = FbUtils();
  Set<String> _selectedIds = {};
  Map<String, String> _userNames = {};

  Future<void> _deleteSelectedUsers() async {
    if (_selectedIds.isEmpty) return;

    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    final fbPath = Provider.of<LoaderProvider>(
      context,
      listen: false,
    ).firebasePath;
    final database = fbUtils.database;

    final namesToDelete = _userNames.values.join(',');

    loaderProvider.showLoader();
    try {
      final DatabaseReference deleteUsers = database.ref('/$fbPath/deleteUsers');
      await deleteUsers.set(namesToDelete);

      final DatabaseReference ack = database.ref('/$fbPath/ack');
      final DatabaseEvent event = await ack.onValue.skip(1).first;
      final DataSnapshot snapshot = event.snapshot;

      if (snapshot.exists) {
        final data = snapshot.value.toString();
        if (data.isNotEmpty && data.contains('Success')) {
          loaderProvider.hideLoader();
          QuickAlert.show(
            context: context,
            type: QuickAlertType.success,
            title: 'Success',
            text: data,
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
            text: data,
            confirmBtnText: 'OK',
            onConfirmBtnTap: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          );
        }
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DeleteUsersDropdownWidget(
          onSelectionChanged: (ids) {
            if (setEquals(_selectedIds, ids)) return;
            setState(() {
              _selectedIds = Set<String>.from(ids);
            });
          },
          onUserNamesChanged: (names) {
            if (mapEquals(_userNames, names)) return;
            setState(() {
              _userNames = Map<String, String>.from(names);
            });
          },
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F1F1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF191C1E).withOpacity(0.06),
                offset: const Offset(0, -4),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PENDING ACTION',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: Color(0xFF717786),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_selectedIds.length} Operator${_selectedIds.length == 1 ? '' : 's'} Selected for Deletion',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF191C1E),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF414755),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _selectedIds.isNotEmpty ? _deleteSelectedUsers : null,
                    child: AnimatedOpacity(
                      opacity: _selectedIds.isNotEmpty ? 1.0 : 0.5,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0058BC), Color(0xFF3DC2FD)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0058BC).withOpacity(0.2),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Text(
                          'Delete Selected',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
