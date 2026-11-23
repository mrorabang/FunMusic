import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final clientId = 'glXhJxvYKPM87la70dG2G1bJ03AdA3hN';
  final url = Uri.parse('https://api-v2.soundcloud.com/search/tracks').replace(queryParameters: {
    'q': 'nhac tre',
    'client_id': clientId,
    'limit': '15',
  });
  final res = await http.get(url);
  final data = json.decode(res.body);
  final List collection = data['collection'] ?? [];
  for (final t in collection) {
    final trans = t['media']?['transcodings'] as List? ?? [];
    final hasProg = trans.any((x) => x['format']?['protocol'] == 'progressive');
    print('${t['title']}: hasProgressive = $hasProg');
  }
}
