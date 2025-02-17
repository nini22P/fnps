import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/models/config.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/provider/config_provider.dart';
import 'package:fnps/utils/get_localizations.dart';
import 'package:provider/provider.dart';

class ContentsFilter extends HookWidget {
  const ContentsFilter({super.key});

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

    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<SortBy>(
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: [
              ButtonSegment<SortBy>(
                value: SortBy.name,
                label: Text(t.name),
                icon: sortBy == SortBy.name
                    ? Icon(sortOrder == SortOrder.asc
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : null,
              ),
              ButtonSegment<SortBy>(
                value: SortBy.titleID,
                label: Text(t.title_id),
                icon: sortBy == SortBy.titleID
                    ? Icon(sortOrder == SortOrder.asc
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : null,
              ),
              ButtonSegment<SortBy>(
                value: SortBy.lastModificationDate,
                label: Text(t.last_modification_date),
                icon: sortBy == SortBy.lastModificationDate
                    ? Icon(sortOrder == SortOrder.asc
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : null,
              ),
            ],
            selected: {sortBy},
            onSelectionChanged: (newSelection) {
              SortBy sortBy_;
              SortOrder sortOrder_;

              if (newSelection.isEmpty) {
                sortBy_ = sortBy;
                sortOrder_ = (sortOrder == SortOrder.desc)
                    ? SortOrder.asc
                    : SortOrder.desc;
              } else {
                sortBy_ = newSelection.first;
                sortOrder_ = newSelection.first == SortBy.lastModificationDate
                    ? SortOrder.desc
                    : SortOrder.asc;
              }

              configProvider.updateConfig(
                config.copyWith(
                  sortBy: sortBy_,
                  sortOrder: sortOrder_,
                ),
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 8),
          child:
              Text(t.platform, style: Theme.of(context).textTheme.titleSmall),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ...Platform.values.map(
              (Platform platform) => FilterChip(
                label: Text(platform.name.toUpperCase()),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                selected: platforms.contains(platform),
                onSelected: (bool selected) {
                  if (platforms.contains(platform)) {
                    configProvider.updateConfig(config.copyWith(
                        platforms: platforms
                            .where((element) => element != platform)
                            .toList()));
                  } else {
                    configProvider.updateConfig(config.copyWith(
                      platforms: [...platforms, platform],
                    ));
                  }
                },
              ),
            )
          ],
        ),
        Container(
          margin: const EdgeInsets.only(left: 8),
          child:
              Text(t.category, style: Theme.of(context).textTheme.titleSmall),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ...Category.values
                .toList()
                .whereNot((element) => element == Category.update)
                .map(
                  (Category category) => FilterChip(
                    label: Text(category.name.toUpperCase()),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    selected: categories.contains(category),
                    onSelected: (bool selected) {
                      if (categories.contains(category)) {
                        configProvider.updateConfig(config.copyWith(
                            categories: categories
                                .where((element) => element != category)
                                .toList()));
                      } else {
                        configProvider.updateConfig(config.copyWith(
                          categories: [...categories, category],
                        ));
                      }
                    },
                  ),
                )
          ],
        ),
        Container(
          margin: const EdgeInsets.only(left: 8),
          child: Text(t.region, style: Theme.of(context).textTheme.titleSmall),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ...Config.initConfig.regions.map(
              (Region region) => FilterChip(
                label: Text(region.name.toUpperCase()),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                selected: regions.contains(region),
                onSelected: (bool selected) {
                  if (regions.contains(region)) {
                    configProvider.updateConfig(config.copyWith(
                        regions: regions
                            .where((element) => element != region)
                            .toList()));
                  } else {
                    configProvider.updateConfig(config.copyWith(
                      regions: [...regions, region],
                    ));
                  }
                },
              ),
            )
          ],
        ),
      ],
    );
  }
}
