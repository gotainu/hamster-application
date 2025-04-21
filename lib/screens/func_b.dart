import 'package:flutter/material.dart';

class FuncBScreen extends StatelessWidget {
  const FuncBScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('機能B'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('これは機能Bのページです'),
            SizedBox(height: 16),
            // ElevatedButton(
            //   onPressed: () {
            //     // Homeに戻る
            //     Navigator.of(context).pop();
            //   },
            //   child: const Text('Homeに戻る'),
            // ),
          ],
        ),
      ),
    );
  }
}
