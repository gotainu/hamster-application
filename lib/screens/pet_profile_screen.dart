import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pet_profile_edit_screen.dart';
import 'breeding_environment_edit_screen.dart';
import 'package:hamster_project/theme/app_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyleHeader = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        );
    final textStyleBody = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'ペットのプロフィール',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 背景グラデ
          Container(
            decoration: BoxDecoration(
              gradient:
                  isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
            ),
          ),
          // メインコンテンツ
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 0),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _userPetStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // ロード中
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    // データなし
                    return _ProfileCardWrapper(
                      isDark: isDark,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pets,
                              size: 64,
                              color: AppTheme.accent.withOpacity(0.6)),
                          const SizedBox(height: 18),
                          Text('ペット情報がまだ登録されていません', style: textStyleBody),
                          const SizedBox(height: 18),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) =>
                                      const PetProfileEditScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              'プロフィールを編集',
                              style: textStyleBody?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
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
                  // 飼育環境
                  final breedingEnv =
                      data['breedingEnvironment'] as Map<String, dynamic>?;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --------- 1. プロフィールカード ----------
                      _ProfileCardWrapper(
                        isDark: isDark,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 円形プロフィール
                            CircleAvatar(
                              radius: 56,
                              backgroundColor: Colors.transparent,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.accent
                                          .withOpacity(isDark ? 0.7 : 0.23),
                                      isDark
                                          ? AppTheme.darkCard
                                          : AppTheme.lightCard,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 52,
                                  backgroundColor: isDark
                                      ? Colors.grey[900]
                                      : Colors.grey[200],
                                  backgroundImage: imageUrl != null
                                      ? NetworkImage(imageUrl)
                                      : null,
                                  child: imageUrl == null
                                      ? Icon(Icons.pets,
                                          size: 48, color: AppTheme.accent)
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(petName,
                                style: textStyleHeader?.copyWith(fontSize: 23)),
                            const SizedBox(height: 4),
                            Text('生年月日: $birthdayDisplay',
                                style: textStyleBody),
                            Text('種類: $species', style: textStyleBody),
                            Text('毛色: $color', style: textStyleBody),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) =>
                                        const PetProfileEditScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit,
                                  size: 20, color: Colors.white),
                              label: Text(
                                'プロフィールを編集',
                                style: textStyleBody?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // --------- 2. 飼育環境カード ----------
                      _ProfileCardWrapper(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '飼育環境情報',
                              style: textStyleHeader?.copyWith(fontSize: 19),
                            ),
                            const SizedBox(height: 14),
                            breedingEnv == null
                                ? Text('飼育環境情報がまだ登録されていません',
                                    style: textStyleBody)
                                : _EnvironmentCard(
                                    env: breedingEnv,
                                    textStyle: textStyleBody,
                                    isDark: isDark,
                                  ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) =>
                                        const BreedingEnvironmentEditScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit,
                                  size: 20, color: Colors.white),
                              label: Text(
                                '飼育環境を編集',
                                style: textStyleBody?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 大きめの角丸・グラデーションカード
class _ProfileCardWrapper extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _ProfileCardWrapper({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: AppTheme.cardGradient(isDark),
      child: child,
    );
  }
}

/// 飼育環境情報サブカード
class _EnvironmentCard extends StatelessWidget {
  final Map<String, dynamic> env;
  final TextStyle? textStyle;
  final bool isDark;

  const _EnvironmentCard({
    required this.env,
    required this.textStyle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final style = textStyle?.copyWith(fontSize: 15);
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.cardInnerDark.withOpacity(0.7)
            : AppTheme.cardInnerLight.withOpacity(0.82),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'ケージの広さ: 横 ${env['cageWidth'] ?? '不明'} cm, 奥 ${env['cageDepth'] ?? '不明'} cm',
              style: style),
          const SizedBox(height: 3),
          Text('床材の嵩: ${env['beddingThickness'] ?? '不明'} cm', style: style),
          const SizedBox(height: 3),
          Text('車輪の直径: ${env['wheelDiameter'] ?? '不明'} cm', style: style),
          const SizedBox(height: 3),
          Text('温度管理方法: ${env['temperatureControl'] ?? '不明'}', style: style),
          const SizedBox(height: 3),
          Text('その他のグッズ類: ${env['accessories'] ?? 'なし'}', style: style),
        ],
      ),
    );
  }
}
