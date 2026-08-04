import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'shine_border.dart';

class FloatingBottomNavigation extends StatelessWidget {
  static const double contentClearance = 94;

  const FloatingBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onQuickRecord,
    this.highlightQuickRecord = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onQuickRecord;
  final bool highlightQuickRecord;

  static const _items = <_FloatingNavigationItemData>[
    _FloatingNavigationItemData(
      icon: Icons.home_rounded,
      label: '今日',
    ),
    _FloatingNavigationItemData(
      icon: Icons.smart_toy_rounded,
      label: '相談',
    ),
    _FloatingNavigationItemData(
      icon: Icons.insights_rounded,
      label: '変化',
    ),
  ];

  void _selectTab(int index) {
    if (index == currentIndex) return;
    HapticFeedback.selectionClick();
    onTabSelected(index);
  }

  void _openQuickRecord() {
    HapticFeedback.mediumImpact();
    onQuickRecord();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: SizedBox(
        height: 70,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _GlassNavigationCapsule(
                child: Row(
                  children: List.generate(
                    _items.length,
                    (index) => Expanded(
                      child: _FloatingNavigationItem(
                        data: _items[index],
                        selected: currentIndex == index,
                        onTap: () => _selectTab(index),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: highlightQuickRecord ? '未入力の記録があります。日々の記録を追加' : '日々の記録を追加',
              child: AnimatedShiningBorder(
                active: highlightQuickRecord,
                borderRadius: 999,
                borderWidth: 2.2,
                duration: const Duration(milliseconds: 2600),
                colors: [
                  AppTheme.accent.withValues(alpha: 0.40),
                  AppTheme.accent,
                  Colors.cyanAccent.withValues(alpha: 0.92),
                  Colors.white.withValues(alpha: 0.94),
                  AppTheme.accent,
                ],
                child: SizedBox.square(
                  dimension: 70,
                  child: Material(
                    type: MaterialType.transparency,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _openQuickRecord,
                      child: Ink(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.floatingRecordButtonSurface(context),
                          border: Border.all(
                            color: AppTheme.floatingNavigationBorder(context),
                          ),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 34,
                          color: AppTheme.primaryText(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassNavigationCapsule extends StatelessWidget {
  const _GlassNavigationCapsule({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppTheme.floatingNavigationShadows(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.floatingNavigationSurface(context),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppTheme.floatingNavigationBorder(context),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FloatingNavigationItem extends StatelessWidget {
  const _FloatingNavigationItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _FloatingNavigationItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? AppTheme.floatingNavigationSelected(context)
        : AppTheme.floatingNavigationUnselected(context);
    final labelColor = AppTheme.floatingNavigationLabel(context);

    return Semantics(
      selected: selected,
      button: true,
      label: data.label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.floatingNavigationSelectedFill(context),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  data.icon,
                  size: 24,
                  color: iconColor,
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavigationItemData {
  const _FloatingNavigationItemData({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}
