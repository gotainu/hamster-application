import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hamster_project/screens/pet_profile_screen.dart';
import 'package:hamster_project/screens/search_function.dart';
import 'package:hamster_project/screens/graph_function.dart';
import 'package:hamster_project/screens/home.dart';
import 'package:hamster_project/screens/settings.dart';
import 'package:hamster_project/screens/record_screen.dart';
import 'package:hamster_project/screens/star_collection.dart';
import 'package:hamster_project/screens/daily_status_detail.dart';
import 'package:hamster_project/services/daily_record_completion_service.dart';
import 'package:hamster_project/services/star_rewards_repo.dart';
import 'package:hamster_project/services/app_analytics.dart';
import 'package:hamster_project/models/daily_record_completion.dart';
import 'package:hamster_project/widgets/main_drawer.dart';
import 'package:hamster_project/widgets/paid_feature_gate.dart';
import 'package:hamster_project/widgets/floating_bottom_navigation.dart';
import 'package:hamster_project/widgets/quick_record_sheet.dart';
import 'package:hamster_project/widgets/screen_edge_fade.dart';
import 'package:hamster_project/widgets/app_habitat_background.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/models/feature_trial_access.dart';
import 'package:hamster_project/services/onboarding_state_repo.dart';
import 'package:hamster_project/screens/monitoring_introduction_screen.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key});

  @override
  State<TabsScreen> createState() => TabsScreenState();
}

class TabsScreenState extends State<TabsScreen> with WidgetsBindingObserver {
  int selectedIndex = 0;
  late final List<Widget> _pages;

  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<FuncSearchScreenState> _searchKey =
      GlobalKey<FuncSearchScreenState>();
  final GlobalKey _consultationTabKey = GlobalKey();

  final DailyRecordCompletionService _recordCompletionService =
      DailyRecordCompletionService();
  final StarRewardsRepo _starRewardsRepo = StarRewardsRepo();
  final ValueNotifier<DailyRecordCompletion?> _recordCompletionNotifier =
      ValueNotifier<DailyRecordCompletion?>(null);

  StreamSubscription<DailyRecordCompletion>? _recordCompletionSubscription;
  StreamSubscription<bool>? _fiftyMilestoneSubscription;
  bool _fiftyCelebrationScheduled = false;
  DateTime? _watchedRecordDay;
  Timer? _midnightRefreshTimer;
  final OnboardingStateRepo _onboardingRepo = OnboardingStateRepo();
  StreamSubscription<OnboardingState>? _onboardingSubscription;
  bool _homeAiCoachScheduled = false;

