import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/location.dart';
import '../models/crop.dart';
import '../models/record.dart';

class DatabaseService {
  static const _dbName = 'grow.db';
  static const _dbVersion = 1;

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
            name TEXT NOT NULL,
            variety TEXT NOT NULL DEFAULT '',
            acquisition_type INTEGER NOT NULL,
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
      },
    );
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
}
