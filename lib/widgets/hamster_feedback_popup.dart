import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum HamsterFeedbackTone { success, info, warning, error }

/// A brief, non-blocking response card that matches Ham Care's glassy world.
/// It deliberately avoids the platform SnackBar location at the bottom edge.
class HamsterFeedbackPopup {
  static OverlayEntry? _activeEntry;

  static void show(
    BuildContext context, {
    required String message,
    HamsterFeedbackTone tone = HamsterFeedbackTone.success,
  }) {
    _activeEntry?.remove();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _HamsterFeedbackPopupCard(
        message: message,
        tone: tone,
        onDismissed: () {
          if (_activeEntry == entry) _activeEntry = null;
          entry.remove();
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }
}

class _HamsterFeedbackPopupCard extends StatefulWidget {
  final String message;
  final HamsterFeedbackTone tone;
  final VoidCallback onDismissed;

  const _HamsterFeedbackPopupCard({
    required this.message,
    required this.tone,
    required this.onDismissed,
  });

  @override
  State<_HamsterFeedbackPopupCard> createState() =>
      _HamsterFeedbackPopupCardState();
}

class _HamsterFeedbackPopupCardState extends State<_HamsterFeedbackPopupCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 210),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _dismissTimer = Timer(const Duration(seconds: 3), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // A lantern-like glass surface: the gentle warm light is concentrated at
    // the centre and fades toward the perimeter, allowing the page behind it
    // to remain clearly visible. There is intentionally no star icon.
    final centerGlow =
        isDark ? const Color(0x36FFE4A0) : const Color(0x30FFE7A1);
    final edgeGlass =
        isDark ? const Color(0x0CF5CF72) : const Color(0x08FFF1B8);
    final borderColor =
        isDark ? const Color(0x8CF8D989) : const Color(0x84D7A73B);
    final textColor = isDark ? Colors.white : AppTheme.lightText;

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: const Alignment(0, -0.30),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 17,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.92,
                            colors: [centerGlow, edgeGlass],
                            stops: const [0, 1],
                          ),
                          border: Border.all(color: borderColor, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD36A).withValues(
                                alpha: isDark ? 0.13 : 0.08,
                              ),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                    height: 1.45,
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
