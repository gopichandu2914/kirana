import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../core/localization.dart';
import '../dashboard/home_screen.dart';
import 'phone_sign_in_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final AuthService _auth = AuthService();
  bool _isLoading = false;

  void _handleSignIn() async {
    setState(() => _isLoading = true);
    final user = await _auth.signInWithGoogle();
    
    if (user != null) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign in. Please check your internet.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Prominent Cloud Sync Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_done, size: 100, color: Colors.green),
                ),
              ),
              const SizedBox(height: 42),
              
              // Title
              Text(
                loc.get('app_name'),
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(color: Colors.green.shade900),
              ),
              const SizedBox(height: 24),
              
              // Localized Subtitle
              Text(
                loc.get('login_to_backup'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
              ),
              const Spacer(),
              
              // Google Sign-In Button
              if (_isLoading)
                const Center(child: CircularProgressIndicator(strokeWidth: 4))
              else
                ElevatedButton.icon(
                  onPressed: _handleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.grey.shade300, width: 2),
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  icon: const Icon(Icons.login, size: 32, color: Colors.green),
                  label: Text(
                    loc.get('continue_with_google'), 
                  ),
                ),
              
              const SizedBox(height: 20),

              if (!_isLoading)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PhoneSignInScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    side: BorderSide(color: Colors.green.shade700, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(Icons.phone_android, size: 32, color: Colors.green.shade700),
                  label: Text(
                    loc.get('continue_with_phone_otp'),
                    style: TextStyle(fontSize: 18, color: Colors.green.shade900, fontWeight: FontWeight.bold),
                  ),
                ),
              
              const SizedBox(height: 32),
              
              // Localized Helper text
              Text(
                loc.get('sync_disclaimer'),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
