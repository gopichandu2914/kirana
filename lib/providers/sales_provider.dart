import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class SalesProvider with ChangeNotifier {
  List<Map<String, dynamic>> _todaySales = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get todaySales => _todaySales;
  bool get isLoading => _isLoading;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? get _uid => _auth.currentUser?.uid;

  double get todayRevenue {
    return _todaySales.fold(0.0, (sum, s) => sum + (s['total_price'] as num).toDouble());
  }

  int get todayUnitsSold {
    return _todaySales.fold(0, (sum, s) => sum + (s['quantity_sold'] as int));
  }

  int get todayTransactionCount => _todaySales.length;

  int get totalUnitsInPeriod {
    return _todaySales.fold(0, (sum, s) => sum + (s['quantity_sold'] as int));
  }


  /// Returns product name with highest units sold today, or null
  String? get topProductToday {
    if (_todaySales.isEmpty) return null;
    final Map<String, int> totals = {};
    for (final s in _todaySales) {
      final name = s['product_name'] as String;
      totals[name] = (totals[name] ?? 0) + (s['quantity_sold'] as int);
    }
    return totals.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Future<void> fetchTodaySales() async {
    _isLoading = true;
    notifyListeners();

    final today = DateTime.now();
    final isoDate = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    _todaySales = await DatabaseHelper.instance.getSalesForDate(isoDate);

    _isLoading = false;
    notifyListeners();
  }

  /// Alias used by analytics screen — fetches last 7 days of sales
  Future<void> fetchRecentSales() async {
    _isLoading = true;
    notifyListeners();

    // 1. Local fetch
    _todaySales = await DatabaseHelper.instance.getRecentSales(7);

    // 2. Cloud fetch fallback
    if (_todaySales.isEmpty && _uid != null) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(_uid)
            .collection('sales')
            .orderBy('sale_date', descending: true)
            .limit(100)
            .get();
        
        _todaySales = snapshot.docs.map((d) => d.data()).toList();
      } catch (e) {
        print('Firestore sales fetch error: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Returns total units sold per product name for the currently loaded sales
  Map<String, int> getSalesGroupedByProduct() {
    final Map<String, int> grouped = {};
    for (final s in _todaySales) {
      final name = s['product_name'] as String;
      grouped[name] = (grouped[name] ?? 0) + (s['quantity_sold'] as int);
    }
    // Sort by volume descending
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Map.fromEntries(sortedEntries);
  }
}
