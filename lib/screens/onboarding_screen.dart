import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingScreen({
    super.key,
    required this.onFinished,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      title: '小さな変化を\n見逃さない',
      body: '毎日の様子と飼育環境をまとめて見て、いつもとの違いに気づけます。',
      imagePath: 'assets/images/onboarding/detect_small_changes_portrait.png',
    ),
    _OnboardingPageData(
      title: 'うちの子に合わせて\n見守る',
      body: '種類・年齢・飼育環境をもとに、その子のための見守り基準を作れます。',
      imagePath: 'assets/images/onboarding/personalized_care_portrait.png',
    ),
    _OnboardingPageData(
      title: '迷ったら\nすぐ相談できる',
      body: '記録した情報を踏まえて、今確認したいことをAIと整理できます。',
      imagePath: 'assets/images/onboarding/ai_consultation_portrait.png',
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_isLastPage) {
      widget.onFinished();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skip() async {
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF07080C),
                    Color(0xFF11141C),
                  ],
                )
              : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Ham Care',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryText(context),
                          ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        'スキップ',
                        style: TextStyle(
                          color: AppTheme.secondaryText(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _OnboardingPage(
                        data: _pages[index],
                        pageIndex: index,
                        active: index == _currentPage,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SmoothPageIndicator(
                  controller: _pageController,
                  count: _pages.length,
                  effect: ExpandingDotsEffect(
                    activeDotColor: AppTheme.accent,
                    dotColor: AppTheme.isDark(context)
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.14),
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 3.2,
                    spacing: 8,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _goNext,
                    icon: Icon(
                      _isLastPage
                          ? Icons.check_circle_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(
                      _isLastPage ? '見守りを始める' : '次へ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  final int pageIndex;
  final bool active;

  const _OnboardingPage({
    required this.data,
    required this.pageIndex,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final accent = AppTheme.accent;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 360),
      opacity: active ? 1.0 : 0.45,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        offset: active ? Offset.zero : const Offset(0.04, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight =
                constraints.maxHeight < 486 ? constraints.maxHeight : 486.0;

            return Column(
              children: [
                const Spacer(),
                Container(
                  width: double.infinity,
                  height: cardHeight,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.20 : 0.14),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(data.imagePath, fit: BoxFit.cover),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),
                            Text(
                              data.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    height: 1.08,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8,
                                    color: AppTheme.primaryText(context),
                                  ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              data.body,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    height: 1.65,
                                    color: AppTheme.secondaryText(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                  alpha: isDark ? 0.16 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: accent.withValues(
                                    alpha: isDark ? 0.32 : 0.20,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Step ${pageIndex + 1} / 3',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String body;
  final String imagePath;

  const _OnboardingPageData({
    required this.title,
    required this.body,
    required this.imagePath,
  });
}
