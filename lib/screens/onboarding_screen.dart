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
      title: 'うちの子専属の\n飼育アドバイザー',
      body: '温湿度・活動量・今日の様子をもとに、毎日の飼育をサポートします。',
      imagePath: 'assets/images/roiroi.png',
      icon: Icons.pets_rounded,
    ),
    _OnboardingPageData(
      title: '感覚ではなく\nデータで見守る',
      body: 'SwitchBotの温湿度、回し車の走行距離、毎日の様子をまとめて確認できます。',
      imagePath: 'assets/images/chat.png',
      icon: Icons.show_chart_rounded,
    ),
    _OnboardingPageData(
      title: '小さな変化に\n早く気づく',
      body: '高湿の継続、活動量の低下など、見逃しやすい変化を知らせます。',
      imagePath: 'assets/images/roi.png',
      icon: Icons.notifications_active_rounded,
    ),
    _OnboardingPageData(
      title: '迷ったら\nそのまま相談',
      body: '今の飼育環境や記録を踏まえて、AIに相談できます。',
      imagePath: 'assets/images/chat.png',
      icon: Icons.smart_toy_rounded,
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
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Hamster Well-being',
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
                      _isLastPage ? '初期設定をはじめる' : '次へ',
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
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface(context),
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
                children: [
                  Positioned(
                    right: -42,
                    top: -42,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: isDark ? 0.08 : 0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -36,
                    bottom: -48,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: isDark ? 0.05 : 0.045),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      _OnboardingImageBadge(
                        imagePath: data.imagePath,
                        icon: data.icon,
                      ),
                      const SizedBox(height: 28),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
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
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          data.body,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    height: 1.65,
                                    color: AppTheme.secondaryText(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(
                              alpha: isDark ? 0.12 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: accent.withValues(
                                alpha: isDark ? 0.20 : 0.16,
                              ),
                            ),
                          ),
                          child: Text(
                            'Step ${pageIndex + 1} / 4',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _OnboardingImageBadge extends StatelessWidget {
  final String imagePath;
  final IconData icon;

  const _OnboardingImageBadge({
    required this.imagePath,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 188,
          height: 188,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF31456F),
                      Color(0xFF1F2438),
                    ]
                  : const [
                      Color(0xFFEAF1FF),
                      Color(0xFFFFFFFF),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: isDark ? 0.22 : 0.14),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accent,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
      ],
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String body;
  final String imagePath;
  final IconData icon;

  const _OnboardingPageData({
    required this.title,
    required this.body,
    required this.imagePath,
    required this.icon,
  });
}
