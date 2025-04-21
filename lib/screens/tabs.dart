import 'package:flutter/material.dart';
import 'package:hamster_project/screens/pet_profile_screen.dart';
import 'package:hamster_project/widgets/main_drawer.dart';

// 他のタブで表示する画面もインポートするならここで行う
import 'package:hamster_project/screens/search_function.dart';
import 'package:hamster_project/screens/func_b.dart';
import 'package:hamster_project/screens/mypage_func.dart';
import 'package:hamster_project/screens/home.dart';
import 'package:hamster_project/screens/settings.dart';

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key});

  @override
  State<TabsScreen> createState() => TabsScreenState();
}

class TabsScreenState extends State<TabsScreen> {
  // 選択中のタブを管理するためのインデックス
  int selectedIndex = 0;

  // 表示したい画面をまとめたリスト
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // HomeScreen に onTabSelected コールバックを渡す
    _pages = [
      HomeScreen(
        onTabSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
      const FuncSearchScreen(),
      const FuncBScreen(),
      const FuncMyPageScreen(),
    ];
  }

  // タブアイコンをタップした時の処理
  void _onTabSelected(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  // Drawer から呼び出す各画面への遷移処理
  void _setScreen(String identifier) {
    // Drawer を閉じる
    Navigator.of(context).pop();

    if (identifier == 'settings') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (ctx) => const SettingScreen()),
      );
    } else if (identifier == 'pets_profile') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (ctx) => const PetProfileScreen()),
      );
    } else {
      // その他の場合は何もしない
    }
  }

  @override
  Widget build(BuildContext context) {
    // タブ毎のタイトル
    final titles = [
      'Home',
      'さがす',
      'FuncB',
      'マイページ',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[selectedIndex]),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: MainDrawer(
        onSelectScreen: _setScreen,
      ),
      body: _pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: _onTabSelected,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'さがす',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cake_sharp),
            label: 'FuncB',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            label: 'マイページ',
          ),
        ],
        selectedItemColor: const Color.fromARGB(255, 58, 102, 183),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
      ),
    );
  }
}
