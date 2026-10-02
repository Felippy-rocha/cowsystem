import 'dart:convert';

import 'birth_analysis_repository.dart' show birthSqlDate;
import 'soap_client.dart';

class DailyMilkSummaryRecord {
  const DailyMilkSummaryRecord({
    required this.date,
    required this.animalCode,
    required this.lotCode,
    required this.lot,
    required this.tag,
    required this.weight1,
    required this.weight2,
    required this.weight3,
    required this.total,
    required this.del,
    required this.lactationCount,
    required this.reproductiveStatus,
    required this.lactationCode,
    required this.inseminationCount,
    required this.dpDui,
    required this.toDiscard,
    required this.breed,
  });

  final String date;
  final int animalCode;
  final int lotCode;
  final String lot;
  final String tag;
  final double weight1;
  final double weight2;
  final double weight3;
  final double total;
  final int del;
  final int lactationCount;
  final String reproductiveStatus;
  final String lactationCode;
  final int inseminationCount;
  final int dpDui;
  final int toDiscard;
  final String breed;

  factory DailyMilkSummaryRecord.fromJson(Map<String, dynamic> json) =>
      DailyMilkSummaryRecord(
        date: '${_milkField(json, 'DATA') ?? ''}'.trim(),
        animalCode: _milkInt(_milkField(json, 'CODANIMAL')),
        lotCode: _milkInt(_milkField(json, 'CODLOTE')),
        lot: '${_milkField(json, 'LOTE') ?? ''}'.trim(),
        tag: '${_milkField(json, 'BRINCO') ?? ''}'.trim(),
        weight1: _milkDouble(_milkField(json, 'PESO1')),
        weight2: _milkDouble(_milkField(json, 'PESO2')),
        weight3: _milkDouble(_milkField(json, 'PESO3')),
        total: _milkDouble(_milkField(json, 'TOTAL')),
        del: _milkInt(_milkField(json, 'DEL')),
        lactationCount: _milkInt(_milkField(json, 'NUMLACTACOES')),
        reproductiveStatus: '${_milkField(json, 'STATUSREPRODUCAO') ?? ''}'
            .trim(),
        lactationCode: '${_milkField(json, 'CODLACTACAO') ?? ''}'.trim(),
        inseminationCount: _milkInt(_milkField(json, 'NUMIAS')),
        dpDui: _milkInt(_milkField(json, 'DP_DUI')),
        toDiscard: _milkInt(_milkField(json, 'ADESCARTAR')),
        breed: '${_milkField(json, 'RACA') ?? ''}'.trim(),
      );
}

class DailyMilkSummaryRepository {
  DailyMilkSummaryRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<DailyMilkSummaryRecord>> fetchSummary(String date) async {
    final rows = await _query(dailyMilkSummarySql(date));
    return rows.map(DailyMilkSummaryRecord.fromJson).toList(growable: false);
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

String dailyMilkSummarySql(String date) {
  return 'SELECT DATA, CODANIMAL, CODLOTE, LOTE, BRINCO, PESO1, PESO2, '
      'PESO3, TOTAL, DEL, NUMLACTACOES, STATUSREPRODUCAO, CODLACTACAO, '
      'NUMIAS, DP_DUI, ADESCARTAR, RACA '
      'FROM dbo.RESUMO_LEITE_DIARIO(${birthSqlDate(date)})';
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
