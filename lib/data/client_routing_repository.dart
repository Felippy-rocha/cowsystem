import 'dart:convert';

import 'client_routing.dart';
import 'soap_client.dart';

class UnregisteredDeviceException extends SoapException {
  const UnregisteredDeviceException(this.deviceId)
    : super('Este dispositivo ainda nao esta cadastrado no servidor.');

  final String deviceId;
}

class ClientRoutingRepository {
  ClientRoutingRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<ClientRoutingRecord> resolveDevice() async {
    final deviceId = soapClient.deviceId.trim();
    if (deviceId.isEmpty) {
      throw const SoapException('Dispositivo nao identificado.');
    }

    final response = await soapClient.callResult(
      action: 'ObterClientePorDispositivo',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body: '<xDispositivo>${_xmlEscape(deviceId)}</xDispositivo>',
    );
    final rows = _parseRows(response);
    if (rows.isEmpty) {
      throw UnregisteredDeviceException(deviceId);
    }

    final routing = ClientRoutingRecord.fromJson(rows.first);
    if (routing.deviceId.isNotEmpty &&
        routing.deviceId.trim().toLowerCase() != deviceId.toLowerCase()) {
      throw SoapException(
        'Dispositivo retornado diferente do consultado: '
        '${routing.deviceId.trim()} / $deviceId',
      );
    }
    if (routing.suffix.isEmpty) {
      throw const SoapException('Dispositivo sem sufixo de base configurado.');
    }
    if (!routing.active) {
      throw const SoapException('Dispositivo desativado.');
    }

    soapClient.suffix = routing.suffix;
    ClientRoutingSession.deviceId = soapClient.deviceId;
    ClientRoutingSession.suffix = routing.suffix;
    ClientRoutingSession.profileCode = routing.profileCode;
    ClientRoutingSession.profileDescription = await _fetchProfileDescription(
      routing.profileCode,
    );
    ClientRoutingSession.company = routing.company;
    ClientRoutingSession.username = routing.username;
    ClientRoutingSession.appVersion = routing.appVersion;
    ClientRoutingSession.canGrantPermissions = await _canGrantPermissions(
      routing.profileCode,
    );
    return routing;
  }

  Future<bool> _canGrantPermissions(int profileCode) async {
    if (profileCode <= 0) return false;
    final query =
        '''SELECT TOP 1 PP.PERMITIDO
FROM TB_PERFILPERMISSOES_NEW PP
INNER JOIN TB_PERMISSOES_NEW P ON P.CODPERMISSAO = PP.CODPERMISSAO
WHERE PP.CODPERFIL = $profileCode
AND UPPER(P.ROTINA) = 'PERFIL'
AND UPPER(P.PERMISSAO) LIKE 'CONCEDER%'
AND PP.PERMITIDO = 1''';
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_xmlEscape(query)}</xSql>'
          '<Sufixo>${_xmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    return _parseRows(response).isNotEmpty;
  }

  Future<String> _fetchProfileDescription(int profileCode) async {
    if (profileCode <= 0) return '';
    final query =
        'SELECT TOP 1 DESCRICAO FROM TB_PERFIL '
        'WHERE CODPERFIL = $profileCode';
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_xmlEscape(query)}</xSql>'
          '<Sufixo>${_xmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    final rows = _parseRows(response);
    if (rows.isEmpty) return '';
    final description = rows.first['DESCRICAO'];
    return description == null ? '' : '$description'.trim();
  }

  List<Map<String, dynamic>> _parseRows(String response) {
    final value = response.trim();
    if (value.isEmpty ||
        value.toLowerCase().contains('dispositivo nao liberado')) {
      return const [];
    }
    if (value.startsWith('#ic#')) {
      final message = value.replaceFirst('#ic#', '').replaceFirst('#fc#', '');
      throw SoapException(message);
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );
      }
      if (decoded is Map<String, dynamic>) return [decoded];
    } on FormatException {
      throw SoapException(value);
    }
    throw SoapException(value);
  }

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
