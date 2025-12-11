import 'dart:io';


import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

part 'database.g.dart';

@Riverpod(keepAlive: true)
class Database extends _$LibraryDB {
  late Database _paladin;
  late String _databasePath;

  String get dbPath => _databasePath;

  @override
  Future<Database> build() async {
    sqfliteFfiInit();

    _paladin = await databaseFactoryFfi.openDatabase(await _getDatabasePath(),
        options: OpenDatabaseOptions(
            version: 1,
            onConfigure: (db) {
              _paladin = db;
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

    return _paladin;
  }

  static const String _bookauthors = '''
        create table if not exists book_authors(
          authorId integer not null, 
          bookId text not null, 
          foreign key(authorId) references authors(id),
          foreign key(bookId) references books(uuid));
          ''';

  static const String _booktags = '''
        create table if not exists book_tags(
          bookId text not null, 
          tagId integer not null, 
          foreign key(bookId) REFERENCES books(uuid));
          ''';

  static const String _tags = '''
        create table tags(
          id integer primary key,
          tag text not null,
          unique(tag) on conflict ignore);
          ''';
  static const String _indexBookauthors = 'create index book_authors_idx on book_authors(bookId, authorId);';
  static const String _indexTagname = 'create index tagname_idx on tags(tag);';
  static const String _indexBooktags = 'create index book_tags_idx on book_tags(bookId, tagId);';
  static const String _indexLastread = 'create index lastread_idx on books(lastRead);';
  static const String _indexAddeddate = 'create index added_idx on books(added);';

  void _createTables(Database db, int oldVersion, int newVersion) {
    _enableForeignKeys(db);
    if (oldVersion < 1) {
      db.execute(AuthorsRepository.authors);
      db.execute(BooksRepository.books);
      db.execute(SeriesRepository.series);
      db.execute(ShelvesRepository.shelves);

      db.execute(_bookauthors);
      db.execute(_tags);
      db.execute(_booktags);
      db.execute(CalibreServerRepository.calibre);

      db.execute(AuthorsRepository.indexAuthors);
      db.execute(BooksRepository.indexBooks);
      db.execute(SeriesRepository.indexSeriesName);
      db.execute(_indexBookauthors);
      db.execute(_indexTagname);
      db.execute(_indexBooktags);

      db.execute(_indexLastread);
      db.execute(_indexAddeddate);

      _insertInitialShelves(db, 'Currently Reading', CollectionType.CURRENT.index, 15);
      _insertInitialShelves(db, 'Random Shelf',  CollectionType.RANDOM.index, 30);
    }

    return;
  }

  Future _enableForeignKeys(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
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
    _paladin.rawDelete('delete from tags where id in (select tagId from book_tags where bookId not in (select uuid from books));');
  }

  Future<List<Uuid>> findLocalBooksNotInCalibre() async {
    List<Map<String, dynamic>> books = await _paladin.rawQuery('select uuid from books where uuid not in (select uuid from temp.calibreUuids);');
    return books.map((uuid) => Uuid.fromMap(uuid)).toList();
  }

  Future<List<Uuid>> findRemoteBooksNotInDb() async {
    List<Map<String, dynamic>> books = await _paladin.rawQuery('select uuid from temp.calibreUuids where uuid not in (select uuid from books);');
    return books.map((uuid) => Uuid.fromMap(uuid)).toList();
  }

  Future<int> getCount(String table, { String? where, List<dynamic>? whereArgs }) async {
    List<Map<String, dynamic>> results = await _paladin.query(table, columns: ['count(*) as count'], where: where, whereArgs: whereArgs);
    return results.first['count'] as int;
  }

  Future<int> getLastModified(Book book) async {
    final List<Map<String, dynamic>> maps = await _paladin.query('books', columns: [ 'lastModified'], where: 'uuid = ?', whereArgs: [book.uuid]);
    return maps.isNotEmpty ? maps.first['lastModified'] as int : 0;
  }

  Future<void> insertBook(Book book) async {
    // Ensure we update the Added date if we don't already have it.
    int added = book.added ?? (DateTime.now().millisecondsSinceEpoch / 1000).round();

    // Insert Series, returning foreign key for the Book.
    Series? series;
    if (book.series != null) {
      if (book.series!.id == null) {
        List<Map> result = await _paladin.query('series', columns: ['id'], where: 'series = ?', whereArgs: [book.series!.series]);
        series = book.series!.copySeriesWith(id: result.isNotEmpty
            ? result.first['id'] as int
            : await _paladin.insert('series', book.series!.toMap())
        );
      }
    }
    book = book.copyBookWith(added: added, series: series);

    // Now insert the Book.
    await _paladin.insert('books', book.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    // Insert all the Authors, updating the id for the next foreign key
    List<Author> authors = [];
    for (Author author in book.authors) {
      List<Map> result = await _paladin.query('authors', columns: ['id'], where: 'name = ?', whereArgs: [author.name]);

      authors.add(author.copyAuthorWith(id: result.isNotEmpty
          ? result.first['id'] as int
          : await _paladin.insert('authors', author.toMap())
      ));
    }

    // Insert the many-many relationship into book_authors.
    for (var author in authors) {
      List<Map> result = await _paladin.query('book_authors', columns: ['authorId'], where: 'authorId = ? and bookId = ?', whereArgs: [author.id, book.uuid]);
      if (result.isEmpty) {
        await _paladin.insert('book_authors', { 'authorId': author.id, 'bookId': book.uuid});
      }
    }

    // Insert all the Tags, updating the id for the next foreign key
    List<Tag> tags = [];
    for (var tag in book.tags) {
      List<Map> result = await _paladin.query('tags', columns: ['id'], where: 'tag = ?', whereArgs: [tag.tag]);
      tags.add(tag.copyTagWith(id: result.isNotEmpty
          ? result.first['id'] as int
          : await _paladin.insert('tags', tag.toMap())
      ));

      // Insert the many-many relationship into book_tags.
      // Delete all tags before we start to ensure we are up to date with Calibre.
      await _paladin.delete('book_tags', where: 'bookId = ?', whereArgs: [book.uuid]);
      for (var tag in tags) {
        await _paladin.insert('book_tags', { 'tagId': tag.id, 'bookId': book.uuid});
      }
    }
  }

  Future<void> removeBook(Uuid uuid) async {
    // Remove the books; check for Tags that may no longer be used and clean up if required.
    _paladin.rawDelete('delete from book_tags where bookId in (select id from books where uuid = ?)', [uuid.uuid]);
    _paladin.delete('books', where: 'uuid = ?', whereArgs: [uuid.uuid]);
  }

  Future<void> uploadTemporaryUuids(List<Uuid> booksInCalibreLibrary) async {
    _paladin.execute('DROP TABLE IF EXISTS temp.calibreUuids;');
    _paladin.execute('CREATE TEMPORARY TABLE calibreUuids(uuid text not null);');

    final Batch batch = _paladin.batch();
    for (Uuid uuid in booksInCalibreLibrary) {
      batch.insert('temp.calibreUuids', uuid.toMap());
    }
    await batch.commit();
  }

  Future<int> insert({ required String table, required Map<String, dynamic> rows, ConflictAlgorithm? conflictAlgorithm }) async {
    return _paladin.insert(table, rows, conflictAlgorithm: conflictAlgorithm);
  }

  Future<List<Map<String, dynamic>>> query({ required String table, List<String>? columns, String? where, List<dynamic>? whereArgs, String? orderBy, int? limit }) async {
    return _paladin.query(table, columns: columns, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
  }

  Future<List<Map<String, dynamic>>> rawQuery({ required String sql, List<Object?>? args }) async {
    return _paladin.rawQuery(sql, args);
  }

  Future<int> updateTable({ required String table, required Map<String, dynamic> values, String? where, List<String>? whereArgs }) {
    return _paladin.update(table, values, where: where, whereArgs: whereArgs);
  }
}