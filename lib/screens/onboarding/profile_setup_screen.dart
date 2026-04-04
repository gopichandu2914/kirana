import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization.dart';
import '../../providers/settings_provider.dart';
import '../auth/sign_in_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _supplierPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill if we already have data saved
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _nameController.text = settings.shopName;
    _ownerPhoneController.text = settings.whatsappNumber;
    _supplierPhoneController.text = settings.supplierWhatsapp;
  }

  void _save(BuildContext context) {
    if (_nameController.text.isEmpty || _supplierPhoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill Shop Name and Supplier WhatsApp number')),
      );
      return;
    }
    
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    settings.saveProfile(
      _nameController.text.trim(),
      _ownerPhoneController.text.trim(),
      _supplierPhoneController.text.trim(),
    );
    
    // Mark first launch as complete so main.dart shows SignIn instead of Language
    settings.completeFirstLaunch();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.get('profile'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.storefront, size: 100, color: Colors.green),
              const SizedBox(height: 32),
              
              // Shop Name
              _buildLargeField(
                label: loc.get('shop_name'),
                controller: _nameController,
                icon: Icons.shopping_cart,
                hint: 'e.g. Ramu Kirana Store',
              ),
              const SizedBox(height: 24),

              // Owner phone
              _buildLargeField(
                label: loc.get('whatsapp_number'),
                controller: _ownerPhoneController,
                icon: Icons.person,
                hint: '+91 9876543210',
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              // Supplier WhatsApp
              _buildLargeField(
                label: loc.get('supplier_whatsapp'),
                controller: _supplierPhoneController,
                icon: Icons.local_shipping,
                hint: '+91 9876543210',
                keyboard: TextInputType.phone,
                isImportant: true,
              ),

              const SizedBox(height: 48),

              ElevatedButton(
                onPressed: () => _save(context),
                child: Text(loc.get('save_and_continue')),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    TextInputType keyboard = TextInputType.text,
    bool isImportant = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18, // 20 -> 18
              fontWeight: FontWeight.bold,
              color: isImportant ? Colors.green.shade800 : Colors.black87,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 20), // 22 -> 20
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 16, color: Colors.grey.shade400), // 18 -> 16
            prefixIcon: Icon(icon, size: 30, color: isImportant ? Colors.green : Colors.grey),
            filled: true,
            fillColor: isImportant ? Colors.green.shade50 : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: isImportant ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          ),
        ),
      ],
    );
  }
}
