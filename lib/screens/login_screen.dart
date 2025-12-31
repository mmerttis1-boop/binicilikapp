import 'package:flutter/material.dart';
// Ana sayfa ekranını sonraki adımda oluşturacağımız için şimdiden import edelim
import 'home_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Metin giriş alanlarından veriyi almak için Controller'lar
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Öğretmen kullanıcı adı ve şifreleri (Şimdilik statik)
  final Map<String, String> _teachers = {
    'muratbaskan': 'mb35',
    'ekinn': 'ekin35',
  };

  // Giriş yapma fonksiyonu
  void _login() {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();

    if (_teachers.containsKey(username) && _teachers[username] == password) {
      // Başarılı Giriş
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hoş geldiniz, $username!')),
      );

      // Ana Sayfaya Yönlendirme
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    } else {
      // Başarısız Giriş
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı adı veya şifre yanlış!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    // Controller'ları temizlemeyi unutmayın
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Beyaz arka plan
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Uygulama Başlığı ve İkon
              const Text(
                '🐴 Binicilik Okulu Yönetimi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2c3e50), // Koyu Mavi/Gri
                ),
              ),
              const SizedBox(height: 50),

              // Kullanıcı Adı Girişi
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  hintText: 'muratbaskan veya ekinn',
                  prefixIcon: Icon(Icons.person, color: Color(0xFFe67e22)), // Turuncu ikon
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Şifre Girişi
              TextField(
                controller: _passwordController,
                obscureText: true, // Şifreyi gizle
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: Icon(Icons.lock, color: Color(0xFFe67e22)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Giriş Butonu
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498db), // Mavi buton
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Giriş Yap',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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