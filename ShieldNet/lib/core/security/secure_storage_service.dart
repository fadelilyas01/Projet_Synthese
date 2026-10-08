import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../security/crypto_utils.dart';

/// Modèle d'élément de liste noire
class BlacklistedNumber {
  final String phoneHash;
  final String category; // 'fraud', 'telemarketing', 'financial_scam', etc.
  final int riskScore; // 0 à 100
  final int reportsCount;
  final String updatedAt;

  BlacklistedNumber({
    required this.phoneHash,
    required this.category,
    required this.riskScore,
    required this.reportsCount,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'phone_hash': phoneHash,
      'category': category,
      'risk_score': riskScore,
      'reports_count': reportsCount,
      'updated_at': updatedAt,
    };
  }

  factory BlacklistedNumber.fromMap(Map<String, dynamic> map) {
    return BlacklistedNumber(
      phoneHash: map['phone_hash'] as String,
      category: map['category'] as String,
      riskScore: map['risk_score'] as int,
      reportsCount: map['reports_count'] as int,
      updatedAt: map['updated_at'] as String,
    );
  }
}

/// Modèle de Liste Blanche (VIP / Contacts de confiance)
class WhitelistedNumber {
  final String phoneHash;
  final String name;
  final String maskedNumber;
  final String addedAt;

  WhitelistedNumber({
    required this.phoneHash,
    required this.name,
    required this.maskedNumber,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'phone_hash': phoneHash,
      'name': name,
      'masked_number': maskedNumber,
      'added_at': addedAt,
    };
  }

  factory WhitelistedNumber.fromMap(Map<String, dynamic> map) {
    return WhitelistedNumber(
      phoneHash: map['phone_hash'] as String,
      name: map['name'] as String,
      maskedNumber: map['masked_number'] as String,
      addedAt: map['added_at'] as String,
    );
  }
}

/// Helper SQLite local sécurisé pour ShieldNet
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shieldnet_pro_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Table 1: Liste Noire Globale (Cache Offline)
    await db.execute('''
      CREATE TABLE blacklist (
        phone_hash TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        risk_score INTEGER NOT NULL,
        reports_count INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Table 2: Signalements Utilisateurs
    await db.execute('''
      CREATE TABLE user_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone_hash TEXT NOT NULL,
        category TEXT NOT NULL,
        comment TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Table 3: Liste Blanche (Whitelist / VIP Contacts)
    await db.execute('''
      CREATE TABLE whitelist (
        phone_hash TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        masked_number TEXT NOT NULL,
        added_at TEXT NOT NULL
      )
    ''');

    // Table 4: Journal Historique des Appels Bloqués (Blocked Logs)
    await db.execute('''
      CREATE TABLE blocked_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone_hash TEXT NOT NULL,
        masked_number TEXT NOT NULL,
        category TEXT NOT NULL,
        risk_score INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS whitelist (
          phone_hash TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          masked_number TEXT NOT NULL,
          added_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS blocked_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          phone_hash TEXT NOT NULL,
          masked_number TEXT NOT NULL,
          category TEXT NOT NULL,
          risk_score INTEGER NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
    }
  }

  // --- MÉTHODES LISTE NOIRE ---
  Future<void> insertOrUpdateBlacklistedNumber(BlacklistedNumber number) async {
    final db = await instance.database;
    await db.insert('blacklist', number.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<BlacklistedNumber?> checkNumber(String rawPhoneNumber) async {
    final hash = CryptoUtils.hashPhoneNumber(rawPhoneNumber);
    final db = await instance.database;
    final maps = await db.query('blacklist', where: 'phone_hash = ?', whereArgs: [hash]);
    if (maps.isNotEmpty) return BlacklistedNumber.fromMap(maps.first);
    return null;
  }

  Future<List<BlacklistedNumber>> getAllBlacklistedNumbers() async {
    final db = await instance.database;
    final result = await db.query('blacklist', orderBy: 'risk_score DESC');
    return result.map((json) => BlacklistedNumber.fromMap(json)).toList();
  }

  // --- MÉTHODES LISTE BLANCHE (WHITELIST) ---
  Future<void> addToWhitelist(String rawPhoneNumber, String name) async {
    final hash = CryptoUtils.hashPhoneNumber(rawPhoneNumber);
    final masked = CryptoUtils.maskPhoneNumber(rawPhoneNumber);
    final db = await instance.database;

    final item = WhitelistedNumber(
      phoneHash: hash,
      name: name,
      maskedNumber: masked,
      addedAt: DateTime.now().toIso8601String(),
    );

    await db.insert('whitelist', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> isWhitelisted(String rawPhoneNumber) async {
    final hash = CryptoUtils.hashPhoneNumber(rawPhoneNumber);
    final db = await instance.database;
    final maps = await db.query('whitelist', where: 'phone_hash = ?', whereArgs: [hash]);
    return maps.isNotEmpty;
  }

  Future<List<WhitelistedNumber>> getWhitelist() async {
    final db = await instance.database;
    final result = await db.query('whitelist', orderBy: 'added_at DESC');
    return result.map((json) => WhitelistedNumber.fromMap(json)).toList();
  }

  Future<void> removeFromWhitelist(String phoneHash) async {
    final db = await instance.database;
    await db.delete('whitelist', where: 'phone_hash = ?', whereArgs: [phoneHash]);
  }

  // --- MÉTHODES HISTORIQUE (LOGS) ---
  Future<void> logBlockedCall({
    required String rawPhoneNumber,
    required String category,
    required int riskScore,
  }) async {
    final hash = CryptoUtils.hashPhoneNumber(rawPhoneNumber);
    final masked = CryptoUtils.maskPhoneNumber(rawPhoneNumber);
    final db = await instance.database;

    await db.insert('blocked_logs', {
      'phone_hash': hash,
      'masked_number': masked,
      'category': category,
      'risk_score': riskScore,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getBlockedLogs() async {
    final db = await instance.database;
    return await db.query('blocked_logs', orderBy: 'timestamp DESC', limit: 100);
  }

  Future<void> clearCache() async {
    final db = await instance.database;
    await db.delete('blacklist');
  }
}
