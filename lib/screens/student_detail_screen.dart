// lib/screens/student_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // Para birimi formatlama için eklendi

class StudentDetailScreen extends StatefulWidget {
  // Gösterilecek öğrencinin listedeki indeksi (API ID'si)
  final int studentIndex; 
  // API Base adresi (http://192.168.1.134:5000/api/students/)
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
  // Kredi butonunun durumunu kontrol etmek için local değişken
  bool _isCreditUpdating = false; 

  // Para birimi formatlayıcı (Türk Lirası için)
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

  // ---------------------------------------------------------------------
  // VERİ ÇEKME FONKSİYONLARI (GET)
  // ---------------------------------------------------------------------
  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    // API adresi: http://192.168.1.134:5000/api/students/INDEX
    final url = Uri.parse('${widget.apiUrlBase}${widget.studentIndex}');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Türkçe karakter desteği için decode
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
            _error = 'Detay çekilemedi. Hata kodu: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Bağlantı hatası: API\'ye erişilemiyor.';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('❌ Bağlantı Hatası: Flask sunucusuna erişilemiyor.')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Kredi Düşürme (POST)
  // ---------------------------------------------------------------------

  Future<void> _decreaseCredit() async {
    if (_isCreditUpdating) return; 

    final currentCredits = _studentData?['remaining_credits'] ?? 0;
    if (currentCredits <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Kredi düşürme başarısız. Kredi zaten 0 ders.')),
        );
      }
      return;
    }

    setState(() {
      _isCreditUpdating = true;
    });

    // API adresi: http://192.168.1.134:5000/api/students/INDEX/credit_decrease
    final url = Uri.parse('${widget.apiUrlBase}${widget.studentIndex}/credit_decrease');

    try {
      final response = await http.post(url); 

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final newCredits = data['new_credits'];
        
        // Kredi düştükten sonra detayları yeniden çek
        await _fetchDetail(); 
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('✅ Kredi başarıyla $newCredits derse düşürüldü.')),
          );
          // Home Screen'e başarılı işlem yapıldığı sinyalini gönder
          Navigator.pop(context, true); 
        }
      } else {
        String message = 'Kredi düşürme başarısız!';
        try {
            final errorData = json.decode(utf8.decode(response.bodyBytes));
            message = errorData['message'] ?? errorData['error'] ?? 'Hata kodu: ${response.statusCode}';
        } catch (_) {
             message = 'Hata kodu: ${response.statusCode}';
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $message')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Bağlantı hatası: Kredi düşürülemedi. Hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreditUpdating = false;
        });
      }
    }
  }

  void _showCreditDecreaseDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('❓ Kredi Düşürme Onayı'),
          content: const Text('Bu ders yapıldı mı? Öğrencinin kalan ders kredisini 1 azaltmak istediğinizden emin misiniz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop(); 
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.of(context).pop(); 
                _decreaseCredit(); 
              },
              child: const Text('Krediyi Düşür', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }


  // ---------------------------------------------------------------------
  // SİLME FONKSİYONLARI (DELETE)
  // ---------------------------------------------------------------------

  Future<void> _deleteStudent() async {
    final url = Uri.parse('${widget.apiUrlBase}${widget.studentIndex}');

    try {
        final response = await http.delete(url);

        if (response.statusCode == 200) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Öğrenci kaydı başarıyla silindi.')),
              );
              // Home Screen'e başarılı silme yapıldığı sinyalini gönder
              Navigator.pop(context, true); 
            }
        } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Silme başarısız! Hata kodu: ${response.statusCode}')),
              );
            }
        }
    } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('❌ Bağlantı hatası: Öğrenci silinemedi.')),
          );
        }
    }
  }
  
  void _showDeleteConfirmationDialog() {
      showDialog(
          context: context,
          builder: (BuildContext context) {
              return AlertDialog(
                  title: const Text('⚠️ Kaydı Sil Onayı'),
                  content: const Text('Bu öğrenci kaydını kesinlikle silmek istiyor musunuz? Bu işlem geri alınamaz.'),
                  actions: <Widget>[
                      TextButton(
                          child: const Text('İptal', style: TextStyle(color: Colors.grey)),
                          onPressed: () {
                              Navigator.of(context).pop(); 
                          },
                      ),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                              Navigator.of(context).pop(); 
                              _deleteStudent(); 
                          },
                          child: const Text('Sil', style: TextStyle(color: Colors.white)),
                      ),
                  ],
              );
          },
      );
  }

  // ---------------------------------------------------------------------
  // WIDGET YARDIMCI FONKSİYONLARI 
  // ---------------------------------------------------------------------
  
  // Flask API'den gelen gün numarasını Türkçe isme çevirir
  String _getDayName(int dayIndex) {
    switch (dayIndex) {
      case 0: return 'Pazar';
      case 1: return 'Pazartesi';
      case 2: return 'Salı';
      case 3: return 'Çarşamba';
      case 4: return 'Perşembe';
      case 5: return 'Cuma';
      case 6: return 'Cumartesi';
      default: return 'Bilinmiyor';
    }
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF3498db), size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF95a5a6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF2c3e50),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // WIDGET BUILD
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // API'den gelen verileri al veya varsayılan değerleri kullan
    final int remainingCredits = _studentData?['remaining_credits'] ?? 0; 
    
    // Tekrarlayan gün numarasını isme çevir
    final int recurringDayIndex = _studentData?['recurring_day_of_week'] ?? -1;
    final String nextRecurringDayName = _getDayName(recurringDayIndex);

    final String nextRecurringTime = _studentData?['recurring_time'] ?? 'Bilgi Yok';

    // Ödenen tutarı formatla
    final String odenenTutar = _studentData?['odenen_tutar'] != null 
        ? _currencyFormat.format(_studentData!['odenen_tutar'] as num)
        : _currencyFormat.format(0.0);
    
    // Kayıt zamanını sadece tarih olarak göster
    final String kayitZamani = _studentData?['kayit_zamani']?.split('T')[0] ?? 'Bilinmiyor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenci Detayı', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF3498db),
        foregroundColor: Colors.white,
        actions: [
            IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                tooltip: 'Kaydı Sil',
                onPressed: _showDeleteConfirmationDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('Hata: $_error', style: const TextStyle(color: Colors.red))),
                )
              : _studentData == null
                  ? const Center(child: Text('Öğrenci verisi bulunamadı.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // Başlık (Ad Soyad)
                                Center(
                                  child: Text(
                                    _studentData!['ad_soyad'] ?? 'Bilinmeyen Öğrenci',
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2ecc71)),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const Divider(height: 30, thickness: 2),
                                
                                // TEKRAR EDEN DERS BİLGİSİ
                                _buildDetailRow(
                                  'Tekrar Eden Ders (Sonraki)', 
                                  '$nextRecurringDayName, Saat: $nextRecurringTime', 
                                  Icons.repeat,
                                ),
                                const Divider(height: 10, thickness: 1),

                                // KALAN KREDİ BİLGİSİ
                                _buildDetailRow(
                                  'Kalan Ders Kredisi', 
                                  '$remainingCredits Ders', 
                                  Icons.card_membership,
                                ),
                                const Divider(height: 30, thickness: 2),

                                // KREDİ DÜŞÜRME BUTONU (Sadece kredi > 0 ise göster)
                                if (remainingCredits > 0)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                                    child: ElevatedButton.icon(
                                      icon: _isCreditUpdating 
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.remove_circle_outline),
                                      label: Text(_isCreditUpdating ? 'İşleniyor...' : '1 Ders Kredisini Düşür (Kalan: $remainingCredits)'), // Kalan krediyi göster
                                      onPressed: _isCreditUpdating ? null : _showCreditDecreaseDialog, // Onay dialogunu çağır
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange, 
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 50), 
                                      ),
                                    ),
                                  )
                                else 
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 10.0),
                                    child: Text(
                                      '⚠️ Kredi Bitti! Yeni paket alınması gerekiyor.',
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                
                                const Divider(height: 30, thickness: 2),

                                // MEVCUT DETAY SATIRLARI
                                _buildDetailRow(
                                  'Ders Saati (İlk Kayıt)', 
                                  _studentData!['saat'] ?? 'Yok', 
                                  Icons.access_time,
                                ),
                                _buildDetailRow(
                                  'Ders Tarihi (İlk Kayıt)', 
                                  _studentData!['tarih'] ?? 'Yok', 
                                  Icons.calendar_today,
                                ),
                                _buildDetailRow(
                                  'Paket/Ücret Türü', 
                                  _studentData!['ucret_turu'] ?? 'Belirtilmemiş', 
                                  Icons.wallet_giftcard,
                                ),
                                _buildDetailRow(
                                  'Ödenen Tutar', 
                                  odenenTutar, // Formatlanmış tutar
                                  Icons.monetization_on,
                                ),
                                _buildDetailRow(
                                  'Veli Telefon', 
                                  _studentData!['veli_telefon'] ?? 'Yok', 
                                  Icons.phone,
                                ),
                                _buildDetailRow(
                                  'Sınıfı', 
                                  _studentData!['sinif'] ?? 'Belirtilmemiş', 
                                  Icons.school,
                                ),
                                _buildDetailRow(
                                  'At Bilgisi', 
                                  _studentData!['at_bilgisi'] ?? 'Yok', 
                                  Icons.sports_kabaddi,
                                ),
                                _buildDetailRow(
                                  'Öğretmen', 
                                  _studentData!['ogretmen'] ?? 'Bilinmiyor', 
                                  Icons.person_pin,
                                ),
                                _buildDetailRow(
                                  'Kayıt Zamanı (API)', 
                                  kayitZamani, // Sadece tarih
                                  Icons.schedule,
                                ),
                              ],
                            ),
                          ),
                      ),
                    ),
    );
  }
}