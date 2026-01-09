// lib/screens/cashier_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // Para birimi formatlama için eklendi

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  // Kasa toplamını tutacak değişken
  double _totalCash = 0.0;
  bool _isLoading = true;
  String _errorMessage = '';

  // API adresini GÜNCEL IP: 192.168.1.134:5000 olarak düzeltildi
  final String _apiUrl = 'http://192.168.1.134:5000/api/cashier/total'; 

  // Para birimi formatlayıcı (Türk Lirası için)
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR', 
    symbol: '₺', // Veya ' TL' kullanabilirsiniz
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _fetchTotalCash();
  }

  // API'den toplam kasayı çeken fonksiyon (Güncellendi)
  Future<void> _fetchTotalCash() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        // Hata giderme: Türkçe karakterler için decode
        final data = json.decode(utf8.decode(response.bodyBytes)); 
        
        if (!mounted) return;
        setState(() {
          // Gelen verinin num (int/double) olduğundan emin ol
          _totalCash = (data['total_amount'] is num) ? data['total_amount'].toDouble() : 0.0;
          _isLoading = false;
        });

      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'API bağlantı hatası: Sunucu ${response.statusCode} döndürdü.';
          _isLoading = false;
        });
        _showSnackBar('Sunucu hatası! Lütfen API loglarını kontrol edin.');
      }
    } catch (e) {
      if (!mounted) return;
      // Ağ veya bağlantı hatası durumunda
      setState(() {
        _errorMessage = 'Bağlantı kurulamadı. Flask API çalışıyor ve IP adresiniz doğru mu?';
        _isLoading = false;
      });
      _showSnackBar('❌ Bağlantı Hatası! Sunucuya erişilemiyor.');
    }
  }

  // Kullanıcıya bilgi veren SnackBar fonksiyonu
  void _showSnackBar(String message) {
     if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                duration: const Duration(seconds: 4),
            ),
        );
    }
  }

  // Yenileme için kullanabileceğiniz özel bir Widget
  Widget _buildRefreshButton() {
    return ElevatedButton.icon(
      onPressed: _fetchTotalCash, // Yenileme işlemi
      icon: const Icon(Icons.refresh, color: Colors.white),
      label: const Text('Kasa Verilerini Yenile', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3498db),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Daha modern bir görünüm
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Toplam kasayı formatla (Örn: 15.450,50 ₺)
    final String formattedTotal = _currencyFormat.format(_totalCash);

    return Scaffold(
      appBar: AppBar(
        title: const Text('💵 Kasa Toplamı', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFe74c3c), 
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator(color: Color(0xFF3498db))
              else if (_errorMessage.isNotEmpty)
                Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage, 
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    _buildRefreshButton(), 
                  ],
                )
              else ...[
                const Text(
                  'Toplam Kasa (Net Gelir):',
                  style: TextStyle(fontSize: 22, color: Color(0xFF2c3e50)),
                ),
                const SizedBox(height: 10),
                // Güncel formatlanmış kasayı göster
                Text(
                  formattedTotal, 
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2ecc71), 
                  ),
                ),
                const SizedBox(height: 40),
                _buildRefreshButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}