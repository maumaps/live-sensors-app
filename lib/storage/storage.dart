import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:live_sensors/snapshot/snapshot.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:live_sensors/logger/logger.dart';

class Storage {
  final Logger logger = Logger();
  Storage();
  final dbName = 'snapshots.db';
  late Future<Database> database;

  Future<void> init() async {
    // Avoid errors caused by flutter upgrade.
    WidgetsFlutterBinding.ensureInitialized();
    database = openDatabase(
      join(await getDatabasesPath(), dbName),
      onCreate: (db, version) => _createSnapshotsTable(db),
      onUpgrade: (db, oldVersion, newVersion) => _createSnapshotsTable(db),
      onOpen: (db) => _createSnapshotsTable(db),
      version: 2,
    );
  }

  Future<void> _createSnapshotsTable(Database db) {
    return db.execute(
      'CREATE TABLE IF NOT EXISTS snapshots('
      'id TEXT PRIMARY KEY, '
      'created_at INTEGER NOT NULL, '
      'payload TEXT NOT NULL'
      ')',
    );
  }

  Future<void> save(Snapshot snapshot) async {
    final db = await database;

    await db.insert(
      'snapshots',
      {
        'id': snapshot.id,
        'created_at': snapshot.startDateTime.millisecondsSinceEpoch,
        'payload': jsonEncode(snapshot.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(Snapshot snapshot) async {
    final db = await database;

    await db.delete(
      'snapshots',
      where: 'id = ?',
      // Pass the id as a whereArg to prevent SQL injection.
      whereArgs: [snapshot.id],
    );
  }

  Future<Snapshot> next() async {
    final db = await database;

    while (true) {
      final rows = await db.query(
        'snapshots',
        orderBy: 'created_at ASC, id ASC',
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('No stored snapshots');
      }

      final row = rows.first;
      final id = row['id'] as String;

      try {
        return Snapshot.fromJson(
          jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        );
      } catch (e) {
        logger.error(
          'Drop invalid stored snapshot $id.\n Reason: $e',
        );
        await db.delete(
          'snapshots',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }
}
