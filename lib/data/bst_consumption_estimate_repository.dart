import 'dart:convert';

import 'soap_client.dart';

class BstConsumptionEstimateRecord {
  const BstConsumptionEstimateRecord({
    required this.animalCode,
    required this.tag,
    required this.reproductiveStatus,
    required this.del,
    required this.dp,
    required this.interval,
    required this.pregnantDoses,
    required this.doses,
    required this.total,
    required this.average,
  });

  final int animalCode;
  final String tag;
  final String reproductiveStatus;
  final int del;
  final int dp;
  final int interval;
  final int pregnantDoses;
  final int doses;
  final int total;
  final double average;

  factory BstConsumptionEstimateRecord.fromJson(Map<String, dynamic> json) =>
      BstConsumptionEstimateRecord(
        animalCode: _bstInt(_bstField(json, 'CODANIMAL')),
        tag: '${_bstField(json, 'BRINCO') ?? ''}'.trim(),
        reproductiveStatus: '${_bstField(json, 'STATUSREPRODUCAO') ?? ''}'
            .trim(),
        del: _bstInt(_bstField(json, 'DEL')),
        dp: _bstInt(_bstField(json, 'DP')),
        interval: _bstInt(_bstField(json, 'INTERVALO')),
        pregnantDoses: _bstInt(_bstField(json, 'DOSES_PRENHES')),
        doses: _bstInt(_bstField(json, 'DOSES')),
        total: _bstInt(_bstField(json, 'TOTAL')),
        average: _bstDouble(_bstField(json, 'MEDIA')),
      );
}

class BstEstimateDel {
  const BstEstimateDel({required this.code, required this.description});

  final int code;
  final String description;

  factory BstEstimateDel.fromJson(Map<String, dynamic> json) => BstEstimateDel(
    code: _bstInt(_bstField(json, 'ID')),
    description: '${_bstField(json, 'DESCRICAO') ?? ''}'.trim(),
  );
}

class BstConsumptionEstimateRepository {
  BstConsumptionEstimateRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<BstEstimateDel>> fetchDels() async {
    final rows = await _query('SELECT ID, DESCRICAO FROM dbo.ESTIMATIVA_DEL()');
    return rows.map(BstEstimateDel.fromJson).toList(growable: false);
  }

  Future<List<BstConsumptionEstimateRecord>> fetchEstimate(int del) async {
    final rows = await _query(bstConsumptionEstimateSql(del));
    return rows
        .map(BstConsumptionEstimateRecord.fromJson)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_bstXmlEscape(sql)}</xSql>'
          '<Sufixo>${_bstXmlEscape(soapClient.suffix)}</Sufixo>'
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

String bstConsumptionEstimateSql(int del) {
  if (del <= 0) {
    throw ArgumentError('Informe o DEL para a estimativa de consumo de BST.');
  }
  return 'SELECT CODANIMAL, BRINCO, STATUSREPRODUCAO, DEL, DP, INTERVALO, '
      'DOSES_PRENHES, DOSES, TOTAL, MEDIA '
      'FROM dbo.BST_ESTIMATIVA_CONSUMO($del)';
}

dynamic _bstField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _bstInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _bstDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _bstXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
