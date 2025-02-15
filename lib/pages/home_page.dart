import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/pages/contents.dart';
import 'package:fnps/pages/downloads.dart';
import 'package:fnps/pages/settings.dart';
import 'package:fnps/utils/get_localizations.dart';

class HomePage extends HookWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    final selectedIndex = useState(0);
    final pageController = usePageController();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    void navigateToPage(int index, {bool animate = false}) {
      animate
          ? pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            )
          : pageController.jumpToPage(index);
    }

    return Scaffold(
      body: Row(
        children: [
          if (!isMobile)
            NavigationRail(
              selectedIndex: selectedIndex.value,
              onDestinationSelected: (index) {
                selectedIndex.value = index;
                pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.apps),
                  label: Text(t.browse),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.palette),
                  label: Text(t.theme),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.download),
                  label: Text(t.download),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings),
                  label: Text(t.settings),
                ),
              ],
            ),
          if (!isMobile) const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: PageView(
              controller: pageController,
              onPageChanged: (index) {
                selectedIndex.value = index;
              },
              children: [
                Contents(
                  categories: const [Category.game],
                  navigateToPage: navigateToPage,
                ),
                Contents(
                  categories: const [Category.theme],
                  navigateToPage: navigateToPage,
                ),
                const Downloads(),
                const Settings(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isMobile
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: selectedIndex.value,
              onTap: (index) {
                selectedIndex.value = index;
                pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              items: <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: const Icon(Icons.apps),
                  label: t.browse,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.palette),
                  label: t.theme,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.download),
                  label: t.download,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.settings),
                  label: t.settings,
                ),
              ],
            ),
    );
  }
}
