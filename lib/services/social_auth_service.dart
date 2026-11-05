import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Google ve Apple ile giriş / yeniden kimlik doğrulama.
///
/// Firebase Console > Authentication > Sign-in method altında Google ve Apple
/// etkin olmalı. OAuth istemci kimlikleri google-services.json ve
/// GoogleService-Info.plist dosyalarından alındı; gizli değildir.
class SocialAuthService {
  SocialAuthService._();

  /// google-services.json içindeki client_type=3 (web) istemcisi.
  /// Android'de idToken alabilmek için serverClientId olarak verilir.
  static const String _webClientId =
      '159656243067-g8mbod35glvo8v3mjbgts7mdd7gjco06.apps.googleusercontent.com';

  /// GoogleService-Info.plist içindeki CLIENT_ID. Plist Xcode projesine
  /// eklenmediği için istemci kimliği buradan veriliyor.
  static const String _iosClientId =
      '159656243067-3ghbfi1oanoq72loof982el2d36vcu91.apps.googleusercontent.com';

  static bool _googleInitialized = false;

  /// Apple ile giriş yalnızca iOS'ta sunulur. Android'de web akışı ve
  /// Apple Services ID gerekir; şimdilik kapsam dışı.
  static bool get isAppleAvailable => Platform.isIOS;

  /// Sosyal giriş sonucu. [fullName] yalnızca Apple'ın ilk girişinde dolu
  /// gelir; sonraki girişlerde Apple adı bir daha vermez.
  static Future<SocialSignInResult?> signInWithGoogle() async {
    final credential = await _googleCredential();
    if (credential == null) return null;
    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    return SocialSignInResult(userCredential: userCredential);
  }

  static Future<SocialSignInResult?> signInWithApple() async {
    final apple = await _appleCredential();
    if (apple == null) return null;
    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(apple.credential);
    return SocialSignInResult(
      userCredential: userCredential,
      fullName: apple.fullName,
    );
  }

  /// Hesap silme gibi hassas işlemler öncesi yeniden kimlik doğrulama.
  /// Kullanıcı vazgeçerse false döner.
  static Future<bool> reauthenticateWithGoogle(User user) async {
    final credential = await _googleCredential();
    if (credential == null) return false;
    await user.reauthenticateWithCredential(credential);
    return true;
  }

  /// Apple ile yeniden doğrular ve App Store kuralı gereği (5.1.1) hesap
  /// silinmeden önce Apple token'ını iptal eder.
  static Future<bool> reauthenticateWithAppleAndRevoke(User user) async {
    final apple = await _appleCredential();
    if (apple == null) return false;
    await user.reauthenticateWithCredential(apple.credential);
    if (apple.authorizationCode.isNotEmpty) {
      await FirebaseAuth.instance
          .revokeTokenWithAuthorizationCode(apple.authorizationCode);
    }
    return true;
  }

  /// Çıkışta Google oturumunu da kapatır; böylece bir sonraki girişte
  /// hesap seçici tekrar görünür.
  static Future<void> signOut() async {
    try {
      await _ensureGoogleInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google oturumu yoksa sessizce geç.
    }
  }

  static Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS ? _iosClientId : null,
      serverClientId: _webClientId,
    );
    _googleInitialized = true;
  }

  /// Kullanıcı iptal ederse null döner.
  static Future<AuthCredential?> _googleCredential() async {
    await _ensureGoogleInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-id-token',
          message: 'Google kimlik belirteci alınamadı.',
        );
      }
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  static Future<_AppleResult?> _appleCredential() async {
    final rawNonce = _generateNonce();
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256(rawNonce),
      );
      final credential = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        rawNonce: rawNonce,
        accessToken: apple.authorizationCode,
      );
      final nameParts = [apple.givenName, apple.familyName]
          .where((p) => p != null && p.trim().isNotEmpty)
          .map((p) => p!.trim())
          .toList();
      return _AppleResult(
        credential: credential,
        authorizationCode: apple.authorizationCode,
        fullName: nameParts.isEmpty ? null : nameParts.join(' '),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}

class SocialSignInResult {
  final UserCredential userCredential;
  final String? fullName;

  const SocialSignInResult({required this.userCredential, this.fullName});
}

class _AppleResult {
  final AuthCredential credential;
  final String authorizationCode;
  final String? fullName;

  const _AppleResult({
    required this.credential,
    required this.authorizationCode,
    this.fullName,
  });
}
