import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/reading_progress.dart';

part 'reading_db.g.dart';

@Riverpod(keepAlive: true)
class ReadingDB extends _$ReadingDB {
  late Database _inkworm;
  late String _databasePath;

  // iOS moves the app's container (/…/Containers/Data/Application/<UUID>/) when
  // the app is updated or reinstalled, so an absolute book path saved before
  // then no longer exists: reopening the last book fails, and its reading
  // progress is lost. Store paths relative to the container instead, and
  // resolve them against wherever it is now.
  static final RegExp _iosContainer = RegExp(r'^.*/Containers/Data/Application/[0-9A-Fa-f-]{36}/');
  String? _containerRoot;

  String get dbPath => _databasePath;

  @override
  Future<Database> build() async {
    sqfliteFfiInit();

    if (Platform.isIOS) {
      _containerRoot = (await getApplicationDocumentsDirectory()).parent.path;
    }

    _inkworm = await databaseFactoryFfi.openDatabase(await _getDatabasePath(),
        options: OpenDatabaseOptions(
            version: 2,
            onConfigure: (db) {
              _inkworm = db;
              _enableForeignKeys(db);
            },
            onCreate: (db, version) {
              _createTables(db, 0, version);
            },
            onOpen: (db) async {
              await _relativiseContainerPaths(db);
            },
            onUpgrade: (db, oldVersion, newVersion) {
              _createTables(db, oldVersion, newVersion);
            }));

    return _inkworm;
  }

  static const String _settings = '''
        create table if not exists settings(
          id integer not null primary key,
          fontSize int not null
        );
        ''';

  static const String _readingHistory = '''
        create table if not exists reading_history(
          path text not null primary key, 
          fontSize int not null,
          chapterNumber int not null, 
          pageNumber int not null 
        );
        ''';

  static const String _indexReadingHistory = 'create index reading_history_idx on reading_history(path);';

  void _createTables(Database db, int oldVersion, int newVersion) {
    if (oldVersion < 1) {
      db.execute(_readingHistory);
      db.execute(_settings);
      db.execute(_indexReadingHistory);
    }

    if (oldVersion < 2) {
      // settings had no primary key, so ConflictAlgorithm.replace inserted new rows
      // rather than replacing, causing the saved default font size to be ignored.
      // Recreate with a fixed id=1 row so REPLACE works correctly.
      db.execute('drop table if exists settings');
      db.execute(_settings);
    }

    return;
  }

  String _storedPath(String path) => _containerRoot == null ? path : path.replaceFirst(_iosContainer, '');

  String _resolvedPath(String path) => _containerRoot == null || path.isEmpty || path.startsWith('/') ? path : '$_containerRoot/$path';

  // Rewrites history saved with absolute paths (before paths were stored
  // relative to the container) so it survives the container moving.
  Future<void> _relativiseContainerPaths(Database db) async {
    if (_containerRoot == null) return;

    final rows = await db.query('reading_history', where: "path like '/%'", orderBy: 'rowid');
    for (final row in rows) {
      final String path = row['path'] as String;
      final String stored = _storedPath(path);
      if (stored == path) continue;

      await db.insert('reading_history', {...row, 'path': stored}, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.delete('reading_history', where: 'path = ?', whereArgs: [path]);
    }
  }

  Future _enableForeignKeys(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<String> getApplicationPath() async {
    String dir = "";
    if (!kIsWeb) {
      if (Platform.isAndroid || Platform.isMacOS || Platform.isIOS) {
        Directory documentsDirectory = await getApplicationDocumentsDirectory();
        dir = documentsDirectory.path;
      } else if (Platform.isWindows) {
        dir = path.join(Platform.environment['LOCALAPPDATA']!, 'Inkworm');
      } else {
        dir = path.join(Platform.environment['HOME']!, '.inkworm');
      }
    }

    return dir;
  }

  Future<String> _getDatabasePath() async {
    _databasePath = await getApplicationPath();
    _databasePath += '/db/';

    await Directory(_databasePath).create(recursive: true);

    _databasePath = path.join(_databasePath, 'inkworm.db');
    return _databasePath;
  }

  Future<int> getDefaultFontSize() async {
    List<Map<String, dynamic>> rows = await query(table: 'settings',);
    if (rows.isEmpty) {
      return 12;
    }

    return rows.first['fontSize'] ?? 12;
  }

  Future<ReadingProgress> getReadingProgress(String? path) async {
    List<Map<String, dynamic>> rows = path != null
      ? await query(table: 'reading_history', where: 'path = ?', whereArgs: [_storedPath(path)])
      : await query(table: 'reading_history', orderBy: 'rowid desc');

    if (rows.isEmpty) {
      ReadingProgress result = ReadingProgress();
      result.book = path ?? '';
      result.fontSize = await getDefaultFontSize();

      return result;
    }
    return ReadingProgress.fromMap({...rows.first, 'path': _resolvedPath(rows.first['path'])});
  }

  Future<void> setDefaultFontSize(int fontSize) async {
    await _inkworm.insert('settings', { 'id': 1, 'fontSize' : fontSize }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setProgress(ReadingProgress progress) async {
    await _inkworm.insert('reading_history', {...progress.toMap(), 'path': _storedPath(progress.book)}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> insert({ required String table, required Map<String, dynamic> rows, ConflictAlgorithm? conflictAlgorithm }) async {
    return _inkworm.insert(table, rows, conflictAlgorithm: conflictAlgorithm);
  }

  Future<List<Map<String, dynamic>>> query({ required String table, List<String>? columns, String? where, List<dynamic>? whereArgs, String? orderBy, int? limit }) async {
    return _inkworm.query(table, columns: columns, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
  }

  Future<List<Map<String, dynamic>>> rawQuery({ required String sql, List<Object?>? args }) async {
    return _inkworm.rawQuery(sql, args);
  }

  Future<int> updateTable({ required String table, required Map<String, dynamic> values, String? where, List<String>? whereArgs }) {
    return _inkworm.update(table, values, where: where, whereArgs: whereArgs);
  }
}