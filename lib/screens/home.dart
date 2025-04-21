// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
//import 'package:hamster_project/screens/tabs.dart';

class HomeScreen extends StatelessWidget {
  // タブのインデックスを切り替えるためのコールバック
  final void Function(int) onTabSelected;
  const HomeScreen({super.key, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🌲ホーム画面ですぞ🌴'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 機能A：タブ1からタブ2へ切り替える例（indexは 1）
            ElevatedButton(
              onPressed: () => onTabSelected(1),
              child: const Text('さがす'),
            ),
            const SizedBox(height: 16),
            // 機能B：タブ1からタブ3へ
            ElevatedButton(
              onPressed: () => onTabSelected(2),
              child: const Text('機能B'),
            ),
            const SizedBox(height: 16),
            // 機能C：タブ1からタブ4へ
            ElevatedButton(
              onPressed: () => onTabSelected(3),
              child: const Text('マイページ'),
            ),
          ],
        ),
      ),
    );
  }
}
