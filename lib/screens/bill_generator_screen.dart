import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/localization.dart';
import '../providers/inventory_provider.dart';
import '../providers/settings_provider.dart';
import 'dashboard/home_screen.dart' show productEmoji;

class BillGeneratorScreen extends StatefulWidget {
  const BillGeneratorScreen({super.key});

  @override
  State<BillGeneratorScreen> createState() => _BillGeneratorScreenState();
}

class _BillGeneratorScreenState extends State<BillGeneratorScreen> {
  final List<Map<String, dynamic>> _billItems = [];
  final _customerPhoneCtrl = TextEditingController();


  void _addProductToBill(Map<String, dynamic> product) {
    setState(() {
      final existing = _billItems.indexWhere((b) => b['product']['id'] == product['id']);
      if (existing >= 0) {
        _billItems[existing]['qty'] = (_billItems[existing]['qty'] as int) + 1;
      } else {
        _billItems.add({'product': product, 'qty': 1});
      }
    });
  }

  void _changeQty(int index, int delta) {
    setState(() {
      final newQty = (_billItems[index]['qty'] as int) + delta;
      if (newQty <= 0) {
        _billItems.removeAt(index);
      } else {
        _billItems[index]['qty'] = newQty;
      }
    });
  }

  double get _total => _billItems.fold(
      0.0, (sum, b) => sum + (b['product']['price'] as double) * (b['qty'] as int));

  void _sendBillWhatsApp() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final inv = Provider.of<InventoryProvider>(context, listen: false);

