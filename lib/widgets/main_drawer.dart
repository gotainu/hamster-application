import 'package:flutter/material.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key, required this.onSelectScreen});

  final void Function(String identifier) onSelectScreen;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // DrawerHeader → Container＋Stackで完全カスタム
          Container(
            height: 108,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.9),
                  Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.7),
                  Colors.transparent
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // ガラス風ぼかしのデコ
                Positioned(
                  right: 0,
                  top: 16,
                  child: Container(
                    width: 68,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.13),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
                // メインロゴ＋プロジェクト名
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pets, color: Colors.white, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Hamster Project',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.97),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.pets_outlined,
              size: 25,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            title: Text(
              'ペット飼育機能',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
            ),
            onTap: () {
              onSelectScreen('pets');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.pie_chart_outline_sharp,
              size: 25,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            title: Text(
              'ペットのプロフィール',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
            ),
            onTap: () {
              onSelectScreen('pets_profile');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.settings,
              size: 25,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            title: Text(
              'アプリの設定',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
            ),
            onTap: () {
              onSelectScreen('settings');
            },
          ),
        ],
      ),
    );
  }
}