  void _scheduleMidnightRefresh() {
    _midnightRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _midnightRefreshTimer = Timer(
      nextDay.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (lifecycle == AppLifecycleState.resumed || lifecycle == null) {
          _watchCompletionForToday();
        }
      },
    );
  }

  void _watchCompletionForToday() {
    final today = DateTime.now();
    final normalized = DateTime(today.year, today.month, today.day);
    if (_watchedRecordDay == normalized) return;
    _watchedRecordDay = normalized;
    _recordCompletionSubscription?.cancel();
    _recordCompletionNotifier.value = null;
    _recordCompletionSubscription =
        _recordCompletionService.watch(referenceDate: normalized).listen(
      (completion) => _recordCompletionNotifier.value = completion,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Daily record completion watch failed: $error');
      },
    );
    unawaited(_claimOpenStar());
    _scheduleMidnightRefresh();
  }

  Future<void> _claimOpenStar() async {
    try {
      await _starRewardsRepo.claimDailyOpenStar();
    } catch (error) {
      debugPrint('Open star could not be claimed: $error');
    }
  }

  Future<void> _celebrateFiftyStars() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 620),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: const Icon(
                Icons.star_rounded,
                size: 84,
                color: Color(0xFFFFD782),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '星が合計50個貯まりました！',
              textAlign: TextAlign.center,
              style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('やった！'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    try {
      await _starRewardsRepo.acknowledgeFiftyStarMilestone();
    } catch (error) {
      debugPrint('Fifty-star celebration acknowledgement failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _watchCompletionForToday();
    }
  }

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

  Future<void> openHealthIncidentDetails({
    String? incidentId,
    String? domain,
  }) async {
    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      selectedIndex = 0;
    });

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyStatusDetailScreen(
          incidentId: incidentId,
          incidentDomain: domain,
        ),
        settings: RouteSettings(
          name: '/health-incident',
          arguments: {
            if (incidentId != null) 'incidentId': incidentId,
            if (domain != null) 'domain': domain,
          },
        ),
      ),
    );
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

  Future<void> _startHomeAiOnboarding() async {
    if (!mounted) return;
    setState(() => selectedIndex = 1);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _searchKey.currentState?.showInputCoach();
  }

  Future<void> _handleFirstAiConsultation() async {
    final state = await _onboardingRepo.fetchState();
    final isFirstAnswer = !state.firstAiConsultationCompleted;
    await _onboardingRepo.markFirstAiConsultationCompleted();
    if (!isFirstAnswer || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MonitoringIntroductionScreen()),
    );
  }

  Future<void> _showHomeAiCoach() async {
    if (!mounted) return;
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'consultation-tab',
          keyTarget: _consultationTabKey,
          shape: ShapeLightFocus.RRect,
          radius: 30,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: const _ConsultationTabCoachContent(),
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.78,
      textSkip: 'あとで',
      onFinish: _startHomeAiOnboarding,
    ).show(context: context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchCompletionForToday();
    _fiftyMilestoneSubscription =
        _starRewardsRepo.watchUnseenFiftyStarMilestone().listen(
      (unseen) {
        if (!unseen || _fiftyCelebrationScheduled) return;
        _fiftyCelebrationScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_celebrateFiftyStars());
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Fifty-star milestone watch failed: $error');
      },
    );

    _pages = [
      HomeScreen(
        key: _homeKey,
        recordCompletionListenable: _recordCompletionNotifier,
        onTabSelected: _onTabSelected,
        onOpenAiWithDraft: openAiWithDraft,
        onOpenQuickRecord: _showQuickRecordSheet,
      ),
      FuncSearchScreen(
        key: _searchKey,
        allowDuringOnboarding: true,
        onConsultationCompleted: _handleFirstAiConsultation,
      ),
      const PaidFeatureGate(
        featureName: '変化',
        lockedTitle: '5日間の無料体験が終わりました',
        lockedMessage: '変化の確認を続けるには、有料プランをご利用ください。',
        icon: Icons.insights_rounded,
        showBackground: false,
        trialFeature: TrialFeature.changes,
        child: GraphFunctionScreen(embeddedInTab: true),
      ),
    ];

    _onboardingSubscription = _onboardingRepo.watchState().listen((state) {
      if (!state.homeAiOnboardingPending || _homeAiCoachScheduled || !mounted) {
        return;
      }
      _homeAiCoachScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted && selectedIndex == 0) {
          await _showHomeAiCoach();
        }
      });
    });

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
        allowDuringOnboarding: true,
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
      barrierColor: Colors.black.withValues(alpha: 0.36),
      builder: (context) => QuickRecordSheet(
        completionListenable: _recordCompletionNotifier,
      ),
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
      case 'stars':
        screen = StarCollectionScreen(repo: _starRewardsRepo);
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
    WidgetsBinding.instance.removeObserver(this);
    _midnightRefreshTimer?.cancel();
    _recordCompletionSubscription?.cancel();
    _fiftyMilestoneSubscription?.cancel();
    _onboardingSubscription?.cancel();
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
                        consultationTargetKey: _consultationTabKey,
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

class _ConsultationTabCoachContent extends StatelessWidget {
  const _ConsultationTabCoachContent();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'さっそく、AIに相談してみましょう',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '「相談」を開いて、いま気になることを聞いてみましょう。',
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
          ],
        ),
      );
}
