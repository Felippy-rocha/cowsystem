import 'dart:convert';

import 'soap_client.dart';

class DelRangeSummaryRecord {
  const DelRangeSummaryRecord({
    required this.range,
    required this.totalMilk,
    required this.animals,
    required this.average,
    required this.del,
  });

  final String range;
  final double totalMilk;
  final int animals;
  final double average;
  final int del;

  factory DelRangeSummaryRecord.fromJson(Map<String, dynamic> json) =>
      DelRangeSummaryRecord(
        range: '${_milkField(json, 'FAIXA') ?? ''}'.trim(),
        totalMilk: _milkDouble(_milkField(json, 'TOTAL_LEITE')),
        animals: _milkInt(_milkField(json, 'NUM_ANIMAIS')),
        average: _milkDouble(_milkField(json, 'MEDIA')),
        del: _milkInt(_milkField(json, 'DEL')),
      );
}

class DelRangeSummaryRepository {
  DelRangeSummaryRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<String>> fetchPeriods() async {
    final rows = await _query(
      'SELECT DISTINCT MES_ANO FROM TB_MES_ANO GROUP BY MES_ANO '
      'ORDER BY MES_ANO DESC',
    );
    return rows
        .map((row) => '${_milkField(row, 'MES_ANO') ?? ''}'.trim())
        .where((period) => period.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> fetchYears() async {
    final rows = await _query(
      'SELECT SUBSTRING(MES_ANO, 4, 4) AS ANO FROM TB_MES_ANO '
      'GROUP BY SUBSTRING(MES_ANO, 4, 4) ORDER BY ANO DESC',
    );
    return rows
        .map((row) => '${_milkField(row, 'ANO') ?? ''}'.trim())
        .where((year) => year.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<DelRangeSummaryRecord>> fetchMonthly(String period) async {
    final rows = await _query(delRangeMonthlySql(period));
    return rows.map(DelRangeSummaryRecord.fromJson).toList(growable: false);
  }

  Future<List<DelRangeSummaryRecord>> fetchAnnual(int year) async {
    final rows = await _query(delRangeAnnualSql(year));
    return rows.map(DelRangeSummaryRecord.fromJson).toList(growable: false);
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

String delRangeMonthlySql(String period) {
  final value = period.trim();
  if (!RegExp(r'^\d{2}/\d{4}$').hasMatch(value)) {
    throw ArgumentError('Informe o período no formato MM/AAAA.');
  }
  return 'SELECT FAIXA, TOTAL_LEITE, NUM_ANIMAIS, MEDIA, DEL_MEDIO AS DEL '
      'FROM dbo.RESUMO_LEITE_FAIXA_DEL_MENSAL(${_milkSqlText(value)})';
}

String delRangeAnnualSql(int year) {
  if (year < 2000 || year > 2100) {
    throw ArgumentError('Informe um ano válido para o resumo por faixa DEL.');
  }
  return 'SELECT FAIXA, TOTAL_LEITE, NUM_ANIMAIS, MEDIA, DEL_MEDIO AS DEL '
      'FROM dbo.RESUMO_LEITE_FAIXA_DEL_ANUAL($year)';
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
