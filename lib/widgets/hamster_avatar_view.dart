import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/hamster_avatar.dart';
import '../theme/app_theme.dart';

class HamsterAvatarView extends StatefulWidget {
  final HamsterAvatarPresentation presentation;
  final double size;
  final bool showMessage;
  final bool showDebugLabel;
  final bool showBackdrop;
  final bool showCauseBadge;

  const HamsterAvatarView({
    super.key,
    required this.presentation,
    this.size = 156,
    this.showMessage = false,
    this.showDebugLabel = false,
    this.showBackdrop = true,
    this.showCauseBadge = false,
  });

  @override
  State<HamsterAvatarView> createState() => _HamsterAvatarViewState();
}

class _HamsterAvatarViewState extends State<HamsterAvatarView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breathingScale;
  int _assetIndex = 0;
  bool _fallbackScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _breathingScale = Tween<double>(begin: 0.985, end: 1.018).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant HamsterAvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(
      oldWidget.presentation.assetCandidates,
      widget.presentation.assetCandidates,
    )) {
      _assetIndex = 0;
      _fallbackScheduled = false;
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldAnimate =
        widget.presentation.animateBreathing && !disableAnimations;

    if (shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleNextAsset() {
    if (_fallbackScheduled) return;
    if (_assetIndex >= widget.presentation.assetCandidates.length - 1) return;

    _fallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _assetIndex += 1;
        _fallbackScheduled = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final presentation = widget.presentation;
    final accent = _conditionAccent(presentation.condition);
    final candidates = presentation.assetCandidates;
    final path = candidates[_assetIndex.clamp(0, candidates.length - 1)];

    final avatar = Semantics(
      label: presentation.message,
      image: true,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: widget.showBackdrop
            ? BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(
                      alpha: AppTheme.isDark(context) ? 0.24 : 0.16,
                    ),
                    AppTheme.cardSurface(context).withValues(alpha: 0.76),
                  ],
                ),
                border: Border.all(
                  color: accent.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              )
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(
                  widget.showBackdrop ? widget.size * 0.055 : 0,
                ),
                child: Image.asset(
                  path,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    _scheduleNextAsset();
                    return Icon(
                      Icons.pets_rounded,
                      size: widget.size * 0.42,
                      color: accent.withValues(alpha: 0.75),
                    );
                  },
                ),
              ),
            ),
            if (widget.showCauseBadge)
              Positioned(
                right: widget.size * 0.035,
                bottom: widget.size * 0.055,
                child: _CauseBadge(
                  cause: presentation.cause,
                  accent: accent,
                  size: widget.size * 0.25,
                ),
              ),
            if (widget.showDebugLabel && kDebugMode)
              Positioned(
                left: 4,
                right: 4,
                top: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    child: Text(
                      '${presentation.appearance.assetDirectory}/'
                      '${presentation.condition.assetKey}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final animatedAvatar = AnimatedBuilder(
      animation: _breathingScale,
      child: avatar,
      builder: (context, child) {
        return Transform.scale(
          scale: _breathingScale.value,
          child: child,
        );
      },
    );

    if (!widget.showMessage) return animatedAvatar;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        animatedAvatar,
        const SizedBox(height: 10),
        Text(
          presentation.message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.secondaryText(context),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
        ),
      ],
    );
  }

  Color _conditionAccent(HamsterAvatarCondition condition) {
    switch (condition) {
      case HamsterAvatarCondition.happy:
      case HamsterAvatarCondition.stable:
        return AppTheme.envGood;
      case HamsterAvatarCondition.worried:
      case HamsterAvatarCondition.environmentDiscomfort:
      case HamsterAvatarCondition.activityHigh:
        return AppTheme.envCaution;
      case HamsterAvatarCondition.alert:
      case HamsterAvatarCondition.conditionConcerned:
        return AppTheme.envDanger;
      case HamsterAvatarCondition.insufficientData:
        return const Color(0xFF8A94A6);
    }
  }
}

class _CauseBadge extends StatelessWidget {
  final HamsterAvatarCause cause;
  final Color accent;
  final double size;

  const _CauseBadge({
    required this.cause,
    required this.accent,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (cause == HamsterAvatarCause.none) {
      return const SizedBox.shrink();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.cardSurface(context),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        _iconForCause(cause),
        color: accent,
        size: size * 0.58,
      ),
    );
  }

  IconData _iconForCause(HamsterAvatarCause cause) {
    switch (cause) {
      case HamsterAvatarCause.heat:
        return Icons.device_thermostat_rounded;
      case HamsterAvatarCause.cold:
        return Icons.ac_unit_rounded;
      case HamsterAvatarCause.humidityHigh:
        return Icons.water_drop_rounded;
      case HamsterAvatarCause.humidityLow:
        return Icons.water_drop_outlined;
      case HamsterAvatarCause.activityHigh:
        return Icons.directions_run_rounded;
      case HamsterAvatarCause.activityLow:
        return Icons.bedtime_rounded;
      case HamsterAvatarCause.weightChanged:
        return Icons.monitor_weight_outlined;
      case HamsterAvatarCause.conditionConcern:
        return Icons.favorite_rounded;
      case HamsterAvatarCause.insufficientData:
        return Icons.question_mark_rounded;
      case HamsterAvatarCause.overallAlert:
        return Icons.priority_high_rounded;
      case HamsterAvatarCause.none:
        return Icons.pets_rounded;
    }
  }
}
