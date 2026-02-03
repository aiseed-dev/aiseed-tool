import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/location.dart';
import '../models/crop.dart';
import '../models/record.dart';
import '../models/record_photo.dart';

class DatabaseService {
  static const _dbName = 'grow.db';
  static const _dbVersion = 4;

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE record_photos (
              id TEXT PRIMARY KEY,
              record_id TEXT NOT NULL,
              file_path TEXT NOT NULL,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              FOREIGN KEY (record_id) REFERENCES records(id) ON DELETE CASCADE
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE crops ADD COLUMN cultivation_name TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE crops ADD COLUMN memo TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE locations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE crops (
        id TEXT PRIMARY KEY,
        location_id TEXT NOT NULL,
        cultivation_name TEXT NOT NULL DEFAULT '',
        memo TEXT NOT NULL DEFAULT '',
        start_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE records (
        id TEXT PRIMARY KEY,
        crop_id TEXT NOT NULL,
        activity_type INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (crop_id) REFERENCES crops(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE record_photos (
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (record_id) REFERENCES records(id) ON DELETE CASCADE
      )
    ''');
  }

  // -- Locations --

  Future<List<Location>> getLocations() async {
    final d = await db;
    final rows = await d.query('locations', orderBy: 'created_at ASC');
    return rows.map(Location.fromMap).toList();
  }

  Future<void> insertLocation(Location location) async {
    final d = await db;
    await d.insert('locations', location.toMap());
  }

  Future<void> updateLocation(Location location) async {
    final d = await db;
    await d.update('locations', location.toMap(),
        where: 'id = ?', whereArgs: [location.id]);
  }

  Future<void> deleteLocation(String id) async {
    final d = await db;
    await d.delete('locations', where: 'id = ?', whereArgs: [id]);
  }

  // -- Crops --

  Future<List<Crop>> getCrops({String? locationId}) async {
    final d = await db;
    if (locationId != null) {
      final rows = await d.query('crops',
          where: 'location_id = ?',
          whereArgs: [locationId],
          orderBy: 'start_date DESC');
      return rows.map(Crop.fromMap).toList();
    }
    final rows = await d.query('crops', orderBy: 'start_date DESC');
    return rows.map(Crop.fromMap).toList();
  }

  Future<void> insertCrop(Crop crop) async {
    final d = await db;
    await d.insert('crops', crop.toMap());
  }

  Future<void> updateCrop(Crop crop) async {
    final d = await db;
    await d.update('crops', crop.toMap(),
        where: 'id = ?', whereArgs: [crop.id]);
  }

  Future<void> deleteCrop(String id) async {
    final d = await db;
    await d.delete('crops', where: 'id = ?', whereArgs: [id]);
  }

  // -- Records --

  Future<List<GrowRecord>> getRecords({String? cropId}) async {
    final d = await db;
    if (cropId != null) {
      final rows = await d.query('records',
          where: 'crop_id = ?',
          whereArgs: [cropId],
          orderBy: 'date DESC');
      return rows.map(GrowRecord.fromMap).toList();
    }
    final rows = await d.query('records', orderBy: 'date DESC');
    return rows.map(GrowRecord.fromMap).toList();
  }

  Future<void> insertRecord(GrowRecord record) async {
    final d = await db;
    await d.insert('records', record.toMap());
  }

  Future<void> updateRecord(GrowRecord record) async {
    final d = await db;
    await d.update('records', record.toMap(),
        where: 'id = ?', whereArgs: [record.id]);
  }

  Future<void> deleteRecord(String id) async {
    final d = await db;
    await d.delete('records', where: 'id = ?', whereArgs: [id]);
  }

  // -- Record Photos --

  Future<List<RecordPhoto>> getPhotos(String recordId) async {
    final d = await db;
    final rows = await d.query('record_photos',
        where: 'record_id = ?',
        whereArgs: [recordId],
        orderBy: 'sort_order ASC');
    return rows.map(RecordPhoto.fromMap).toList();
  }

  Future<void> insertPhoto(RecordPhoto photo) async {
    final d = await db;
    await d.insert('record_photos', photo.toMap());
  }

  Future<void> deletePhoto(String id) async {
    final d = await db;
    await d.delete('record_photos', where: 'id = ?', whereArgs: [id]);
  }
}
