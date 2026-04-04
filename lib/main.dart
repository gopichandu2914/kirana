import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/localization.dart';
import 'providers/settings_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/sales_provider.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/onboarding/language_screen.dart';
import 'screens/dashboard/home_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await AuthService.initialize(); // Required for 7.x
  await NotificationService().init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
      ],
      child: const KiranaApp(),
    ),
  );
}

class KiranaApp extends StatelessWidget {
  const KiranaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'Smart Kirana AI',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.green,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, primary: Colors.green),
            useMaterial3: true,
            // Senior-friendly typography (Large & Clear)
            textTheme: const TextTheme(
              displayLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black),
              displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
              headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
              bodyLarge: TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w500),
              bodyMedium: TextStyle(fontSize: 18, color: Colors.black87),
              labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            // Ultra-large buttons for physical ease of use
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 58),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          locale: settings.locale,
          supportedLocales: const [
            Locale('en', ''),
            Locale('te', ''),
            Locale('hi', ''),
          ],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              if (snapshot.hasData) {
                // User is signed in
                return const HomeScreen();
              } else {
                // User is not signed in
                // ALWAYS start with Language screen for the demo flow
                // (It will then navigate to Profile -> Sign In)
                return const LanguageScreen();
              }
            },
          ),
        );
      },
    );
  }
}
