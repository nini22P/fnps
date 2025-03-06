import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/pages/contents_filter.dart';
import 'package:fnps/pages/popup.dart';
import 'package:fnps/utils/platform.dart';
import 'package:fnps/utils/request_storage_permission.dart';
import 'package:fnps/widgets/custom_badge.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
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
    required this.navigateToPage,
  });

  final void Function(int index) navigateToPage;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    final configProvider = Provider.of<ConfigProvider>(context);
    Config config = configProvider.config;
    final regions = config.regions;
    final platforms = config.platforms;
    final categories = config.categories;
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
        ]);

    final focusNode = useFocusNode();
    final searchText = useState('');
    final searchTextController = useTextEditingController();

    final sortedContents = useState(<Content>[]);

    final filteredContents = useMemoized(
        () => contents
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
                regions.contains(content.region) &&
                platforms.contains(content.platform) &&
                categories.contains(content.category) &&
                content.titleID.isNotEmpty)
            .toList(),
        [contents, regions, platforms, categories, searchText.value]);

    useEffect(() {
      List<Content> contents = [...filteredContents]..sort((a, b) {
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
    }, [filteredContents, sortBy, sortOrder]);

    void clearSearchText() {
      searchTextController.clear();
      searchText.value = '';
      focusNode.unfocus();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final storagePermissionStatus =
        useState<PermissionStatus>(PermissionStatus.granted);

    useEffect(() {
      () async {
        storagePermissionStatus.value = isAndroid
            ? await isAndroid11OrHigher()
                ? await Permission.manageExternalStorage.status
                : await Permission.storage.status
            : PermissionStatus.granted;
      }();
      return null;
    }, []);

    return Scaffold(
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
                        IconButton(
                          icon: const Icon(Icons.filter_list),
                          onPressed: () => showPopup(
                            context: context,
                            child: const ContentsFilter(),
                          ),
                        )
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
              storagePermissionStatus.value != PermissionStatus.granted
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (storagePermissionStatus.value != PermissionStatus.granted)
                    ElevatedButton(
                      onPressed: () async {
                        storagePermissionStatus.value =
                            await requestStoragePermission();
                      },
                      child: Text(t.grant_storage_permission),
                    ),
                  if (storagePermissionStatus.value != PermissionStatus.granted)
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
                        errorListener: (_) {},
                      ),
                    ),
                  ),
                  title: Text(content.name),
                  subtitle: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      CustomBadge(text: content.platform.name, primary: true),
                      CustomBadge(text: content.category.name, tertiary: true),
                      if (content.region != null)
                        CustomBadge(text: content.region!.name),
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
