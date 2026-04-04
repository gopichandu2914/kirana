import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/database_helper.dart';
import '../services/notification_service.dart';

class InventoryProvider with ChangeNotifier {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  Map<int, double> _daysRemaining = {};

  List<Map<String, dynamic>> get products => _products;
  bool get isLoading => _isLoading;
  Map<int, double> get daysRemaining => _daysRemaining;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;
  CollectionReference get _productsCol => 
      _firestore.collection('users').doc(_uid).collection('products');

  List<Map<String, dynamic>> get lowStockProducts {
    return _products.where((p) => p['quantity'] <= p['min_threshold']).toList();
  }

  List<Map<String, dynamic>> get criticalStockProducts {
    return _products.where((p) {
      final days = _daysRemaining[p['id']];
      return days != null && days >= 0 && days <= 5;
    }).toList();
  }

  // ── Profit Stats ────────────────────────────────────────────────────
  double get totalInventoryValue {
    return _products.fold(0.0, (sum, p) => sum + (p['price'] as double) * (p['quantity'] as int));
  }

  double get totalInventoryCost {
    return _products.fold(0.0, (sum, p) => sum + (p['cost_price'] as double) * (p['quantity'] as int));
  }

  double get totalPotentialProfit => totalInventoryValue - totalInventoryCost;

  double profitMarginFor(Map<String, dynamic> product) {
    final price = product['price'] as double;
    final cost = product['cost_price'] as double;
    if (price == 0) return 0;
    return ((price - cost) / price) * 100;
  }

  double profitPerUnitFor(Map<String, dynamic> product) {
    return (product['price'] as double) - (product['cost_price'] as double);
  }
  // ────────────────────────────────────────────────────────────────────

