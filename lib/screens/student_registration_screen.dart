// lib/screens/student_registration_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Klavyeyi kapatmak için eklendi
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// Paket seçeneklerini tanımlayan enum yapısı
enum PaketSecenekleri { sekizKredi, yirmiDortKredi, diger }

class StudentRegistrationScreen extends StatefulWidget {
  final DateTime selectedDate;

  const StudentRegistrationScreen({super.key, required this.selectedDate});

  @override
  State<StudentRegistrationScreen> createState() => _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  // Form Kontrolcüler
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _adSoyadController = TextEditingController();
  final TextEditingController _sinifController = TextEditingController();
  final TextEditingController _veliTelefonController = TextEditingController();
  final TextEditingController _atBilgisiController = TextEditingController();
  final TextEditingController _digerUcretController = TextEditingController();

  // Saat bilgisini tutmak için
  TimeOfDay _selectedTime = TimeOfDay.now(); 

  // Seçili paket durumu
  PaketSecenekleri? _seciliPaket = PaketSecenekleri.sekizKredi;
  
  // Kayıt işlemi devam ediyor mu?
  bool _isSaving = false; 

  // Paketlerin örnek fiyatları (sabit değerler)
  final Map<PaketSecenekleri, double> _paketFiyatlari = {
    PaketSecenekleri.sekizKredi: 1500.0,
    PaketSecenekleri.yirmiDortKredi: 4000.0,
  };

  // API adresi GÜNCEL IP: 192.168.1.134:5000
  final String apiUrl = 'http://192.168.1.134:5000/api/students/register'; 


  @override
  void dispose() {
    _adSoyadController.dispose();
    _sinifController.dispose();
    _veliTelefonController.dispose();
    _atBilgisiController.dispose();
    _digerUcretController.dispose();
    super.dispose();
  }
  
