// lib/screens/pet_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hamster_project/theme/app_theme.dart';

import '../models/pet_profile.dart';
import '../services/pet_profile_repo.dart';
import '../services/breeding_environment_repo.dart';
import 'pet_profile_edit_screen.dart';
import 'breeding_environment_edit_screen.dart';

import '../models/breeding_environment.dart';

class PetProfileScreen extends StatelessWidget {
  const PetProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repoPet = PetProfileRepo();
    final repoEnv = BreedingEnvironmentRepo();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyleHeader = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        );
    final textStyleBody = Theme.of(context).textTheme.bodyMedium;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title:
              Text('ペットのプロフィール', style: Theme.of(context).textTheme.titleLarge),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient:
                    isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(vertical: 30, horizontal: 0),
                child: StreamBuilder<PetProfile?>(
                  stream: repoPet.watchMainPet(),
                  builder: (context, petSnap) {
                    if (petSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final pet = petSnap.data;

                    // 未登録UI
                    if (pet == null) {
                      return _ProfileCardWrapper(
                        isDark: isDark,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pets,
                                size: 64,
                                color: AppTheme.accent.withValues(alpha: 0.6)),
                            const SizedBox(height: 18),
                            Text('ペット情報がまだ登録されていません', style: textStyleBody),
                            const SizedBox(height: 18),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
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
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const BreedingEnvironmentEditScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.eco,
                                  size: 20, color: Colors.white),
                              label: Text(
                                '飼育環境を編集',
                                style: textStyleBody?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
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
                      );
                    }

                    // 文字説明用
                    String birthdayDisplay = '未設定';
                    if (pet.birthday != null) {
                      final d = pet.birthday!;
                      birthdayDisplay =
                          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                    }

                    return StreamBuilder<BreedingEnvironment?>(
                      stream: repoEnv.watchMainEnv(),
                      builder: (context, envSnap) {
                        final env = envSnap.data;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ProfileCardWrapper(
                              isDark: isDark,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 56,
                                    backgroundColor: Colors.transparent,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.accent.withValues(
                                                alpha: isDark ? 0.7 : 0.23),
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
                                        backgroundImage: pet.imageUrl != null
                                            ? NetworkImage(pet.imageUrl!)
                                            : null,
                                        child: pet.imageUrl == null
                                            ? const Icon(Icons.pets,
                                                size: 48,
                                                color: AppTheme.accent)
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(pet.name.isEmpty ? '不明' : pet.name,
                                      style: textStyleHeader?.copyWith(
                                          fontSize: 23)),
                                  const SizedBox(height: 4),
                                  Text('生年月日: $birthdayDisplay',
                                      style: textStyleBody),
                                  Text('種類: ${pet.species}',
                                      style: textStyleBody),
                                  Text('毛色: ${pet.color ?? '不明'}',
                                      style: textStyleBody),
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
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
                            _ProfileCardWrapper(
                              isDark: isDark,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('飼育環境情報',
                                      style: textStyleHeader?.copyWith(
                                          fontSize: 19)),
                                  const SizedBox(height: 14),
                                  env == null
                                      ? Text('飼育環境情報がまだ登録されていません',
                                          style: textStyleBody)
                                      : _EnvironmentCard(
                                          env: env,
                                          textStyle: textStyleBody,
                                          isDark: isDark,
                                        ),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
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
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _EnvironmentCard extends StatelessWidget {
  final BreedingEnvironment env;
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
            ? AppTheme.cardInnerDark.withValues(alpha: 0.7)
            : AppTheme.cardInnerLight.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ケージの広さ: 横 ${env.cageWidth ?? '不明'} cm, 奥 ${env.cageDepth ?? '不明'} cm',
            style: style,
          ),
          const SizedBox(height: 3),
          Text('床材の嵩: ${env.beddingThickness ?? '不明'} cm', style: style),
          const SizedBox(height: 3),
          Text('車輪の直径: ${env.wheelDiameter ?? '不明'} cm', style: style),
          const SizedBox(height: 3),
          Text('温度管理方法: ${env.temperatureControl}', style: style),
          const SizedBox(height: 3),
          Text('その他のグッズ類: ${env.accessories ?? 'なし'}', style: style),
        ],
      ),
    );
  }
}
