import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 👈 1. Import
import 'screens/login_screen.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Binicilik Okulu App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3498db), 
        ),
        useMaterial3: true,
      ),
      
      // 👇👇👇 EK KISIMLAR BURADA 👇👇👇

      // 2. Lokalizasyon Delegelerini Ekliyoruz
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      // 3. Desteklenen Dilleri Tanımlıyoruz
      supportedLocales: const [
        Locale('en', ''), // İngilizce (Varsayılan)
        Locale('tr', 'TR'), // Türkçe 🇹🇷
      ],

      home: const LoginScreen(), 
    );
  }
}