  // Saat Seçiciyi Açan Fonksiyon
  Future<void> _selectTime(BuildContext context) async {
      final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: _selectedTime,
          builder: (context, child) {
              return MediaQuery(
                  data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
              );
          },
      );
      if (picked != null && picked != _selectedTime) {
          setState(() {
              _selectedTime = picked;
          });
      }
  }

  // Kayıt işlemini gerçekleştiren fonksiyon
  void _kayitYap() async { 
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Klavyeyi kapat
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    String ucretTuru;
    double odenenTutar;
    String ucretTuruForApi; // API'ye gönderilecek kredi bilgisini tutar

    // Ücret türünü ve tutarı belirle
    if (_seciliPaket == PaketSecenekleri.diger) {
      ucretTuru = "Diğer";
      ucretTuruForApi = "Tek Ders"; 
      odenenTutar = double.tryParse(_digerUcretController.text.replaceAll(',', '.')) ?? 0.0;
    } else {
      // Paket seçeneklerinden biri seçiliyorsa
      if (_seciliPaket == PaketSecenekleri.sekizKredi) {
        ucretTuru = "8 Kredi";
        ucretTuruForApi = "8 Ders"; 
        odenenTutar = _paketFiyatlari[PaketSecenekleri.sekizKredi] ?? 0.0;
      } else { // yirmiDortKredi
        ucretTuru = "24 Kredi";
        ucretTuruForApi = "24 Ders"; 
        odenenTutar = _paketFiyatlari[PaketSecenekleri.yirmiDortKredi] ?? 0.0;
      }
    }
    
    // Saati "HH:MM" formatına çevir
    String lessonTime = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    // Tarih formatını "dd/MM/yyyy" olarak formatla
    String formattedDate = DateFormat('dd/MM/yyyy').format(widget.selectedDate);

    // API'ye gönderilecek veri haritası
    Map<String, dynamic> ogrenciVerisi = {
      'tarih': formattedDate, 
      'saat': lessonTime, 
      'ad_soyad': _adSoyadController.text.trim(),
      'sinif': _sinifController.text.trim(),
      'veli_telefon': _veliTelefonController.text.trim(),
      'at_bilgisi': _atBilgisiController.text.trim(),
      'ucret_turu': ucretTuruForApi, // Flask'ın anlayacağı formatı gönder
      'odenen_tutar': odenenTutar, 
      'ogretmen': 'Giriş Yapan Öğretmen (TODO)', // TODO: Giriş yapan öğretmen bilgisini ekle
      'kayit_zamani': DateTime.now().toIso8601String(),
    };
    
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(ogrenciVerisi),
      );

      if (response.statusCode == 201) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Öğrenci kaydı başarılı! İlk ders kredisi düşürüldü.'),
                backgroundColor: Color(0xFF2ecc71),
              ),
            );
          // Başarılı işlem sonrası takvimin yenilenmesi için true döndür
          Navigator.pop(context, true); 
        }
      } else {
        if (mounted) {
          String errorBody = 'Sunucu Hatası';
          try {
            // Hata mesajını API'den çekmeyi dene
            final errorJson = json.decode(utf8.decode(response.bodyBytes));
            errorBody = errorJson['error'] ?? errorJson['message'] ?? errorJson.toString();
          } catch (_) {
            errorBody = response.body.isNotEmpty ? response.body : 'Sunucu Hatası';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Kayıt başarısız! Hata: ${response.statusCode} - $errorBody'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Bağlantı hatası: Flask API çalışıyor mu? (IP: 192.168.1.134:5000)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // RadioListTile'ları oluşturmak için yardımcı fonksiyon
  Widget _buildPaketRadio(PaketSecenekleri paket, String title, double? fiyat) {
    String subtitle = '';
    
    if (paket == PaketSecenekleri.sekizKredi) {
        subtitle = fiyat != null ? '${fiyat.toStringAsFixed(2)} TL (Kalan Kredi: 7)' : '';
    } else if (paket == PaketSecenekleri.yirmiDortKredi) {
        subtitle = fiyat != null ? '${fiyat.toStringAsFixed(2)} TL (Kalan Kredi: 23)' : '';
    } else {
        subtitle = 'Serbest Ücret Girişi (Tek Ders)';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: _seciliPaket == paket ? 3 : 1, // Seçili olana gölge ekle
      child: RadioListTile<PaketSecenekleri>(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _seciliPaket == paket ? const Color(0xFF3498db) : const Color(0xFF2c3e50))),
        subtitle: Text(subtitle),
        value: paket,
        groupValue: _seciliPaket,
        onChanged: _isSaving ? null : (PaketSecenekleri? value) {
          setState(() {
            _seciliPaket = value;
            // Diğer alanını temizle
            if (value != PaketSecenekleri.diger) {
                _digerUcretController.clear();
            }
          });
        },
        activeColor: const Color(0xFFe67e22),
      ),
    );
  }

  // Ortak TextField stilini oluşturmak için yardımcı widget
  Widget _buildTextField(
    TextEditingController controller, 
    String labelText, 
    IconData icon, 
    {TextInputType keyboardType = TextInputType.text, bool required = true, String? Function(String?)? validator}
  ) {
    // Telefon numarası için input formatter
    List<TextInputFormatter>? formatters;
    if (keyboardType == TextInputType.phone) {
        formatters = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: keyboardType == TextInputType.phone ? 'Örn: 5xx1234567' : null,
          prefixIcon: Icon(icon, color: const Color(0xFF95a5a6)),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFF3498db), width: 2),
          ),
        ),
        validator: validator ?? (value) {
          if (required && (value == null || value.isEmpty || value.trim().isEmpty)) {
            return '$labelText boş bırakılamaz.';
          }
          if (keyboardType == TextInputType.phone && value != null && value.length < 10 && value.isNotEmpty) {
            return 'Telefon numarası 10 hane olmalıdır.';
          }
          return null;
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenci Kaydı', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF3498db), 
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Tarih Bilgisi
                  Text(
                    'Ders Tarihi: ${DateFormat('dd.MM.yyyy').format(widget.selectedDate)}', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2c3e50)),
                  ),
                  const Divider(height: 30, thickness: 1),

                  // Saat Seçme Alanı
                  Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Row(
                          children: [
                              const Icon(Icons.schedule, color: Color(0xFFe67e22)),
                              const SizedBox(width: 15),
                              Expanded(
                                  child: Text(
                                      'Ders Saati: ${_selectedTime.format(context)}',
                                      style: const TextStyle(fontSize: 16, color: Color(0xFF2c3e50), fontWeight: FontWeight.bold),
                                  ),
                              ),
                              TextButton(
                                  onPressed: _isSaving ? null : () => _selectTime(context),
                                  child: const Text('Saat Seç / Değiştir', style: TextStyle(color: Color(0xFF3498db), fontWeight: FontWeight.bold)),
                              ),
                          ],
                      ),
                  ),
                  const Divider(height: 30, thickness: 1),
                  
                  // Öğrenci Bilgileri Giriş Alanları
                  _buildTextField(_adSoyadController, 'Öğrenci Adı Soyadı', Icons.person),
                  _buildTextField(_sinifController, 'Sınıfı (Opsiyonel)', Icons.school, required: false),
                  _buildTextField(_veliTelefonController, 'Veli Telefon Numarası (Sadece Rakam)', Icons.phone, keyboardType: TextInputType.phone),
                  _buildTextField(_atBilgisiController, 'At Bilgisi', Icons.sports),

                  const SizedBox(height: 30),
                  const Text('Paket ve Ücretlendirme Seçenekleri:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2c3e50))),
                  const SizedBox(height: 10),

                  // Paket Seçenekleri 
                  _buildPaketRadio(PaketSecenekleri.sekizKredi, '8 Derslik Paket', _paketFiyatlari[PaketSecenekleri.sekizKredi]),
                  _buildPaketRadio(PaketSecenekleri.yirmiDortKredi, '24 Derslik Paket', _paketFiyatlari[PaketSecenekleri.yirmiDortKredi]),
                  
                  // Diğer Ücret Girişi Seçeneği (Tek ders gibi)
                  _buildPaketRadio(PaketSecenekleri.diger, 'Diğer (Serbest Ücret/Tek Ders)', null),

                  // Diğer ücret seçeneği seçiliyse fiyat giriş alanını göster
                  if (_seciliPaket == PaketSecenekleri.diger)
                    Padding(
                      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 10),
                      child: _buildTextField(
                        _digerUcretController, 
                        'Ödenen Tutar Girin (TL)', 
                        Icons.attach_money, 
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen ders ücretini giriniz.';
                          }
                          // Virgül veya nokta ile girilen sayıyı kontrol et
                          final cleanedValue = value.replaceAll(',', '.');
                          if (double.tryParse(cleanedValue) == null || double.parse(cleanedValue) <= 0) {
                              return 'Geçerli bir pozitif sayı giriniz.';
                          }
                          return null;
                        }
                      ),
                    ),

                  const SizedBox(height: 40),

                  // Kaydet Butonu
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _kayitYap, // Kayıt yapılırken butonu devre dışı bırak
                      icon: _isSaving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, color: Colors.white),
                      label: Text(
                        _isSaving ? 'Kaydediliyor...' : 'KAYDET',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ecc71), 
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Loading Overlay (İşlem sürerken ekranı karartmak için)
          if (_isSaving)
            const Opacity(
              opacity: 0.6,
              child: ModalBarrier(dismissible: false, color: Colors.black),
            ),
          if (_isSaving)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}