import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {

  static String baseUrl =
       "http://localhost:5000";

  // --- LOGIN ---
  Future<Map<String, dynamic>?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  // --- REGISTER ---
  Future<bool> register(
      String email, String name, String age, String password, String location) async {

    final response = await http.post(
      Uri.parse("$baseUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
         "name": name,
         "email": email,
         "password": password,
         "age": age,
         "location": location,
      }),

    );

    return response.statusCode == 201;
  }
}
