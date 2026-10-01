import 'dart:convert';

import 'soap_client.dart';

class BirthAnalysisRecord {
  const BirthAnalysisRecord({
    required this.order,
    required this.quantity,
    required this.description,
  });

  final int order;
  final int quantity;
  final String description;

  factory BirthAnalysisRecord.fromJson(Map<String, dynamic> json) =>
      BirthAnalysisRecord(
        order: _birthInt(_birthField(json, 'ORDEM')),
        quantity: _birthInt(_birthField(json, 'QTD')),
        description: '${_birthField(json, 'DESCRICAO') ?? ''}'.trim(),
      );
}

class BirthAnalysisRepository {
  BirthAnalysisRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<BirthAnalysisRecord>> fetchRecords() async {
    final rows = await _query(
      'SELECT ORDEM, QTD, DESCRICAO FROM REL_ANALISE_PARTOS ORDER BY ORDEM',
    );
    return rows.map(BirthAnalysisRecord.fromJson).toList(growable: false);
  }

  Future<void> generate(String dateStart, String dateEnd) => _execute(
    birthAnalysisGenerateSql(dateStart: dateStart, dateEnd: dateEnd),
    action: 'ExecSql',
  );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_birthXmlEscape(sql)}</xSql>'
          '<Sufixo>${_birthXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_birthXmlEscape(sql)}</xSql>'
          '<Login>${_birthXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_birthXmlEscape(password)}</Senha>'
          '<Sufixo>${_birthXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String birthAnalysisGenerateSql({
  required String dateStart,
  required String dateEnd,
}) {
  return 'EXEC SP_REL_ANALISE_PARTOS ${birthSqlDate(dateStart)}, ${birthSqlDate(dateEnd)};';
}

String birthSqlDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data da análise inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data da análise inválida: $value');
  }
  return "'$normalized'";
}

dynamic _birthField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _birthInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

String _birthXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
