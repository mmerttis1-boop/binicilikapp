// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'student_registration_screen.dart';
import 'cashier_screen.dart';
import 'student_detail_screen.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart'; // Tarih formatlama için zorunlu

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Takvim ayarları için gerekli değişkenler
  DateTime _focusedDay = DateTime.now(); 
  DateTime _selectedDay = DateTime.now(); 

  // API'den çekilen TÜM öğrencileri tutan liste
  List<Map<String, dynamic>> _allStudents = []; 
  
  // Takvimi doldurmak için kullanılan Map
  Map<DateTime, List<Map<String, dynamic>>> _events = {}; 

  // Hata ve Yüklenme durumu
  bool _isLoading = true;
  String _errorMessage = '';

  // API adresi GÜNCEL IP: 192.168.1.134:5000 olarak düzeltildi
  final String _apiUrl = 'http://192.168.1.134:5000/api/students';
  final String _apiBaseUrl = 'http://192.168.1.134:5000/api/students/';

  @override
  void initState() {
    super.initState();
    // Türkiye saat dilimine ve diline göre ayar
    initializeDateFormatting('tr_TR', null); 
    // Uygulama başlar başlamaz tüm veriyi çek
    _fetchStudentData(); 
  }

  // ----------------------------------------------------------------------
  // Tekrarlayan Ders Tarihlerini Hesaplama Fonksiyonu
  // ----------------------------------------------------------------------
  List<DateTime> _getRecurringDates(DateTime initialDate, int recurringDayOfWeek, int numWeeks) {
    // Flask'tan gelen: 0=Pazar, 1=Pazartesi, ..., 6=Cumartesi
    // Dart'ın gün standardı: 1=Pazartesi, ..., 7=Pazar

    List<DateTime> dates = [];
    
    // Flask gününü Dart gününe çevir (Pazar: 0 -> 7)
    int recurringDayDart = (recurringDayOfWeek == 0) ? 7 : recurringDayOfWeek;
    int initialDayDart = initialDate.weekday;

    // Dersin ilk gerçekleşeceği tarihi bul (initialDate'e göre)
    DateTime firstRecurringDate = initialDate;
    int daysDifference = recurringDayDart - initialDayDart;
    
    // Eğer daysDifference pozitifse, ilk ders zaten kaydın yapıldığı hafta içinde.
    // Eğer daysDifference negatifse (Örn: Çarşamba kayıt yapıldı, tekrar Pazartesi), 
    // bu haftayı es geçip bir sonraki haftaya geçer.
    if (daysDifference < 0) {
      firstRecurringDate = initialDate.add(Duration(days: daysDifference + 7));
    } else {
      firstRecurringDate = initialDate.add(Duration(days: daysDifference));
    }
    
    // 26 hafta (yaklaşık 6 ay) boyunca tekrarlayan dersleri ekle
    for (int i = 0; i < numWeeks; i++) {
      DateTime nextDate = firstRecurringDate.add(Duration(days: i * 7));
      
      // Sadece bugünden sonraki veya bugünün derslerini ekle (saat farkını yok saymak için)
      // UTC normalizasyonu, tarih karşılaştırması için kritik
      final normalizedNow = DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final normalizedNextDate = DateTime.utc(nextDate.year, nextDate.month, nextDate.day);
      
      // Eğer tarih geçmişte değilse veya tam bugüne denk geliyorsa ekle
      if (normalizedNextDate.isAfter(normalizedNow) || normalizedNextDate.isAtSameMomentAs(normalizedNow)) {
          dates.add(normalizedNextDate); 
      }
    }
    
    // KRİTİK: İlk dersin kayıt tarihi (initialDate) de listeye eklenmeli.
    // Bunu ayrı ekliyoruz, çünkü bu ders API'de *kredisi düşürülmüş* olarak kaydı başlatan derstir.
    final normalizedInitialDate = DateTime.utc(initialDate.year, initialDate.month, initialDate.day);
    if (!dates.contains(normalizedInitialDate)) {
        // İlk kaydı, tekrarlayan ders listesinde yoksa ekle (çoğu zaman olmayacaktır)
        dates.add(normalizedInitialDate);
    }
    
    return dates;
  }

  // ---------------------------------------------------------------------
  // API VE VERİ İŞLEME FONKSİYONLARI 
  // ---------------------------------------------------------------------

  // API'den öğrenci verilerini çeken fonksiyon (GET İsteği)
  Future<void> _fetchStudentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _events.clear(); // Yeniden yükleme yaparken eski olayları temizle
    });

    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        // Hata giderme: Türkçe karakterler için decode
        final List<dynamic> studentsList = json.decode(utf8.decode(response.bodyBytes)); 
        
        setState(() {
          _allStudents = studentsList.cast<Map<String, dynamic>>();
          _groupEvents(); // Yeni veriyi takvime işle
          _isLoading = false;
        });

      } else {
        setState(() {
          _errorMessage = 'Sunucu Hatası: Öğrenci çekilemedi! Hata kodu: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        // Hata mesajını daha anlaşılır yapalım
        _errorMessage = 'Bağlantı Hatası: Flask sunucusuna erişilemiyor. Lütfen API\'nin çalıştığından ve IP adresinin doğru olduğundan emin olun.';
        _isLoading = false;
      });
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Bağlantı Hatası! Sunucuya erişilemiyor.')),
        );
      }
    }
  }

  // API'den gelen veriyi takvime uygun hale getirir (TEKRAR MANTIĞI EKLENDİ)
  void _groupEvents() {
    Map<DateTime, List<Map<String, dynamic>>> newEvents = {}; 
    
    // Listeyi saate göre sıralayalım (görünüm için)
    _allStudents.sort((a, b) => (a['saat'] ?? '00:00').compareTo(b['saat'] ?? '00:00'));

    for (int originalIndex = 0; originalIndex < _allStudents.length; originalIndex++) {
      var student = _allStudents[originalIndex];
      
      String dateString = student['tarih']; 
      String timeString = student['saat'];
      
      // Tekrarlayan ders bilgileri (API'den gelmesi beklenir)
      String recurringTimeString = student['recurring_time'] ?? timeString;
      int recurringDay = student['recurring_day_of_week'] ?? -1; // -1 hata durumunu gösterir 

      try {
        DateTime initialDate = DateFormat('dd/MM/yyyy').parse(dateString);
        
        // Sadece kalan kredisi 0'dan büyük olanları tekrar eden ders olarak göster
        final int remainingCredits = student['remaining_credits'] ?? 0;
        
        // 1. DERS: İLK KAYIT TARİHİ (Kredisi zaten 1 düşürülmüş olsa da ilk ders listelenmeli)
        final normalizedInitialDate = DateTime.utc(initialDate.year, initialDate.month, initialDate.day);
        
        var initialLessonData = Map<String, dynamic>.from(student);
        initialLessonData['display_time'] = timeString; // İlk kayıtta orijinal saati kullan
        initialLessonData['original_index'] = originalIndex; 
        initialLessonData['is_recurring'] = false;
        
        if (newEvents[normalizedInitialDate] == null) {
            newEvents[normalizedInitialDate] = [];
        }
        // Eğer ilk kayıt bu tarihte listelenmediyse ekle (Tekrarlayan Derslerde olmaması için)
        if (!newEvents[normalizedInitialDate]!.any((e) => e['original_index'] == originalIndex)) {
            newEvents[normalizedInitialDate]!.add(initialLessonData);
        }

        // 2. TEKRAR EDEN DERSLERİ HESAPLA ve ekle (Kalan kredi varsa)
        if (remainingCredits > 0 && recurringDay != -1) {
            List<DateTime> recurringDates = _getRecurringDates(
              initialDate, 
              recurringDay, 
              26 // 6 ay
            );

            for (DateTime date in recurringDates) {
                // İlk kayıt tarihi, tekrar edenler listesinde tekrar edilmemeli.
                if (isSameDay(date, initialDate)) continue;

                var lessonData = Map<String, dynamic>.from(student);
                lessonData['display_time'] = recurringTimeString; // Tekrar eden saat
                lessonData['original_index'] = originalIndex; 
                lessonData['is_recurring'] = true; // Tekrar eden ders olduğunu işaretle
                
                if (newEvents[date] == null) {
                    newEvents[date] = [];
                }
                
                newEvents[date]!.add(lessonData);
            }
        }
        
      } catch (e) {
        print('Tarih/Saat ayrıştırma hatası veya eksik veri: $e');
        continue; 
      }
    }
    
    // Tüm günlerdeki dersleri saate göre sırala
    newEvents.forEach((key, value) {
        value.sort((a, b) => (a['display_time'] ?? '00:00').compareTo(b['display_time'] ?? '00:00'));
    });
    
    _events = newEvents;
  }

  // Dersleri seçilen güne göre filtreleme
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  // Kullanıcı takvimde bir gün seçtiğinde çalışacak fonksiyon
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  // ---------------------------------------------------------------------
  // WIDGET AĞACI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Seçilen güne ait olaylar, saate göre sıralanmış olarak gelir
    final List<Map<String, dynamic>> selectedDayEvents = _getEventsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🗓️ Ders Takvimi', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2ecc71),
        actions: [
          // Kasa Butonu
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
            tooltip: 'Kasa Toplamı',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CashierScreen()),
              );
            },
          ),
          // Yenileme Butonu (Manuel Yenileme için)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Verileri Yenile',
            onPressed: _fetchStudentData, // Eski kayıtları da dahil tüm veriyi yeniden çeker
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    ),
                  )
              : Column(
                    children: [
                      // 1. TABLE CALENDAR Widget'ı
                      Card(
                        margin: const EdgeInsets.all(8.0),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: CalendarFormat.month, 
                          locale: 'tr_TR', 
                          startingDayOfWeek: StartingDayOfWeek.monday, 

                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),

                          // Gün Seçimi
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          onDaySelected: _onDaySelected,
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                          
                          // Olay İşaretleme (Events)
                          eventLoader: _getEventsForDay, 
                          
                          calendarStyle: const CalendarStyle(
                              selectedDecoration: BoxDecoration(
                                  color: Color(0xFFe67e22), 
                                  shape: BoxShape.circle),
                              todayDecoration: BoxDecoration(
                                  color: Color(0xFF95a5a6), 
                                  shape: BoxShape.circle),
                              markerDecoration: BoxDecoration(
                                  color: Colors.red, 
                                  shape: BoxShape.circle)
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 10),

                      // 2. ÖĞRENCİ EKLEME BUTONU
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15.0),
                        child: ElevatedButton.icon(
                          onPressed: () async { 
                            final normalizedSelectedDay = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
                            // Navigator.push sonrası gelen sonucu beklemek KRİTİKTİR
                            final result = await Navigator.push( 
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentRegistrationScreen(selectedDate: normalizedSelectedDay),
                              ),
                            );
                            
                            // Yeni kayıt başarılıysa (result == true gelirse) veriyi yenile
                            if (result == true) { 
                                await _fetchStudentData(); // Eski ve yeni tüm veriyi yeniden çek
                            }
                          },
                          icon: const Icon(Icons.person_add, color: Colors.white),
                          label: Text(
                            '${_selectedDay.day}.${_selectedDay.month}.${_selectedDay.year} İçin Öğrenci Kayıt',
                            style: const TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3498db), 
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            minimumSize: const Size(double.infinity, 50), 
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),

                      // 3. SEÇİLİ GÜNÜN DERSLERİNİ LİSTELEME BAŞLIĞI
                      Padding(
                        padding: const EdgeInsets.only(left: 15.0, bottom: 5),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_selectedDay.day}.${_selectedDay.month}.${_selectedDay.year} Dersleri:',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2c3e50)),
                          ),
                        ),
                      ),
                      
                      // 4. LİSTELEME WİDGET'I
                      Expanded(
                        child: selectedDayEvents.isEmpty
                          ? const Center(child: Text('Bu günde ders kaydı bulunmamaktadır.'))
                          : ListView.builder(
                              itemCount: selectedDayEvents.length,
                              itemBuilder: (context, index) {
                                final event = selectedDayEvents[index];
                                final int remainingCredits = event['remaining_credits'] ?? 0;
                                
                                // Ders başlığı ve saati
                                final String eventTitle = 
                                    '${event['display_time'] ?? event['saat'] ?? '??:??'} - ${event['ad_soyad'] ?? 'Bilinmeyen'}';
                                
                                // Liste Tile rengi ve alt başlık
                                final bool isRecurring = event['is_recurring'] ?? false;
                                Color tileColor;
                                String subtitleText;

                                if (isRecurring) {
                                    tileColor = remainingCredits > 0 ? Colors.blue.shade100 : Colors.red.shade100;
                                    subtitleText = remainingCredits > 0 ? 'Tekrar Eden Ders (Kalan Kredi: $remainingCredits)' : '⚠️ Tekrar Eden Ders (Kredi BİTTİ)';
                                } else {
                                    tileColor = Colors.green.shade50;
                                    subtitleText = 'Orijinal Kayıt (${event['ucret_turu'] ?? 'Paket Yok'})';
                                }

                                final int originalIndex = event['original_index'] ?? -1;

                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                                  color: tileColor, // Kalan krediye/duruma göre renk
                                  elevation: 2,
                                  child: ListTile(
                                    leading: const Icon(Icons.sports, color: Color(0xFFe67e22)),
                                    title: Text(
                                      eventTitle, 
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      subtitleText,
                                      style: TextStyle(color: isRecurring && remainingCredits <= 0 ? Colors.red.shade900 : Colors.black54),
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () async { 
                                      if (originalIndex != -1) {
                                        // Detay sayfasına git ve geri dönünce yenileme yap
                                        final result = await Navigator.push( 
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => StudentDetailScreen(
                                              studentIndex: originalIndex, 
                                              apiUrlBase: _apiBaseUrl, 
                                            ),
                                          ),
                                        );
                                        // Silme veya Kredi Düşürme sonrası Home Screen'i yenile
                                        if (result == true) {
                                            await _fetchStudentData();
                                        }

                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('HATA: Öğrenci detayı bulunamadı.')),
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                      ),
                    ],
                  ),
    );
  }
}