import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'cliente_http_io.dart' if (dart.library.html) 'cliente_http_web.dart' as impl;
import 'almacen_seguro.dart';

export 'package:http/http.dart'
    hide get, post, put, patch, delete, head, read, readBytes, MultipartRequest;

Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    impl.cliente.get(url, headers: impl.conSesion(headers));

Future<http.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    impl.cliente.post(
      url,
      headers: impl.conSesion(headers),
      body: body,
      encoding: encoding,
    );

Future<http.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    impl.cliente.put(
      url,
      headers: impl.conSesion(headers),
      body: body,
      encoding: encoding,
    );

Future<http.Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    impl.cliente.patch(
      url,
      headers: impl.conSesion(headers),
      body: body,
      encoding: encoding,
    );

Future<http.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    impl.cliente.delete(
      url,
      headers: impl.conSesion(headers),
      body: body,
      encoding: encoding,
    );

Future<http.Response> head(Uri url, {Map<String, String>? headers}) =>
    impl.cliente.head(url, headers: impl.conSesion(headers));

Future<String> read(Uri url, {Map<String, String>? headers}) =>
    impl.cliente.read(url, headers: impl.conSesion(headers));

Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) =>
    impl.cliente.readBytes(url, headers: impl.conSesion(headers));

void recordarSesion(String? token, {bool persistir = false}) {
  impl.recordarSesion(token);
  if (token == null || !persistir) {
    AlmacenSeguro.guardar(null);
  } else {
    AlmacenSeguro.guardar(token);
  }
}

class MultipartRequest extends http.MultipartRequest {
  MultipartRequest(super.method, super.url);

  @override
  Future<http.StreamedResponse> send() {
    headers.addAll(impl.conSesion(null));
    return impl.cliente.send(this);
  }
}
