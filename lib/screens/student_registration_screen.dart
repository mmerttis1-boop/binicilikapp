import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Paket seçeneklerini tanımlayan enum yapısı
enum PaketSecenekleri { ucAylik, altiAylik, senelik, diger }

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

  // YENİ: Saat bilgisini tutmak için (Şu anki saat)
  TimeOfDay _selectedTime = TimeOfDay.now(); 

  // Seçili paket durumu
  PaketSecenekleri? _seciliPaket = PaketSecenekleri.ucAylik;

  // Paketlerin örnek fiyatları (sabit değerler)
  final Map<PaketSecenekleri, double> _paketFiyatlari = {
    PaketSecenekleri.ucAylik: 1500.0,
    PaketSecenekleri.altiAylik: 2800.0,
    PaketSecenekleri.senelik: 5000.0,
  };

  // API adresi (GÜNCEL IP: 10.159.74.210:5000)
  final String apiUrl = 'http://10.159.74.210:5000/api/students/register';


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
          // 24 saat formatını zorla
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
    // Form geçerliyse ve validation başarılıysa devam et
    if (!_formKey.currentState!.validate()) {
      return;
    }

    String ucretTuru;
    double odenenTutar;

    // Ücret türünü ve tutarı belirle
    if (_seciliPaket == PaketSecenekleri.diger) {
      ucretTuru = "Tek Ders";
      // Text alanındaki değeri double'a çevir, başarısız olursa 0.0 kullan
      odenenTutar = double.tryParse(_digerUcretController.text) ?? 0.0;
    } else {
      // Paket seçeneklerinden biri seçiliyorsa
      ucretTuru = _seciliPaket.toString().split('.').last; 
      // Seçili paketin fiyatını _paketFiyatlari map'inden al
      odenenTutar = _paketFiyatlari[_seciliPaket!] ?? 0.0;
    }
    
    // Saati "HH:MM" formatına çevir
    String lessonTime = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    // API'ye gönderilecek veri haritası
    Map<String, dynamic> ogrenciVerisi = {
      // Tarih formatını "YYYY-MM-DD" olarak gönderiyoruz
      'tarih': widget.selectedDate.toIso8601String().split('T')[0],
      'saat': lessonTime, // Saat bilgisini ekledik
      'ad_soyad': _adSoyadController.text,
      'sinif': _sinifController.text,
      'veli_telefon': _veliTelefonController.text,
      'at_bilgisi': _atBilgisiController.text,
      'ucret_turu': ucretTuru, 
      'odenen_tutar': odenenTutar, 
      'ogretmen': 'Giriş Yapan Öğretmen',
      'kayit_zamani': DateTime.now().toIso8601String(), // Kayıt zamanını ekleyelim
    };
    
    // Yükleniyor durumunu göstermek isterseniz burada bir yükleme göstergesi ekleyebilirsiniz.
    
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(ogrenciVerisi),
      );

      if (response.statusCode == 201) {
        // Başarılı kayıt
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Öğrenci kaydı başarılı! Kasa güncellendi.'),
                backgroundColor: Color(0xFF2ecc71), // Yeşil
              ),
            );
          // Ana ekrana geri dön ve home_screen'in yenilenmesini tetikle
          Navigator.pop(context, true); 
        }
      } else {
        // API'den hata geldi (Örn: 400 Bad Request)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kayıt başarısız! Hata: ${response.statusCode} - ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Bağlantı hatası (ClientException)
      print('Kayıt gönderme bağlantı hatası: $e'); // Terminale yaz
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bağlantı hatası: Flask API çalışıyor mu? (IP: 10.159.74.210:5000)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // RadioListTile'ları oluşturmak için yardımcı fonksiyon
  Widget _buildPaketRadio(PaketSecenekleri paket, String title, double? fiyat) {
    String subtitle = fiyat != null ? '${fiyat.toStringAsFixed(2)} TL' : 'Diğer/Tek Ders';
    
    return RadioListTile<PaketSecenekleri>(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      value: paket,
      groupValue: _seciliPaket,
      onChanged: (PaketSecenekleri? value) {
        setState(() {
          _seciliPaket = value;
        });
      },
      activeColor: const Color(0xFFe67e22), // Turuncu
    );
  }

  // Ortak TextField stilini oluşturmak için yardımcı widget
  Widget _buildTextField(
    TextEditingController controller, 
    String labelText, 
    IconData icon, 
    {TextInputType keyboardType = TextInputType.text, bool required = true, String? Function(String?)? validator}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: labelText,
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
          if (required && (value == null || value.isEmpty)) {
            return '$labelText boş bırakılamaz.';
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
        backgroundColor: const Color(0xFF3498db), // Mavi
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Tarih Bilgisi
              Text(
                'Ders Tarihi: ${widget.selectedDate.day}.${widget.selectedDate.month}.${widget.selectedDate.year}',
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
                                  // Saati 24 saat formatında göstermek için TimeOfDay.format(context) kullanıyoruz.
                                  'Ders Saati: ${_selectedTime.format(context)}',
                                  style: const TextStyle(fontSize: 16, color: Color(0xFF2c3e50), fontWeight: FontWeight.bold),
                              ),
                          ),
                          TextButton(
                              onPressed: () => _selectTime(context),
                              child: const Text('Saat Seç / Değiştir', style: TextStyle(color: Color(0xFF3498db), fontWeight: FontWeight.bold)),
                          ),
                      ],
                  ),
              ),
              const Divider(height: 30, thickness: 1), // Ayırıcı ekle
              
              // Öğrenci Bilgileri Giriş Alanları
              _buildTextField(_adSoyadController, 'Öğrenci Adı Soyadı', Icons.person),
              _buildTextField(_sinifController, 'Sınıfı (Opsiyonel)', Icons.school, required: false),
              // Telefon Numarası için daha sıkı validator eklenebilir.
              _buildTextField(_veliTelefonController, 'Veli Telefon Numarası', Icons.phone, keyboardType: TextInputType.phone),
              _buildTextField(_atBilgisiController, 'At Bilgisi', Icons.sports),

              const SizedBox(height: 30),
              const Text('Paket ve Ücretlendirme Seçenekleri:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2c3e50))),
              const SizedBox(height: 10),

              // Paket Seçenekleri
              _buildPaketRadio(PaketSecenekleri.ucAylik, '3 Aylık Paket', _paketFiyatlari[PaketSecenekleri.ucAylik]),
              _buildPaketRadio(PaketSecenekleri.altiAylik, '6 Aylık Paket', _paketFiyatlari[PaketSecenekleri.altiAylik]),
              _buildPaketRadio(PaketSecenekleri.senelik, 'Senelik Paket', _paketFiyatlari[PaketSecenekleri.senelik]),
              
              // Diğer Ücret Girişi Seçeneği
              _buildPaketRadio(PaketSecenekleri.diger, 'Diğer (Tek Ders Ücreti)', null),

              // Diğer ücret seçeneği seçiliyse fiyat giriş alanını göster
              if (_seciliPaket == PaketSecenekleri.diger)
                Padding(
                  padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 10),
                  child: _buildTextField(
                    _digerUcretController, 
                    'Tek Ders Ücretini Girin (TL)', 
                    Icons.attach_money, 
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_seciliPaket == PaketSecenekleri.diger && (value == null || value.isEmpty)) {
                        return 'Lütfen ders ücretini giriniz.';
                      }
                      // Double parse kontrolünü sadece 'diger' seçeneği aktifken yap
                      if (_seciliPaket == PaketSecenekleri.diger && double.tryParse(value ?? '') == null) {
                            return 'Geçerli bir sayı giriniz.';
                      }
                      return null;
                    }
                  ),
                ),

              const SizedBox(height: 40),

              // Kaydet Butonu
              Center(
                child: ElevatedButton(
                  onPressed: _kayitYap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ecc71), // Yeşil
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'KAYDET',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}