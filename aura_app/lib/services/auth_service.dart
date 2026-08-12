import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AuthService {
  static const String tokensFile = 'tokens.json';

  static const String clientId = '861556708454-d6dlm3lh05idd8npek18k6be8ba3oc68.apps.googleusercontent.com';
  static const String clientSecret = 'SboVhoG9s0rNafixCSGGKXAT';
  static const String deviceCodeUrl = 'https://oauth2.googleapis.com/device/code';
  static const String tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String scope = 'http://gdata.youtube.com https://www.googleapis.com/auth/youtube-paid-content';

  static bool isLinked() {
    final file = File(tokensFile);
    if (file.existsSync()) {
      try {
        final content = file.readAsStringSync();
        final json = jsonDecode(content);
        return json['access_token'] != null;
      } catch (_) {}
    }
    return false;
  }

  static void clearTokens() {
    final file = File(tokensFile);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
  }

  /// Initiates authentic Google OAuth 2.0 Device Flow
  static Future<Map<String, dynamic>> initiateDeviceAuth() async {
    try {
      final response = await http.post(
        Uri.parse(deviceCodeUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'scope': scope,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status': 'ok',
          'user_code': data['user_code'] ?? '',
          'device_code': data['device_code'] ?? '',
          'verification_url': data['verification_url'] ?? 'https://www.google.com/device',
          'interval': data['interval'] ?? 5,
          'expires_in': data['expires_in'] ?? 1800,
        };
      } else {
        return {
          'status': 'error',
          'message': 'Google API hatası: HTTP ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Bağlantı hatası: $e',
      };
    }
  }

  /// Polls Google token endpoint until user confirms or timeout
  static Stream<bool> pollDeviceToken(String deviceCode, {int intervalSeconds = 5, int maxWaitSeconds = 1800}) async* {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime).inSeconds < maxWaitSeconds) {
      await Future.delayed(Duration(seconds: intervalSeconds));

      try {
        final response = await http.post(
          Uri.parse(tokenUrl),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'client_id': clientId,
            'client_secret': clientSecret,
            'code': deviceCode,
            'grant_type': 'http://oauth.net/grant_type/device/1.0',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['access_token'] != null) {
            final tokenData = {
              'access_token': data['access_token'],
              'refresh_token': data['refresh_token'],
              'token_type': data['token_type'] ?? 'Bearer',
              'expires_in': data['expires_in'],
              'created_at': DateTime.now().toIso8601String(),
            };

            // Write tokens to tokens.json
            final file = File(tokensFile);
            file.writeAsStringSync(jsonEncode(tokenData));

            yield true;
            return;
          }
        } else {
          try {
            final err = jsonDecode(response.body);
            final error = err['error'];
            if (error == 'authorization_pending') {
              yield false;
              continue;
            } else if (error == 'slow_down') {
              intervalSeconds += 2;
              yield false;
              continue;
            } else {
              yield false;
              return;
            }
          } catch (_) {
            yield false;
          }
        }
      } catch (_) {
        yield false;
      }
    }
  }
}
