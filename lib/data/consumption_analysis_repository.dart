import 'dart:convert';

import 'soap_client.dart';

class ConsumptionAnalysisRecord {
  const ConsumptionAnalysisRecord({
    required this.date,
    required this.dietCode,
    required this.lotCode,
    required this.diet,
    required this.consumption,
    required this.animalCount,
    required this.consumedQuantity,
    required this.dryMatterConsumed,
    required this.dryMatter,
  });

  final String date;
  final int dietCode;
  final int lotCode;
  final String diet;
  final double consumption;
  final double animalCount;
  final double consumedQuantity;
  final double dryMatterConsumed;
  final double dryMatter;

  factory ConsumptionAnalysisRecord.fromJson(Map<String, dynamic> json) =>
      ConsumptionAnalysisRecord(
        date: '${_consumptionField(json, 'DATA') ?? ''}'.trim(),
        dietCode: _consumptionInt(_consumptionField(json, 'CODDIETA')),
        lotCode: _consumptionInt(_consumptionField(json, 'CODLOTE')),
        diet: '${_consumptionField(json, 'DIETA') ?? ''}'.trim(),
        consumption: _consumptionDouble(_consumptionField(json, 'CONSUMO')),
        animalCount: _consumptionDouble(_consumptionField(json, 'QTD_ANIMAIS')),
        consumedQuantity: _consumptionDouble(
          _consumptionField(json, 'QTD_CONSUMIDA'),
        ),
        dryMatterConsumed: _consumptionDouble(
          _consumptionField(json, 'QTD_MS_CONSUMIDA'),
        ),
        dryMatter: _consumptionDouble(_consumptionField(json, 'MS')),
      );
}

class ConsumptionAnalysisRepository {
  ConsumptionAnalysisRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<({int code, String name})>> fetchDiets() async {
    final rows = await _query(
      'SELECT CODDIETA, DESCRICAO FROM TB_DIETA ORDER BY DESCRICAO',
    );
    return rows
        .map(
          (row) => (
            code: _consumptionInt(_consumptionField(row, 'CODDIETA')),
            name: '${_consumptionField(row, 'DESCRICAO') ?? ''}'.trim(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<({int code, String name})>> fetchLots() async {
    final rows = await _query(
      'SELECT CODLOTE, LOTE FROM TB_LOTES ORDER BY LOTE',
    );
    return rows
        .map(
          (row) => (
            code: _consumptionInt(_consumptionField(row, 'CODLOTE')),
            name: '${_consumptionField(row, 'LOTE') ?? ''}'.trim(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<ConsumptionAnalysisRecord>> fetchMonthly({
    required int dietCode,
    required String period,
    required int lotCode,
  }) async {
    final rows = await _query('''
SELECT DATA, CODDIETA, CODLOTE, CONSUMO, QTD_ANIMAIS, QTD_CONSUMIDA,
  QTD_MS_CONSUMIDA, MS
FROM dbo.ANALISE_CONSUMO_MENSAL_LOTE($dietCode, '${_consumptionSqlText(period)}', $lotCode)
ORDER BY DATA''');
    return rows.map(ConsumptionAnalysisRecord.fromJson).toList(growable: false);
  }

  Future<List<ConsumptionAnalysisRecord>> fetchDaily({
    required int dietCode,
    required String date,
  }) async {
    final rows = await _query('''
SELECT DATA, CODDIETA, CODLOTE, CONSUMO, QTD_ANIMAIS, QTD_CONSUMIDA,
  QTD_MS_CONSUMIDA, MS
FROM dbo.ANALISE_CONSUMO_DIARIO($dietCode, ${_consumptionSqlDate(date)})
ORDER BY DATA''');
    return rows.map(ConsumptionAnalysisRecord.fromJson).toList(growable: false);
  }

  Future<void> generateMonthly({
    required int dietCode,
    required String period,
    required int lotCode,
  }) => _execute(
    consumptionAnalysisMonthlySql(
      dietCode: dietCode,
      period: period,
      lotCode: lotCode,
    ),
    action: 'ExecSql',
  );

  Future<void> generateDaily({required int dietCode, required String date}) =>
      _execute(
        consumptionAnalysisDailySql(dietCode: dietCode, date: date),
        action: 'ExecSql',
      );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_consumptionXmlEscape(sql)}</xSql>'
          '<Sufixo>${_consumptionXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_consumptionXmlEscape(sql)}</xSql>'
          '<Login>${_consumptionXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_consumptionXmlEscape(password)}</Senha>'
          '<Sufixo>${_consumptionXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String consumptionAnalysisMonthlySql({
  required int dietCode,
  required String period,
  required int lotCode,
}) {
  if (dietCode <= 0 || lotCode <= 0 || period.trim().isEmpty) {
    throw ArgumentError('Informe dieta, período e lote válidos.');
  }
  return 'EXEC SP_TB_ANALISE_CONSUMO_MENSAL_LOTE $dietCode, '
      '${_consumptionSqlText(period)}, $lotCode;';
}

String consumptionAnalysisDailySql({
  required int dietCode,
  required String date,
}) {
  if (dietCode <= 0) {
    throw ArgumentError.value(dietCode, 'dietCode');
  }
  return 'EXEC SP_TB_ANALISE_CONSUMO_DIARIO $dietCode, ${_consumptionSqlDate(date)};';
}

String _consumptionSqlDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data do consumo inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data do consumo inválida: $value');
  }
  return "'$normalized'";
}

dynamic _consumptionField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _consumptionInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _consumptionDouble(Object? value) =>
    double.tryParse('${value ?? 0}') ?? 0;

String _consumptionSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

String _consumptionXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
