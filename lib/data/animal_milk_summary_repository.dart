import 'dart:convert';

import 'soap_client.dart';

class AnimalMilkSummaryRecord {
  const AnimalMilkSummaryRecord({
    required this.date,
    required this.totalMilk,
    required this.del,
    required this.lactationCode,
    required this.withdrawalType,
  });

  final String date;
  final double totalMilk;
  final int del;
  final String lactationCode;
  final String withdrawalType;

  factory AnimalMilkSummaryRecord.fromJson(Map<String, dynamic> json) =>
      AnimalMilkSummaryRecord(
        date: '${_milkField(json, 'DATA') ?? ''}'.trim(),
        totalMilk: _milkDouble(_milkField(json, 'TOTAL_LEITE')),
        del: _milkInt(_milkField(json, 'DEL')),
        lactationCode: '${_milkField(json, 'CODLACTACAO') ?? ''}'.trim(),
        withdrawalType: '${_milkField(json, 'TIPO_CARENCIA') ?? ''}'.trim(),
      );
}

class AnimalMilkSummaryRepository {
  AnimalMilkSummaryRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<String>> fetchLactations(int animalCode) async {
    final rows = await _query(
      'SELECT CODLACTACAO FROM TB_CONTROLE_LEITEIRO_DETALHES '
      'WHERE CODANIMAL = $animalCode '
      'GROUP BY CODLACTACAO ORDER BY CODLACTACAO DESC',
    );
    return rows
        .map((row) => '${_milkField(row, 'CODLACTACAO') ?? ''}'.trim())
        .where((code) => code.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<AnimalMilkSummaryRecord>> fetchSummary(
    int animalCode,
    String lactationCode,
  ) async {
    final rows = await _query(
      'SELECT CODANIMAL, DATA, TOTAL_LEITE, DEL, CODLACTACAO, TIPO_CARENCIA '
      'FROM DBO.RESUMO_LEITE_ANIMAL($animalCode, ${_milkSqlText(lactationCode)})',
    );
    return rows.map(AnimalMilkSummaryRecord.fromJson).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_milkXmlEscape(sql)}</xSql>'
          '<Sufixo>${_milkXmlEscape(soapClient.suffix)}</Sufixo>'
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
}

String animalMilkSummarySql(int animalCode, String lactationCode) {
  if (animalCode <= 0) {
    throw ArgumentError('Informe o animal do resumo de leite.');
  }
  final value = lactationCode.trim();
  if (value.isEmpty) {
    throw ArgumentError('Informe a lactação do resumo de leite.');
  }
  return 'SELECT CODANIMAL, DATA, TOTAL_LEITE, DEL, CODLACTACAO, '
      'TIPO_CARENCIA FROM DBO.RESUMO_LEITE_ANIMAL('
      '$animalCode, ${_milkSqlText(value)})';
}

dynamic _milkField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _milkInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _milkDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _milkSqlText(String value) => "'${value.replaceAll("'", "''")}'";

String _milkXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
