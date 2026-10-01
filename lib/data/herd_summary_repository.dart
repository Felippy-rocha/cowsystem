import 'dart:convert';

import 'soap_client.dart';

class HerdSummaryRecord {
  const HerdSummaryRecord({
    required this.order,
    required this.quantity,
    required this.description,
    required this.sql,
  });

  final int order;
  final int quantity;
  final String description;
  final String sql;

  factory HerdSummaryRecord.fromJson(Map<String, dynamic> json) =>
      HerdSummaryRecord(
        order: _summaryInt(_summaryField(json, 'ORDEM')),
        quantity: _summaryInt(_summaryField(json, 'QTD')),
        description: '${_summaryField(json, 'DESCRICAO') ?? ''}'.trim(),
        sql: '${_summaryField(json, 'SQL') ?? ''}'.trim(),
      );
}

class HerdSummaryRepository {
  HerdSummaryRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<HerdSummaryRecord>> fetchSummary(String description) async {
    final rows = await _query(
      'SELECT ORDEM, QTD, DESCRICAO, SQL FROM REL_RESUMO_REBANHO '
      'WHERE DESCRICAO LIKE ${_summarySqlText(description.trim())} '
      'ORDER BY ORDEM',
    );
    return rows.map(HerdSummaryRecord.fromJson).toList(growable: false);
  }

  Future<void> generateSummary(String description) =>
      _execute(herdSummaryGenerateSql(description), action: 'ExecSql');

  Future<void> openDetail(String sql) => _execute(sql, action: 'ExecSql');

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_summaryXmlEscape(sql)}</xSql>'
          '<Sufixo>${_summaryXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_summaryXmlEscape(sql)}</xSql>'
          '<Login>${_summaryXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_summaryXmlEscape(password)}</Senha>'
          '<Sufixo>${_summaryXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String herdSummaryGenerateSql(String description) {
  final value = description.trim();
  if (value.isEmpty) {
    throw ArgumentError('Informe a descrição do relatório.');
  }
  return 'EXEC SP_REL_RESUMO_REBANHO ${_summarySqlText(value)};';
}

String _summarySqlText(String value) => "N'${value.replaceAll("'", "''")}'";

dynamic _summaryField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _summaryInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

String _summaryXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
