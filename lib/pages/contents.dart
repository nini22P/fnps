import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/utils/request_storage_permission.dart';
import 'package:fnps/widgets/custom_badge.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:fnps/globals.dart' as globals;
import 'package:fnps/hive/hive_box_names.dart';
import 'package:fnps/models/config.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/pages/content_page/content_page.dart';
import 'package:fnps/provider/config_provider.dart';
import 'package:fnps/utils/content_info.dart';
import 'package:fnps/utils/file_size_convert.dart';
import 'package:fnps/utils/get_localizations.dart';

class Contents extends HookWidget {
  const Contents({
    super.key,
    required this.categories,
    required this.navigateToPage,
  });

  final List<Category> categories;
  final void Function(int index) navigateToPage;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    final configProvider = Provider.of<ConfigProvider>(context);
    Config config = configProvider.config;
    final selectedRegions = config.regions;
    final sortBy = config.sortBy;
    final sortOrder = config.sortOrder;

    final psvBox = Hive.box<Content>(psvBoxName);
    final pspBox = Hive.box<Content>(pspBoxName);
    final psmBox = Hive.box<Content>(psmBoxName);
    final psxBox = Hive.box<Content>(psxBoxName);
    final ps3Box = Hive.box<Content>(ps3BoxName);

    final contents = useMemoized(() => [
          ...psvBox.values,
          ...pspBox.values,
          ...psmBox.values,
          ...psxBox.values,
          ...ps3Box.values
        ].where((content) => categories.contains(content.category)).toList());

    final filteredContents = useState(<Content>[]);
    final sortedContents = useState(<Content>[]);
    final searchText = useState('');
    final regions = Config.initConfig.regions;

    final focusNode = useFocusNode();
    final searchTextController = useTextEditingController();

    useEffect(() {
      filteredContents.value = contents
          .where((content) =>
              (content.name
                      .toLowerCase()
                      .contains(searchText.value.toLowerCase()) ||
                  '${content.contentID}'
                      .toLowerCase()
                      .contains(searchText.value.toLowerCase()) ||
                  '${content.originalName}'
                      .toLowerCase()
                      .contains(searchText.value.toLowerCase())) &&
              selectedRegions.contains(content.region) &&
              content.titleID.isNotEmpty)
          .toList();
      return;
    }, [searchText.value, selectedRegions, contents]);

    useEffect(() {
      List<Content> contents = [...filteredContents.value]..sort((a, b) {
          switch (sortBy) {
            case SortBy.titleID:
              return a.titleID.compareTo(b.titleID);
            case SortBy.name:
              return a.name.compareTo(b.name);
            case SortBy.lastModificationDate:
              return (a.lastModificationDate ?? '')
                  .compareTo(b.lastModificationDate ?? '');
          }
        });
      sortedContents.value =
          sortOrder == SortOrder.asc ? contents : contents.reversed.toList();
      return;
    }, [filteredContents.value, sortBy, sortOrder]);

