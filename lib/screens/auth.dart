import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../widgets/hamster_feedback_popup.dart';

final _firebase = FirebaseAuth.instance;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static final Uri _termsUrl = Uri.parse(
    'https://hamster-breeding-app.web.app/terms/',
  );
  static final Uri _privacyUrl = Uri.parse(
    'https://hamster-breeding-app.web.app/privacy/',
  );
  static Future<void>? _googleInitialization;

  final _form = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  var _isLogin = true;
  var _showEmailForm = false;
  var _isAuthenticating = false;
  var _showPassword = false;
  var _showConfirmationPassword = false;
  var _hasAcceptedTerms = false;

  bool get _isApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get _supportsGoogle => !kIsWeb;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'このメールアドレスはすでに登録されています。ログインをお試しください。';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません。';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'メールアドレスまたはパスワードが正しくありません。';
      case 'user-disabled':
        return 'このアカウントは現在利用できません。サポートへお問い合わせください。';
      case 'weak-password':
        return 'パスワードは8文字以上で設定してください。';
      case 'too-many-requests':
        return '試行回数が多すぎます。少し時間を置いてからお試しください。';
      case 'network-request-failed':
        return '通信に失敗しました。ネットワーク接続を確認してください。';
      case 'account-exists-with-different-credential':
        return 'このメールアドレスは別の方法で登録されています。登録済みの方法でログインしてください。';
      default:
        return error.message ?? '認証に失敗しました。時間を置いてもう一度お試しください。';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    HamsterFeedbackPopup.show(context, message: message);
  }

  Future<void> _recordLegalConsent(User user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'legalConsent': {
            'termsVersion': '2026-09-24',
            'privacyVersion': '2026-09-24',
            'acceptedAt': FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Authentication must not leave a newly created account unusable if the
      // consent audit write is temporarily unavailable. It is retried later.
    }
  }

  Future<void> _sendVerificationIfNeeded(UserCredential credential) async {
    if (credential.additionalUserInfo?.isNewUser != true) return;

    final user = credential.user;
    if (user == null) return;

    await _recordLegalConsent(user);
    if (user.email != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> _runAuthentication(
    Future<UserCredential> Function() operation,
  ) async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);
    try {
      final credential = await operation();
      await _sendVerificationIfNeeded(credential);
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error));
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _showMessage('Googleでのログインを完了できませんでした。もう一度お試しください。');
      }
    } catch (_) {
      _showMessage('認証を完了できませんでした。時間を置いてもう一度お試しください。');
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _submitEmail() async {
    final isValid = _form.currentState?.validate() ?? false;
    if (!isValid) return;

    if (!_isLogin && !_hasAcceptedTerms) {
      _showMessage('利用規約とプライバシーポリシーへの同意を確認してください。');
      return;
    }

    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    await _runAuthentication(() async {
      if (_isLogin) {
        return _firebase.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      return _firebase.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    });
  }

  Future<void> _signInWithGoogle() async {
    await _runAuthentication(() async {
      _googleInitialization ??= GoogleSignIn.instance.initialize();
      await _googleInitialization;
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw StateError('Google ID token is unavailable.');
      return _firebase.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    });
  }

  Future<void> _signInWithApple() async {
    await _runAuthentication(
      () => _firebase.signInWithProvider(AppleAuthProvider()),
    );
  }

  Future<void> _openUrl(Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) _showMessage('ページを開けませんでした。時間を置いてもう一度お試しください。');
  }

  Future<void> _showPasswordResetDialog() async {
    final controller =
        TextEditingController(text: _emailController.text.trim());
    var isSending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('パスワードを再設定'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'メールアドレス',
              hintText: 'example@mail.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final email = controller.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        _showMessage('有効なメールアドレスを入力してください。');
                        return;
                      }
                      setDialogState(() => isSending = true);
                      try {
                        await _firebase.sendPasswordResetEmail(email: email);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        _showMessage('再設定用のメールを送信しました。受信箱をご確認ください。');
                      } on FirebaseAuthException catch (error) {
                        _showMessage(_authErrorMessage(error));
                        setDialogState(() => isSending = false);
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('送信する'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  void _showEmailLogin() {
    if (_isAuthenticating) return;
    setState(() {
      _showEmailForm = true;
      _isLogin = true;
    });
  }

  void _showEmailSignup() {
    if (_isAuthenticating) return;
    setState(() {
      _showEmailForm = true;
      _isLogin = false;
    });
  }

  void _toggleMode() {
    if (_isAuthenticating) return;
    setState(() {
      _isLogin = !_isLogin;
      _hasAcceptedTerms = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final textColor = isDark ? Colors.white : const Color(0xFF173148);
    final panelColor = isDark
        ? const Color(0xFF0B1728).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.92);
    final imageAsset = isDark
        ? 'assets/images/auth/auth_welcome_night.png'
        : 'assets/images/auth/auth_welcome_day.png';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(imageAsset, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: isDark ? 0.06 : 0.02),
                  Colors.black.withValues(alpha: isDark ? 0.48 : 0.24),
                ],
                stops: const [0, 0.74, 0.82, 1],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      _BrandHeader(textColor: textColor, isDark: isDark),
                      const SizedBox(height: 28),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Container(
                          key: ValueKey('auth-panel-$_showEmailForm-$_isLogin'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: panelColor,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFB7D0E5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: isDark ? 0.30 : 0.13),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: _showEmailForm
                              ? _EmailForm(
                                  formKey: _form,
                                  isLogin: _isLogin,
                                  isAuthenticating: _isAuthenticating,
                                  showPassword: _showPassword,
                                  showConfirmationPassword:
                                      _showConfirmationPassword,
                                  hasAcceptedTerms: _hasAcceptedTerms,
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  confirmPasswordController:
                                      _confirmPasswordController,
                                  onShowPasswordChanged: (value) =>
                                      setState(() => _showPassword = value),
                                  onShowConfirmationPasswordChanged: (value) =>
                                      setState(() =>
                                          _showConfirmationPassword = value),
                                  onAcceptedTermsChanged: (value) => setState(
                                      () => _hasAcceptedTerms = value ?? false),
                                  onSubmit: _submitEmail,
                                  onForgotPassword: _showPasswordResetDialog,
                                  onToggleMode: _toggleMode,
                                  onBack: () =>
                                      setState(() => _showEmailForm = false),
                                  onTermsTap: () => _openUrl(_termsUrl),
                                  onPrivacyTap: () => _openUrl(_privacyUrl),
                                )
                              : _ProviderPicker(
                                  isAuthenticating: _isAuthenticating,
                                  supportsGoogle: _supportsGoogle,
                                  supportsApple: _isApplePlatform,
                                  onGoogle: _signInWithGoogle,
                                  onApple: _signInWithApple,
                                  onEmailLogin: _showEmailLogin,
                                  onEmailSignup: _showEmailSignup,
                                  onTermsTap: () => _openUrl(_termsUrl),
                                  onPrivacyTap: () => _openUrl(_privacyUrl),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.textColor, required this.isDark});

  final Color textColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            isDark ? Colors.white.withValues(alpha: 0.92) : textColor,
            BlendMode.srcIn,
          ),
          child: Image.asset(
            'assets/images/auth/hamster_pencil_mark.png',
            width: 48,
            height: 48,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Ham Care',
          style: GoogleFonts.caveat(
            color: textColor,
            fontSize: 40,
            fontWeight: FontWeight.w700,
            height: 0.95,
          ),
        ),
      ],
    );
  }
}

