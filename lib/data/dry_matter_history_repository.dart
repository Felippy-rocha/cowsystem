import 'dart:convert';

import 'soap_client.dart';

class DryMatterChoice {
  const DryMatterChoice({required this.code, required this.name});

  final int code;
  final String name;

  factory DryMatterChoice.fromJson(Map<String, dynamic> json) =>
      DryMatterChoice(
        code: _dmInt(_dmField(json, 'CODIGO')),
        name: '${_dmField(json, 'NOME') ?? ''}'.trim(),
      );
}

class DryMatterHistoryRecord {
  const DryMatterHistoryRecord({
    required this.id,
    required this.typeCode,
    required this.typeName,
    required this.date,
    required this.ingredientCode,
    required this.dietCode,
    required this.entityName,
    required this.percentage,
  });

  final int id;
  final int typeCode;
  final String typeName;
  final String date;
  final int ingredientCode;
  final int dietCode;
  final String entityName;
  final double percentage;

  factory DryMatterHistoryRecord.fromJson(Map<String, dynamic> json) =>
      DryMatterHistoryRecord(
        id: _dmInt(_dmField(json, 'ID')),
        typeCode: _dmInt(_dmField(json, 'CODTIPO')),
        typeName: '${_dmField(json, 'TIPO') ?? ''}'.trim(),
        date: '${_dmField(json, 'DATA') ?? ''}'.trim(),
        ingredientCode: _dmInt(_dmField(json, 'CODINGREDIENTE')),
        dietCode: _dmInt(_dmField(json, 'CODDIETA')),
        entityName: '${_dmField(json, 'ENTIDADE') ?? ''}'.trim(),
        percentage: _dmDouble(_dmField(json, 'MS')),
      );
}

class DryMatterHistoryRepository {
  DryMatterHistoryRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<DryMatterChoice>> fetchTypes() async {
    final rows = await _query(
      'SELECT CODIGO, DESCRICAO AS NOME FROM TB_TIPOHISTORICOMS ORDER BY CODIGO',
    );
    return rows.map(DryMatterChoice.fromJson).toList(growable: false);
  }

  Future<List<DryMatterChoice>> fetchDiets() async {
    final rows = await _query(
      'SELECT CODDIETA AS CODIGO, DESCRICAO AS NOME FROM TB_DIETA ORDER BY DESCRICAO',
    );
    return rows.map(DryMatterChoice.fromJson).toList(growable: false);
  }

  Future<List<DryMatterChoice>> fetchIngredients() async {
    final rows = await _query(
      'SELECT CODINGREDIENTE AS CODIGO, INGREDIENTE AS NOME '
      'FROM TB_INGREDIENTES ORDER BY INGREDIENTE',
    );
    return rows.map(DryMatterChoice.fromJson).toList(growable: false);
  }

  Future<List<DryMatterHistoryRecord>> fetchHistory({String date = ''}) async {
    final filter = date.trim().isEmpty
        ? ''
        : 'WHERE TRY_CONVERT(date, H.DATA, 103) = ${dryMatterSqlDate(date)}';
    final rows = await _query('''
SELECT H.ID, H.CODTIPO, T.DESCRICAO AS TIPO, H.DATA,
  H.CODINGREDIENTE, H.CODDIETA, H.MS,
  CASE WHEN H.CODTIPO = 1 THEN D.DESCRICAO ELSE I.INGREDIENTE END AS ENTIDADE
FROM TB_HISTORICOMS H
INNER JOIN TB_TIPOHISTORICOMS T ON T.CODIGO = H.CODTIPO
LEFT JOIN TB_INGREDIENTES I ON I.CODINGREDIENTE = H.CODINGREDIENTE
LEFT JOIN TB_DIETA D ON D.CODDIETA = H.CODDIETA
$filter
ORDER BY H.ID DESC''');
    return rows.map(DryMatterHistoryRecord.fromJson).toList(growable: false);
  }

  Future<void> save({
    int id = -1,
    required int typeCode,
    required String date,
    required int ingredientCode,
    required int dietCode,
    required double percentage,
  }) => _execute(
    dryMatterHistorySaveSql(
      id: id,
      typeCode: typeCode,
      date: date,
      ingredientCode: ingredientCode,
      dietCode: dietCode,
      percentage: percentage,
    ),
  );

  Future<void> delete(int id) =>
      _execute('DELETE FROM TB_HISTORICOMS WHERE ID = ${_dmPositive(id)};');

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_dmXmlEscape(sql)}</xSql>'
          '<Sufixo>${_dmXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_dmXmlEscape(sql)}</xSql>'
          '<Login>${_dmXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_dmXmlEscape(password)}</Senha>'
          '<Sufixo>${_dmXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String dryMatterSqlDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data de matéria seca inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data de matéria seca inválida: $value');
  }
  return "'$normalized'";
}

String dryMatterHistorySaveSql({
  int id = -1,
  required int typeCode,
  required String date,
  required int ingredientCode,
  required int dietCode,
  required double percentage,
}) {
  if (id < -1 ||
      typeCode <= 0 ||
      percentage <= 0 ||
      (typeCode == 1 && dietCode <= 0) ||
      (typeCode == 2 && ingredientCode <= 0)) {
    throw ArgumentError(
      'Informe tipo, dieta ou ingrediente e percentual MS válido.',
    );
  }
  final value = percentage.toStringAsFixed(2);
  return 'EXEC SP_TB_HISTORICOMS_INSERT $id, $typeCode, '
      '${dryMatterSqlDate(date)}, $ingredientCode, $dietCode, $value;';
}

int _dmPositive(int value) {
  if (value <= 0) throw ArgumentError.value(value, 'id');
  return value;
}

dynamic _dmField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _dmInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _dmDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _dmXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
