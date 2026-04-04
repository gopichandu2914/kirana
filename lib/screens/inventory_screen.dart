import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/localization.dart';
import '../providers/inventory_provider.dart';
import '../providers/settings_provider.dart';
import '../services/gemini_service.dart';
import 'dashboard/home_screen.dart' show productEmoji;

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<InventoryProvider>(context, listen: false).fetchProducts());
  }

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Text('➕', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(loc.get('add_product'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(labelText: loc.get('product_name'), prefixIcon: const Icon(Icons.inventory_2)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(labelText: loc.get('stock_qty_label'), prefixIcon: const Icon(Icons.numbers)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(labelText: loc.get('price'), prefixIcon: const Icon(Icons.sell)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  labelText: 'Cost Price (₹) — for profit',
                  prefixIcon: Icon(Icons.price_check),
                  helperText: 'Optional: how much you paid per unit',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.get('cancel'), style: const TextStyle(fontSize: 18, color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 50)),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && qtyCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                Provider.of<InventoryProvider>(context, listen: false).addProduct(
                  nameCtrl.text,
                  int.tryParse(qtyCtrl.text) ?? 0,
                  double.tryParse(priceCtrl.text) ?? 0.0,
                  costPrice: double.tryParse(costCtrl.text) ?? 0.0,
                );
                Navigator.pop(context);
              }
            },
            child: Text(loc.get('save'), style: const TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  void _showAddStockDialog(BuildContext context, Map<String, dynamic> product, InventoryProvider inv) {
    final qtyCtrl = TextEditingController();
    final emoji = productEmoji(product['name'].toString());
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Expanded(child: Text('${loc.get('add_stock_title')}\n${product['name']}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${loc.get('current_stock')}: ${product['quantity']} units',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: loc.get('quantity_to_add'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.get('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text) ?? 0;
              if (qty > 0) {
                inv.updateProductStock(product['id'], qty);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Added $qty units to ${product['name']}'),
                    backgroundColor: Colors.blue.shade700,
                  ),
                );
              }
            },
            child: Text(loc.get('add_stock_title'), style: const TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSaleDialog(BuildContext context, Map<String, dynamic> product, InventoryProvider inv) {
    final qtyCtrl = TextEditingController(text: '1');
    final emoji = productEmoji(product['name'].toString());
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${loc.get('log_sale')}\n${product['name']}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${loc.get('current_stock')}: ${product['quantity']} units',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: loc.get('quantity_sold'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.get('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text) ?? 1;
              inv.logSale(product['id'], qty);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Sold $qty × ${product['name']}'),
                  backgroundColor: Colors.green.shade700,
                ),
              );
            },
            child: Text(loc.get('confirm_sale'), style: const TextStyle(fontSize: 15, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  final Map<int, String> _productPitches = {};
  final Map<int, bool> _loadingPitches = {};

  Future<void> _generatePitch(int productId, String name) async {
    setState(() => _loadingPitches[productId] = true);
    final lang = Provider.of<SettingsProvider>(context, listen: false).locale.languageCode;
    final pitch = await GeminiService.generateProductPitch(name, lang);
    if (mounted) {
      setState(() {
        _productPitches[productId] = pitch;
        _loadingPitches[productId] = false;
      });
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
        title: Text('📦 ${loc.get('inventory')}', 
            style: TextStyle(fontSize: isTablet ? 32 : 28, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: inv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Profit Summary Banner ──
                if (inv.products.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.green.shade700, Colors.green.shade500]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statChip('💰', '₹${inv.totalInventoryValue.toStringAsFixed(0)}', 'Value'),
                        Container(width: 1.5, height: 50, color: Colors.white38),
                        _statChip('💸', '₹${inv.totalInventoryCost.toStringAsFixed(0)}', 'Cost'),
                        Container(width: 1.5, height: 50, color: Colors.white38),
                        _statChip('📈', '₹${inv.totalPotentialProfit.toStringAsFixed(0)}', 'Profit'),
                      ],
                    ),
                  ),

                // ── AI Selling Header Placeholder ──
                // (We can add a toggle here later if needed)

                // ── Product List (Responsive Grid/List) ──
                Expanded(
                  child: inv.products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📦', style: TextStyle(fontSize: 80)),
                          const SizedBox(height: 16),
                          Text(loc.get('tap_product_to_add').replaceFirst(':', ''), 
                              style: TextStyle(fontSize: isTablet ? 24 : 20, color: Colors.grey.shade600),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.blue.shade700,
                                side: BorderSide(color: Colors.blue.shade700)),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Load Sample Data'),
                            onPressed: () => inv.seedSampleData(),
                          ),
                        ],
                      ),
                    )
                  : (isTablet 
                      ? GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: inv.products.length,
                        itemBuilder: (context, index) => _buildProductCard(context, inv, inv.products[index], loc, true),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: inv.products.length,
                        itemBuilder: (context, index) => _buildProductCard(context, inv, inv.products[index], loc, false),
                      )),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        icon: Icon(Icons.add, size: isTablet ? 48 : 40),
        label: Text(loc.get('add_product'), style: TextStyle(fontSize: isTablet ? 24 : 22, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, InventoryProvider inv, Map<String, dynamic> p, AppLocalizations loc, bool isTablet) {
    final isLowStock = p['quantity'] <= p['min_threshold'];
    final int stockQty = p['quantity'];
    final double price = p['price'];
    final double costPrice = p['cost_price'] ?? 0.0;
    final double profit = inv.profitPerUnitFor(p);
    final double margin = inv.profitMarginFor(p);
    final double totalValue = stockQty * price;
    final double titleSize = isTablet ? 22 : 26;
    final double emojiSize = isTablet ? 32 : 40;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isLowStock ? Colors.red : Colors.transparent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: SingleChildScrollView( // Added scroll for smaller card content in grid
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Name Row
              Row(
                children: [
                  Text(productEmoji(p['name'].toString()), style: TextStyle(fontSize: emojiSize)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(p['name'],
                        style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold)),
                  ),
                  // Stock badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLowStock ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$stockQty',
                      style: TextStyle(
                        fontSize: titleSize, fontWeight: FontWeight.bold,
                        color: isLowStock ? Colors.red : Colors.green.shade800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.grey, size: isTablet ? 24 : 28),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Product?'),
                          content: const Text('This will permanently remove this product.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) inv.deleteProduct(p['id']);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Price & Profit Row
              Text('Sell: ₹$price | Cost: ₹$costPrice',
                  style: TextStyle(fontSize: isTablet ? 12 : 14, color: Colors.grey.shade700)),
              Row(
                children: [
                  Text('Profit: ₹${profit.toStringAsFixed(1)}',
                      style: TextStyle(
                          fontSize: isTablet ? 13 : 15,
                          color: profit >= 0 ? Colors.green.shade700 : Colors.red,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: profit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('${margin.toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 12,
                            color: profit >= 0 ? Colors.green.shade800 : Colors.red,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              // AI Pitch
              if (_productPitches.containsKey(p['id']))
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200, width: 1.5),
                  ),
                  child: Text(
                    _productPitches[p['id']]!,
                    style: TextStyle(fontSize: isTablet ? 14 : 16, color: Colors.brown.shade800, fontStyle: FontStyle.italic),
                  ),
                ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade900,
                        minimumSize: Size(0, isTablet ? 50 : 60),
                      ),
                      icon: const Icon(Icons.point_of_sale, size: 24),
                      label: Text(loc.get('sell'), style: TextStyle(fontSize: isTablet ? 16 : 18)),
                      onPressed: () => _showSaleDialog(context, p, inv),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade900,
                        minimumSize: Size(0, isTablet ? 50 : 60),
                      ),
                      icon: const Icon(Icons.add_box, size: 24),
                      label: Text(loc.get('add_stock'), style: TextStyle(fontSize: isTablet ? 16 : 18)),
                      onPressed: () => _showAddStockDialog(context, p, inv),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loadingPitches[p['id']] == true)
                const Center(child: LinearProgressIndicator())
              else
                OutlinedButton.icon(
                  onPressed: () => _generatePitch(p['id'], p['name']),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    side: const BorderSide(color: Colors.amber, width: 1.5),
                    backgroundColor: Colors.amber.shade50,
                  ),
                  icon: const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                  label: Text(loc.get('ai_pitch'), style: const TextStyle(fontSize: 14, color: Colors.brown)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}
