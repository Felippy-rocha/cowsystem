import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class SoapException implements Exception {
  const SoapException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'SoapException: $message';
}

class SoapClient {
  SoapClient({
    http.Client? client,
    this.endpoint = const String.fromEnvironment(
      'COWSYSTEM_SOAP_URL',
      defaultValue: 'https://wscowsystem.azurewebsites.net/servico.asmx',
    ),
    this.username = const String.fromEnvironment(
      'COWSYSTEM_SOAP_USER',
      defaultValue: 'FVR',
    ),
    this.deviceId = const String.fromEnvironment(
      'COWSYSTEM_DEVICE_ID',
      defaultValue: 'flutter',
    ),
    this.timeout = const Duration(seconds: 40),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String endpoint;
  final String username;
  final String deviceId;
  final Duration timeout;

  Future<String> call({
    required String action,
    required String body,
    required String password,
  }) async {
    final envelope = _envelope(action: action, body: body, password: password);

    try {
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/soap+xml; charset=utf-8',
              'SOAPAction': 'http://tempuri.org/$action',
            },
            body: envelope,
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SoapException(
          'O servidor retornou HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }
      return response.body;
    } on TimeoutException {
      throw const SoapException('Tempo limite da comunicacao excedido.');
    } on SoapException {
      rethrow;
    } catch (error) {
      throw SoapException('Falha na comunicacao com o servidor: $error');
    }
  }

  Future<String> callResult({
    required String action,
    required String body,
    required String password,
  }) async {
    final response = await call(action: action, body: body, password: password);
    try {
      final document = XmlDocument.parse(response);
      String? result;
      for (final element in document.descendants.whereType<XmlElement>()) {
        if (element.localName.endsWith('Result')) {
          result = element.innerText;
          break;
        }
      }
      if (result == null || result.isEmpty) {
        throw const SoapException('Resposta SOAP sem elemento de resultado.');
      }
      return result;
    } on SoapException {
      rethrow;
    } catch (error) {
      throw SoapException('Resposta SOAP invalida: $error');
    }
  }

  String buildEnvelope({
    required String action,
    required String body,
    required String password,
  }) {
    return _envelope(action: action, body: body, password: password);
  }

  String _envelope({
    required String action,
    required String body,
    required String password,
  }) {
    return '''<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Header>
    <Autenticacao xmlns="http://tempuri.org/">
      <Usuario>${_xmlEscape(username)}</Usuario>
      <Senha>${_xmlEscape(password)}</Senha>
      <Dispositivo>${_xmlEscape(deviceId)}</Dispositivo>
    </Autenticacao>
  </soap12:Header>
  <soap12:Body>
    <$action xmlns="http://tempuri.org/">$body</$action>
  </soap12:Body>
</soap12:Envelope>''';
  }

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  void close() => _client.close();
}