    final loc = AppLocalizations.of(context);
    if (_billItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(loc.get('add_items_first'))));
      return;
    }

    // First deduct sold items from inventory
    for (final b in _billItems) {
      await inv.logSale(b['product']['id'], b['qty']);
    }

    // Build receipt text
    final now = DateTime.now();
    String bill = '🧾 *${settings.shopName}*\n';
    bill += '📅 ${now.day}/${now.month}/${now.year}  ${now.hour}:${now.minute.toString().padLeft(2, '0')}\n';
    bill += '─────────────────────\n';
    for (final b in _billItems) {
      final emoji = productEmoji(b['product']['name'].toString());
      final price = b['product']['price'] as double;
      final qty = b['qty'] as int;
      bill += '$emoji ${b['product']['name']}\n   $qty × ₹$price = ₹${(qty * price).toStringAsFixed(0)}\n';
    }
    bill += '─────────────────────\n';
    bill += '💰 *${loc.get('total')}: ₹${_total.toStringAsFixed(0)}*\n';
    bill += '\n${loc.get('thank_you_shopping')} 🙏';

    final encodedBill = Uri.encodeComponent(bill);
    // Build WhatsApp URL with customer number
    final cleanNum = _customerPhoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url;
    if (cleanNum.isNotEmpty) {
      url = Uri.parse('https://wa.me/$cleanNum?text=$encodedBill');
    } else {
      // No number — open share picker  
      url = Uri.parse('https://wa.me/?text=$encodedBill');
    }

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      setState(() => _billItems.clear());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open WhatsApp.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = Provider.of<InventoryProvider>(context);
    final loc = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isTablet ? 100 : 80,
        title: Text(loc.get('bill_generator'), 
            style: TextStyle(fontSize: isTablet ? 32 : 28, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: isTablet 
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── LEFT SIDE: Inputs & Product Picker ──
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCustomerInput(loc, isTablet),
                      const SizedBox(height: 32),
                      Text(loc.get('tap_product_to_add'),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildProductGrid(inv, isTablet),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              // ── RIGHT SIDE: Current Bill ──
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Expanded(child: _buildBillList(loc, isTablet)),
                    _buildTotalSection(loc, isTablet),
                  ],
                ),
              ),
            ],
          )
        : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCustomerInput(loc, false),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(loc.get('tap_product_to_add'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      _buildProductHorizontalList(inv),
                      const Divider(thickness: 1.5),
                      SizedBox(
                        height: 400, // Fixed height for bill list in phone view to keep it scrollable
                        child: _buildBillList(loc, false),
                      ),
                    ],
                  ),
                ),
              ),
              _buildTotalSection(loc, false),
            ],
          ),
    );
  }

  Widget _buildCustomerInput(AppLocalizations loc, bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 0 : 12, vertical: 12),
      child: TextField(
        controller: _customerPhoneCtrl,
        keyboardType: TextInputType.phone,
        style: TextStyle(fontSize: isTablet ? 24 : 20),
        decoration: InputDecoration(
          labelText: loc.get('customer_whatsapp'),
          labelStyle: TextStyle(fontSize: isTablet ? 20 : 18, fontWeight: FontWeight.bold),
          hintText: '+91 98765 43210',
          prefixIcon: Icon(Icons.phone, color: Colors.green, size: isTablet ? 36 : 30),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear, size: isTablet ? 36 : 30),
            onPressed: () => _customerPhoneCtrl.clear(),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          helperText: loc.get('bill_helper_text'),
          helperStyle: TextStyle(fontSize: isTablet ? 16 : 14),
        ),
      ),
    );
  }

  Widget _buildProductGrid(InventoryProvider inv, bool isTablet) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: inv.products.length,
      itemBuilder: (context, i) => _buildProductItem(inv.products[i], true),
    );
  }

  Widget _buildProductHorizontalList(InventoryProvider inv) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: inv.products.length,
        itemBuilder: (context, i) => _buildProductItem(inv.products[i], false),
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> p, bool isTablet) {
    return GestureDetector(
      onTap: () => _addProductToBill(p),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade400, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(productEmoji(p['name'].toString()), style: TextStyle(fontSize: isTablet ? 40 : 34)),
            const SizedBox(height: 4),
            Text(
              p['name'],
              style: TextStyle(fontSize: isTablet ? 18 : 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
            Text('₹${p['price']}',
                style: TextStyle(fontSize: isTablet ? 16 : 14, color: Colors.green.shade900, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBillList(AppLocalizations loc, bool isTablet) {
    if (_billItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🧾', style: TextStyle(fontSize: isTablet ? 80 : 60)),
            const SizedBox(height: 12),
            Text(loc.get('tap_product_to_add').replaceFirst(':', ''),
                style: TextStyle(fontSize: isTablet ? 22 : 18, color: Colors.grey.shade600), textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _billItems.length,
      itemBuilder: (context, i) {
        final b = _billItems[i];
        final p = b['product'] as Map<String, dynamic>;
        final qty = b['qty'] as int;
        final price = p['price'] as double;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Text(productEmoji(p['name'].toString()), style: TextStyle(fontSize: isTablet ? 44 : 38)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name'], style: TextStyle(fontSize: isTablet ? 24 : 22, fontWeight: FontWeight.bold)),
                      Text('₹$price × $qty = ₹${(price * qty).toStringAsFixed(0)}',
                          style: TextStyle(fontSize: isTablet ? 20 : 18, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_circle, color: Colors.red, size: isTablet ? 36 : 30),
                      onPressed: () => _changeQty(i, -1),
                    ),
                    Text('$qty', style: TextStyle(fontSize: isTablet ? 24 : 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.add_circle, color: Colors.green, size: isTablet ? 36 : 30),
                      onPressed: () => _changeQty(i, 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTotalSection(AppLocalizations loc, bool isTablet) {
    if (_billItems.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 8, 16, isTablet ? 40 : 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${loc.get('total')}:', style: TextStyle(fontSize: isTablet ? 32 : 26, fontWeight: FontWeight.bold)),
              Text('₹${_total.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: isTablet ? 40 : 30, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: isTablet ? 72 : 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: Text('📲', style: TextStyle(fontSize: isTablet ? 28 : 22)),
              label: Text(loc.get('send_bill_whatsapp'), 
                  style: TextStyle(fontSize: isTablet ? 24 : 18, fontWeight: FontWeight.bold)),
              onPressed: _sendBillWhatsApp,
            ),
          ),
        ],
      ),
    );
  }
}
