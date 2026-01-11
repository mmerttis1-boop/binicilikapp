// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'student_registration_screen.dart';
import 'cashier_screen.dart';
import 'student_detail_screen.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now(); 
  DateTime _selectedDay = DateTime.now(); 
  List<Map<String, dynamic>> _allStudents = []; 
  Map<DateTime, List<Map<String, dynamic>>> _events = {}; 

  bool _isLoading = true;
  String _errorMessage = '';

  // YENİ RENDER API ADRESLERİ
  final String _apiUrl = 'https://binicilikapp-g73g.onrender.com/api/students';
  final String _apiBaseUrl = 'https://binicilikapp-g73g.onrender.com/api/students/';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null); 
    _fetchStudentData(); 
  }

  // --- Tekrarlayan Ders Tarihlerini Hesaplama (Mantık Korundu) ---
  List<DateTime> _getRecurringDates(DateTime initialDate, int recurringDayOfWeek, int numWeeks) {
    List<DateTime> dates = [];
    int recurringDayDart = (recurringDayOfWeek == 0) ? 7 : recurringDayOfWeek;
    int initialDayDart = initialDate.weekday;

    DateTime firstRecurringDate = initialDate;
    int daysDifference = recurringDayDart - initialDayDart;
    
    if (daysDifference < 0) {
      firstRecurringDate = initialDate.add(Duration(days: daysDifference + 7));
    } else {
      firstRecurringDate = initialDate.add(Duration(days: daysDifference));
    }
    
    for (int i = 0; i < numWeeks; i++) {
      DateTime nextDate = firstRecurringDate.add(Duration(days: i * 7));
      final normalizedNow = DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final normalizedNextDate = DateTime.utc(nextDate.year, nextDate.month, nextDate.day);
      
      if (normalizedNextDate.isAfter(normalizedNow) || normalizedNextDate.isAtSameMomentAs(normalizedNow)) {
          dates.add(normalizedNextDate); 
      }
    }
    
    final normalizedInitialDate = DateTime.utc(initialDate.year, initialDate.month, initialDate.day);
    if (!dates.contains(normalizedInitialDate)) {
        dates.add(normalizedInitialDate);
    }
    return dates;
  }

  // --- API Veri Çekme (Render Uyumluluğu Eklendi) ---
  Future<void> _fetchStudentData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _events.clear(); 
    });

    try {
      // 30 saniye timeout: Render'ın uyanma süresi için önemli
      final response = await http.get(Uri.parse(_apiUrl)).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> studentsList = json.decode(utf8.decode(response.bodyBytes)); 
        
        if (!mounted) return;
        setState(() {
          _allStudents = studentsList.cast<Map<String, dynamic>>();
          _groupEvents(); 
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
        _errorMessage = 'Bağlantı kurulamadı. Sunucu uyanıyor olabilir, lütfen yenile butonuna basın.';
        _isLoading = false;
      });
    }
  }

  // --- Veriyi Takvime Gruplama (Mantık Korundu) ---
  void _groupEvents() {
    Map<DateTime, List<Map<String, dynamic>>> newEvents = {}; 
    _allStudents.sort((a, b) => (a['saat'] ?? '00:00').compareTo(b['saat'] ?? '00:00'));

    for (int originalIndex = 0; originalIndex < _allStudents.length; originalIndex++) {
      var student = _allStudents[originalIndex];
      String dateString = student['tarih']; 
      String timeString = student['saat'];
      String recurringTimeString = student['recurring_time'] ?? timeString;
      int recurringDay = student['recurring_day_of_week'] ?? -1; 

      try {
        DateTime initialDate = DateFormat('dd/MM/yyyy').parse(dateString);
        final int remainingCredits = student['remaining_credits'] ?? 0;
        final normalizedInitialDate = DateTime.utc(initialDate.year, initialDate.month, initialDate.day);
        
        var initialLessonData = Map<String, dynamic>.from(student);
        initialLessonData['display_time'] = timeString;
        initialLessonData['original_index'] = originalIndex; 
        initialLessonData['is_recurring'] = false;
        
        if (newEvents[normalizedInitialDate] == null) {
            newEvents[normalizedInitialDate] = [];
        }
        if (!newEvents[normalizedInitialDate]!.any((e) => e['original_index'] == originalIndex)) {
            newEvents[normalizedInitialDate]!.add(initialLessonData);
        }

        if (remainingCredits > 0 && recurringDay != -1) {
            List<DateTime> recurringDates = _getRecurringDates(initialDate, recurringDay, 26);
            for (DateTime date in recurringDates) {
                if (isSameDay(date, initialDate)) continue;
                var lessonData = Map<String, dynamic>.from(student);
                lessonData['display_time'] = recurringTimeString;
                lessonData['original_index'] = originalIndex; 
                lessonData['is_recurring'] = true;
                if (newEvents[date] == null) newEvents[date] = [];
                newEvents[date]!.add(lessonData);
            }
        }
      } catch (e) { continue; }
    }
    newEvents.forEach((key, value) {
        value.sort((a, b) => (a['display_time'] ?? '00:00').compareTo(b['display_time'] ?? '00:00'));
    });
    _events = newEvents;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> selectedDayEvents = _getEventsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🗓️ Ders Takvimi', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2ecc71),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CashierScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchStudentData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Veriler Yükleniyor... (İlk açılış 30sn sürebilir)"),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 20),
                      ElevatedButton(onPressed: _fetchStudentData, child: const Text("Tekrar Dene"))
                    ],
                  ),
                )
              : Column(
                  children: [
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
                        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        onDaySelected: _onDaySelected,
                        onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                        eventLoader: _getEventsForDay, 
                        calendarStyle: const CalendarStyle(
                            selectedDecoration: BoxDecoration(color: Color(0xFFe67e22), shape: BoxShape.circle),
                            todayDecoration: BoxDecoration(color: Color(0xFF95a5a6), shape: BoxShape.circle),
                            markerDecoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle)
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15.0),
                      child: ElevatedButton.icon(
                        onPressed: () async { 
                          final normalizedSelectedDay = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
                          final result = await Navigator.push(context, MaterialPageRoute(
                              builder: (context) => StudentRegistrationScreen(selectedDate: normalizedSelectedDay),
                          ));
                          if (result == true) await _fetchStudentData();
                        },
                        icon: const Icon(Icons.person_add, color: Colors.white),
                        label: Text('${_selectedDay.day}.${_selectedDay.month}.${_selectedDay.year} İçin Kayıt', style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3498db), minimumSize: const Size(double.infinity, 50)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: selectedDayEvents.isEmpty
                        ? const Center(child: Text('Bu günde ders kaydı bulunmamaktadır.'))
                        : ListView.builder(
                            itemCount: selectedDayEvents.length,
                            itemBuilder: (context, index) {
                              final event = selectedDayEvents[index];
                              final int remainingCredits = event['remaining_credits'] ?? 0;
                              final bool isRecurring = event['is_recurring'] ?? false;
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                                color: isRecurring ? (remainingCredits > 0 ? Colors.blue.shade50 : Colors.red.shade50) : Colors.green.shade50,
                                child: ListTile(
                                  leading: const Icon(Icons.sports, color: Color(0xFFe67e22)),
                                  title: Text('${event['display_time'] ?? '??:??'} - ${event['ad_soyad'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(isRecurring ? 'Tekrar Eden (Kredi: $remainingCredits)' : 'Orijinal Kayıt'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () async { 
                                    final int originalIndex = event['original_index'] ?? -1;
                                    if (originalIndex != -1) {
                                      final res = await Navigator.push(context, MaterialPageRoute(
                                        builder: (context) => StudentDetailScreen(studentIndex: originalIndex, apiUrlBase: _apiBaseUrl),
                                      ));
                                      if (res == true) await _fetchStudentData();
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