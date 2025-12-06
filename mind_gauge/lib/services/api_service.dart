import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://127.0.0.1:5000"; 
  // use your local IP when testing on Android device

  // --- LOGIN ---
  Future<Map<String, dynamic>?> login(String email, String password) async {
    final url = Uri.parse("$baseUrl/login");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  // --- REGISTER ---
  Future<bool> register(
      String email, String name, String age, String password, String location) async {
    final url = Uri.parse("$baseUrl/register");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "name": name,
        "age": age,
        "password": password,
        "location": location,
      }),
    );

    return response.statusCode == 201;
  }
}
