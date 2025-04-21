import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pet_profile_edit_screen.dart';
import 'breeding_environment_edit_screen.dart';

class PetProfileScreen extends StatelessWidget {
  const PetProfileScreen({super.key});

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userPetStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ペットのプロフィール'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userPetStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // ロード中
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            // ドキュメントが存在しない場合
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ペット情報がまだ登録されていません'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const PetProfileEditScreen(),
                        ),
                      );
                    },
                    child: const Text('プロフィールを編集'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!.data()!;
          final petName = data['name'] ?? '不明';
          final birthdayStr = data['birthday'] as String?;
          final species = data['species'] ?? '不明';
          final color = data['color'] ?? '不明';
          final imageUrl = data['imageUrl'] as String?;

          String birthdayDisplay = '未設定';
          if (birthdayStr != null) {
            birthdayDisplay = birthdayStr.split('T').first;
          }

          // 飼育環境情報（breedingEnvironment）を取得
          final breedingEnv =
              data['breedingEnvironment'] as Map<String, dynamic>?;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 画像表示
                  Center(
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey,
                      backgroundImage:
                          imageUrl != null ? NetworkImage(imageUrl) : null,
                      child: imageUrl == null
                          ? const Icon(Icons.pets, size: 40)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  const Text(
                    'ハムスター情報',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // ペット情報表示
                  Text('ハムスターの名前: $petName'),
                  const SizedBox(height: 8),
                  Text('生年月日: $birthdayDisplay'),
                  const SizedBox(height: 8),
                  Text('種類: $species'),
                  const SizedBox(height: 8),
                  Text('毛色: $color'),
                  const SizedBox(height: 16),

                  // プロフィール編集ボタン
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const PetProfileEditScreen(),
                        ),
                      );
                    },
                    child: const Text('プロフィールを編集'),
                  ),
                  const SizedBox(height: 32),

                  // 飼育環境情報表示セクション
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    '飼育環境情報',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (breedingEnv == null)
                    const Text('飼育環境情報がまだ登録されていません')
                  else
                    Builder(
                      builder: (context) {
                        final cageWidth = breedingEnv['cageWidth'] ?? '不明';
                        final cageDepth = breedingEnv['cageDepth'] ?? '不明';
                        final beddingThickness =
                            breedingEnv['beddingThickness'] ?? '不明';
                        final wheelDiameter =
                            breedingEnv['wheelDiameter'] ?? '不明';
                        final temperatureControl =
                            breedingEnv['temperatureControl'] ?? '不明';
                        final accessories = breedingEnv['accessories'] ?? 'なし';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ケージの広さ: 横 $cageWidth cm, 奥 $cageDepth cm'),
                            const SizedBox(height: 4),
                            Text('床材の嵩: $beddingThickness cm'),
                            const SizedBox(height: 4),
                            Text('車輪の直径: $wheelDiameter cm'),
                            const SizedBox(height: 4),
                            Text('温度管理方法: $temperatureControl'),
                            const SizedBox(height: 4),
                            Text('その他のグッズ類: $accessories'),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  // 飼育環境を編集するボタン
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) =>
                              const BreedingEnvironmentEditScreen(),
                        ),
                      );
                    },
                    child: const Text('飼育環境を編集'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
