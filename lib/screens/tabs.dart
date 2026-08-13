import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hamster_project/screens/pet_profile_screen.dart';
import 'package:hamster_project/screens/search_function.dart';
import 'package:hamster_project/screens/graph_function.dart';
import 'package:hamster_project/screens/home.dart';
import 'package:hamster_project/screens/settings.dart';
import 'package:hamster_project/screens/record_screen.dart';
import 'package:hamster_project/services/daily_record_completion_service.dart';
import 'package:hamster_project/services/app_analytics.dart';
import 'package:hamster_project/models/daily_record_completion.dart';
import 'package:hamster_project/widgets/main_drawer.dart';
import 'package:hamster_project/widgets/paid_feature_gate.dart';
import 'package:hamster_project/widgets/floating_bottom_navigation.dart';
import 'package:hamster_project/widgets/quick_record_sheet.dart';
import 'package:hamster_project/widgets/screen_edge_fade.dart';
import 'package:hamster_project/widgets/app_habitat_background.dart';
import 'package:hamster_project/theme/app_theme.dart';

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key});

  @override
  State<TabsScreen> createState() => TabsScreenState();
}

class TabsScreenState extends State<TabsScreen> {
  int selectedIndex = 0;
  late final List<Widget> _pages;

  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<FuncSearchScreenState> _searchKey =
      GlobalKey<FuncSearchScreenState>();

  final DailyRecordCompletionService _recordCompletionService =
      DailyRecordCompletionService();
  final ValueNotifier<DailyRecordCompletion?> _recordCompletionNotifier =
      ValueNotifier<DailyRecordCompletion?>(null);

  StreamSubscription<DailyRecordCompletion>? _recordCompletionSubscription;

  Future<void> openHomeAnomalyCard() async {
    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);

    await Future<void>.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    setState(() {
      selectedIndex = 0;
    });

    await Future<void>.delayed(const Duration(milliseconds: 450));

    await _homeKey.currentState?.focusAnomalyCard();
  }

  Future<void> openAiWithDraft(String draftText) async {
    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);

    setState(() {
      selectedIndex = 1;
    });

    await Future<void>.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    _searchKey.currentState?.setDraftText(draftText);
  }

  @override
  void initState() {
    super.initState();

    _recordCompletionSubscription = _recordCompletionService.watch().listen(
      (completion) {
        _recordCompletionNotifier.value = completion;
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Daily record completion watch failed: $error');
      },
    );

    _pages = [
      HomeScreen(
        key: _homeKey,
        recordCompletionListenable: _recordCompletionNotifier,
        onTabSelected: _onTabSelected,
        onOpenAiWithDraft: openAiWithDraft,
        onOpenRecord: _openRecordScreen,
      ),
      PaidFeatureGate(
        featureName: 'AI相談',
        lockedTitle: 'AI相談は有料プランの機能です',
        lockedMessage: 'ペットプロフィール、飼育環境、温湿度データを踏まえたAI相談は、有料プランで利用できます。',
        showBackground: false,
        child: FuncSearchScreen(key: _searchKey),
      ),
      const PaidFeatureGate(
        featureName: '変化',
        lockedTitle: '変化の確認は有料プランの機能です',
        lockedMessage: '走行距離、温湿度、環境評価の推移を確認する機能は、有料プランで利用できます。',
        icon: Icons.insights_rounded,
        showBackground: false,
        child: GraphFunctionScreen(embeddedInTab: true),
      ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(AppAnalytics.logHomeView(source: 'app_start'));
    });
  }

  Widget _buildRecordDestination() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('記録'),
        centerTitle: true,
      ),
      body: const PaidFeatureGate(
        featureName: '記録',
        lockedTitle: '記録は有料プランの機能です',
        lockedMessage: '走行距離の記録、今日の様子、活動量評価に使う記録機能は、有料プランで利用できます。',
        icon: Icons.edit_note_rounded,
        showBackground: false,
        child: RecordScreen(),
      ),
    );
  }

  Future<void> _openRecordScreen() async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _buildRecordDestination(),
      ),
    );
  }

  Future<void> _showQuickRecordSheet() async {
    if (!mounted) return;

    final result = await showModalBottomSheet<QuickRecordSheetResult>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.50),
      builder: (context) => const QuickRecordSheet(),
    );

    if (!mounted) return;

    if (result == QuickRecordSheetResult.openAllRecords) {
      await _openRecordScreen();
    }
  }

  void _onTabSelected(int index) {
    if (index == selectedIndex) return;

    setState(() {
      selectedIndex = index;
    });

    if (index == 0) {
      unawaited(AppAnalytics.logHomeView(source: 'bottom_navigation'));
    }
  }

  void _setScreen(String identifier) {
    Navigator.of(context).pop();

    late final Widget screen;

    switch (identifier) {
      case 'record':
        screen = _buildRecordDestination();
        break;
      case 'settings':
        screen = const SettingScreen();
        break;
      case 'pets_profile':
        screen = const PetProfileScreen();
        break;
      default:
        return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  void dispose() {
    _recordCompletionSubscription?.cancel();
    _recordCompletionNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final appBarForeground = AppTheme.overlayAppBarForeground(context);

    const titles = [
      '今日',
      '相談',
      '変化',
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          titles[selectedIndex],
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: appBarForeground,
                fontWeight: FontWeight.w800,
              ),
        ),
        centerTitle: true,
        actions: selectedIndex == 1
            ? [
                IconButton(
                  tooltip: '相談履歴',
                  onPressed: () {
                    _searchKey.currentState?.openChatHistory();
                  },
                  icon: const Icon(Icons.history_rounded),
                ),
                IconButton(
                  tooltip: '新しく相談',
                  onPressed: () {
                    _searchKey.currentState?.requestStartNewChat();
                  },
                  icon: const Icon(Icons.add_comment_rounded),
                ),
                const SizedBox(width: 4),
              ]
            : null,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        foregroundColor: appBarForeground,
        iconTheme: IconThemeData(
          color: appBarForeground,
        ),
        actionsIconTheme: IconThemeData(
          color: appBarForeground,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      drawer: MainDrawer(
        onSelectScreen: _setScreen,
        recordCompletionListenable: _recordCompletionNotifier,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppHabitatBackground(
            child: SafeArea(
              top: false,
              child: _pages[selectedIndex],
            ),
          ),
          Positioned.fill(
            child: ScreenEdgeFade(
              showBottom: !keyboardVisible,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: keyboardVisible,
              child: AnimatedSlide(
                offset: keyboardVisible ? const Offset(0, 1.35) : Offset.zero,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: keyboardVisible ? 0 : 1,
                  duration: const Duration(milliseconds: 140),
                  child: ValueListenableBuilder<DailyRecordCompletion?>(
                    valueListenable: _recordCompletionNotifier,
                    builder: (context, completion, _) {
                      return FloatingBottomNavigation(
                        currentIndex: selectedIndex,
                        onTabSelected: _onTabSelected,
                        onQuickRecord: _showQuickRecordSheet,
                        highlightQuickRecord:
                            completion?.shouldShowPrompt == true,
                      );
                    },
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
