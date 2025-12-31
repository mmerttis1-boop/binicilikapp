# app.py

from flask import Flask, request, jsonify
from flask_cors import CORS
import json
from datetime import datetime
import os 

app = Flask(__name__)
# Flutter uygulamasından gelen isteklere izin vermek için CORS'u etkinleştirin
CORS(app) 

# Veritabanı dosyasının yolu
DATA_FILE = 'students.json'

# Verileri dosyadan yükleme veya boş liste oluşturma
def load_data():
    """Kayıtları JSON dosyasından yükler."""
    if not os.path.exists(DATA_FILE):
        return []

    try:
        with open(DATA_FILE, 'r', encoding='utf-8') as f:
            content = f.read()
            if not content:
                return []
            return json.loads(content)
    except json.JSONDecodeError:
        print(f"UYARI: {DATA_FILE} dosyası bozuk veya geçersiz JSON formatında. Boş liste ile devam ediliyor.")
        return []

# Verileri dosyaya kaydetme
def save_data(data):
    """Kayıtları JSON dosyasına kaydeder."""
    with open(DATA_FILE, 'w', encoding='utf-8') as f:
        # ensure_ascii=False ayarı Türkçe karakterlerin düzgün kaydedilmesini sağlar
        json.dump(data, f, indent=4, ensure_ascii=False)

# ----------------------------------------------------------------------
# 1. ÖĞRENCİ KAYDI ENDPOINT'İ (Saat eklendi)
# ----------------------------------------------------------------------

@app.route('/api/students/register', methods=['POST'])
def register_student():
    """Yeni öğrenci ve ders kaydı ekler (Saat alanı içerir)."""
    students = load_data()
    
    try:
        data = request.get_json()
        
        # Gelen veriyi kontrol et
        # 'saat' alanı zorunlu olarak eklenmiştir
        required_fields = ['ad_soyad', 'veli_telefon', 'odenen_tutar', 'tarih', 'saat'] 
        
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Eksik alan: {field}'}), 400

        # Tutar kontrolü
        try:
            # Gelen değeri float'a çevir
            odenen_tutar = float(data['odenen_tutar']) 
        except (ValueError, TypeError):
            return jsonify({'error': 'odenen_tutar geçerli bir sayı olmalıdır.'}), 400

        new_student = {
            'ad_soyad': data['ad_soyad'],
            'veli_telefon': data['veli_telefon'],
            'sinif': data.get('sinif', ''),
            'at_bilgisi': data.get('at_bilgisi', ''),
            'ucret_turu': data.get('ucret_turu', ''),
            'odenen_tutar': odenen_tutar,
            'ogretmen': data.get('ogretmen', ''),
            'kayit_zamani': data.get('kayit_zamani', datetime.now().isoformat()),
            'tarih': data['tarih'],
            'saat': data['saat'] # KAYIT BAŞARILI: Saat verisi kaydedildi.
        }
        
        students.append(new_student)
        save_data(students)
        
        return jsonify({
            'message': 'Öğrenci kaydı başarıyla eklendi.',
            'data': new_student
        }), 201

    except Exception as e:
        return jsonify({'error': f'Kayıt işlemi başarısız oldu: {str(e)}'}), 500


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
# 3. TÜM KAYITLARI GETİRME ENDPOINT'İ (TableCalendar için zorunlu)
# ----------------------------------------------------------------------

@app.route('/api/students', methods=['GET'])
def get_all_students():
    """Tüm öğrenci kayıtlarını listeler (home_screen.dart için kullanılır)."""
    students = load_data()
    return jsonify(students), 200

# ----------------------------------------------------------------------
# 4. TEK ÖĞRENCİ DETAYINI GETİRME ENDPOINT'İ
# ----------------------------------------------------------------------

@app.route('/api/students/<int:index>', methods=['GET'])
def get_student_detail(index):
    """Belirli bir öğrencinin detaylarını indeksine göre döndürür."""
    students = load_data()
    
    # Listenin sınırları içinde olup olmadığını kontrol et
    if index < 0 or index >= len(students):
        return jsonify({'error': 'Öğrenci bulunamadı. Geçersiz indeks.'}), 404

    # İndekse karşılık gelen öğrenci verisini döndür
    student_detail = students[index]
    
    return jsonify(student_detail), 200

# ----------------------------------------------------------------------
# 5. ÖĞRENCİ KAYDINI SİLME ENDPOINT'İ
# ----------------------------------------------------------------------

@app.route('/api/students/<int:index>', methods=['DELETE'])
def delete_student(index):
    """Belirli bir öğrencinin kaydını indeksine göre siler."""
    students = load_data()
    
    # Listenin sınırları içinde olup olmadığını kontrol et
    if index < 0 or index >= len(students):
        return jsonify({'error': 'Öğrenci bulunamadı. Geçersiz indeks.'}), 404

    try:
        # İndekse karşılık gelen öğrenciyi listeden çıkar
        deleted_student = students.pop(index)
        
        # Güncellenmiş listeyi dosyaya kaydet
        save_data(students)
        
        return jsonify({
            'message': 'Öğrenci kaydı başarıyla silindi.',
            'deleted_student': deleted_student
        }), 200

    except Exception as e:
        return jsonify({'error': f'Silme işlemi başarısız oldu: {str(e)}'}), 500

if __name__ == '__main__':
    # host='0.0.0.0' ayarı, yerel ağdaki veya mobil cihazdaki isteklere yanıt vermenizi sağlar.
    # Bu ayar sayesinde Flask, 10.159.74.210 IP'si üzerinden erişilebilir olur.
    print("---------------------------------------------------------")
    print("Flask API Çalışıyor. Erişilebilir Adres (LAN/Mobil): http://10.159.74.210:5000")
    print("Yerel Adres: http://127.0.0.1:5000")
    print("---------------------------------------------------------")
    app.run(debug=True, host='0.0.0.0', port=5000)