class _ProviderPicker extends StatelessWidget {
  const _ProviderPicker({
    required this.isAuthenticating,
    required this.supportsGoogle,
    required this.supportsApple,
    required this.onGoogle,
    required this.onApple,
    required this.onEmailLogin,
    required this.onEmailSignup,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  final bool isAuthenticating;
  final bool supportsGoogle;
  final bool supportsApple;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onEmailLogin;
  final VoidCallback onEmailSignup;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '続ける方法を選択',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 16),
        if (supportsGoogle)
          _ProviderButton(
            icon: SvgPicture.asset(
              'assets/images/auth/google_g_logo.svg',
              width: 21,
              height: 21,
            ),
            label: 'Google で続ける',
            onPressed: isAuthenticating ? null : onGoogle,
            style: _ProviderButtonStyle.google,
          ),
        if (supportsGoogle && supportsApple) const SizedBox(height: 10),
        if (supportsApple)
          _ProviderButton(
            icon: const Icon(Icons.apple_rounded, size: 24),
            label: 'Apple で続ける',
            onPressed: isAuthenticating ? null : onApple,
            style: _ProviderButtonStyle.apple,
          ),
        if (supportsGoogle || supportsApple) ...[
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('または'),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 18),
        ],
        SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton.icon(
            onPressed: isAuthenticating ? null : onEmailLogin,
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text(
              'メールアドレスでログイン',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: isAuthenticating ? null : onEmailSignup,
          child: const Text('はじめての方はこちら'),
        ),
        const SizedBox(height: 8),
        _LegalNotice(onTermsTap: onTermsTap, onPrivacyTap: onPrivacyTap),
      ],
    );
  }
}

