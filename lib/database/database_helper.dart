import 'package:sqflite/sqflite.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/utils/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<List<String>> getDatabasePath() async =>
      [...(await getAppPath()), 'config', 'contents.db'];

  Future<Database> _initDB() async {
    final path = await getDatabasePath();
    return await openDatabase(pathJoin(path), version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contents(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT, -- app | update | dlc | theme
        titleID TEXT,
        region TEXT,
        name TEXT,
        pkgDirectLink TEXT,
        zRIF TEXT,
        contentID TEXT,
        lastModificationDate TEXT,
        originalName TEXT,
        fileSize INTEGER,
        sha256 TEXT,
        requiredFW TEXT,
        appVersion TEXT
      )
    ''');
  }

  Future<void> insertContent(Content content) async {
    final db = await database;
    await db.insert(
      'contents',
      content.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertContents(List<Content> contents) async {
    final db = await database;

    final batch = db.batch();
    for (var content in contents) {
      batch.insert(
        'contents',
        content.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Content>> getContents(
      List<String>? types, String? titleId) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (types != null && types.isNotEmpty) {
      whereClause += 'type IN (${List.filled(types.length, '?').join(',')})';
      whereArgs.addAll(types);
    }

    if (titleId != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'titleId = ?';
      whereArgs.add(titleId);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'contents',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );

    return List.generate(maps.length, (i) {
      return Content.fromJson(maps[i]);
    });
  }

  Future<void> deleteContentsByTypes(List<String> types) async {
    final db = await database;

    if (types.isNotEmpty) {
      String whereClause =
          'type IN (${List.filled(types.length, '?').join(',')})';
      await db.delete(
        'contents',
        where: whereClause,
        whereArgs: types,
      );
    }
  }

  Future<void> deleteContents() async {
    final db = await database;
    await db.delete('contents');
  }

  Future<List<String>> getRegions() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT DISTINCT region FROM contents WHERE region IS NOT NULL');
    return result.map((e) => e['region'] as String).toList();
  }
}
