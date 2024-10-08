import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vita_dl/utils/storage.dart';

import '../model/content_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('contents.db');
    return _database!;
  }

  Future<String> getDatabasePath() async =>
      join(await getDataPath(), 'config', 'contents.db');

  Future<Database> _initDB(String fileName) async {
    String path = await getDatabasePath();
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contents(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT, -- app | dlc | theme
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
      content.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertContents(List<Content> contents) async {
    final db = await database;

    final batch = db.batch();
    for (var content in contents) {
      batch.insert(
        'contents',
        content.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Content>> getContents(String? type, String? titleId) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (type != null) {
      whereClause += 'type = ?';
      whereArgs.add(type);
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
      return Content.fromMap(maps[i]);
    });
  }

  Future<void> deleteContentsByType(String type) async {
    final db = await database;
    await db.delete(
      'contents',
      where: 'type = ?',
      whereArgs: [type],
    );
  }

  Future<void> deleteContents() async {
    final db = await database;
    await db.delete('contents');
  }
}
