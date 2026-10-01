import 'dart:convert';

import 'permission_repository.dart';
import 'soap_client.dart';

class DiscardReason {
  const DiscardReason({required this.code, required this.description});

  final int code;
  final String description;

  factory DiscardReason.fromJson(Map<String, dynamic> json) => DiscardReason(
    code: int.tryParse('${_discardField(json, 'CODMOTIVODESCARTE') ?? 0}') ?? 0,
    description: '${_discardField(json, 'MOTIVODESCARTE') ?? ''}'.trim(),
  );
}

class AnimalDiscardRepository {
  AnimalDiscardRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<DiscardReason>> fetchReasons() async => (await _query(
    'SELECT CODMOTIVODESCARTE, MOTIVODESCARTE FROM TB_MOTIVODESCARTE '
    'ORDER BY MOTIVODESCARTE',
  )).map(DiscardReason.fromJson).toList(growable: false);

  Future<bool> canDiscard(int profileCode) async {
    if (profileCode <= 0) return false;
    final permissions = PermissionRepository(soapClient: soapClient);
    final results = await Future.wait([
      permissions.fetchPermissionCatalog(),
      permissions.fetchProfilePermissions(profileCode),
    ]);
    final catalog = results[0] as List<PermissionDefinitionRecord>;
    final allowed = results[1] as Map<int, bool>;
    return catalog.any((item) {
      final routine = item.routine.trim().toUpperCase();
      final action = item.action.trim().toUpperCase();
      return routine == 'ANIMAIS' &&
          (action == 'DESCARTAR ANIMAL' ||
              action == 'EXCLUIR ANIMAL' ||
              action == 'EXCLUIR REGISTRO') &&
          allowed[item.code] == true;
    });
  }

  Future<void> discard({
    required int animalCode,
    required int reasonCode,
    required String date,
    required String comment,
  }) => _execute(
    animalDiscardSql(
      animalCode: animalCode,
      reasonCode: reasonCode,
      date: date,
      comment: comment,
    ),
  );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_discardXmlEscape(sql)}</xSql>'
          '<Sufixo>${_discardXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    final value = response.trim();
    if (value.startsWith('#ic#')) {
      throw SoapException(
        value.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
      if (decoded is Map<String, dynamic>) return [decoded];
    } on FormatException {
      throw SoapException(value.isEmpty ? 'Resposta vazia do Azure.' : value);
    }
    if (value.isEmpty) return const [];
    throw SoapException(value);
  }

  Future<void> _execute(String sql) async {
    final password = const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD');
    final response = await soapClient.callResult(
      action: 'ExecSql',
      password: password,
      body:
          '<xSql>${_discardXmlEscape(sql)}</xSql>'
          '<Login>${_discardXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_discardXmlEscape(password)}</Senha>'
          '<Sufixo>${_discardXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String animalDiscardSql({
  required int animalCode,
  required int reasonCode,
  required String date,
  required String comment,
}) {
  if (animalCode <= 0 || reasonCode <= 0) {
    throw ArgumentError('Animal e motivo são obrigatórios.');
  }
  return 'EXEC SP_TB_ANIMAIS_DESCARTAR '
      '@CODANIMAL = $animalCode, @CODMOTIVODESCARTE = $reasonCode, '
      '@DATADESCARTE = ${_discardSqlDate(date)}, '
      '@COMENTARIODESCARTE = ${_discardSqlText(comment)};';
}

String _discardSqlDate(String value) {
  final trimmed = value.trim();
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = br == null
      ? trimmed
      : '${br.group(3)}-${br.group(2)}-${br.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data de descarte inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw FormatException('Data de descarte inválida: $value');
  }
  return "'$normalized'";
}

String _discardSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

dynamic _discardField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

String _discardXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