    void clearSearchText() {
      searchTextController.clear();
      searchText.value = '';
      focusNode.unfocus();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final refreshValue = useState(0);
    refresh() => refreshValue.value++;

    return Scaffold(
      key: ValueKey(refreshValue.value),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('FNPS'),
            const SizedBox(width: 8),
            Expanded(
              flex: isMobile ? 1 : 0,
              child: SizedBox(
                width: 300,
                height: 40,
                child: TextField(
                  style: const TextStyle(height: 1),
                  controller: searchTextController,
                  focusNode: focusNode,
                  onChanged: (value) => searchText.value = value,
                  decoration: InputDecoration(
                    labelText: t.serach,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (searchText.value.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: clearSearchText,
                          ),
                        PopupMenuButton<String>(
                            icon: const Icon(Icons.filter_list),
                            onOpened: () => focusNode.unfocus(),
                            itemBuilder: (BuildContext context) => [
                                  ...regions.map(
                                    (Region region) => CheckedPopupMenuItem(
                                      checked: selectedRegions.contains(region),
                                      child: Text(region.name.toUpperCase()),
                                      onTap: () {
                                        focusNode.unfocus();
                                        if (selectedRegions.contains(region)) {
                                          configProvider.updateConfig(
                                              config.copyWith(
                                                  regions: selectedRegions
                                                      .where((element) =>
                                                          element != region)
                                                      .toList()));
                                        } else {
                                          configProvider
                                              .updateConfig(config.copyWith(
                                            regions: [
                                              ...selectedRegions,
                                              region
                                            ],
                                          ));
                                        }
                                      },
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  PopupMenuItem(
                                    child: ListTile(
                                      mouseCursor: SystemMouseCursors.click,
                                      title: Text(t.name),
                                      trailing: sortBy == SortBy.name
                                          ? Icon(sortOrder == SortOrder.asc
                                              ? Icons.arrow_upward_rounded
                                              : Icons.arrow_downward_rounded)
                                          : null,
                                    ),
                                    onTap: () => configProvider.updateConfig(
                                      config.copyWith(
                                          sortBy: SortBy.name,
                                          sortOrder:
                                              sortOrder == SortOrder.desc ||
                                                      sortBy != SortBy.name
                                                  ? SortOrder.asc
                                                  : SortOrder.desc),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    child: ListTile(
                                      mouseCursor: SystemMouseCursors.click,
                                      title: Text(t.title_id),
                                      trailing: sortBy == SortBy.titleID
                                          ? Icon(sortOrder == SortOrder.asc
                                              ? Icons.arrow_upward_rounded
                                              : Icons.arrow_downward_rounded)
                                          : null,
                                    ),
                                    onTap: () => configProvider.updateConfig(
                                      config.copyWith(
                                          sortBy: SortBy.titleID,
                                          sortOrder:
                                              sortOrder == SortOrder.desc ||
                                                      sortBy != SortBy.titleID
                                                  ? SortOrder.asc
                                                  : SortOrder.desc),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    child: ListTile(
                                      mouseCursor: SystemMouseCursors.click,
                                      title: Text(t.last_modification_date),
                                      trailing: sortBy ==
                                              SortBy.lastModificationDate
                                          ? Icon(sortOrder == SortOrder.asc
                                              ? Icons.arrow_upward_rounded
                                              : Icons.arrow_downward_rounded)
                                          : null,
                                    ),
                                    onTap: () => configProvider.updateConfig(
                                      config.copyWith(
                                          sortBy: SortBy.lastModificationDate,
                                          sortOrder: sortOrder ==
                                                      SortOrder.asc ||
                                                  sortBy !=
                                                      SortBy
                                                          .lastModificationDate
                                              ? SortOrder.desc
                                              : SortOrder.asc),
                                    ),
                                  ),
                                ]),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        forceMaterialTransparency: true,
      ),
      body: contents.isEmpty ||
              globals.storagePermissionStatus != PermissionStatus.granted
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (globals.storagePermissionStatus !=
                      PermissionStatus.granted)
                    ElevatedButton(
                      onPressed: () async {
                        await requestStoragePermission();
                        refresh();
                      },
                      child: Text(t.grant_storage_permission),
                    ),
                  if (globals.storagePermissionStatus !=
                      PermissionStatus.granted)
                    const SizedBox(height: 16),
                  if (contents.isEmpty)
                    ElevatedButton(
                      onPressed: () => navigateToPage(3),
                      child: Text(t.sync_or_add_content_list),
                    )
                ],
              ),
            )
          : ListView.builder(
              key: PageStorageKey(searchText.value),
              itemCount: sortedContents.value.length,
              itemBuilder: (context, index) {
                final content = sortedContents.value[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CachedNetworkImage(
                        imageUrl: getContentIcon(content, size: 96) ?? '',
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const SizedBox(
                          child: Center(child: Icon(Icons.gamepad)),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.gamepad),
                      ),
                    ),
                  ),
                  title: Text(content.name),
                  subtitle: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (content.region != null)
                        CustomBadge(text: content.region!.name, primary: true),
                      CustomBadge(text: content.platform.name),
                      CustomBadge(text: content.category.name),
                      CustomBadge(text: content.titleID),
                      if (content.fileSize != null && content.fileSize != 0)
                        CustomBadge(text: fileSizeConv(content.fileSize)!),
                    ],
                  ),
                  onTap: () {
                    focusNode.unfocus();
                    Navigator.pushNamed(context, '/content',
                        arguments: ContentPageProps(content: content));
                  },
                );
              },
            ),
    );
  }
}
