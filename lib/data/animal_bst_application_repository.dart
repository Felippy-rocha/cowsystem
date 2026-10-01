import 'dart:convert';

import 'soap_client.dart';

class BstApplicationLot {
  const BstApplicationLot({required this.code, required this.name});

  final int code;
  final String name;

  factory BstApplicationLot.fromJson(Map<String, dynamic> json) =>
      BstApplicationLot(
        code: _bstInt(_bstField(json, 'CODLOTE')),
        name: '${_bstField(json, 'LOTE') ?? ''}'.trim(),
      );
}

class BstApplicationRecord {
  const BstApplicationRecord({
    required this.id,
    required this.bstCode,
    required this.animalCode,
    required this.tag,
    required this.date,
    required this.hormone,
    required this.quantity,
    required this.applied,
    required this.productionStatus,
    required this.reproductiveStatus,
    required this.expectedDryOff,
    required this.lot,
  });

  final int id;
  final int bstCode;
  final int animalCode;
  final String tag;
  final String date;
  final String hormone;
  final double quantity;
  final bool applied;
  final String productionStatus;
  final String reproductiveStatus;
  final String expectedDryOff;
  final String lot;

  factory BstApplicationRecord.fromJson(Map<String, dynamic> json) =>
      BstApplicationRecord(
        id: _bstInt(_bstField(json, 'ID')),
        bstCode: _bstInt(_bstField(json, 'CODBST')),
        animalCode: _bstInt(_bstField(json, 'CODANIMAL')),
        tag: '${_bstField(json, 'BRINCO') ?? ''}'.trim(),
        date: '${_bstField(json, 'DATAAPLICACAO') ?? ''}'.trim(),
        hormone: '${_bstField(json, 'MEDICAMENTO') ?? ''}'.trim(),
        quantity: _bstDouble(_bstField(json, 'QTD')),
        applied: _bstInt(_bstField(json, 'APLICACAO')) == 2,
        productionStatus: '${_bstField(json, 'STATUSPRODUCAO') ?? ''}'.trim(),
        reproductiveStatus: '${_bstField(json, 'STATUSREPRODUCAO') ?? ''}'
            .trim(),
        expectedDryOff: '${_bstField(json, 'PREVISAOSECAGEM') ?? ''}'.trim(),
        lot: '${_bstField(json, 'LOTE') ?? ''}'.trim(),
      );
}

class AnimalBstApplicationRepository {
  AnimalBstApplicationRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<BstApplicationLot>> fetchLots() async {
    final rows = await _query(
      'SELECT CODLOTE, LOTE FROM TB_LOTES ORDER BY LOTE',
    );
    return rows.map(BstApplicationLot.fromJson).toList(growable: false);
  }

  Future<List<BstApplicationRecord>> fetchApplications(
    String date, {
    int? lotCode,
  }) async {
    final dateSql = bstApplicationDate(date);
    final filters = <String>['CONVERT(date, B.DATAAPLICACAO) = $dateSql'];
    if (lotCode != null && lotCode > 0) {
      filters.add('A.CODLOTE = $lotCode');
    }
    final rows = await _query('''
SELECT B.ID, B.CODBST, B.CODANIMAL, B.DATAAPLICACAO, B.CODHORMONIO,
  B.QTD, B.APLICACAO, A.STATUSPRODUCAO, A.STATUSREPRODUCAO, A.BRINCO,
  M.MEDICAMENTO, P.PREVISAOSECAGEM, L.LOTE
FROM TB_BST_APLICACAO B
INNER JOIN TB_ANIMAIS A ON A.CODANIMAL = B.CODANIMAL
INNER JOIN TB_MEDICAMENTOS_NOVO M ON M.CODMEDICAMENTO = B.CODHORMONIO
INNER JOIN TB_LOTES L ON L.CODLOTE = A.CODLOTE
LEFT JOIN TB_PRENHEZES P ON P.CODANIMAL = B.CODANIMAL
  AND P.CODLACTACAO = A.CODLACTACAOATUAL
WHERE ${filters.join(' AND ')}
ORDER BY TRY_CONVERT(int, A.BRINCO), A.BRINCO''');
    return rows.map(BstApplicationRecord.fromJson).toList(growable: false);
  }

  Future<int> createApplicationList(String date) async {
    final response = await _execute(bstApplicationCreateListSql(date));
    final value = response.replaceAll('#ic#', '').replaceAll('#fc#', '').trim();
    final result = int.tryParse(value);
    if (result == null) {
      throw SoapException(
        value.isEmpty ? 'Resposta inválida do servidor.' : value,
      );
    }
    return result;
  }

  Future<void> markApplied(int id) =>
      _execute(bstApplicationMarkAppliedSql(id));

  Future<void> deletePending(int id) =>
      _execute(bstApplicationDeletePendingSql(id), action: 'ExecSql');

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

  Future<String> _execute(String sql, {String action = 'ExecSP'}) async {
    final password = const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD');
    final response = await soapClient.callResult(
      action: action,
      password: password,
      body:
          '<xSql>${_bstXmlEscape(sql)}</xSql>'
          '<Login>${_bstXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_bstXmlEscape(password)}</Senha>'
          '<Sufixo>${_bstXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
    return response;
  }
}

String bstApplicationDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data de aplicação BST inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data de aplicação BST inválida: $value');
  }
  return "'$normalized'";
}

String bstApplicationCreateListSql(String date) =>
    'EXEC SP_TB_BST_APLICACAO_INSERT ${bstApplicationDate(date)};';

String bstApplicationMarkAppliedSql(int id) {
  if (id <= 0) throw ArgumentError.value(id, 'id');
  return 'UPDATE TB_BST_APLICACAO SET APLICACAO = 2, '
      'HORA_DO_REGISTRO = dbo.cHORA_DO_REGISTRO() '
      'WHERE ID = $id AND APLICACAO <> 2;';
}

String bstApplicationDeletePendingSql(int id) {
  if (id <= 0) throw ArgumentError.value(id, 'id');
  return 'DELETE FROM TB_BST_APLICACAO WHERE ID = $id AND APLICACAO <> 2;';
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
