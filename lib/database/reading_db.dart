import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

part 'reading_db.g.dart';

@Riverpod(keepAlive: true)
class ReadingDB extends _$ReadingDB {
  late Database _inkworm;
  late String _databasePath;

  String get dbPath => _databasePath;

  @override
  Future<Database> build() async {
    sqfliteFfiInit();

    _inkworm = await databaseFactoryFfi.openDatabase(await _getDatabasePath(),
        options: OpenDatabaseOptions(
            version: 1,
            onConfigure: (db) {
              _inkworm = db;
              _enableForeignKeys(db);
            },
            onCreate: (db, version) {
              _createTables(db, 0, version);
            },
            onOpen: (db) {
            },
            onUpgrade: (db, oldVersion, newVersion) {
              _createTables(db, oldVersion, newVersion);
            }));

    return _inkworm;
  }

  static const String _readingHistory = '''
        create table if not exists reading_history(
          path text not null, 
          fontSize int not null,
          chapterNumber int not null, 
          pageNumber int not null, 
          );
          ''';

  static const String _indexReadingHistory = 'create index reading_history_idx on reading_history(path);';

  void _createTables(Database db, int oldVersion, int newVersion) {
    _enableForeignKeys(db);
    if (oldVersion < 1) {
      db.execute(_readingHistory);
      db.execute(_indexReadingHistory);
    }

    return;
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
        dir = path.join(Platform.environment['LOCALAPPDATA']!, 'Paladin');
      } else {
        dir = path.join(Platform.environment['HOME']!, '.paladin');
      }
    }

    return dir;
  }

  Future<String> _getDatabasePath() async {
    _databasePath = await getApplicationPath();
    _databasePath += '/db/';

    await Directory(_databasePath).create(recursive: true);

    _databasePath = path.join(_databasePath, 'paladin.db');
    return _databasePath;
  }

  Future<int> _insertInitialShelves(Database db, String name, int type, int size) async {
    return db.rawInsert('insert into shelves(name, type, size) values(?, ?, ?)', [name, type, size]);
  }

  Future<void> cleanDanglingTags() async {
    _inkworm.rawDelete('delete from tags where id in (select tagId from book_tags where bookId not in (select uuid from books));');
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