class _EmailForm extends StatelessWidget {
  const _EmailForm({
    required this.formKey,
    required this.isLogin,
    required this.isAuthenticating,
    required this.showPassword,
    required this.showConfirmationPassword,
    required this.hasAcceptedTerms,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onShowPasswordChanged,
    required this.onShowConfirmationPasswordChanged,
    required this.onAcceptedTermsChanged,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onToggleMode,
    required this.onBack,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  final GlobalKey<FormState> formKey;
  final bool isLogin;
  final bool isAuthenticating;
  final bool showPassword;
  final bool showConfirmationPassword;
  final bool hasAcceptedTerms;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final ValueChanged<bool> onShowPasswordChanged;
  final ValueChanged<bool> onShowConfirmationPasswordChanged;
  final ValueChanged<bool?> onAcceptedTermsChanged;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onToggleMode;
  final VoidCallback onBack;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: isAuthenticating ? null : onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('ログイン方法を選ぶ'),
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'メールアドレス',
              hintText: 'example@mail.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            textCapitalization: TextCapitalization.none,
            enabled: !isAuthenticating,
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty || !email.contains('@')) {
                return '有効なメールアドレスを入力してください';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: 'パスワード',
              hintText: isLogin ? 'パスワードを入力' : '8文字以上',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: showPassword ? 'パスワードを隠す' : 'パスワードを表示',
                onPressed: isAuthenticating
                    ? null
                    : () => onShowPasswordChanged(!showPassword),
                icon: Icon(
                  showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            obscureText: !showPassword,
            enableSuggestions: false,
            autocorrect: false,
            textInputAction:
                isLogin ? TextInputAction.done : TextInputAction.next,
            autofillHints: isLogin
                ? const [AutofillHints.password]
                : const [AutofillHints.newPassword],
            enabled: !isAuthenticating,
            onFieldSubmitted: isLogin ? (_) => onSubmit() : null,
            validator: (value) {
              final minLength = isLogin ? 6 : 8;
              if (value == null || value.length < minLength) {
                return isLogin ? 'パスワードを入力してください' : 'パスワードは8文字以上で設定してください';
              }
              return null;
            },
          ),
          if (!isLogin) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'パスワードを確認',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  tooltip: showConfirmationPassword ? 'パスワードを隠す' : 'パスワードを表示',
                  onPressed: isAuthenticating
                      ? null
                      : () => onShowConfirmationPasswordChanged(
                          !showConfirmationPassword),
                  icon: Icon(
                    showConfirmationPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              obscureText: !showConfirmationPassword,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              enabled: !isAuthenticating,
              onFieldSubmitted: (_) => onSubmit(),
              validator: (value) {
                if (value != passwordController.text) {
                  return 'パスワードが一致しません';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: hasAcceptedTerms,
              onChanged: isAuthenticating ? null : onAcceptedTermsChanged,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                '利用規約とプライバシーポリシーに同意する',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            _LegalNotice(onTermsTap: onTermsTap, onPrivacyTap: onPrivacyTap),
          ],
          if (isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isAuthenticating ? null : onForgotPassword,
                child: const Text('パスワードを忘れた場合'),
              ),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: isAuthenticating ? null : onSubmit,
            icon: isAuthenticating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(isLogin
                    ? Icons.login_rounded
                    : Icons.person_add_alt_rounded),
            label: Text(isAuthenticating
                ? '処理中…'
                : isLogin
                    ? 'ログイン'
                    : 'アカウントを作成'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: isAuthenticating ? null : onToggleMode,
            child: Text(isLogin ? '新しくアカウントを作成' : 'すでにアカウントをお持ちの方'),
          ),
        ],
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.style,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final _ProviderButtonStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: style == _ProviderButtonStyle.standard
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
            )
          : FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: style == _ProviderButtonStyle.google
                    ? Colors.white
                    : Colors.black,
                foregroundColor: style == _ProviderButtonStyle.google
                    ? const Color(0xFF1F2D3D)
                    : Colors.white,
                side: style == _ProviderButtonStyle.google
                    ? const BorderSide(color: Color(0xFF747775))
                    : BorderSide.none,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
            ),
    );
  }
}

enum _ProviderButtonStyle { google, apple, standard }

class _LegalNotice extends StatelessWidget {
  const _LegalNotice({required this.onTermsTap, required this.onPrivacyTap});

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('続けることで、', style: TextStyle(fontSize: 11)),
        TextButton(
          onPressed: onTermsTap,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('利用規約', style: TextStyle(fontSize: 11)),
        ),
        const Text('と', style: TextStyle(fontSize: 11)),
        TextButton(
          onPressed: onPrivacyTap,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('プライバシーポリシー', style: TextStyle(fontSize: 11)),
        ),
        const Text('に同意したものとします。', style: TextStyle(fontSize: 11)),
      ],
    );
  }
}
