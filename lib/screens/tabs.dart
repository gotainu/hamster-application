import 'package:flutter/material.dart';
import 'package:hamster_project/widgets/paid_feature_gate.dart';
import 'package:hamster_project/screens/pet_profile_screen.dart';
import 'package:hamster_project/widgets/main_drawer.dart';
import 'package:hamster_project/screens/search_function.dart';
import 'package:hamster_project/screens/graph_function.dart';
import 'package:hamster_project/screens/home.dart';
import 'package:hamster_project/screens/settings.dart';
import 'package:hamster_project/screens/record_screen.dart';
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
    _pages = [
      HomeScreen(
        key: _homeKey,
        onTabSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        onOpenAiWithDraft: openAiWithDraft,
      ),
      PaidFeatureGate(
        featureName: 'AI相談',
        lockedTitle: 'AI相談は有料プランの機能です',
        lockedMessage: 'ペットプロフィール、飼育環境、温湿度データを踏まえたAI相談は、有料プランで利用できます。',
        showBackground: false,
        child: FuncSearchScreen(key: _searchKey),
      ),
      const PaidFeatureGate(
        featureName: '記録',
        lockedTitle: '記録は有料プランの機能です',
        lockedMessage: '走行距離の記録、今日の様子、活動量評価に使う記録機能は、有料プランで利用できます。',
        icon: Icons.edit_note_rounded,
        showBackground: false,
        child: RecordScreen(),
      ),
      const PaidFeatureGate(
        featureName: '変化',
        lockedTitle: '変化の確認は有料プランの機能です',
        lockedMessage: '走行距離、温湿度、環境評価の推移を確認する機能は、有料プランで利用できます。',
        icon: Icons.insights_rounded,
        showBackground: false,
        child: GraphFunctionScreen(embeddedInTab: true),
      ),
      const SettingScreen(embeddedInTab: true),
    ];
  }

  void _onTabSelected(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  void _setScreen(String identifier) {
    Navigator.of(context).pop();
    if (identifier == 'settings') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (ctx) => const SettingScreen()),
      );
    } else if (identifier == 'pets_profile') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (ctx) => const PetProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titles = [
      '今日',
      '相談',
      '記録',
      '変化',
      '設定',
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          titles[selectedIndex],
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, // ← 背景を完全透明に
        elevation: 0,
        // flexibleSpaceは完全削除（グラデはbodyで行う！）
      ),
      drawer: MainDrawer(
        onSelectScreen: _setScreen,
      ),
      // ===== グラデ背景はbodyで統一！ =====
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          top: false, // AppBarの裏まで伸ばす
          child: _pages[selectedIndex],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: '今日',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_rounded),
            label: '相談',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_note_rounded),
            label: '記録',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_rounded),
            label: '変化',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: '設定',
          ),
        ],
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
