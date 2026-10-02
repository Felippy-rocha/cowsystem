import 'dart:convert';

import 'soap_client.dart';

class AnnualMilkSummaryRecord {
  const AnnualMilkSummaryRecord({
    required this.period,
    required this.totalMilk,
    required this.animals,
    required this.average,
    required this.del,
  });

  final String period;
  final double totalMilk;
  final int animals;
  final double average;
  final int del;

  factory AnnualMilkSummaryRecord.fromJson(Map<String, dynamic> json) =>
      AnnualMilkSummaryRecord(
        period: '${_milkField(json, 'PERIODO') ?? ''}'.trim(),
        totalMilk: _milkDouble(_milkField(json, 'TOTAL_LEITE')),
        animals: _milkInt(_milkField(json, 'ANIMAIS')),
        average: _milkDouble(_milkField(json, 'MEDIA')),
        del: _milkInt(_milkField(json, 'DEL')),
      );
}

class AnnualMilkComparisonRecord {
  const AnnualMilkComparisonRecord({
    required this.label,
    required this.average,
    required this.totalMilk,
    required this.previousAverage,
    required this.previousTotalMilk,
  });

  final String label;
  final double average;
  final double totalMilk;
  final double previousAverage;
  final double previousTotalMilk;

  factory AnnualMilkComparisonRecord.fromJson(
    Map<String, dynamic> json,
  ) => AnnualMilkComparisonRecord(
    label:
        '${_milkField(json, 'NUMLACTACOES') ?? _milkField(json, 'RACA') ?? ''}'
            .trim(),
    average: _milkDouble(_milkField(json, 'MEDIA')),
    totalMilk: _milkDouble(_milkField(json, 'TOTAL_LEITE')),
    previousAverage: _milkDouble(_milkField(json, 'MEDIA_ANTERIOR')),
    previousTotalMilk: _milkDouble(_milkField(json, 'TOTAL_LEITE_ANTERIOR')),
  );
}

class AnnualMilkSummaryRepository {
  AnnualMilkSummaryRepository({required this.soapClient});

  final SoapClient soapClient;

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

  Future<List<AnnualMilkSummaryRecord>> fetchSummary(int year) async {
    final rows = await _query(
      'SELECT PERIODO, TOTAL_LEITE, ANIMAIS, MEDIA, DEL '
      'FROM dbo.RESUMO_LEITE_ANUAL($year)',
    );
    return rows.map(AnnualMilkSummaryRecord.fromJson).toList(growable: false);
  }

  Future<List<AnnualMilkComparisonRecord>> fetchByLactation(int year) async {
    final rows = await _query(annualMilkLactationSql(year));
    return rows
        .map(AnnualMilkComparisonRecord.fromJson)
        .toList(growable: false);
  }

  Future<List<AnnualMilkComparisonRecord>> fetchByBreed(int year) async {
    final rows = await _query(annualMilkBreedSql(year));
    return rows
        .map(AnnualMilkComparisonRecord.fromJson)
        .toList(growable: false);
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

String annualMilkSummarySql(int year) {
  _validateYear(year);
  return 'SELECT PERIODO, TOTAL_LEITE, ANIMAIS, MEDIA, DEL '
      'FROM dbo.RESUMO_LEITE_ANUAL($year)';
}

String annualMilkLactationSql(int year) {
  _validateYear(year);
  final previous = year - 1;
  return 'SELECT D.NUMLACTACOES, SUM(D.MEDIA) AS MEDIA, '
      'SUM(D.TOTAL_LEITE) AS TOTAL_LEITE, '
      'SUM(D.MEDIA_ANTERIOR) AS MEDIA_ANTERIOR, '
      'SUM(D.TOTAL_LEITE_ANTERIOR) AS TOTAL_LEITE_ANTERIOR FROM ('
      'SELECT NUMLACTACOES, MEDIA, TOTAL_LEITE, 0 AS MEDIA_ANTERIOR, '
      '0 AS TOTAL_LEITE_ANTERIOR FROM dbo.RESUMO_LEITE_ANUAL_NUMLACTACOES($year) '
      'UNION SELECT NUMLACTACOES, 0, 0, MEDIA, TOTAL_LEITE '
      'FROM dbo.RESUMO_LEITE_ANUAL_NUMLACTACOES($previous)'
      ') AS D GROUP BY D.NUMLACTACOES';
}

String annualMilkBreedSql(int year) {
  _validateYear(year);
  return 'SELECT RACA, MEDIA, TOTAL_LEITE '
      'FROM dbo.RESUMO_LEITE_ANUAL_RACA($year)';
}

void _validateYear(int year) {
  if (year < 2000 || year > 2100) {
    throw ArgumentError('Informe um ano válido para o resumo anual.');
  }
}

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
