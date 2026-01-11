# app.py
from flask import Flask, request, jsonify
from flask_cors import CORS
import json
from datetime import datetime
import os 

app = Flask(__name__)
CORS(app) 

DATA_FILE = 'students.json'

# Kredi türlerinin karşılığı
CREDIT_MAP = {
    '8 Ders': 8,
    '24 Ders': 24,
    'Tek Ders': 1 
}

def get_recurring_day_of_week(date_obj):
    """Pazar=0, Pazartesi=1, ..., Cumartesi=6 formatını döndürür."""
    return (date_obj.weekday() + 1) % 7

def load_data():
    """Kayıtları JSON dosyasından yükler ve varsayılan alanları ekler."""
    if not os.path.exists(DATA_FILE) or os.stat(DATA_FILE).st_size == 0:
        return []

    try:
        with open(DATA_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
            for student in data:
                ucret_turu = student.get('ucret_turu', '8 Ders')
                if 'remaining_credits' not in student:
                    initial_credit = CREDIT_MAP.get(ucret_turu, 0)
                    if ucret_turu in ['8 Ders', '24 Ders', 'Tek Ders']:
                        student['remaining_credits'] = max(0, initial_credit - 1)
                    else:
                        student['remaining_credits'] = initial_credit
                
                if 'recurring_day_of_week' not in student or 'recurring_time' not in student:
                    try:
                        lesson_date = datetime.strptime(student.get('tarih', '01/01/2024'), '%d/%m/%Y')
                        day_of_week = get_recurring_day_of_week(lesson_date)
                        student['recurring_day_of_week'] = day_of_week
                        student['recurring_time'] = student.get('saat', '13:50')
                    except ValueError:
                        student['recurring_day_of_week'] = 0 
                        student['recurring_time'] = student.get('saat', '13:50')
            return data
    except json.JSONDecodeError:
        return []

def save_data(data):
    """Kayıtları JSON dosyasına kaydeder."""
    with open(DATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

# --- ENDPOINT'LER (Senin orijinal kodun) ---

@app.route('/')
def home():
    return jsonify({"status": "active", "info": "Binicilik API Online"}), 200

@app.route('/api/students/register', methods=['POST'])
def register_student():
    students = load_data()
    try:
        data = request.get_json()
        required_fields = ['ad_soyad', 'veli_telefon', 'odenen_tutar', 'tarih', 'saat', 'ucret_turu'] 
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Eksik alan: {field}'}), 400

        try:
            odenen_tutar_str = str(data['odenen_tutar']).replace(',', '.')
            odenen_tutar = float(odenen_tutar_str) 
            if odenen_tutar < 0:
                 return jsonify({'error': 'odenen_tutar pozitif olmalıdır.'}), 400
        except (ValueError, TypeError):
            return jsonify({'error': 'odenen_tutar geçerli bir sayı olmalıdır.'}), 400

        lesson_date = datetime.strptime(data['tarih'], '%d/%m/%Y') 
        day_of_week = get_recurring_day_of_week(lesson_date)
        
        ucret_turu = data['ucret_turu']
        initial_credit = CREDIT_MAP.get(ucret_turu, 0) 
        remaining_credit = max(0, initial_credit - 1)
        
        new_student = {
            'ad_soyad': data['ad_soyad'],
            'veli_telefon': data['veli_telefon'],
            'sinif': data.get('sinif', ''),
            'at_bilgisi': data.get('at_bilgisi', ''),
            'ucret_turu': ucret_turu,
            'odenen_tutar': odenen_tutar,
            'ogretmen': data.get('ogretmen', 'Belirtilmemiş'), 
            'kayit_zamani': data.get('kayit_zamani', datetime.now().isoformat()),
            'tarih': data['tarih'],
            'saat': data['saat'], 
            'remaining_credits': remaining_credit,
            'recurring_day_of_week': data.get('recurring_day_of_week', day_of_week),
            'recurring_time': data.get('recurring_time', data['saat']),
        }
        
        students.append(new_student)
        save_data(students)
        return jsonify({'message': 'Başarılı', 'data': new_student}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/cashier/total', methods=['GET'])
def get_total_cash():
    students = load_data()
    total_amount = 0.0
    for record in students:
        try:
            amount = float(record.get('odenen_tutar', 0))
            total_amount += amount
        except (ValueError, TypeError):
            continue
    return jsonify({'total_amount': round(total_amount, 2), 'record_count': len(students)}), 200

@app.route('/api/students', methods=['GET'])
def get_all_students():
    return jsonify(load_data()), 200

@app.route('/api/students/<int:index>', methods=['GET'])
def get_student_detail(index):
    students = load_data()
    if index < 0 or index >= len(students):
        return jsonify({'error': 'Bulunamadı'}), 404
    student_detail = students[index]
    day_names = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"]
    day_index = student_detail.get('recurring_day_of_week', 0)
    student_detail['recurring_day'] = day_names[day_index % 7]
    return jsonify(student_detail), 200

@app.route('/api/students/<int:index>/credit_decrease', methods=['POST'])
def decrease_student_credit(index):
    students = load_data()
    if index < 0 or index >= len(students):
        return jsonify({'error': 'Bulunamadı'}), 404
    student = students[index]
    current_credits = student.get('remaining_credits', 0) 
    if current_credits <= 0:
        return jsonify({'message': 'Kredi yetersiz', 'current_credits': current_credits}), 400
    student['remaining_credits'] -= 1
    save_data(students)
    return jsonify({'new_credits': student['remaining_credits']}), 200

@app.route('/api/students/<int:index>', methods=['DELETE'])
def delete_student(index):
    students = load_data()
    if index < 0 or index >= len(students):
        return jsonify({'error': 'Bulunamadı'}), 404
    deleted_student = students.pop(index)
    save_data(students)
    return jsonify({'message': 'Silindi'}), 200

# --- RENDER VE CANLI ORTAM AYARI ---
if __name__ == '__main__':
    # Render'ın atadığı portu al, bulamazsan 5000'i kullan
    port = int(os.environ.get('PORT', 5000))
    # host '0.0.0.0' olmalı ki dış dünyadan erişilebilsin
    app.run(debug=False, host='0.0.0.0', port=port)