import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseManager {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'security.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Table for reputation tracking
        await db.execute('''
          CREATE TABLE reputation (
            sender_hash TEXT PRIMARY KEY,
            last_message_at INTEGER,
            message_count INTEGER,
            last_call_at INTEGER,
            call_count INTEGER
          )
        ''');

        // Table for threats
        await db.execute('''
          CREATE TABLE threats (
            id TEXT PRIMARY KEY,
            channel TEXT,
            sender TEXT,
            risk_score INTEGER,
            category TEXT,
            reason TEXT,
            timestamp TEXT,
            was_blocked INTEGER,
            detail TEXT
          )
        ''');
      },
    );
  }
}
