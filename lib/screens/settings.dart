import 'package:flutter/material.dart';
import 'package:hamster_project/main.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/account_delete_service.dart';
import '../services/ai_chat_history_repo.dart';
import '../services/billing_status_repo.dart';
import '../services/notification_settings_service.dart';
import 'switchbot_setup.dart';
import 'subscription_plan_screen.dart';
import 'pet_profile_edit_screen.dart';
import 'breeding_environment_edit_screen.dart';

class SettingScreen extends StatefulWidget {
  final bool embeddedInTab;

  const SettingScreen({
    super.key,
    this.embeddedInTab = false,
  });

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final AccountDeleteService _accountDeleteService = AccountDeleteService();
  final NotificationSettingsService _notificationSettingsService =
      NotificationSettingsService();
  final AiChatHistoryRepo _aiChatHistoryRepo = AiChatHistoryRepo();
  final BillingStatusRepo _billingStatusRepo = BillingStatusRepo();

  PackageInfo? _packageInfo;

  bool _isOpeningContact = false;
  bool _isDeletingAiChatHistory = false;
  bool _isDeletingAccount = false;
  bool _isSigningOut = false;
  bool _isUpdatingNotificationSetting = false;

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() {
      _isSigningOut = true;
    });

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ログアウトに失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインユーザーが見つかりません。')),
      );
      return;
    }

    final confirmText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String inputText = '';

        return AlertDialog(
          title: const Text('アカウントを削除しますか？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Firestore上の飼育記録、AI相談履歴、SwitchBot連携情報、Firebase Authのアカウントを削除します。この操作は元に戻せません。',
              ),
              const SizedBox(height: 16),
              const Text(
                '削除するには DELETE_MY_ACCOUNT と入力してください。',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'DELETE_MY_ACCOUNT',
                ),
                onChanged: (value) {
                  inputText = value.trim();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(inputText);
              },
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );

    if (confirmText == null) {
      return;
    }

    if (confirmText != 'DELETE_MY_ACCOUNT') {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('削除確認文字列が一致しませんでした。')),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isDeletingAccount = true;
    });

    try {
      final result = await _accountDeleteService.deleteMyAccountAndData(
        confirmText: 'DELETE_MY_ACCOUNT',
        deleteAuthUser: true,
      );

      debugPrint(
        'Account deleted. deletedDocuments=${result['deletedDocuments']}',
      );

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }

  Future<void> _deleteAiChatHistory() async {
    if (_isDeletingAiChatHistory) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('AI相談履歴を削除しますか？'),
          content: const Text(
            '過去のAI相談履歴を削除します。この操作は元に戻せません。\n\n'
            'ペットプロフィール、飼育記録、温湿度データ、SwitchBot連携情報は削除されません。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;

    setState(() {
      _isDeletingAiChatHistory = true;
    });

    try {
      final deletedCount = await _aiChatHistoryRepo.deleteAllHistory();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedCount > 0 ? 'AI相談履歴を削除しました。' : '削除対象のAI相談履歴はありませんでした。',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI相談履歴の削除に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAiChatHistory = false;
        });
      }
    }
  }

  Future<void> _setAnomalyNotificationsEnabled(bool enabled) async {
    if (_isUpdatingNotificationSetting) return;

    setState(() {
      _isUpdatingNotificationSetting = true;
    });

    try {
      await _notificationSettingsService
          .setAnomalyNotificationsEnabled(enabled);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? '異常検知通知をONにしました。' : '異常検知通知をOFFにしました。',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('通知設定の更新に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingNotificationSetting = false;
        });
      }
    }
  }

  Future<void> _openContactEmail() async {
    if (_isOpeningContact) return;

    setState(() {
      _isOpeningContact = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    final packageInfo = _packageInfo;

    final appVersionText = packageInfo == null
        ? '不明'
        : '${packageInfo.version}+${packageInfo.buildNumber}';

    final subject = Uri.encodeComponent('ハムスター飼育アプリへのお問い合わせ');
    final body = Uri.encodeComponent(
      'お問い合わせ内容を入力してください。\n\n'
      '---\n'
      'アプリ情報\n'
      'バージョン: $appVersionText\n'
      'ユーザー: ${user?.email ?? user?.uid ?? '未ログイン'}\n'
      '端末: \n'
      '発生した画面: \n'
      '---\n',
    );

    final uri = Uri.parse(
      'mailto:gotainu@gmail.com?subject=$subject&body=$body',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('メールアプリを開けませんでした');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('メールアプリを開けませんでした: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningContact = false;
        });
      }
    }
  }

  Future<void> _openPaidFeatureOrPlan({
    required String featureName,
    required Widget screen,
  }) async {
    final billing = await _billingStatusRepo.fetchBillingStatus();

    if (!mounted) return;

    if (billing.canUsePaidFeatures) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => screen,
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('$featureNameは有料プランの機能です'),
          content: const Text(
            'この機能を利用するには、有料プランが必要です。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('閉じる'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('利用プランを見る'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SubscriptionPlanScreen(),
      ),
    );
  }

  void _openInfoPage({
    required String title,
    required IconData icon,
    required List<_PolicySectionData> sections,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PolicyInfoScreen(
          title: title,
          icon: icon,
          sections: sections,
        ),
      ),
    );
  }

  void _openPaidPlanPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SubscriptionPlanScreen(),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color? iconColor,
    Color? titleColor,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.cardInnerDark
            : AppTheme.cardInnerLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.quickActionBorder(context),
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? AppTheme.accent,
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.secondaryText(context),
              ),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _appVersionCard() {
    final info = _packageInfo;
    final versionText = info == null
        ? '読み込み中...'
        : 'Version ${info.version} (${info.buildNumber})';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.cardInnerDark
            : AppTheme.cardInnerLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.quickActionBorder(context),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppTheme.secondaryText(context),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              versionText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText(context),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();

      if (!mounted) return;

      setState(() {
        _packageInfo = info;
      });
    } catch (e) {
      debugPrint('PackageInfo load failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MyApp.of(context).themeMode == ThemeMode.dark;
    final currentUser = FirebaseAuth.instance.currentUser;
    final emailOrUid = currentUser?.email ?? currentUser?.uid ?? '未ログイン';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: !widget.embeddedInTab,
        backgroundColor: Colors.transparent,
        appBar: widget.embeddedInTab
            ? null
            : AppBar(
                title: Text(
                  'アプリ設定',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient:
                isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardGradient(isDark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.account_circle_rounded,
                        color: AppTheme.accent,
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'アカウント',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        emailOrUid,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.secondaryText(context),
                            ),
                      ),
                    ],
                  ),
                ),
                _sectionTitle(
                  context,
                  'アプリ表示',
                  '見た目や操作感に関する設定です',
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.cardInnerDark
                        : AppTheme.cardInnerLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.quickActionBorder(context),
                    ),
                  ),
                  child: SwitchListTile(
                    secondary: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: AppTheme.accent,
                    ),
                    title: Text(
                      'ダークモード',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    subtitle: Text(
                      isDark ? '現在はダークモードです' : '現在はライトモードです',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.secondaryText(context),
                          ),
                    ),
                    value: isDark,
                    activeColor: AppTheme.accent,
                    onChanged: (bool newValue) {
                      final newMode =
                          newValue ? ThemeMode.dark : ThemeMode.light;
                      MyApp.of(context).setThemeMode(newMode);
                      setState(() {});
                    },
                  ),
                ),
                _sectionTitle(
                  context,
                  '通知設定',
                  '高温・高湿・危険評価などの異常検知通知を管理します',
                ),
                StreamBuilder<NotificationSettings>(
                  stream: _notificationSettingsService.watchSettings(),
                  builder: (context, snapshot) {
                    final settings = snapshot.data ??
                        const NotificationSettings(
                          anomalyNotificationsEnabled: true,
                        );

                    final enabled = settings.anomalyNotificationsEnabled;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.cardInnerDark
                            : AppTheme.cardInnerLight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppTheme.quickActionBorder(context),
                        ),
                      ),
                      child: SwitchListTile(
                        secondary: Icon(
                          enabled
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_off_rounded,
                          color: enabled
                              ? AppTheme.accent
                              : AppTheme.secondaryText(context),
                        ),
                        title: Text(
                          '異常検知通知',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        subtitle: Text(
                          enabled
                              ? '高温・高湿・危険評価などを検知したときに通知します'
                              : '異常を検知しても通知は送信されません',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.secondaryText(context),
                                  ),
                        ),
                        value: enabled,
                        activeColor: AppTheme.accent,
                        onChanged: _isUpdatingNotificationSetting
                            ? null
                            : _setAnomalyNotificationsEnabled,
                      ),
                    );
                  },
                ),
                _sectionTitle(
                  context,
                  'プラン・課金',
                  'このアプリの利用プランを確認できます',
                ),
                _settingsTile(
                  icon: Icons.workspace_premium_rounded,
                  title: '利用プラン',
                  subtitle: 'ハムスターの環境管理を継続支援する課金プラン',
                  onTap: _openPaidPlanPage,
                ),
                _sectionTitle(
                  context,
                  '飼育情報',
                  'AI相談と環境評価に使う基本情報を編集します',
                ),
                _settingsTile(
                  icon: Icons.pets_rounded,
                  title: 'ペットプロフィール',
                  subtitle: '名前・種類・誕生日・毛色・写真を編集',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PetProfileEditScreen(),
                      ),
                    );
                  },
                ),
                _settingsTile(
                  icon: Icons.eco_rounded,
                  title: '飼育環境',
                  subtitle: 'ケージ・床材・回し車・温度管理を編集',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BreedingEnvironmentEditScreen(),
                      ),
                    );
                  },
                ),
                _sectionTitle(
                  context,
                  'データ連携',
                  '温湿度や外部サービスとの連携を管理します',
                ),
                _settingsTile(
                  icon: Icons.thermostat_rounded,
                  title: 'SwitchBot連携設定',
                  subtitle: 'TOKEN/SECRET、温湿度計の選択、連携解除',
                  onTap: () {
                    _openPaidFeatureOrPlan(
                      featureName: 'SwitchBot連携',
                      screen: const SwitchbotSetupScreen(),
                    );
                  },
                ),
                _sectionTitle(
                  context,
                  'データとプライバシー',
                  '利用条件、データの扱い、AI相談の注意点を確認できます',
                ),
                _settingsTile(
                  icon: Icons.delete_sweep_rounded,
                  title: 'AI相談履歴を削除',
                  subtitle: '過去のAI相談履歴だけを削除します',
                  iconColor: Colors.redAccent,
                  titleColor: Colors.redAccent,
                  onTap: _isDeletingAiChatHistory ? null : _deleteAiChatHistory,
                  trailing: _isDeletingAiChatHistory
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                ),
                _settingsTile(
                  icon: Icons.privacy_tip_rounded,
                  title: 'プライバシーポリシー',
                  subtitle: '保存するデータ、利用目的、削除について',
                  onTap: () {
                    _openInfoPage(
                      title: 'プライバシーポリシー',
                      icon: Icons.privacy_tip_rounded,
                      sections: _privacyPolicySections,
                    );
                  },
                ),
                _settingsTile(
                  icon: Icons.description_rounded,
                  title: '利用規約',
                  subtitle: 'アプリ利用時の基本ルール',
                  onTap: () {
                    _openInfoPage(
                      title: '利用規約',
                      icon: Icons.description_rounded,
                      sections: _termsSections,
                    );
                  },
                ),
                _settingsTile(
                  icon: Icons.smart_toy_rounded,
                  title: 'AI相談について',
                  subtitle: 'AI回答の限界、受診判断、緊急時の注意',
                  onTap: () {
                    _openInfoPage(
                      title: 'AI相談について',
                      icon: Icons.smart_toy_rounded,
                      sections: _aiDisclaimerSections,
                    );
                  },
                ),
                _sectionTitle(
                  context,
                  'サポート',
                  'お問い合わせやアプリ情報を確認できます',
                ),
                _settingsTile(
                  icon: Icons.mail_outline_rounded,
                  title: 'お問い合わせ',
                  subtitle: '不具合報告・ご相談・フィードバックを送信',
                  onTap: _isOpeningContact ? null : _openContactEmail,
                  trailing: _isOpeningContact
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                ),
                _appVersionCard(),
                _sectionTitle(
                  context,
                  'アカウント操作',
                  'ログアウトやアカウント削除を行います',
                ),
                _settingsTile(
                  icon: Icons.logout_rounded,
                  title: 'ログアウト',
                  subtitle: 'この端末からログアウトします',
                  onTap: _isSigningOut ? null : _signOut,
                  trailing: _isSigningOut
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                ),
                _settingsTile(
                  icon: Icons.warning_rounded,
                  title: 'アカウントを削除',
                  subtitle: '飼育記録・AI相談履歴・連携情報を完全に削除します',
                  iconColor: Colors.red,
                  titleColor: Colors.red,
                  onTap: _isDeletingAccount ? null : _deleteAccount,
                  trailing: _isDeletingAccount
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicySectionData {
  const _PolicySectionData({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class _PolicyInfoScreen extends StatelessWidget {
  const _PolicyInfoScreen({
    required this.title,
    required this.icon,
    required this.sections,
  });

  final String title;
  final IconData icon;
  final List<_PolicySectionData> sections;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient:
                isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardGradient(isDark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon,
                        color: AppTheme.accent,
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'この内容は、アプリ利用時の重要な確認事項です。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.secondaryText(context),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...sections.map(
                  (section) => _PolicySectionCard(section: section),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicySectionCard extends StatelessWidget {
  const _PolicySectionCard({
    required this.section,
  });

  final _PolicySectionData section;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardInnerDark : AppTheme.cardInnerLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.quickActionBorder(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.softShadow(context),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            section.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                  height: 1.55,
                ),
          ),
        ],
      ),
    );
  }
}

const List<_PolicySectionData> _privacyPolicySections = [
  _PolicySectionData(
    title: '取得・保存する情報',
    body:
        '本アプリでは、アカウント情報、ペットプロフィール、飼育環境、日々の飼育記録、AI相談履歴、温湿度などのセンサーデータ、通知に必要な端末トークンを保存することがあります。\n\n'
        'ペットプロフィールには、名前、種類、誕生日、毛色、画像URLなどが含まれます。飼育環境には、ケージサイズ、床材の厚み、回し車、温度管理方法などが含まれます。',
  ),
  _PolicySectionData(
    title: 'SwitchBot連携情報',
    body: 'SwitchBot連携を利用する場合、TOKEN/SECRET、選択した温湿度計の情報、温湿度の記録を保存します。\n\n'
        'TOKEN/SECRETはCloud Functions経由で保存され、アプリ画面上では全文を表示しません。連携解除を行うと、TOKEN/SECRETと選択中の温湿度計情報は解除されます。',
  ),
  _PolicySectionData(
    title: '利用目的',
    body: '保存された情報は、飼育記録の表示、温湿度の環境評価、AI相談の文脈補助、異常傾向の通知、アプリ機能の改善のために利用します。\n\n'
        'AI相談では、質問内容に関係する場合に限り、ペット情報、飼育環境、センサー評価などを参照することがあります。',
  ),
  _PolicySectionData(
    title: '通知トークン',
    body:
        '異常検知通知などを行うため、端末の通知トークンを保存することがあります。通知トークンは通知送信のために利用され、不要になった場合はアカウント削除などにより削除対象となります。',
  ),
  _PolicySectionData(
    title: 'データの削除',
    body:
        '設定画面のアカウント削除を実行すると、Firestore上のユーザーデータ、ペット情報、飼育記録、AI相談履歴、SwitchBot連携情報、通知関連データ、Firebase Authのアカウントを削除します。\n\n'
        '削除後の復元はできません。',
  ),
];

const List<_PolicySectionData> _termsSections = [
  _PolicySectionData(
    title: '本アプリの目的',
    body: '本アプリは、ハムスターの飼育記録、温湿度管理、環境評価、AI相談を通じて、日々の飼育を補助することを目的としています。\n\n'
        '本アプリは、獣医師による診断、治療、緊急対応の代替ではありません。',
  ),
  _PolicySectionData(
    title: '利用者の責任',
    body:
        '利用者は、入力する情報ができるだけ正確になるよう努めるものとします。入力内容やセンサー設定が不正確な場合、環境評価やAI相談の内容も不正確になる可能性があります。\n\n'
        'ペットの体調不良、怪我、食欲不振、呼吸異常、ぐったりしているなどの異変がある場合は、アプリの回答だけで判断せず、必要に応じて動物病院へ相談してください。',
  ),
  _PolicySectionData(
    title: '禁止事項',
    body:
        '本アプリを、不正アクセス、虚偽情報の登録、他者のアカウント利用、アプリやサーバーへの過度な負荷、その他不適切な目的で利用しないでください。',
  ),
  _PolicySectionData(
    title: 'サービス内容の変更',
    body: '本アプリの機能、表示内容、AI相談の仕様、通知内容、外部サービス連携の仕様は、改善や安全性向上のために変更されることがあります。',
  ),
  _PolicySectionData(
    title: '免責',
    body: '本アプリは、飼育判断を支援するための情報を提供しますが、すべての状況における正確性、完全性、結果を保証するものではありません。\n\n'
        '最終的な飼育判断、環境調整、受診判断は利用者の責任で行ってください。',
  ),
];

const List<_PolicySectionData> _aiDisclaimerSections = [
  _PolicySectionData(
    title: 'AI相談の位置づけ',
    body:
        'AI相談は、入力された質問、飼育情報、温湿度データ、過去の相談内容などをもとに、飼育の考え方や確認ポイントを提案する補助機能です。\n\n'
        'AIの回答は、獣医師による診断や治療方針の代わりにはなりません。',
  ),
  _PolicySectionData(
    title: '回答が不完全になる場合',
    body:
        'AIは、入力情報が不足している場合、センサー情報が古い場合、ペットの状態が文章だけでは判断しにくい場合に、誤った推測や不十分な回答をする可能性があります。\n\n'
        '特に体調不良の相談では、AIの回答を断定的な診断として扱わないでください。',
  ),
  _PolicySectionData(
    title: '受診を優先すべき場面',
    body:
        '呼吸が苦しそう、ぐったりしている、出血している、食べない・飲まない状態が続く、下痢、けいれん、急激な体重減少、強い暑さ寒さにさらされた可能性がある場合などは、AI相談よりも動物病院への相談を優先してください。',
  ),
  _PolicySectionData(
    title: 'センサー評価の扱い',
    body: '温湿度評価は、SwitchBotなどから取得したデータをもとにした環境面の参考情報です。\n\n'
        'センサーの設置場所、通信状況、電池残量、記録間隔によって、実際のケージ内環境と差が出る可能性があります。',
  ),
  _PolicySectionData(
    title: 'AI相談で大切な使い方',
    body: 'AI相談は、日々の観察を整理し、確認すべきポイントを見つけるために使ってください。\n\n'
        '「環境要因として考えられること」「観察すべき変化」「受診を検討すべきサイン」を分けて確認する使い方が安全です。',
  ),
];
