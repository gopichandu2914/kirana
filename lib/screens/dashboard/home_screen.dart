import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/localization.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/gemini_service.dart';
import '../inventory_screen.dart';
import '../analytics_screen.dart';
import '../profile_screen.dart';
import '../bill_generator_screen.dart';

// Returns an emoji for common grocery products by name
String productEmoji(String name) {
  final n = name.toLowerCase();
  if (n.contains('rice') || n.contains('అన్నం') || n.contains('चावल')) return '🍚';
  if (n.contains('wheat') || n.contains('atta') || n.contains('గోధుమ')) return '🌾';
  if (n.contains('sugar') || n.contains('చక్కెర') || n.contains('चीनी')) return '🍬';
  if (n.contains('oil') || n.contains('నూనె') || n.contains('तेल')) return '🫙';
  if (n.contains('salt') || n.contains('ఉప్పు') || n.contains('नमक')) return '🧂';
  if (n.contains('milk') || n.contains('పాలు') || n.contains('दूध')) return '🥛';
  if (n.contains('egg') || n.contains('గుడ్డు') || n.contains('अंडा')) return '🥚';
  if (n.contains('bread') || n.contains('రొట్టె') || n.contains('रोटी')) return '🍞';
  if (n.contains('soap') || n.contains('శాబు') || n.contains('साबुन')) return '🧼';
  if (n.contains('water') || n.contains('నీళ్ళు') || n.contains('पानी')) return '💧';
  if (n.contains('biscuit') || n.contains('cookie')) return '🍪';
  if (n.contains('tea') || n.contains('chai') || n.contains('చాయ్')) return '🍵';
  if (n.contains('coffee')) return '☕';
  if (n.contains('dal') || n.contains('lentil') || n.contains('పప్పు')) return '🫘';
  if (n.contains('tomato') || n.contains('టమాటా')) return '🍅';
  if (n.contains('onion') || n.contains('ఉల్లిపాయ')) return '🧅';
  if (n.contains('potato') || n.contains('బంగాళాదుంప')) return '🥔';
  if (n.contains('banana') || n.contains('అరటి')) return '🍌';
  if (n.contains('apple') || n.contains('యాపిల్')) return '🍎';
  if (n.contains('chicken') || n.contains('meat') || n.contains('చికెన్')) return '🍗';
  if (n.contains('fish') || n.contains('చేప')) return '🐟';
  if (n.contains('cold drink') || n.contains('soda') || n.contains('cola')) return '🥤';
  if (n.contains('shampoo') || n.contains('hair')) return '🧴';
  if (n.contains('pen') || n.contains('pencil')) return '✏️';
  return '📦';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late stt.SpeechToText _speech;
  late AudioPlayer _audioPlayer;
  late FlutterTts _tts;
  bool _isListening = false;
  List<Map<String, String>> _suggestionCards = [];
  bool _loadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _audioPlayer = AudioPlayer();
    _tts = FlutterTts();
    _loadSuggestions();
    Future.microtask(() {
      Provider.of<InventoryProvider>(context, listen: false).fetchProducts();
      Provider.of<SalesProvider>(context, listen: false).fetchTodaySales();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loadingSuggestions = true);
    final lang = Provider.of<SettingsProvider>(context, listen: false).locale.languageCode;
    final cards = await GeminiService.getSeasonalSuggestionCards(lang);
    if (mounted) {
      setState(() {
        _suggestionCards = cards;
        _loadingSuggestions = false;
      });
    }
  }

  Future<void> _handleVoiceResult(String spokenText) async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    final inv = Provider.of<InventoryProvider>(context, listen: false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🎤 Processing: "$spokenText"')),
    );

    try {
      final result = await GeminiService.parseVoiceCommand(spokenText);
      if (result == null || !mounted) return;

      final intent = result['intent'] as String? ?? '';
      final productName = result['product'] as String? ?? '';
      final quantity = (result['quantity'] as num?)?.toInt() ?? 1;
      final price = (result['price'] as num?)?.toDouble();
      final inv = Provider.of<InventoryProvider>(context, listen: false);

      String verbalResponse = '';

      switch (intent) {
        case 'sale':
          await inv.logSaleByName(productName, quantity);
          verbalResponse = loc.get('voice_sold')
              .replaceAll('{product}', productName)
              .replaceAll('{qty}', '$quantity');
          _showSuccess(verbalResponse);
          break;

        case 'add_stock':
          await inv.fetchProducts();
          final existing = inv.products.cast<Map<String, dynamic>?>()
              .firstWhere((p) => p!['name'].toString().toLowerCase().contains(productName.toLowerCase()), orElse: () => null);
          if (existing != null) {
            await inv.updateProductStock(existing['id'], quantity);
            verbalResponse = loc.get('voice_added')
                .replaceAll('{product}', existing['name'])
                .replaceAll('{qty}', '$quantity');
            _showSuccess(verbalResponse);
          } else {
            await inv.addProduct(productName, quantity, price ?? 0.0);
            verbalResponse = loc.get('voice_new_product')
                .replaceAll('{product}', productName)
                .replaceAll('{qty}', '$quantity');
            _showSuccess(verbalResponse);
          }
          break;

        case 'add_product':
          await inv.addProduct(productName, quantity, price ?? 0.0);
          verbalResponse = loc.get('voice_new_product')
              .replaceAll('{product}', productName)
              .replaceAll('{qty}', '$quantity');
          _showSuccess(verbalResponse);
          break;

        case 'query_inventory':
          await inv.fetchProducts();
          final item = inv.products.cast<Map<String, dynamic>?>()
              .firstWhere((p) => p!['name'].toString().toLowerCase().contains(productName.toLowerCase()), orElse: () => null);
          if (item != null) {
            final q = item['quantity'];
            verbalResponse = loc.get('voice_stock_status')
                .replaceAll('{product}', item['name'])
                .replaceAll('{qty}', '$q');
            _showSuccess(verbalResponse);
          } else {
            verbalResponse = loc.get('voice_not_found').replaceAll('{product}', productName);
            _showError(verbalResponse);
          }
          break;

        default:
          verbalResponse = loc.get('voice_error');
          _showError(verbalResponse);
      }

      // ── TALKING AI LOOP (Verbal Response) ──────────────────
      if (verbalResponse.isNotEmpty) {
        await _speak(verbalResponse);
      }

    } catch (e) {
      if (mounted) _showError('AI Error: ${e.toString().split('\n').first.replaceAll('Exception: ', '')}');
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700, duration: const Duration(seconds: 3)),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _speak(String text) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final langCode = settings.locale.languageCode;
    
    String ttsLang = 'en-US';
    if (langCode == 'te') ttsLang = 'te-IN';
    if (langCode == 'hi') ttsLang = 'hi-IN';

    await _tts.setLanguage(ttsLang);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5); // Slightly slower for senior shopkeepers
    await _tts.speak(text);
  }

  Future<void> _listen() async {
    if (!_isListening) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showError('Microphone permission denied. Please enable it in Settings.');
        return;
      }

      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' && mounted) setState(() => _isListening = false);
        },
        onError: (val) {
          if (mounted) {
            String errorMsg = 'Mic error: ${val.errorMsg}';
            if (val.errorMsg == 'error_speech_timeout') errorMsg = 'No speech detected. Try again.';
            _showError(errorMsg);
          }
          setState(() => _isListening = false);
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: Provider.of<SettingsProvider>(context, listen: false).locale.toLanguageTag(),
          onResult: (val) {
            if (val.finalResult) {
              setState(() => _isListening = false);
              _handleVoiceResult(val.recognizedWords);
            }
          },
        );
      } else {
        _showError('Microphone not available. Check permissions.');
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _sendWhatsAppReorderList() async {
    final inv = Provider.of<InventoryProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    final lowStock = inv.lowStockProducts;
    if (lowStock.isEmpty) {
      _showSuccess('✅ All stock levels are good!');
      return;
    }

    String message = '🛒 Reorder List — ${settings.shopName}\n\n';
    for (var item in lowStock) {
      final emoji = productEmoji(item['name'].toString());
      final smartQty = inv.smartReorderQty(item['id'] as int);
      message += '$emoji ${item['name']}: Stock ${item['quantity']}, Order $smartQty units\n';
    }
    message += '\nPlease send at earliest. Thank you!';

    final encodedMessage = Uri.encodeComponent(message);
    late Uri url;
    if (settings.supplierWhatsapp.isNotEmpty) {
      String cleanNum = settings.supplierWhatsapp.replaceAll(RegExp(r'[^0-9]'), '');
      url = Uri.parse('https://wa.me/$cleanNum?text=$encodedMessage');
    } else {
      url = Uri.parse('https://wa.me/?text=$encodedMessage');
    }

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showError('Failed to open WhatsApp.');
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadSuggestions(),
      Provider.of<InventoryProvider>(context, listen: false).fetchProducts(),
      Provider.of<SalesProvider>(context, listen: false).fetchTodaySales(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final inv = Provider.of<InventoryProvider>(context);
    final sales = Provider.of<SalesProvider>(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final buttonHeight = isTablet ? 160.0 : 130.0;
    final headerFontSize = isTablet ? 32.0 : 28.0;

    final lowStockCount = inv.lowStockProducts.length;
    final criticalCount = inv.criticalStockProducts.length;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isTablet ? 100 : 80, 
        title: Text(loc.get('dashboard'),
            style: TextStyle(fontSize: headerFontSize, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle, size: isTablet ? 54 : 44), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: Colors.green,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCriticalStockAlert(context, inv, loc),
                const SizedBox(height: 8),
                // ── AI Business Tips Header ───────────────────────
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.amber, size: isTablet ? 40 : 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(loc.get('business_tips'),
                        style: TextStyle(fontSize: isTablet ? 28 : 24, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_loadingSuggestions)
                      const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.amber),
                        onPressed: _loadSuggestions,
                        tooltip: 'Refresh AI Tips',
                      )
                  ],
                ),
                const SizedBox(height: 8),

                // ── BUSINESS TIPS (Responsive Height) ───────────────
                if (_loadingSuggestions)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else if (_suggestionCards.isEmpty)
                   const SizedBox.shrink()
                else
                  SizedBox(
                    height: isTablet ? 210 : 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: _suggestionCards.length,
                      itemBuilder: (context, index) => _buildSuggestionCard(_suggestionCards[index]),
                    ),
                  ),

                // ── Today's Summary Card (Responsive) ───────────────
                _buildTodaySummaryCard(sales, isTablet),

                // ── Stockout Warnings ─────────────────────────────
                if (criticalCount > 0) _buildStockoutWarning(inv),

                const SizedBox(height: 8),

                // ── Navigation 2×2 Grid (Responsive Scaling) ──────────
                Row(
                  children: [
                    Expanded(
                      child: _buildSquareNavButton(
                        loc.get('inventory') ?? 'Inventory',
                        Icons.inventory_2,
                        Colors.blue,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
                        height: buttonHeight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSquareNavBadgeButton(
                        loc.get('low_stock_alerts') ?? 'Low Stock',
                        Icons.warning_amber_rounded,
                        Colors.orange,
                        _sendWhatsAppReorderList,
                        badgeCount: lowStockCount,
                        height: buttonHeight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSquareNavButton(
                        '🧾 Bill',
                        Icons.receipt_long,
                        Colors.teal,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillGeneratorScreen())),
                        height: buttonHeight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSquareNavButton(
                        loc.get('analytics') ?? 'Analytics',
                        Icons.bar_chart_rounded,
                        Colors.purple,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
                        height: buttonHeight,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Voice Button ──────────────────────────────────
                GestureDetector(
                  onTap: _listen,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: _isListening ? Colors.red : Colors.green,
                        width: 4,
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          size: 64, // 72 -> 64
                          color: _isListening ? Colors.red : Colors.green.shade800,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isListening
                              ? loc.get('listening') ?? 'Listening...'
                              : loc.get('tap_to_speak') ?? 'Tap to speak',
                          style: TextStyle(
                            fontSize: 24, // 28 -> 24
                            fontWeight: FontWeight.bold,
                            color: _isListening ? Colors.red : Colors.green.shade900,
                          ),
                        ),
                        if (!_isListening)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '"Sold 5 rice" • "Add 20 sugar" • "New product wheat"',
                              style: TextStyle(fontSize: 13, color: Colors.green.shade700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCriticalStockAlert(BuildContext context, InventoryProvider inv, AppLocalizations loc) {
    final critical = inv.criticalStockProducts;
    if (critical.isEmpty) return const SizedBox.shrink();

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final firstItem = critical.first;
    final name = firstItem['name'].toString();
    final qty = firstItem['quantity'].toString();

    return Card(
      color: Colors.red.shade50,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.red, width: 2.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text('🚨', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    loc.get('critical_stock_alert'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${loc.get('stock_low_warning').replaceAll('{product}', firstItem['name']).replaceAll('{qty}', qty)} (${inv.daysRemaining[firstItem['id']]?.toStringAsFixed(1)} days left)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Order Now (Supplier)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sendStockWhatsApp(
                      settings.supplierWhatsapp,
                      loc.get('supplier_msg_template')
                          .replaceAll('{product}', name)
                          .replaceAll('{qty}', qty)
                          .replaceAll('{shop}', settings.shopName),
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: Text(loc.get('order_now'), style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 8),
                // Remind Me (Self)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _sendStockWhatsApp(
                      settings.whatsappNumber,
                      loc.get('self_reminder_template')
                          .replaceAll('{product}', name)
                          .replaceAll('{qty}', qty),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue, width: 2),
                      foregroundColor: Colors.blue.shade900,
                    ),
                    child: Text(loc.get('remind_me'), style: const TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendStockWhatsApp(String number, String message) async {
    if (number.isEmpty) {
       _showError('No phone number set in profile!');
       return;
    }
    
    final cleanNum = number.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('https://wa.me/$cleanNum?text=${Uri.encodeComponent(message)}');
    
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showError('Could not open WhatsApp');
    }
  }

  Widget _buildSuggestionCard(Map<String, String> card) {
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(card['emoji'] ?? '💡', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    card['title'] ?? '',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                card['detail'] ?? '',
                style: const TextStyle(fontSize: 14, height: 1.4),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(String title, IconData icon, MaterialColor color, VoidCallback onTap, {double height = 130}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.shade300, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: color.shade700),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color.shade900)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBadgeButton(String title, IconData icon, MaterialColor color, VoidCallback onTap, {int badgeCount = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.shade300, width: 2),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 42, color: color.shade700),
                  const SizedBox(height: 8),
                  Text(title, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color.shade900)),
                ],
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareNavButton(String title, IconData icon, MaterialColor color, VoidCallback onTap, {double height = 130}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.shade300, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: height * 0.35, color: color.shade700),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: height * 0.12, fontWeight: FontWeight.bold, color: color.shade900)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareNavBadgeButton(String title, IconData icon, MaterialColor color, VoidCallback onTap, {int badgeCount = 0, double height = 130}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.shade300, width: 2),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: height * 0.35, color: color.shade700),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(title,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: height * 0.12, fontWeight: FontWeight.bold, color: color.shade900)),
                  ),
                ],
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text('$badgeCount',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySummaryCard(SalesProvider sales, bool isTablet) {
    final now = DateTime.now();
    final timeStr = '${now.day}/${now.month}/${now.year}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.blue.shade200, width: 1.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('📊', style: TextStyle(fontSize: isTablet ? 32 : 24)),
                const SizedBox(width: 8),
                Text("Today's Summary", 
                    style: TextStyle(fontSize: isTablet ? 22 : 17, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                const Spacer(),
                Text(timeStr, style: TextStyle(fontSize: isTablet ? 16 : 13, color: Colors.blue.shade400)),
              ],
            ),
            const SizedBox(height: 12),
            if (sales.todayTransactionCount == 0)
              Text('No sales logged today yet.\nTap the mic to log a sale!',
                  style: TextStyle(fontSize: 16, color: Colors.blue.shade700))
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryTile('💰', '₹${sales.todayRevenue.toStringAsFixed(0)}', 'Revenue'),
                  _summaryTile('📦', '${sales.todayUnitsSold}', 'Units Sold'),
                  _summaryTile('🏆', sales.topProductToday ?? '-', 'Top Item'),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(String emoji, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(value,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildStockoutWarning(InventoryProvider inv) {
    final critical = inv.criticalStockProducts;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.red.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.red, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('⚠️', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Text('Running Out Soon!',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 8),
            ...critical.map((p) {
              final days = inv.daysRemaining[p['id']];
              final daysStr = days != null && days >= 0
                  ? '~${days.toStringAsFixed(1)} days left'
                  : 'Check stock';
              final emoji = productEmoji(p['name'].toString());
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text('$emoji ', style: const TextStyle(fontSize: 20)),
                    Expanded(
                      child: Text(p['name'].toString(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Text(daysStr, style: const TextStyle(fontSize: 14, color: Colors.red)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

