import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted client-side session store. The backend is stateless JWT bearer
/// auth, so we persist the token (and the actor username, sent on mutations for
/// audit logging) in the platform keystore/keychain.
class Session {
  Session._();
  static final Session instance = Session._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kToken = 'emp.token';
  static const _kUser = 'emp.username';
  static const _kBiometric = 'emp.biometric';
  static const _kRemember = 'emp.remember';
  static const _kFace = 'emp.face';

  String? _token;
  String? _username;
  bool _remember = false;
  bool _face = false;

  String? get token => _token;
  String? get username => _username;
  bool get remember => _remember;
  bool get face => _face;

  Future<void> load() async {
    _token = await _storage.read(key: _kToken);
    _username = await _storage.read(key: _kUser);
    _remember = (await _storage.read(key: _kRemember)) == '1';
    _face = (await _storage.read(key: _kFace)) == '1';
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: _kToken, value: token);
  }

  Future<void> setUsername(String username) async {
    _username = username;
    await _storage.write(key: _kUser, value: username);
  }

  Future<void> setRemember(bool on) async {
    _remember = on;
    await _storage.write(key: _kRemember, value: on ? '1' : '0');
  }

  Future<void> clear() async {
    _token = null;
    _username = null;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUser);
  }

  Future<bool> biometricEnabled() async =>
      (await _storage.read(key: _kBiometric)) == '1';

  Future<void> setBiometricEnabled(bool on) async =>
      _storage.write(key: _kBiometric, value: on ? '1' : '0');

  Future<bool> faceEnabled() async =>
      (await _storage.read(key: _kFace)) == '1';

  Future<void> setFaceEnabled(bool on) async {
    _face = on;
    await _storage.write(key: _kFace, value: on ? '1' : '0');
  }
}
