import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({
    super.key,
    required this.onSelectScreen,
  });

  final void Function(String identifier) onSelectScreen;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Drawer(
      backgroundColor:
          isDark ? const Color(0xFF1B2131) : const Color(0xFFF7F9FC),
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(isDark: isDark),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
                children: [
                  _SectionLabel(label: '記録・管理'),
                  const SizedBox(height: 8),
                  _DrawerItem(
                    icon: Icons.edit_note_rounded,
                    title: '記録する',
                    subtitle: '体重・食事・活動などを入力',
                    onTap: () => onSelectScreen('record'),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(label: 'プロフィール・設定'),
                  const SizedBox(height: 8),
                  _DrawerItem(
                    icon: Icons.account_circle_outlined,
                    title: 'ペットのプロフィール',
                    subtitle: '名前や基本情報を編集',
                    onTap: () => onSelectScreen('pets_profile'),
                  ),
                  const SizedBox(height: 10),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'アプリの設定',
                    subtitle: '表示・通知・アカウント',
                    onTap: () => onSelectScreen('settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.95),
            AppTheme.accent.withValues(alpha: 0.52),
            if (isDark) const Color(0xFF27324E) else const Color(0xFFE7EEFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.pets_rounded,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 14),
          Text(
            'Hamster Project',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '記録と管理',
            style: TextStyle(
              color: Color(0xFFDCE7FF),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.secondaryText(context),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardSurface(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.accent,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.secondaryText(context),
                            height: 1.3,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.tertiaryText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
