import 'dart:convert';

import 'soap_client.dart';

class MilkSummaryRecord {
  const MilkSummaryRecord({
    required this.date,
    required this.totalMilk,
    required this.animals,
    required this.average,
    required this.del,
  });

  final String date;
  final double totalMilk;
  final int animals;
  final double average;
  final int del;

  factory MilkSummaryRecord.fromJson(Map<String, dynamic> json) =>
      MilkSummaryRecord(
        date: '${_milkField(json, 'DATA') ?? ''}'.trim(),
        totalMilk: _milkDouble(_milkField(json, 'TOTAL_LEITE')),
        animals: _milkInt(_milkField(json, 'ANIMAIS')),
        average: _milkDouble(_milkField(json, 'MEDIA')),
        del: _milkInt(_milkField(json, 'DEL')),
      );
}

class MilkSummaryRepository {
  MilkSummaryRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<String>> fetchPeriods() async {
    final rows = await _query(
      'SELECT DISTINCT MES_ANO FROM TB_MES_ANO GROUP BY MES_ANO ORDER BY MES_ANO DESC',
    );
    return rows
        .map((row) => '${_milkField(row, 'MES_ANO') ?? ''}'.trim())
        .where((period) => period.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<MilkSummaryRecord>> fetchMonthly(String period) async {
    final rows = await _query(
      'SELECT DATA, TOTAL_LEITE, ANIMAIS, MEDIA, DEL '
      'FROM dbo.RESUMO_LEITE_MENSAL(${_milkSqlText(period)})',
    );
    return rows.map(MilkSummaryRecord.fromJson).toList(growable: false);
  }

  Future<List<MilkSummaryRecord>> fetchByLactation(String period) async {
    final rows = await _query(
      'SELECT NUMLACTACOES AS DATA, TOTAL_LEITE, ANIMAIS, MEDIA, DEL '
      'FROM dbo.RESUMO_LEITE_MENSAL_NUMLACTACOES(${_milkSqlText(period)})',
    );
    return rows.map(MilkSummaryRecord.fromJson).toList(growable: false);
  }

  Future<List<MilkSummaryRecord>> fetchByBreed(String period) async {
    final rows = await _query(
      'SELECT RACA AS DATA, TOTAL_LEITE, ANIMAIS, MEDIA, DEL '
      'FROM dbo.RESUMO_LEITE_MENSAL_RACA(${_milkSqlText(period)})',
    );
    return rows.map(MilkSummaryRecord.fromJson).toList(growable: false);
  }

  Future<List<MilkSummaryRecord>> fetchByLot(String period) async {
    final rows = await _query(
      'SELECT LOTE AS DATA, TOTAL_LEITE, ANIMAIS, MEDIA, DEL '
      'FROM dbo.RESUMO_LEITE_MENSAL_LOTE(${_milkSqlText(period)})',
    );
    return rows.map(MilkSummaryRecord.fromJson).toList(growable: false);
  }

  Future<void> generate(String period) =>
      _execute(milkSummaryGenerateSql(period), action: 'ExecSql');

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

  Future<void> _execute(String sql, {String action = 'ExecSP'}) async {
    final password = const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD');
    final response = await soapClient.callResult(
      action: action,
      password: password,
      body:
          '<xSql>${_milkXmlEscape(sql)}</xSql>'
          '<Login>${_milkXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_milkXmlEscape(password)}</Senha>'
          '<Sufixo>${_milkXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String milkSummaryGenerateSql(String period) {
  final value = period.trim();
  if (value.isEmpty) {
    throw ArgumentError('Informe o período do resumo de leite.');
  }
  return 'EXEC SP_TB_RESUMO_LEITE_MENSAL_INSERT @PERIODO = ${_milkSqlText(value)};';
}

dynamic _milkField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _milkInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _milkDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _milkSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

String _milkXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
