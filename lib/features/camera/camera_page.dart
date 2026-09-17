import 'package:flutter/material.dart';

class CameraPage extends StatelessWidget {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
      ),

      body: const Center(
        child: Text(
          'Camera module - Người 2',
          style: TextStyle(
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}