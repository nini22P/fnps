import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:vita_dl/pages/contents_list.dart';
import 'package:vita_dl/pages/downloads.dart';
import 'package:vita_dl/pages/settings.dart';
import 'package:vita_dl/utils/get_localizations.dart';

class HomePage extends HookWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final selectedIndex = useState(0);
    final pageController = usePageController();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: PageView(
        controller: pageController,
        onPageChanged: (index) {
          selectedIndex.value = index;
        },
        children: const [
          ContentsList(types: ['app']),
          ContentsList(types: ['theme']),
          Downloads(),
          Settings(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
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
            label: t.app,
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
