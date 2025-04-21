import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FuncMyPageScreen extends StatelessWidget {
  const FuncMyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マイページ'),
        actions: [
          IconButton(
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
            icon: Icon(
              Icons.exit_to_app,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('これはマイページです'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Homeに戻る
                //Navigator.of(context).pop();
                FirebaseAuth.instance.signOut();
              },
              child: const Text('ログアウトすっぞ！😇'),
            ),
          ],
        ),
      ),
    );
  }
}
