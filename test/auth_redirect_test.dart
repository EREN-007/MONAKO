import 'package:flutter_test/flutter_test.dart';
import 'package:monako/services/auth_service.dart';

void main() {
  test('le lien du courriel revient sur la page publiée, sans route ni code', () {
    expect(
      AuthService.webRedirectUrl(
          Uri.parse('https://eren-007.github.io/MONAKO/?code=abc#/library')),
      'https://eren-007.github.io/MONAKO/',
    );
    expect(AuthService.webRedirectUrl(Uri.parse('http://localhost:3000/')),
        'http://localhost:3000/');
  });
}
