import 'dart:convert';

import 'soap_client.dart';

class MilkHistoryRecord {
  const MilkHistoryRecord({
    required this.year,
    required this.totalMilk,
    required this.animals,
    required this.average,
    required this.del,
  });

  final String year;
  final double totalMilk;
  final int animals;
  final double average;
  final int del;

  factory MilkHistoryRecord.fromJson(Map<String, dynamic> json) =>
      MilkHistoryRecord(
        year: '${_milkField(json, 'ANO') ?? ''}'.trim(),
        totalMilk: _milkDouble(_milkField(json, 'TOTAL_LEITE')),
        animals: _milkInt(_milkField(json, 'NUM_ANIMAIS')),
        average: _milkDouble(_milkField(json, 'MEDIA')),
        del: _milkInt(_milkField(json, 'DEL')),
      );
}

class MilkHistoryRepository {
  MilkHistoryRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<MilkHistoryRecord>> fetchHistory() async {
    final rows = await _query(milkHistorySql());
    return rows.map(MilkHistoryRecord.fromJson).toList(growable: false);
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

String milkHistorySql() =>
    'SELECT ANO, TOTAL_LEITE, NUM_ANIMAIS, MEDIA, DEL '
    'FROM dbo.RESUMO_LEITE_HISTORICO()';

dynamic _milkField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _milkInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _milkDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _milkXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
