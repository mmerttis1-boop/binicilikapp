// lib/screens/student_detail_screen.dart dosyası

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StudentDetailScreen extends StatefulWidget {
  // Gösterilecek öğrencinin listedeki indeksi
  final int studentIndex; 
  
  // API Base adresi (YENİ GÜNCEL IP: http://10.159.74.210:5000/api/students/)
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
    
    // API adresi: http://10.159.74.210:5000/api/students/INDEX
    final url = Uri.parse('${widget.apiUrlBase}${widget.studentIndex}');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _studentData = data as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Detay çekilemedi. Hata kodu: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Bağlantı hatası: $e';
        _isLoading = false;
      });
      // Bağlantı hatası durumunda kullanıcıya görsel geri bildirim verebiliriz
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Bağlantı Hatası: Flask sunucusuna (10.159.74.210:5000) erişilemiyor.')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // SİLME FONKSİYONLARI (DELETE)
  // ---------------------------------------------------------------------

  // Öğrenciyi Flask API'sinden silme
  Future<void> _deleteStudent() async {
    // API adresi: http://10.159.74.210:5000/api/students/INDEX (apiUrlBase, home_screen'den geliyor ve güncel)
    final url = Uri.parse('${widget.apiUrlBase}${widget.studentIndex}');

    try {
        final response = await http.delete(url);

        if (response.statusCode == 200) {
            // Silme başarılı, kullanıcıya bilgi ver
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Öğrenci kaydı başarıyla silindi.')),
            );
            
            // Ana ekrana geri dön ve ana ekranın verileri yenilemesini sağla (true döndürülüyor)
            if (mounted) {
                // true döndürerek home_screen'deki listenin yeniden çekilmesini tetikliyoruz.
                Navigator.pop(context, true); 
            }
        } else {
            // Hata durumunda kullanıcıyı bilgilendir
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('❌ Silme başarısız! Hata kodu: ${response.statusCode}')),
            );
        }
    } catch (e) {
        // Bağlantı hatası durumunda kullanıcıyı bilgilendir
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Bağlantı hatası: Öğrenci silinemedi.')),
        );
    }
  }
  
  // Silme Onay Diyaloğu
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
                              Navigator.of(context).pop(); // Diyaloğu kapat
                          },
                      ),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                              Navigator.of(context).pop(); // Diyaloğu kapat
                              _deleteStudent(); // Silme işlemini başlat
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenci Detayı', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF3498db),
        foregroundColor: Colors.white,
        // YENİ: Silme butonu
        actions: [
            IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent), // Silme için kırmızı renk
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

                              // YENİ EKLENEN SATIR: Ders Saati
                              _buildDetailRow(
                                'Ders Saati', 
                                _studentData!['saat'] ?? 'Yok', 
                                Icons.access_time,
                              ),
                              
                              // Detay Satırları
                              _buildDetailRow(
                                'Ders Tarihi', 
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
                                // Odenen tutar yoksa veya null ise 0.00 göster
                                '${_studentData!['odenen_tutar'] != null ? (_studentData!['odenen_tutar'] as num).toStringAsFixed(2) : '0.00'} TL', 
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
                                // Kayıt zamanını sadece tarih olarak göster
                                _studentData!['kayit_zamani']?.split('T')[0] ?? 'Bilinmiyor', 
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