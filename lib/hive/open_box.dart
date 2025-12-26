import 'package:hive_ce/hive.dart';
import 'package:fnps/utils/logger.dart';

Future<Box<T>> openBox<T>(String boxName) async {
  try {
    return await Hive.openBox<T>(boxName);
  } catch (e) {
    logger(
      'Failed to open box "$boxName". Deleting and recreating...',
      error: e,
    );

    try {
      await Hive.deleteBoxFromDisk(boxName);
    } catch (e2) {
      logger('Failed to delete box "$boxName" from disk.', error: e2);
    }

    return await Hive.openBox<T>(boxName);
  }
}
