# app.py

from flask import Flask, request, jsonify
from flask_cors import CORS
import json
from datetime import datetime
import os 

app = Flask(__name__)
CORS(app) 

DATA_FILE = 'students.json'

# Kredi türlerinin karşılığı (Örn: 8 Ders paketi 8 krediye karşılık gelir)
CREDIT_MAP = {
    '8 Ders': 8,
    '24 Ders': 24,
    'Tek Ders': 1 # Diğer olarak girilen tek bir ders kredisini temsil eder
}

# Python'ın Pazartesi=0, Pazar=6 yapısını Pazar=0, Pazartesi=1... Cumartesi=6'ya çeviren fonksiyon
def get_recurring_day_of_week(date_obj):
    """Pazar=0, Pazartesi=1, ..., Cumartesi=6 formatını döndürür."""
    # datetime.weekday() -> Pazartesi=0 ... Pazar=6
    # (day_of_week + 1) % 7 -> Pazar'ı (6+1)%7=0 yapar, Pazartesi'yi (0+1)%7=1 yapar.
    return (date_obj.weekday() + 1) % 7


# Verileri dosyadan yükleme veya boş liste oluşturma
def load_data():
    """Kayıtları JSON dosyasından yükler ve varsayılan alanları ekler."""
    if not os.path.exists(DATA_FILE) or os.stat(DATA_FILE).st_size == 0:
        return []

    try:
        with open(DATA_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
            
            # Veri bütünlüğünü sağlamak için varsayılan alanları ekle (Migration)
            for student in data:
                ucret_turu = student.get('ucret_turu', '8 Ders')
                
                # remaining_credits yoksa, başlangıç kredisini hesapla
                if 'remaining_credits' not in student:
                    initial_credit = CREDIT_MAP.get(ucret_turu, 0)
                    
                    # Eğer kayıt anında ilk ders düşürülmediyse, şimdi düşürülmüş halini varsay.
                    if ucret_turu in ['8 Ders', '24 Ders', 'Tek Ders']:
                        # Kayıt anında 1 kredi düşüldüğü varsayımı ile migration yapılıyor.
                        student['remaining_credits'] = max(0, initial_credit - 1)
                    else:
                        student['remaining_credits'] = initial_credit
                
                # Tekrar eden gün/saat bilgisi yoksa, kayıt anındaki bilgileri kullan
                if 'recurring_day_of_week' not in student or 'recurring_time' not in student:
                    try:
                        # Kayıt anındaki ders tarihini ve saatini kullan
                        lesson_date = datetime.strptime(student.get('tarih', '01/01/2024'), '%d/%m/%Y')
                        day_of_week = get_recurring_day_of_week(lesson_date)
                        student['recurring_day_of_week'] = day_of_week
                        student['recurring_time'] = student.get('saat', '13:50')
                    except ValueError:
                        # Tarih formatı bozuksa varsayılan değerler
                        student['recurring_day_of_week'] = 0 
                        student['recurring_time'] = student.get('saat', '13:50')
            
            return data
            
    except json.JSONDecodeError:
        print(f"UYARI: {DATA_FILE} dosyası bozuk veya geçersiz JSON formatında. Boş liste ile devam ediliyor.")
        return []

# Verileri dosyaya kaydetme
def save_data(data):
    """Kayıtları JSON dosyasına kaydeder."""
    with open(DATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

# ----------------------------------------------------------------------
# 1. ÖĞRENCİ KAYDI ENDPOINT'İ (Kredi Düşürme Mantığı Düzeltildi)
# ----------------------------------------------------------------------

@app.route('/api/students/register', methods=['POST'])
def register_student():
    """Yeni öğrenci ve ders kaydı ekler (Kredi ve Tekrar alanları ile)."""
    students = load_data()
    
    try:
        data = request.get_json()
        
        required_fields = ['ad_soyad', 'veli_telefon', 'odenen_tutar', 'tarih', 'saat', 'ucret_turu'] 
        
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Eksik alan: {field}'}), 400

        # Ödeme tutarı doğrulaması (string gelip float'a çevirme)
        try:
            # Gelen string'deki virgül ve noktayı float'a çevirmeden önce temizle
            odenen_tutar_str = str(data['odenen_tutar']).replace(',', '.')
            odenen_tutar = float(odenen_tutar_str) 
            if odenen_tutar < 0:
                 return jsonify({'error': 'odenen_tutar pozitif bir sayı olmalıdır.'}), 400
        except (ValueError, TypeError):
            return jsonify({'error': 'odenen_tutar geçerli bir sayı olmalıdır.'}), 400

        # Dersin hangi gün olduğunu (Pazar=0, ...) hesaplama
        try:
            lesson_date = datetime.strptime(data['tarih'], '%d/%m/%Y') 
            day_of_week = get_recurring_day_of_week(lesson_date)
        except ValueError:
            return jsonify({'error': 'Geçersiz tarih formatı. Beklenen: dd/MM/yyyy'}), 400
        
        # Yeni Kredi Mantığı: Kayıt yapıldığı an ilk ders sayılır ve düşülür.
        ucret_turu = data['ucret_turu']
        initial_credit = CREDIT_MAP.get(ucret_turu, 0) 
        
        # İlk ders düştükten sonra kalan kredi
        remaining_credit = max(0, initial_credit - 1)
        
        
        new_student = {
            'ad_soyad': data['ad_soyad'],
            'veli_telefon': data['veli_telefon'],
            'sinif': data.get('sinif', ''),
            'at_bilgisi': data.get('at_bilgisi', ''),
            'ucret_turu': ucret_turu,
            'odenen_tutar': odenen_tutar,
            'ogretmen': data.get('ogretmen', 'Belirtilmemiş'), # "Giriş Yapan Öğretmen (TODO)" yerine "Belirtilmemiş" 
            'kayit_zamani': data.get('kayit_zamani', datetime.now().isoformat()),
            'tarih': data['tarih'],
            'saat': data['saat'], 
            'remaining_credits': remaining_credit, # İlk ders sayıldıktan sonraki kredi
            'recurring_day_of_week': data.get('recurring_day_of_week', day_of_week), # Tekrar eden gün (kayıt anındaki ders günü)
            'recurring_time': data.get('recurring_time', data['saat']), # Tekrar eden saat
        }
        
        students.append(new_student)
        save_data(students)
        
        return jsonify({
            'message': 'Öğrenci kaydı başarıyla eklendi ve ilk ders kredisi düşürüldü.',
            'data': new_student
        }), 201

    except Exception as e:
        print(f"Hata: {e}")
        return jsonify({'error': f'Kayıt işlemi başarısız oldu: Sunucu hatası ({str(e)})'}), 500


# ----------------------------------------------------------------------
# 2. KASA TOPLAMINI GETİRME ENDPOINT'İ 
# ----------------------------------------------------------------------

@app.route('/api/cashier/total', methods=['GET'])
def get_total_cash():
    """Tüm kayıtlı ödemelerin toplamını (kasayı) hesaplar ve döndürür."""
    students = load_data()
    
    total_amount = 0.0
    for record in students:
        try:
            # Odenen tutarı float'a çevirirken hata yoksayılır
            amount = float(record.get('odenen_tutar', 0))
            total_amount += amount
        except (ValueError, TypeError):
            continue

    return jsonify({
        'message': 'Toplam kasa bilgisi.',
        'total_amount': round(total_amount, 2),
        'record_count': len(students)
    }), 200

# ----------------------------------------------------------------------
# 3. TÜM KAYITLARI GETİRME ENDPOINT'İ 
# ----------------------------------------------------------------------

@app.route('/api/students', methods=['GET'])
def get_all_students():
    """Tüm öğrenci kayıtlarını listeler (home_screen.dart için kullanılır)."""
    students = load_data()
    # Güvenlik/Performans için gerekirse bazı alanları çıkartabilirsiniz (örn: tüm JSON datasını değil, sadece özet bilgileri göndermek)
    return jsonify(students), 200

# ----------------------------------------------------------------------
# 4. TEK ÖĞRENCİ DETAYINI GETİRME ENDPOINT'İ 
# ----------------------------------------------------------------------

@app.route('/api/students/<int:index>', methods=['GET'])
def get_student_detail(index):
    """Belirli bir öğrencinin detaylarını indeksine göre döndürür (Kredi ve Tekrar Bilgisi ile)."""
    students = load_data()
    
    if index < 0 or index >= len(students):
        return jsonify({'error': 'Öğrenci bulunamadı. Geçersiz indeks.'}), 404

    student_detail = students[index]
    
    # Python gün adlarını Türkçe'ye çevirme (Pazar=0, Pazartesi=1, ...)
    day_names = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"]
    day_index = student_detail.get('recurring_day_of_week', 0)
    
    # Tekrar eden gün adını ve saatini hazırlama
    recurring_day_name = day_names[day_index % 7]
    recurring_time_name = student_detail.get('recurring_time', 'Belirtilmemiş')

    # Flutter'a gönderilecek son detaylara Tekrar Bilgisini ekle
    student_detail['recurring_day'] = recurring_day_name
    student_detail['recurring_time'] = recurring_time_name

    # Kredi Bilgisini ekle (load_data'dan geldiği için zaten mevcut olmalı)
    student_detail['remaining_credits'] = student_detail.get('remaining_credits', 0)
    
    return jsonify(student_detail), 200

# ----------------------------------------------------------------------
# 5. KREDİ DÜŞÜRME İŞLEMİ 
# ----------------------------------------------------------------------

@app.route('/api/students/<int:index>/credit_decrease', methods=['POST'])
def decrease_student_credit(index):
    """Belirli bir öğrencinin ders kredisini 1 azaltır."""
    students = load_data()

    if index < 0 or index >= len(students):
        return jsonify({'error': 'Öğrenci bulunamadı. Geçersiz indeks.'}), 404
    
    student = students[index]
    
    # Kalan kredi bilgisinin olduğundan emin ol (migration'dan geçememişse bile)
    current_credits = student.get('remaining_credits', 0) 
    
    # Kredi 0 veya altındaysa düşürme yapma
    if current_credits <= 0:
        return jsonify({
            'message': f'Kredi düşürme başarısız. Kredi zaten {current_credits} ders.',
            'current_credits': current_credits
        }), 400

    try:
        # Krediyi 1 azalt
        student['remaining_credits'] -= 1
        new_credits = student['remaining_credits']
        
        # Güncellenmiş listeyi dosyaya kaydet
        save_data(students)
        
        return jsonify({
            'message': f'Öğrencinin ders kredisi başarıyla {new_credits} derse düşürüldü.',
            'new_credits': new_credits
        }), 200

    except Exception as e:
        print(f"Kredi düşürme hatası: {e}")
        return jsonify({'error': f'Kredi düşürme işlemi başarısız oldu: {str(e)}'}), 500


# ----------------------------------------------------------------------
# 6. ÖĞRENCİ KAYDINI SİLME ENDPOINT'İ 
# ----------------------------------------------------------------------

@app.route('/api/students/<int:index>', methods=['DELETE'])
def delete_student(index):
    """Belirli bir öğrencinin kaydını indeksine göre siler."""
    students = load_data()
    
    if index < 0 or index >= len(students):
        return jsonify({'error': 'Öğrenci bulunamadı. Geçersiz indeks.'}), 404

    try:
        deleted_student = students.pop(index)
        save_data(students)
        
        return jsonify({
            'message': 'Öğrenci kaydı başarıyla silindi.',
            'deleted_student': deleted_student
        }), 200

    except Exception as e:
        print(f"Silme hatası: {e}")
        return jsonify({'error': f'Silme işlemi başarısız oldu: {str(e)}'}), 500

if __name__ == '__main__':
    # GÜNCEL IP ADRESİNİZ: 192.168.1.134
    NEW_IP = '192.168.1.134' 
    print("---------------------------------------------------------")
    print(f"Flask API Çalışıyor. Erişilebilir Adres (LAN/Mobil): http://{NEW_IP}:5000")
    print("Yerel Adres: http://127.0.0.1:5000")
    print("---------------------------------------------------------")
    # '0.0.0.0' tüm arayüzlerde dinlemeyi sağlar, bu da LAN erişimi için gereklidir.
    app.run(debug=True, host='0.0.0.0', port=5000)