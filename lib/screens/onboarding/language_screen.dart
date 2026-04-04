import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization.dart';
import '../../providers/settings_provider.dart';
import 'profile_setup_screen.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.language, size: 100, color: Colors.green),
              const SizedBox(height: 32),
              Text(
                loc.get('select_language'),
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
              const SizedBox(height: 48),
              _buildLangBtn(context, loc.get('english'), 'en'),
              const SizedBox(height: 20),
              _buildLangBtn(context, loc.get('telugu'), 'te'),
              const SizedBox(height: 20),
              _buildLangBtn(context, loc.get('hindi'), 'hi'),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
                  );
                },
                child: Text(loc.get('next')),
              ),
              const SizedBox(height: 24),
              const Text(
                'Choose your language and tap Next to continue',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangBtn(BuildContext context, String text, String code) {
    final settings = Provider.of<SettingsProvider>(context);
    final isSelected = settings.locale.languageCode == code;

    return InkWell(
      onTap: () {
        settings.setLanguage(code);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade300,
            width: 2.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 22,
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
