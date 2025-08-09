import 'package:flutter/material.dart';
import 'package:hamster_project/screens/pet_profile_screen.dart';
import 'package:hamster_project/widgets/main_drawer.dart';
import 'package:hamster_project/screens/search_function.dart';
import 'package:hamster_project/screens/graph_function.dart';
import 'package:hamster_project/screens/mypage_function.dart';
import 'package:hamster_project/screens/home.dart';
import 'package:hamster_project/screens/settings.dart';
import 'package:hamster_project/theme/app_theme.dart';

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key});

  @override
  State<TabsScreen> createState() => TabsScreenState();
}

class TabsScreenState extends State<TabsScreen> {
  int selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(
        onTabSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
      const FuncSearchScreen(),
      const GraphFunctionScreen(),
      const FuncMyPageScreen(),
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
      'Home',
      'AIに相談',
      '走った記録',
      'マイページ',
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy),
            label: 'AIに相談',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cake_sharp),
            label: '走った記録',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            label: 'マイページ',
          ),
        ],
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.transparent, // グラデ背景を活かす
        elevation: 0,
      ),
    );
  }
}
