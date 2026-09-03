import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'daily_condition_input_card.dart';
import 'paid_feature_gate.dart';
import 'weight_input_card.dart';
import 'wheel_rotation_input_card.dart';

enum QuickRecordSheetResult {
  openAllRecords,
}

enum _QuickRecordCategory {
  wheel,
  condition,
  weight,
}

class QuickRecordSheet extends StatefulWidget {
  const QuickRecordSheet({super.key});

  @override
  State<QuickRecordSheet> createState() => _QuickRecordSheetState();
}

class _QuickRecordSheetState extends State<QuickRecordSheet> {
  _QuickRecordCategory? _selectedCategory;

  String get _title {
    switch (_selectedCategory) {
      case _QuickRecordCategory.wheel:
        return '走った記録';
      case _QuickRecordCategory.condition:
        return '今日の様子';
      case _QuickRecordCategory.weight:
        return '体重';
      case null:
        return 'クイック記録';
    }
  }

  String get _subtitle {
    switch (_selectedCategory) {
      case _QuickRecordCategory.wheel:
        return '昨晩から今朝までの回転数を記録します';
      case _QuickRecordCategory.condition:
        return '食欲や動きなど、今日の様子を残します';
      case _QuickRecordCategory.weight:
        return '測定した体重とメモを記録します';
      case null:
        return '記録したい項目を選んでください';
    }
  }

  void _selectCategory(_QuickRecordCategory category) {
    HapticFeedback.selectionClick();
    setState(() => _selectedCategory = category);
  }

  void _backToCategories() {
    FocusScope.of(context).unfocus();
    setState(() => _selectedCategory = null);
  }

  void _openAllRecords() {
    Navigator.of(context).pop(QuickRecordSheetResult.openAllRecords);
  }

  void _savedFeedback() {
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom;
    final maximumSheetHeight = math.min(
      760.0,
      math.max(360.0, availableHeight * 0.88),
    );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maximumSheetHeight,
          ),
          child: Material(
            color: Colors.transparent,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.quickRecordSheetSurface(context),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.softBorder(context),
                    ),
                  ),
                  boxShadow: AppTheme.floatingNavigationShadows(context),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.tertiaryText(context),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SheetHeader(
                        title: _title,
                        subtitle: _subtitle,
                        showBack: _selectedCategory != null,
                        onBack: _backToCategories,
                        onClose: () => Navigator.of(context).pop(),
                      ),
                      Divider(
                        height: 1,
                        color: AppTheme.softBorder(context),
                      ),
                      Flexible(
                        fit: FlexFit.loose,
                        child: PaidFeatureGate(
                          featureName: '記録',
                          lockedTitle: 'クイック記録は有料プランの機能です',
                          lockedMessage:
                              '走った記録、今日の様子、体重をすばやく入力する機能は、有料プランで利用できます。',
                          icon: Icons.add_circle_outline_rounded,
                          showBackground: false,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _selectedCategory == null
                                ? _CategorySelection(
                                    key: const ValueKey('categories'),
                                    onSelect: _selectCategory,
                                    onOpenAllRecords: _openAllRecords,
                                  )
                                : _SelectedRecordForm(
                                    key: ValueKey(_selectedCategory),
                                    category: _selectedCategory!,
                                    onSaved: _savedFeedback,
                                  ),
                          ),
                        ),
                      ),
                    ],
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

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.subtitle,
    required this.showBack,
    required this.onBack,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: showBack
                ? IconButton(
                    tooltip: '項目一覧へ戻る',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : null,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.secondaryText(context),
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: IconButton(
              tooltip: '閉じる',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySelection extends StatelessWidget {
  const _CategorySelection({
    super.key,
    required this.onSelect,
    required this.onOpenAllRecords,
  });

  final ValueChanged<_QuickRecordCategory> onSelect;
  final VoidCallback onOpenAllRecords;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuickRecordCategoryTile(
            icon: Icons.directions_run_rounded,
            title: '走った記録',
            subtitle: '昨晩〜今朝の回転数・走行距離',
            accent: AppTheme.accent,
            onTap: () => onSelect(_QuickRecordCategory.wheel),
          ),
          const SizedBox(height: 12),
          _QuickRecordCategoryTile(
            icon: Icons.favorite_border_rounded,
            title: '今日の様子',
            subtitle: '食欲・うんち・動き・気になること',
            accent: AppTheme.envGood,
            onTap: () => onSelect(_QuickRecordCategory.condition),
          ),
          const SizedBox(height: 12),
          _QuickRecordCategoryTile(
            icon: Icons.monitor_weight_outlined,
            title: '体重',
            subtitle: '定期的な体重と前回からの変化',
            accent: AppTheme.envCaution,
            onTap: () => onSelect(_QuickRecordCategory.weight),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: onOpenAllRecords,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('すべての記録を開く'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickRecordCategoryTile extends StatelessWidget {
  const _QuickRecordCategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardSurface(context),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accent.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.chipFill(
                    accent,
                    context,
                    opacity: AppTheme.isDark(context) ? 0.15 : 0.11,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.secondaryText(context),
                            height: 1.35,
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

class _SelectedRecordForm extends StatelessWidget {
  const _SelectedRecordForm({
    super.key,
    required this.category,
    required this.onSaved,
  });

  final _QuickRecordCategory category;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      child: switch (category) {
        _QuickRecordCategory.wheel => WheelRotationInputCard(
            compact: true,
            title: '昨日の走った記録',
            subtitle: '昨晩〜今朝の回転数を入れると、活動量評価に反映されます。',
            onSaved: ({
              required DateTime date,
              required int rotations,
              double? distanceMeters,
            }) {
              onSaved();
            },
          ),
        _QuickRecordCategory.condition => DailyConditionInputCard(
            onSaved: onSaved,
          ),
        _QuickRecordCategory.weight => WeightInputCard(
            onSaved: (_) => onSaved(),
          ),
      },
    );
  }
}
