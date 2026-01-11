// lib/screens/student_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class StudentDetailScreen extends StatefulWidget {
  final int studentIndex; 
  final String apiUrlBase; 

  const StudentDetailScreen({
    super.key, 
    required this.studentIndex,
    required this.apiUrlBase, 
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  Map<String, dynamic>? _studentData;
  bool _isLoading = true;
  String _error = '';
  bool _isCreditUpdating = false; 

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR', 
    symbol: '₺', 
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  // --- Veri Çekme (GET) ---
  Future<void> _fetchDetail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    // URL Yapılandırması (Render üzerinden)
    final url = Uri.parse('${widget.apiUrlBase}${widget.studentIndex}');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)); 
        if (mounted) {
          setState(() {
            _studentData = data as Map<String, dynamic>;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Detay çekilemedi. Sunucu hatası: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Bağlantı hatası: İnternet veya sunucu kaynaklı bir sorun oluştu.';
          _isLoading = false;
        });
      }
    }
  }

  // --- Kredi Düşürme (POST) ---
  Future<void> _decreaseCredit() async {
    if (_isCreditUpdating) return; 

    final currentCredits = _studentData?['remaining_credits'] ?? 0;
    if (currentCredits <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Kredi zaten 0. Daha fazla düşürülemez.')),
      );
      return;
    }

    setState(() { _isCreditUpdating = true; });

    final url = Uri.parse('${widget.apiUrlBase}${widget.studentIndex}/credit_decrease');

    try {
      final response = await http.post(url).timeout(const Duration(seconds: 20)); 

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final newCredits = data['new_credits'];
        
        await _fetchDetail(); // Ekranı güncelle
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Kredi düşürüldü. Kalan: $newCredits ders.')),
          );
          // Home screen'e yenileme yapması için true döndür ama sayfayı hemen kapatma
        }
      } else {
        throw Exception('İşlem başarısız oldu.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ İşlem sırasında bir hata oluştu.')),
        );
      }
    } finally {
      if (mounted) setState(() { _isCreditUpdating = false; });
    }
  }

  // --- Silme Fonksiyonu (DELETE) ---
  Future<void> _deleteStudent() async {
    final url = Uri.parse('${widget.apiUrlBase}${widget.studentIndex}');

    try {
      final response = await http.delete(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Öğrenci kaydı başarıyla silindi.')),
          );
          Navigator.pop(context, true); // Ana ekrana dön ve listeyi yenile
        }
      } else {
        throw Exception();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Silme işlemi başarısız.')),
        );
      }
    }
  }

  // --- Onay Dialogları ---
  void _showCreditDecreaseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❓ Kredi Düşürülsün mü?'),
        content: const Text('Bu dersin yapıldığını onaylıyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () { Navigator.pop(context); _decreaseCredit(); },
            child: const Text('Evet, Düşür', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Kaydı Sil'),
        content: const Text('Bu işlem geri alınamaz. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { Navigator.pop(context); _deleteStudent(); },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- Yardımcı Metodlar ---
  String _getDayName(int dayIndex) {
    const days = ['Pazar', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi'];
    if (dayIndex >= 0 && dayIndex < 7) return days[dayIndex];
    return 'Belirlenmedi';
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF3498db)),
      title: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int remainingCredits = _studentData?['remaining_credits'] ?? 0;
    final String odenenTutar = _currencyFormat.format(_studentData?['odenen_tutar'] ?? 0);
    final String kayitZamani = _studentData?['kayit_zamani']?.split('T')[0] ?? 'Bilinmiyor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenci Detayı'),
        backgroundColor: const Color(0xFF3498db),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            onPressed: _showDeleteConfirmationDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFf8f9fa),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                          ),
                          child: Text(
                            _studentData?['ad_soyad'] ?? 'Bilinmeyen',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2c3e50)),
                          ),
                        ),
                        _buildDetailRow('Kalan Ders Kredisi', '$remainingCredits Ders', Icons.confirmation_number),
                        _buildDetailRow('Sonraki Ders', '${_getDayName(_studentData?['recurring_day_of_week'] ?? -1)} - ${_studentData?['recurring_time'] ?? 'Yok'}', Icons.repeat),
                        const Divider(),
                        if (remainingCredits > 0)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _isCreditUpdating ? null : _showCreditDecreaseDialog,
                              icon: _isCreditUpdating 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.check_circle_outline, color: Colors.white),
                              label: Text(_isCreditUpdating ? 'Güncelleniyor...' : 'Dersi Yapıldı İşaretle (-1 Kredi)', style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                        const Divider(),
                        _buildDetailRow('Paket Türü', _studentData?['ucret_turu'] ?? '-', Icons.inventory),
                        _buildDetailRow('Ödenen Toplam', odenenTutar, Icons.payments),
                        _buildDetailRow('Telefon', _studentData?['veli_telefon'] ?? '-', Icons.phone),
                        _buildDetailRow('At Bilgisi', _studentData?['at_bilgisi'] ?? '-', Icons.pets),
                        _buildDetailRow('Öğretmen', _studentData?['ogretmen'] ?? '-', Icons.person),
                        _buildDetailRow('Kayıt Tarihi', kayitZamani, Icons.date_range),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }
}