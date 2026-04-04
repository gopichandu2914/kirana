import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kirana.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0,
        min_threshold INTEGER NOT NULL DEFAULT 10
      )
    ''');

    await db.execute('''
      CREATE TABLE sales_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity_sold INTEGER NOT NULL,
        total_price REAL NOT NULL,
        sale_date TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await _seedDB(db);
  }

  Future _seedDB(Database db) async {
    final List<Map<String, dynamic>> initialProducts = [
      {'name': 'Rice (Rice)', 'quantity': 50, 'price': 60.0, 'cost_price': 45.0, 'min_threshold': 10},
      {'name': 'Wheat (Wheat/Atta)', 'quantity': 40, 'price': 40.0, 'cost_price': 32.0, 'min_threshold': 10},
      {'name': 'Sugar (Sugar)', 'quantity': 30, 'price': 44.0, 'cost_price': 38.0, 'min_threshold': 10},
      {'name': 'Cooking Oil (OIl)', 'quantity': 20, 'price': 120.0, 'cost_price': 105.0, 'min_threshold': 10},
      {'name': 'Dal (Dal/Lentils)', 'quantity': 25, 'price': 110.0, 'cost_price': 90.0, 'min_threshold': 5},
    ];

    for (final p in initialProducts) {
      await db.insert('products', p);
    }
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        // ALTER TABLE cannot use NOT NULL without a default in SQLite
        await db.execute('ALTER TABLE products ADD COLUMN cost_price REAL DEFAULT 0');
      } catch (_) {
        // Column already exists — safe to ignore
      }
    }
  }

  // --- Product Methods ---
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await instance.database;
    return await db.insert('products', product);
  }

  Future<List<Map<String, dynamic>>> readAllProducts() async {
    final db = await instance.database;
    return await db.query('products', orderBy: 'name ASC');
  }

  Future<int> updateProduct(Map<String, dynamic> product) async {
    final db = await instance.database;
    return db.update(
      'products',
      product,
      where: 'id = ?',
      whereArgs: [product['id']],
    );
  }

  Future<int> updateProductQuantity(int id, int newQuantity) async {
    final db = await instance.database;
    return db.update(
      'products',
      {'quantity': newQuantity},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Sales Methods ---
  Future<int> logSale(Map<String, dynamic> saleLog) async {
    final db = await instance.database;
    return await db.insert('sales_logs', saleLog);
  }

  Future<List<Map<String, dynamic>>> getSalesForDate(String isoDate) async {
    final db = await instance.database;
    return await db.query(
      'sales_logs',
      where: 'sale_date LIKE ?',
      whereArgs: ['$isoDate%'],
    );
  }

  Future<List<Map<String, dynamic>>> getRecentSales(int daysLimit) async {
    final db = await instance.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysLimit)).toIso8601String();
    return await db.query(
      'sales_logs',
      where: 'sale_date >= ?',
      whereArgs: [cutoffDate],
      orderBy: 'sale_date DESC',
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
