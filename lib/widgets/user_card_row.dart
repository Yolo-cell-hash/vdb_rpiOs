import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class UserCardRow extends StatelessWidget {
  final String name;
  final Uint8List? imageData;

  const UserCardRow({super.key, required this.name, this.imageData});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            imageData != null
                ? GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => FadeIn(
                            child: AlertDialog(
                              title: Text(
                                name,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              content: InteractiveViewer(
                                panEnabled: true,
                                minScale: 1.0,
                                maxScale: 4.0,
                                child: Image.memory(
                                  imageData!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.memory(
                      imageData!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => const Icon(
                            Icons.error,
                            color: Colors.red,
                            size: 28,
                          ),
                    ),
                  ),
                )
                : Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.person, color: Colors.grey, size: 28),
                ),

            const SizedBox(width: 16),
            Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
