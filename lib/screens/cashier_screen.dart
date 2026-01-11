// lib/screens/cashier_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  double _totalCash = 0.0;
  bool _isLoading = true;
  String _errorMessage = '';

  // YENİ RENDER API ADRESİ
  final String _apiUrl = 'https://binicilikapp-g73g.onrender.com/api/cashier/total'; 

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR', 
    symbol: '₺', 
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _fetchTotalCash();
  }

  Future<void> _fetchTotalCash() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Render bazen geç yanıt verebilir (uyku modu), timeout süresini uzun tutmak iyidir
      final response = await http.get(Uri.parse(_apiUrl)).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)); 
        
        if (!mounted) return;
        setState(() {
          _totalCash = (data['total_amount'] is num) ? data['total_amount'].toDouble() : 0.0;
          _isLoading = false;
        });

      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Sunucu Hatası: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Hata mesajını daha kullanıcı dostu yaptık
        _errorMessage = 'Sunucuya bağlanılamadı.\n(Uygulama uyanıyor olabilir, lütfen tekrar deneyin)';
        _isLoading = false;
      });
      _showSnackBar('Bağlantı Hatası! Lütfen internetinizi kontrol edin.');
    }
  }

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

  Widget _buildRefreshButton() {
    return ElevatedButton.icon(
      onPressed: _fetchTotalCash,
      icon: const Icon(Icons.refresh, color: Colors.white),
      label: const Text('Kasa Verilerini Yenile', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3498db),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            children: [
              if (_isLoading)
                const Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF3498db)),
                    SizedBox(height: 20),
                    Text('Sunucu uyandırılıyor, lütfen bekleyin...', 
                         style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                )
              else if (_errorMessage.isNotEmpty)
                Column(
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.red, size: 60),
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
                Text(
                  formattedTotal, 
                  style: const TextStyle(
                    fontSize: 40, // Boyutu biraz küçülttüm sığması için
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