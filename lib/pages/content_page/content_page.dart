import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/pages/content_page/content_page_info.dart';
import 'package:vita_dl/pages/content_page/content_page_list.dart';
import 'package:vita_dl/utils/get_localizations.dart';

class ITab {
  final String title;
  final Widget child;

  const ITab({
    required this.title,
    required this.child,
  });
}

class ContentPage extends HookWidget {
  const ContentPage({super.key, required this.content});

  final Content content;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    List<ITab> tabs = [
      ITab(title: t.info, child: ContentPageInfo(content: content)),
      ITab(title: t.items, child: ContentPageList(content: content)),
    ];

    final tabController = useTabController(initialLength: tabs.length);

    return Scaffold(
      appBar: AppBar(
        title: Text('${content.name} [${content.titleID}]'),
        bottom: TabBar(
            controller: tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: tabs.map((e) => Tab(text: e.title)).toList()),
      ),
      body: TabBarView(
        controller: tabController,
        children: tabs.map((e) => e.child).toList(),
      ),
    );
  }
}
