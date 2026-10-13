import 'dart:convert';

import 'soap_client.dart';

class GenomaRecord {
  const GenomaRecord({
    required this.tag,
    required this.ic,
    required this.nm,
    required this.milk,
    required this.fat,
    required this.protein,
    required this.vp,
    required this.dpr,
    required this.ccr,
    required this.hcr,
    required this.cub,
    required this.ccs,
    required this.betaCasein,
  });

  final String tag;
  final int ic;
  final int nm;
  final int milk;
  final int fat;
  final int protein;
  final double vp;
  final double dpr;
  final double ccr;
  final double hcr;
  final double cub;
  final double ccs;
  final String betaCasein;

  factory GenomaRecord.fromJson(Map<String, dynamic> json) => GenomaRecord(
    tag: '${_genomaField(json, 'BRINCO') ?? ''}'.trim(),
    ic: _genomaInt(_genomaField(json, 'IC')),
    nm: _genomaInt(_genomaField(json, 'NM')),
    milk: _genomaInt(_genomaField(json, 'LEITE')),
    fat: _genomaInt(_genomaField(json, 'GOR')),
    protein: _genomaInt(_genomaField(json, 'PRO')),
    vp: _genomaDouble(_genomaField(json, 'VP')),
    dpr: _genomaDouble(_genomaField(json, 'DPR')),
    ccr: _genomaDouble(_genomaField(json, 'CCR')),
    hcr: _genomaDouble(_genomaField(json, 'HCR')),
    cub: _genomaDouble(_genomaField(json, 'CUB')),
    ccs: _genomaDouble(_genomaField(json, 'CCS')),
    betaCasein: '${_genomaField(json, 'BETAC') ?? ''}'.trim(),
  );
}

class GenomaRepository {
  GenomaRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<GenomaRecord>> fetchRecords({String? tag}) async {
    final filter = tag != null && tag.trim().isNotEmpty
        ? " AND TB_ANIMAIS.BRINCO LIKE '%${tag.trim().replaceAll("'", "''")}%'"
        : '';
    final rows = await _query(
      'SELECT TB_ANIMAIS.BRINCO, IC, NM, LEITE, GOR, PRO, VP, DPR, CCR, '
      'HCR, CUB, CCS, BETAC FROM TB_GENOMAS '
      'INNER JOIN TB_ANIMAIS ON TB_ANIMAIS.CODANIMAL = TB_GENOMAS.CODANIMAL '
      'WHERE TB_GENOMAS.CODANIMAL IS NOT NULL$filter '
      'ORDER BY TB_ANIMAIS.BRINCO',
    );
    return rows.map(GenomaRecord.fromJson).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_genomaXmlEscape(sql)}</xSql>'
          '<Sufixo>${_genomaXmlEscape(soapClient.suffix)}</Sufixo>'
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

String genomaSql({String? tag}) {
  final filter = tag != null && tag.trim().isNotEmpty
      ? " AND TB_ANIMAIS.BRINCO LIKE '%${tag.trim().replaceAll("'", "''")}%'"
      : '';
  return 'SELECT TB_ANIMAIS.BRINCO, IC, NM, LEITE, GOR, PRO, VP, DPR, CCR, '
      'HCR, CUB, CCS, BETAC FROM TB_GENOMAS '
      'INNER JOIN TB_ANIMAIS ON TB_ANIMAIS.CODANIMAL = TB_GENOMAS.CODANIMAL '
      'WHERE TB_GENOMAS.CODANIMAL IS NOT NULL$filter '
      'ORDER BY TB_ANIMAIS.BRINCO';
}

dynamic _genomaField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _genomaInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _genomaDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _genomaXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
