import 'dart:convert';

import 'soap_client.dart';

class PrevisionTouchRecord {
  const PrevisionTouchRecord({
    required this.id,
    required this.animalCode,
    required this.tag,
    required this.lotCode,
    required this.type,
    required this.daysSinceInsemination,
    required this.daysInMilk,
    required this.inseminationCount,
    required this.cowHeifer,
    required this.birthDate,
    required this.lastCalvingDate,
    required this.lastInseminationDate,
    required this.lactationCode,
    required this.lot,
    required this.productionStatus,
    required this.reproductiveStatus,
    required this.weight,
  });

  final int id;
  final int animalCode;
  final String tag;
  final int lotCode;
  final String type;
  final int daysSinceInsemination;
  final int daysInMilk;
  final int inseminationCount;
  final String cowHeifer;
  final String birthDate;
  final String lastCalvingDate;
  final String lastInseminationDate;
  final String lactationCode;
  final String lot;
  final String productionStatus;
  final String reproductiveStatus;
  final double weight;

  factory PrevisionTouchRecord.fromJson(Map<String, dynamic> json) =>
      PrevisionTouchRecord(
        id: _previsionInt(_previsionField(json, 'ID_INSEMINACAO')),
        animalCode: _previsionInt(_previsionField(json, 'CODANIMAL')),
        tag: '${_previsionField(json, 'BRINCO') ?? ''}'.trim(),
        lotCode: _previsionInt(_previsionField(json, 'CODLOTE')),
        type: '${_previsionField(json, 'TIPOTOQUE') ?? ''}'.trim(),
        daysSinceInsemination: _previsionInt(
          _previsionField(json, 'DIASDEINSEMINADA'),
        ),
        daysInMilk: _previsionInt(_previsionField(json, 'DEL')),
        inseminationCount: _previsionInt(_previsionField(json, 'NUMIAS')),
        cowHeifer: '${_previsionField(json, 'VACANOVILHA') ?? ''}'.trim(),
        birthDate: '${_previsionField(json, 'DATANASCIMENTO') ?? ''}'.trim(),
        lastCalvingDate: '${_previsionField(json, 'ULTIMOPARTO') ?? ''}'.trim(),
        lastInseminationDate: '${_previsionField(json, 'DATAULTIMAIA') ?? ''}'
            .trim(),
        lactationCode: '${_previsionField(json, 'CODLACTACAO') ?? ''}'.trim(),
        lot: '${_previsionField(json, 'LOTE') ?? ''}'.trim(),
        productionStatus: '${_previsionField(json, 'STATUSPRODUCAO') ?? ''}'
            .trim(),
        reproductiveStatus: '${_previsionField(json, 'STATUSREPRODUCAO') ?? ''}'
            .trim(),
        weight: _previsionDouble(_previsionField(json, 'PESO')),
      );
}

class PrevisionTouchRepository {
  PrevisionTouchRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<PrevisionTouchRecord>> fetchRecords(String date) async {
    final rows = await _query('''
SELECT ID_INSEMINACAO, CODANIMAL, BRINCO, CODLOTE, TIPOTOQUE,
  DIASDEINSEMINADA, DEL, NUMIAS, VACANOVILHA, DATANASCIMENTO, ULTIMOPARTO,
  DATAULTIMAIA, CODLACTACAO, LOTE, STATUSPRODUCAO, STATUSREPRODUCAO, PESO
FROM TB_PREVISAO_TOQUE
WHERE TRY_CONVERT(date, DATAULTIMAIA, 103) = ${previsionSqlDate(date)}
ORDER BY BRINCO''');
    return rows.map(PrevisionTouchRecord.fromJson).toList(growable: false);
  }

  Future<void> generate(String date) =>
      _execute(previsionTouchGenerateSql(date), action: 'ExecSql');

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_previsionXmlEscape(sql)}</xSql>'
          '<Sufixo>${_previsionXmlEscape(soapClient.suffix)}</Sufixo>'
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

  Future<void> _execute(String sql, {String action = 'ExecSP'}) async {
    final password = const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD');
    final response = await soapClient.callResult(
      action: action,
      password: password,
      body:
          '<xSql>${_previsionXmlEscape(sql)}</xSql>'
          '<Login>${_previsionXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_previsionXmlEscape(password)}</Senha>'
          '<Sufixo>${_previsionXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String previsionTouchGenerateSql(String date) {
  final value = date.trim();
  if (value.isEmpty) {
    throw ArgumentError('Informe a data da previsão de toque.');
  }
  return 'EXEC SP_TB_PREVISAO_TOQUE_INSERT @DATA = ${_previsionSqlDate(value)};';
}

String previsionSqlDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data da previsão inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data da previsão inválida: $value');
  }
  return "'$normalized'";
}

String _previsionSqlDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data da previsão inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data da previsão inválida: $value');
  }
  return "'$normalized'";
}

dynamic _previsionField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _previsionInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _previsionDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _previsionXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
