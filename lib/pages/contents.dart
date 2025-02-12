import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/config.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/pages/content_page/content_page.dart';
import 'package:vita_dl/provider/config_provider.dart';
import 'package:vita_dl/utils/file_size_convert.dart';
import 'package:vita_dl/utils/get_localizations.dart';

class Contents extends HookWidget {
  const Contents({
    super.key,
    required this.types,
  });

  final List<ContentType> types;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    final configProvider = Provider.of<ConfigProvider>(context);
    Config config = configProvider.config;
    final selectedRegions = config.regions;

    final appBox = Hive.box<Content>(appBoxName);
    final dlcBox = Hive.box<Content>(dlcBoxName);
    final themeBox = Hive.box<Content>(themeBoxName);

    final contents = useMemoized(() => [
          if (types.contains(ContentType.app)) ...appBox.values,
          if (types.contains(ContentType.dlc)) ...dlcBox.values,
          if (types.contains(ContentType.theme)) ...themeBox.values,
        ]);

    final filteredContents = useState(<Content>[]);
    final sortedContents = useState(<Content>[]);
    final searchText = useState('');
    final regions = ['JP', 'US', 'INT', 'EU', 'ASIA', 'UNKNOWN'];

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
              selectedRegions.contains(content.region))
          .toList();
      return;
    }, [searchText.value, selectedRegions, contents]);

    useEffect(() {
      sortedContents.value = [...filteredContents.value]
        ..sort((a, b) => a.name.compareTo(b.name));
      return;
    }, [filteredContents.value]);

    void clearSearchText() {
      searchTextController.clear();
      searchText.value = '';
      focusNode.unfocus();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
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
                  searchText.value.isEmpty
                      ? const SizedBox()
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: clearSearchText,
                        ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.filter_list),
                    onOpened: () => focusNode.unfocus(),
                    itemBuilder: (BuildContext context) => regions
                        .map(
                          (String region) => CheckedPopupMenuItem<String>(
                            value: region,
                            checked: selectedRegions.contains(region),
                            child: Text(region),
                            onTap: () {
                              focusNode.unfocus();
                              if (selectedRegions.contains(region)) {
                                configProvider.updateConfig(config.copyWith(
                                    regions: selectedRegions
                                        .where((element) => element != region)
                                        .toList()));
                              } else {
                                configProvider.updateConfig(config.copyWith(
                                    regions: [...selectedRegions, region]));
                              }
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: const BorderSide(color: Colors.grey),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: PageStorageKey(searchText.value),
            itemCount: sortedContents.value.length,
            itemBuilder: (context, index) {
              final content = sortedContents.value[index];
              return ListTile(
                title: Text(content.name),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (content.region != null)
                      Badge(
                        label: Text(content.region!.toUpperCase()),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                      ),
                    const SizedBox(width: 4),
                    Badge(
                      label: Text(content.titleID.toUpperCase()),
                      backgroundColor: Colors.blueGrey,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                    ),
                    const SizedBox(width: 4),
                    if (content.pkgDirectLink != null)
                      Badge(
                        label: content.fileSize == null
                            ? Text(t.unknown_size)
                            : Text('${fileSizeConv(content.fileSize)}'),
                        backgroundColor: Colors.blueGrey,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                      ),
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
        )
      ],
    );
  }
}
