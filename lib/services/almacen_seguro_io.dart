import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const persisteToken = true;

const _almacen = FlutterSecureStorage(
  aOptions: AndroidOptions(),
);

const _clave = 'paw_sesion_nativa';

Future<void> guardar(String? token) async {
  if (token == null || token.isEmpty) {
    await _almacen.delete(key: _clave);
    return;
  }
  await _almacen.write(key: _clave, value: token);
}

Future<String?> leer() => _almacen.read(key: _clave);
