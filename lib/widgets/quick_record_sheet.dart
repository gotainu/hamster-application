import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../models/daily_record_completion.dart';
import '../theme/app_theme.dart';
import 'daily_condition_input_card.dart';
import 'paid_feature_gate.dart';
import 'quick_record_reward.dart';
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
  final ValueListenable<DailyRecordCompletion?>? completionListenable;

  const QuickRecordSheet({super.key, this.completionListenable});

  @override
  State<QuickRecordSheet> createState() => _QuickRecordSheetState();
}

class _QuickRecordSheetState extends State<QuickRecordSheet> {
  _QuickRecordCategory? _selectedCategory;
  QuickRecordRewardData? _reward;

  String get _title {
    if (_reward != null) return '記録できました';
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

  void _selectCategory(_QuickRecordCategory category) {
    HapticFeedback.selectionClick();
    setState(() => _selectedCategory = category);
  }

  void _backToCategories() {
    FocusScope.of(context).unfocus();
    setState(() {
      _reward = null;
      _selectedCategory = null;
    });
  }

  void _openAllRecords() {
    Navigator.of(context).pop(QuickRecordSheetResult.openAllRecords);
  }

  void _savedFeedback(QuickRecordRewardData reward) {
    HapticFeedback.mediumImpact();
    setState(() => _reward = reward);
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
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.quickRecordSheetSurface(context),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: AppTheme.quickRecordSheetBorder(context),
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
                            showBack:
                                _selectedCategory != null && _reward == null,
                            onBack: _backToCategories,
                            onClose: () => Navigator.of(context).pop(),
                          ),
                          Divider(
                            height: 1,
                            color: AppTheme.quickRecordObjectBorder(context),
                          ),
                          Flexible(
                            fit: FlexFit.loose,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: _reward != null
                                  ? QuickRecordRewardView(
                                      key: ValueKey(_reward),
                                      reward: _reward!,
                                      completionListenable:
                                          widget.completionListenable,
                                      onContinue: _backToCategories,
                                      onClose: () =>
                                          Navigator.of(context).pop(),
                                    )
                                  : PaidFeatureGate(
                                      key: const ValueKey('record-form'),
                                      featureName: '記録',
                                      lockedTitle: 'クイック記録は有料プランの機能です',
                                      lockedMessage:
                                          '走った記録、今日の様子、体重をすばやく入力する機能は、有料プランで利用できます。',
                                      icon: Icons.add_circle_outline_rounded,
                                      showBackground: false,
                                      allowDuringOnboarding: true,
                                      child: _selectedCategory == null
                                          ? _CategorySelection(
                                              key: const ValueKey('categories'),
                                              onSelect: _selectCategory,
                                              onOpenAllRecords: _openAllRecords,
                                            )
                                          : _SelectedRecordForm(
                                              key: ValueKey(
                                                _selectedCategory,
                                              ),
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
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.onClose,
  });

  final String title;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
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
            accent: AppTheme.accent,
            onTap: () => onSelect(_QuickRecordCategory.wheel),
          ),
          const SizedBox(height: 12),
          _QuickRecordCategoryTile(
            icon: Icons.pets_rounded,
            title: '今日の様子',
            accent: AppTheme.envGood,
            useBrandMark: true,
            onTap: () => onSelect(_QuickRecordCategory.condition),
          ),
          const SizedBox(height: 12),
          _QuickRecordCategoryTile(
            icon: Icons.monitor_weight_outlined,
            title: '体重',
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
    required this.accent,
    required this.onTap,
    this.useBrandMark = false,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final VoidCallback onTap;
  final bool useBrandMark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.quickRecordObjectSurface(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.quickRecordObjectBorder(context),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: useBrandMark
                      ? Colors.black
                      : accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: useBrandMark
                        ? const Color(0xFFFFF1D1).withValues(alpha: 0.28)
                        : accent.withValues(alpha: 0.25),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: useBrandMark
                    ? Image.asset(
                        'store_assets/icons/google_play_icon_512.png',
                        fit: BoxFit.cover,
                      )
                    : Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
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
  final ValueChanged<QuickRecordRewardData> onSaved;

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
              onSaved(
                QuickRecordRewardData.activity(
                  rotations: rotations,
                  distanceMeters: distanceMeters,
                ),
              );
            },
          ),
        _QuickRecordCategory.condition => DailyConditionInputCard(
            onSaved: () => onSaved(QuickRecordRewardData.condition()),
          ),
        _QuickRecordCategory.weight => WeightInputCard(
            onSaved: (record) => onSaved(
              QuickRecordRewardData.weight(record.weightGrams),
            ),
          ),
      },
    );
  }
}
