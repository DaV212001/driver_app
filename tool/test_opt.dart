import 'dart:io';

void main() async {
  final client = HttpClient();
  try {
    print('Trying HttpClient to https://androidpublisher.googleapis.com/generate_204...');
    final request = await client.getUrl(Uri.parse('https://androidpublisher.googleapis.com/generate_204'));
    request.headers.set('User-Agent', 'curl/8.21.0');
    final response = await request.close();
    print('Response: ${response.statusCode}');
  } catch (e, st) {
    print('Failed: $e\n$st');
  } finally {
    client.close();
  }
}
