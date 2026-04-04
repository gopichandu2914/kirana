import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  Locale _locale = const Locale('en');
  bool _isFirstLaunch = true;
  String _shopName = '';
  String _whatsappNumber = '';    // Owner's number (for profile display)
  String _supplierWhatsapp = '';  // Supplier's number (for reorder alerts)
  TimeOfDay _reorderReminderTime = const TimeOfDay(hour: 20, minute: 0);

  Locale get locale => _locale;
  bool get isFirstLaunch => _isFirstLaunch;
  String get shopName => _shopName;
  String get whatsappNumber => _whatsappNumber;
  String get supplierWhatsapp => _supplierWhatsapp;
  TimeOfDay get reorderReminderTime => _reorderReminderTime;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final langCode = prefs.getString('language_code') ?? 'en';
    _locale = Locale(langCode);

    _isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    _shopName = prefs.getString('shop_name') ?? '';
    _whatsappNumber = prefs.getString('whatsapp_number') ?? '';
    _supplierWhatsapp = prefs.getString('supplier_whatsapp') ?? '';
    
    final timeStr = prefs.getString('reorder_reminder_time') ?? '20:00';
    final parts = timeStr.split(':');
    _reorderReminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    notifyListeners();
  }

  Future<void> saveReminderTime(TimeOfDay time) async {
    _reorderReminderTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reorder_reminder_time', '${time.hour}:${time.minute}');
    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    _locale = Locale(langCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', langCode);
    notifyListeners();
  }

  Future<void> saveProfile(String name, String ownerPhone, String supplierPhone) async {
    _shopName = name;
    _whatsappNumber = ownerPhone;
    _supplierWhatsapp = supplierPhone;
    _isFirstLaunch = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_name', name);
    await prefs.setString('whatsapp_number', ownerPhone);
    await prefs.setString('supplier_whatsapp', supplierPhone);
    await prefs.setBool('is_first_launch', false);

    notifyListeners();
  }

  Future<void> completeFirstLaunch() async {
    _isFirstLaunch = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_launch', false);
    notifyListeners();
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isFirstLaunch = true;
    _shopName = '';
    _whatsappNumber = '';
    _supplierWhatsapp = '';
    notifyListeners();
  }
}
