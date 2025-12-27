import 'package:fnps/models/config.dart';
import 'package:fnps/models/content.dart';

final Map<Platform, int> _platformOrder = {
  Platform.psv: 1,
  Platform.psp: 2,
  Platform.psx: 3,
  Platform.psm: 4,
  Platform.ps3: 5,
};

final Map<Category, int> _categoryOrder = {
  Category.game: 1,
  Category.dlc: 2,
  Category.theme: 3,
  Category.update: 4,
  Category.demo: 5,
};

List<Source> sourceSorter(List<Source> sources) {
  return List<Source>.from(sources)..sort((a, b) {
    final platformComparison = (_platformOrder[a.platform] ?? 99).compareTo(
      _platformOrder[b.platform] ?? 99,
    );

    if (platformComparison != 0) return platformComparison;

    return (_categoryOrder[a.category] ?? 99).compareTo(
      _categoryOrder[b.category] ?? 99,
    );
  });
}