  Future<void> fetchProducts() async {
    _isLoading = true;
    notifyListeners();

    // 1. Fetch from Local SQLite (Always the source of truth for offline speed)
    _products = await DatabaseHelper.instance.readAllProducts();
    
    // 2. If logged in, check for migration or sync
    if (_uid != null) {
      try {
        final cloudSnapshot = await _productsCol.get();
        if (cloudSnapshot.docs.isEmpty && _products.isNotEmpty) {
          // MIGRATION: Push local to empty cloud
          print('Migrating local data to Firestore...');
          for (final p in _products) {
            await _productsCol.doc(p['id'].toString()).set(p);
          }
        } else if (cloudSnapshot.docs.isNotEmpty) {
           // SYNC: Optional - could overwrite local with cloud or merge.
           // For now, we favor local for speed, but cloud is backed up.
        }
      } catch (e) {
        print('Firestore fetch error: $e');
      }
    }

    await _computeStockoutPredictions();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _computeStockoutPredictions() async {
    final recentSales = await DatabaseHelper.instance.getRecentSales(7);
    final Map<int, int> totalSoldPerProduct = {};

    for (final sale in recentSales) {
      final id = sale['product_id'] as int;
      final qty = sale['quantity_sold'] as int;
      totalSoldPerProduct[id] = (totalSoldPerProduct[id] ?? 0) + qty;
    }

    _daysRemaining = {};
    for (final p in _products) {
      final id = p['id'] as int;
      final stock = p['quantity'] as int;
      final totalSold = totalSoldPerProduct[id] ?? 0;

      if (totalSold == 0) {
        _daysRemaining[id] = -1;
      } else {
        final avgDailyRate = totalSold / 7.0;
        _daysRemaining[id] = stock / avgDailyRate;
      }
    }
  }

  int smartReorderQty(int productId) {
    final p = _products.firstWhere((p) => p['id'] == productId, orElse: () => {});
    if (p.isEmpty) return 10;

    final days = _daysRemaining[productId];
    if (days == null || days < 0) return (p['min_threshold'] as int) * 2;

    final stock = p['quantity'] as int;
    if (days == 0) return 30;
    final avgDaily = stock / days;
    final needed = (avgDaily * 14 - stock).ceil();
    return needed > 0 ? needed : 10;
  }

  Future<void> addProduct(String name, int quantity, double price, {double costPrice = 0.0}) async {
    final Map<String, dynamic> productData = {
      'name': name,
      'quantity': quantity,
      'price': price,
      'cost_price': costPrice,
      'min_threshold': 10,
    };

    final id = await DatabaseHelper.instance.insertProduct(productData);
    
    if (_uid != null) {
      productData['id'] = id;
      await _productsCol.doc(id.toString()).set(productData);
    }

    await fetchProducts();
  }

  Future<void> updateProductStock(int id, int addedQuantity) async {
    final product = _products.firstWhere((p) => p['id'] == id);

    int newQuantity = product['quantity'] + addedQuantity;
    if (newQuantity < 0) newQuantity = 0;

    final updatedData = {
      'id': id,
      'name': product['name'],
      'quantity': newQuantity,
      'price': product['price'],
      'cost_price': product['cost_price'] ?? 0.0,
      'min_threshold': product['min_threshold'],
    };

    await DatabaseHelper.instance.updateProductQuantity(id, newQuantity);

    if (_uid != null) {
      await _productsCol.doc(id.toString()).update({'quantity': newQuantity});
    }

    await fetchProducts();

    // 📳 Haptic Alert + Notification for critical stock (< 10)
    if (newQuantity < 10) {
      HapticFeedback.vibrate();
      await NotificationService().showStockAlert(
        itemName: product['name'],
        quantity: newQuantity,
      );
    }
  }

  Future<void> deleteProduct(int id) async {
    await DatabaseHelper.instance.deleteProduct(id);
    
    if (_uid != null) {
      await _productsCol.doc(id.toString()).delete();
    }
    
    await fetchProducts();
  }

  Future<void> logSale(int productId, int quantitySold) async {
    final product = _products.firstWhere((p) => p['id'] == productId);
    final newQuantity = product['quantity'] - quantitySold;
    final totalPrice = product['price'] * quantitySold;

    final updatedData = {
      'id': product['id'],
      'name': product['name'],
      'quantity': newQuantity >= 0 ? newQuantity : 0,
      'price': product['price'],
      'cost_price': product['cost_price'] ?? 0.0,
      'min_threshold': product['min_threshold'],
    };

    await DatabaseHelper.instance.updateProductQuantity(product['id'], updatedData['quantity']);

    final saleData = {
      'product_id': product['id'],
      'product_name': product['name'],
      'quantity_sold': quantitySold,
      'total_price': totalPrice,
      'sale_date': DateTime.now().toIso8601String(),
    };

    await DatabaseHelper.instance.logSale(saleData);

    if (_uid != null) {
      // Sync stock update
      await _productsCol.doc(productId.toString()).update({'quantity': updatedData['quantity']});
      // Sync sale log
      await _firestore.collection('users').doc(_uid).collection('sales').add(saleData);
    }

    await fetchProducts();

    // 📳 Haptic Alert + Notification for critical stock (< 10)
    if (updatedData['quantity'] != null && (updatedData['quantity'] as int) < 10) {
      HapticFeedback.vibrate();
      await NotificationService().showStockAlert(
        itemName: product['name'],
        quantity: updatedData['quantity'],
      );
    }
  }

  Future<void> logSaleByName(String productName, int quantitySold) async {
    final p = _products.cast<Map<String, dynamic>?>().firstWhere(
      (prod) => prod!['name'].toString().toLowerCase().contains(productName.toLowerCase()),
      orElse: () => null,
    );

    if (p != null) {
      await logSale(p['id'], quantitySold);
    } else {
      throw Exception('Product not found: $productName');
    }
  }

  Future<void> seedSampleData() async {
    _isLoading = true;
    notifyListeners();

    final List<Map<String, dynamic>> samples = [
      {'name': 'Rice (Rice)', 'quantity': 50, 'price': 60.0, 'cost_price': 45.0, 'min_threshold': 10},
      {'name': 'Wheat (Wheat/Atta)', 'quantity': 40, 'price': 40.0, 'cost_price': 32.0, 'min_threshold': 10},
      {'name': 'Sugar (Sugar)', 'quantity': 30, 'price': 44.0, 'cost_price': 38.0, 'min_threshold': 10},
      {'name': 'Cooking Oil (OIl)', 'quantity': 20, 'price': 120.0, 'cost_price': 105.0, 'min_threshold': 10},
      {'name': 'Dal (Dal/Lentils)', 'quantity': 25, 'price': 110.0, 'cost_price': 90.0, 'min_threshold': 5},
    ];

    for (final p in samples) {
      await addProduct(p['name'], p['quantity'], p['price'], costPrice: p['cost_price']);
    }

    _isLoading = false;
    notifyListeners();
  }
}
