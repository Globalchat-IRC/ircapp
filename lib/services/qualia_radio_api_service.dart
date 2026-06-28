import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/qualia_radio_status.dart';

class QualiaRadioApiService {
  static const statusUrl =
      'https://mobilev1.globalchat.org/api/qualia_radio_status.php';

  Future<QualiaRadioStatus> fetchStatus() async {
    final response = await http
        .get(Uri.parse(statusUrl))
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = QualiaRadioStatus.fromJson(json);
    if (!status.ok) {
      throw Exception(status.error ?? 'Estado de radio no disponible');
    }
    return status;
  }
}
