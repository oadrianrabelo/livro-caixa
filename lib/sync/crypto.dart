// Criptografia da sincronização: o Google guarda os arquivos, mas não lê.
//
// - A "senha da casa" vira uma chave de 256 bits com PBKDF2-SHA256 (lento de
//   propósito, para dificultar adivinhar a senha) e um "sal" aleatório que
//   fica no Drive junto com os dados.
// - Cada arquivo é comprimido (gzip) e cifrado com AES-256-GCM, que também
//   detecta qualquer alteração: arquivo mexido = erro, nunca dado errado.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const _magic = [0x4C, 0x43, 0x58, 0x31]; // "LCX1"
const _kdfIterations = 150000;
final _aes = AesGcm.with256bits();

List<int> randomBytes(int n) {
  final r = Random.secure();
  return [for (var i = 0; i < n; i++) r.nextInt(256)];
}

// Tudo que é pesado (derivar a chave, cifrar, decifrar) roda em outro
// isolate: assim a tela nunca trava enquanto sincroniza.

/// Senha + sal -> chave (32 bytes). Leva ~1 s no celular: é feito uma vez por aparelho.
Future<List<int>> deriveKey(String passphrase, List<int> salt) =>
    Isolate.run(() => _deriveKey(passphrase, List<int>.of(salt)));

Future<List<int>> _deriveKey(String passphrase, List<int> salt) async {
  final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: _kdfIterations, bits: 256);
  final key = await kdf.deriveKeyFromPassword(password: passphrase, nonce: salt);
  return key.extractBytes();
}

/// JSON -> gzip -> AES-GCM. Formato: "LCX1" + nonce(12) + mac(16) + dados.
Future<Uint8List> seal(Object json, List<int> key) => Isolate.run(() => _seal(json, List<int>.of(key)));

Future<Uint8List> _seal(Object json, List<int> key) async {
  final plain = gzip.encode(utf8.encode(jsonEncode(json)));
  final box = await _aes.encrypt(plain, secretKey: SecretKey(key), nonce: randomBytes(12));
  return Uint8List.fromList([..._magic, ...box.nonce, ...box.mac.bytes, ...box.cipherText]);
}

class WrongKeyException implements Exception {
  const WrongKeyException();
  @override
  String toString() => 'Senha da casa diferente da usada no outro aparelho.';
}

/// O inverso de [seal]. Lança [WrongKeyException] se a chave não bater
/// (ou se o arquivo foi alterado).
Future<Object?> open(List<int> bytes, List<int> key) =>
    Isolate.run(() => _open(List<int>.of(bytes), List<int>.of(key)));

Future<Object?> _open(List<int> bytes, List<int> key) async {
  if (bytes.length < 32 || !_startsWithMagic(bytes)) throw const FormatException('Arquivo de sincronização inválido.');
  final box = SecretBox(bytes.sublist(32), nonce: bytes.sublist(4, 16), mac: Mac(bytes.sublist(16, 32)));
  try {
    final plain = await _aes.decrypt(box, secretKey: SecretKey(key));
    return jsonDecode(utf8.decode(gzip.decode(plain)));
  } on SecretBoxAuthenticationError {
    throw const WrongKeyException();
  }
}

bool _startsWithMagic(List<int> b) => [for (var i = 0; i < 4; i++) b[i] == _magic[i]].every((x) => x);

/// Impressão digital (SHA-256) de um JSON, calculada fora da tela.
Future<String> jsonHash(Object json) => Isolate.run(() async {
  final h = await Sha256().hash(utf8.encode(jsonEncode(json)));
  return base64.encode(h.bytes);
});
