import 'dart:convert';

import 'soap_client.dart';

class CalvingForecastSummary {
  const CalvingForecastSummary({
    required this.period,
    required this.totalCows,
    required this.totalHeifers,
    required this.ic,
    required this.milk,
    required this.vp,
    required this.dpr,
  });

  final String period;
  final int totalCows;
  final int totalHeifers;
  final int ic;
  final int milk;
  final double vp;
  final double dpr;

  int get total => totalCows + totalHeifers;

  factory CalvingForecastSummary.fromJson(Map<String, dynamic> json) =>
      CalvingForecastSummary(
        period: '${_forecastField(json, 'PERIODO') ?? ''}'.trim(),
        totalCows: _forecastInt(_forecastField(json, 'TOTALVACAS')),
        totalHeifers: _forecastInt(_forecastField(json, 'TOTALNOVILHAS')),
        ic: _forecastInt(_forecastField(json, 'IC')),
        milk: _forecastInt(_forecastField(json, 'LEITE')),
        vp: _forecastDouble(_forecastField(json, 'VP')),
        dpr: _forecastDouble(_forecastField(json, 'DPR')),
      );
}

class CalvingForecastDetail {
  const CalvingForecastDetail({
    required this.date,
    required this.animalCode,
    required this.tag,
    required this.lot,
    required this.bull,
    required this.category,
    required this.ic,
    required this.milk,
    required this.vp,
    required this.dpr,
    required this.betaCasein,
  });

  final String date;
  final int animalCode;
  final String tag;
  final String lot;
  final String bull;
  final String category;
  final int ic;
  final int milk;
  final double vp;
  final double dpr;
  final String betaCasein;

  factory CalvingForecastDetail.fromJson(Map<String, dynamic> json) =>
      CalvingForecastDetail(
        date: '${_forecastField(json, 'DATA') ?? ''}'.trim(),
        animalCode: _forecastInt(_forecastField(json, 'CODANIMAL')),
        tag: '${_forecastField(json, 'BRINCO') ?? ''}'.trim(),
        lot: '${_forecastField(json, 'LOTE') ?? ''}'.trim(),
        bull: '${_forecastField(json, 'TOURO') ?? ''}'.trim(),
        category: '${_forecastField(json, 'CATEGORIA') ?? ''}'.trim(),
        ic: _forecastInt(_forecastField(json, 'IC')),
        milk: _forecastInt(_forecastField(json, 'LEITE')),
        vp: _forecastDouble(_forecastField(json, 'VP')),
        dpr: _forecastDouble(_forecastField(json, 'DPR')),
        betaCasein: '${_forecastField(json, 'BETAC') ?? ''}'.trim(),
      );
}

class CalvingForecastRepository {
  CalvingForecastRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<CalvingForecastSummary>> fetchSummary() async {
    final rows = await _query('''
SELECT PERIODO, TOTALVACAS, TOTALNOVILHAS, IC, LEITE, VP, DPR
FROM TB_PREVISAO_PARTOS
ORDER BY TRY_CONVERT(date, PERIODO, 103) DESC''');
    return rows.map(CalvingForecastSummary.fromJson).toList(growable: false);
  }

  Future<List<CalvingForecastDetail>> fetchDetails({
    required String period,
    int? lotCode,
    List<String> categories = const ['NOVILHA', 'PRIMIPARA', 'MULTIPARA'],
  }) async {
    final filters = <String>['PERIODO = ${_forecastSqlText(period)}'];
    if (lotCode != null && lotCode > 0) {
      filters.add('CODLOTE = $lotCode');
    }
    if (categories.isNotEmpty) {
      final quoted = categories.map((c) => _forecastSqlText(c)).join(', ');
      filters.add('CATEGORIA IN ($quoted)');
    }
    final rows = await _query('''
SELECT DATA, CODANIMAL, BRINCO, LOTE, TOURO, CATEGORIA, IC, LEITE, VP, DPR, BETAC
FROM TB_PREVISAO_PARTOS_DETALHES
WHERE ${filters.join(' AND ')}
ORDER BY DATA, BRINCO''');
    return rows.map(CalvingForecastDetail.fromJson).toList(growable: false);
  }

  Future<List<String>> fetchPeriods() async {
    final rows = await _query(
      'SELECT MAX(SEQUENCIA) AS ID, PERIODO FROM TB_PREVISAO_PARTOS_DETALHES '
      'GROUP BY PERIODO ORDER BY ID DESC',
    );
    return rows
        .map((row) => '${_forecastField(row, 'PERIODO') ?? ''}'.trim())
        .where((period) => period.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<({int code, String name})>> fetchLots() async {
    final rows = await _query(
      'SELECT CODLOTE, LOTE FROM TB_LOTES WHERE CODLOTE IN '
      '(SELECT CODLOTE FROM TB_PREVISAO_PARTOS_DETALHES) ORDER BY LOTE',
    );
    return rows
        .map(
          (row) => (
            code: _forecastInt(_forecastField(row, 'CODLOTE')),
            name: '${_forecastField(row, 'LOTE') ?? ''}'.trim(),
          ),
        )
        .toList(growable: false);
  }

  Future<void> generate() =>
      _execute('EXEC SP_TB_PREVISAO_PARTOS_INSERT;', action: 'ExecSql');

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_forecastXmlEscape(sql)}</xSql>'
          '<Sufixo>${_forecastXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_forecastXmlEscape(sql)}</xSql>'
          '<Login>${_forecastXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_forecastXmlEscape(password)}</Senha>'
          '<Sufixo>${_forecastXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String calvingForecastGenerateSql() => 'EXEC SP_TB_PREVISAO_PARTOS_INSERT;';

String _forecastSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

dynamic _forecastField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _forecastInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _forecastDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _forecastXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
