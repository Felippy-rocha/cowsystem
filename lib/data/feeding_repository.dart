import 'dart:convert';

import 'soap_client.dart';

class FeedingRecord {
  const FeedingRecord({
    required this.code,
    required this.dietCode,
    required this.date,
    required this.diet,
    required this.employee,
    required this.assistant,
    required this.totalWeight,
    required this.totalDryMatter,
    required this.dryMatterPercent,
    required this.animalCount,
    required this.totalGeneral,
    required this.totalConsumption,
  });

  final int code;
  final int dietCode;
  final String date;
  final String diet;
  final String employee;
  final String assistant;
  final double totalWeight;
  final double totalDryMatter;
  final double dryMatterPercent;
  final int animalCount;
  final double totalGeneral;
  final double totalConsumption;

  double get remainingWeight => totalWeight - totalConsumption;

  factory FeedingRecord.fromJson(Map<String, dynamic> json) => FeedingRecord(
    code: _feedInt(_feedField(json, 'CODTRATO')),
    dietCode: _feedInt(_feedField(json, 'CODDIETA')),
    date: '${_feedField(json, 'DATA') ?? ''}'.trim(),
    diet: '${_feedField(json, 'DIETA') ?? ''}'.trim(),
    employee: '${_feedField(json, 'FUNCIONARIO') ?? ''}'.trim(),
    assistant: '${_feedField(json, 'AJUDANTE') ?? ''}'.trim(),
    totalWeight: _feedDouble(_feedField(json, 'TOTALPESO')),
    totalDryMatter: _feedDouble(_feedField(json, 'TOTALMS')),
    dryMatterPercent: _feedDouble(_feedField(json, 'MS')),
    animalCount: _feedInt(_feedField(json, 'QTD_ANIMAIS')),
    totalGeneral: _feedDouble(_feedField(json, 'TOTALGERAL')),
    totalConsumption: _feedDouble(_feedField(json, 'TOTAL_CONSUMO')),
  );
}

class FeedingIngredient {
  const FeedingIngredient({
    required this.id,
    required this.name,
    required this.order,
    required this.expectedQuantity,
    required this.includedQuantity,
  });

  final int id;
  final String name;
  final int order;
  final double expectedQuantity;
  final double includedQuantity;

  factory FeedingIngredient.fromJson(Map<String, dynamic> json) =>
      FeedingIngredient(
        id: _feedInt(_feedField(json, 'ID')),
        name: '${_feedField(json, 'INGREDIENTE') ?? ''}'.trim(),
        order: _feedInt(_feedField(json, 'ORDEM')),
        expectedQuantity: _feedDouble(_feedField(json, 'QTD_ESPERADA')),
        includedQuantity: _feedDouble(_feedField(json, 'QTD_INCLUIDA')),
      );
}

class FeedingDischarge {
  const FeedingDischarge({
    required this.code,
    required this.lotCode,
    required this.lot,
    required this.date,
    required this.feedingCode,
    required this.total,
    required this.animalCount,
  });

  final int code;
  final int lotCode;
  final String lot;
  final String date;
  final int feedingCode;
  final double total;
  final int animalCount;

  factory FeedingDischarge.fromJson(Map<String, dynamic> json) =>
      FeedingDischarge(
        code: _feedInt(_feedField(json, 'CODCONSUMO')),
        lotCode: _feedInt(_feedField(json, 'CODLOTE')),
        lot: '${_feedField(json, 'LOTE') ?? ''}'.trim(),
        date: '${_feedField(json, 'DATA') ?? ''}'.trim(),
        feedingCode: _feedInt(_feedField(json, 'CODTRATO')),
        total: _feedDouble(_feedField(json, 'TOTAL')),
        animalCount: _feedInt(_feedField(json, 'QTD_ANIMAIS')),
      );
}

class FeedingChoice {
  const FeedingChoice({required this.code, required this.name});

  final int code;
  final String name;

  factory FeedingChoice.fromJson(Map<String, dynamic> json) => FeedingChoice(
    code: _feedInt(_feedField(json, 'CODIGO')),
    name: '${_feedField(json, 'NOME') ?? ''}'.trim(),
  );
}

class FeedingRepository {
  FeedingRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<FeedingRecord>> fetchFeedings(String date) async {
    final rows = await _query('''
SELECT CODTRATO, DIETA, DATA, FUNCIONARIO, AJUDANTE, TOTALPESO, TOTALMS,
  MS, QTD_ANIMAIS, TOTALGERAL, CODDIETA, TOTAL_CONSUMO
FROM dbo.LISTA_TRATOS()
WHERE TRY_CONVERT(date, DATA, 103) = ${feedingSqlDate(date)}
ORDER BY CODTRATO''');
    return rows.map(FeedingRecord.fromJson).toList(growable: false);
  }

  Future<List<FeedingIngredient>> fetchIngredients(int feedingCode) async {
    final rows = await _query('''
SELECT ID, INGREDIENTE, ORDEM, QTD_ESPERADA, QTD_INCLUIDA
FROM TB_TRATO_INGREDIENTES
WHERE CODTRATO = ${_feedPositive(feedingCode)}
ORDER BY ORDEM''');
    return rows.map(FeedingIngredient.fromJson).toList(growable: false);
  }

  Future<List<FeedingDischarge>> fetchDischarges(int feedingCode) async {
    final rows = await _query('''
SELECT CODCONSUMO, CODLOTE, DATA, CODTRATO, LOTE, TOTAL, QTD_ANIMAIS, MEDIA
FROM dbo.LISTA_DESCARGAS()
WHERE CODTRATO = ${_feedPositive(feedingCode)}
ORDER BY CODCONSUMO''');
    return rows.map(FeedingDischarge.fromJson).toList(growable: false);
  }

  Future<List<FeedingChoice>> fetchDiets() async {
    final rows = await _query(
      'SELECT CODDIETA AS CODIGO, DESCRICAO AS NOME FROM TB_DIETA '
      'WHERE ATIVO = 1 ORDER BY DESCRICAO',
    );
    return rows.map(FeedingChoice.fromJson).toList(growable: false);
  }

  Future<List<FeedingChoice>> fetchEmployees() async {
    final rows = await _query(
      'SELECT CODFUNCIONARIO AS CODIGO, FUNCIONARIO AS NOME '
      'FROM TB_FUNCIONARIOS ORDER BY FUNCIONARIO',
    );
    return rows.map(FeedingChoice.fromJson).toList(growable: false);
  }

  Future<List<FeedingChoice>> fetchLots(int dietCode) async {
    final rows = await _query(
      'SELECT CODLOTE AS CODIGO, LOTE AS NOME FROM TB_LOTES '
      'WHERE CODDIETA = $dietCode ORDER BY LOTE',
    );
    return rows.map(FeedingChoice.fromJson).toList(growable: false);
  }

  Future<int> animalCountInLot(int lotCode) async {
    final rows = await _query(
      'SELECT COUNT(*) AS QTD FROM TB_ANIMAIS '
      'WHERE CODLOTE = ${_feedPositive(lotCode)} AND ATIVO = 1',
    );
    return rows.isEmpty ? 0 : _feedInt(_feedField(rows.first, 'QTD'));
  }

  Future<void> createFeeding({
    required int dietCode,
    required String date,
    required int employeeCode,
    required int assistantCode,
    required int animalCount,
  }) => _execute(
    feedingCreateSql(
      dietCode: dietCode,
      date: date,
      employeeCode: employeeCode,
      assistantCode: assistantCode,
      animalCount: animalCount,
    ),
  );

  Future<void> createDischarge({
    required String date,
    required int feedingCode,
    required int lotCode,
    required double total,
  }) => _execute(
    feedingDischargeSql(
      date: date,
      feedingCode: feedingCode,
      lotCode: lotCode,
      total: total,
    ),
  );

  Future<void> updateDischargeLot({
    required int dischargeCode,
    required String date,
    required int feedingCode,
    required int lotCode,
    required double total,
  }) => _execute(
    feedingDischargeUpdateSql(
      dischargeCode: dischargeCode,
      date: date,
      feedingCode: feedingCode,
      lotCode: lotCode,
      total: total,
    ),
  );

  Future<void> deleteDischarge(int id) =>
      _execute('EXEC SP_TB_CONSUMO_DELETE ${_feedPositive(id)};');

  Future<void> deleteFeeding(int id) =>
      _execute('EXEC SP_TB_TRATO_DELETE ${_feedPositive(id)};');

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_feedXmlEscape(sql)}</xSql>'
          '<Sufixo>${_feedXmlEscape(soapClient.suffix)}</Sufixo>'
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

  Future<void> _execute(String sql) async {
    final password = const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD');
    final response = await soapClient.callResult(
      action: 'ExecSP',
      password: password,
      body:
          '<xSql>${_feedXmlEscape(sql)}</xSql>'
          '<Login>${_feedXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_feedXmlEscape(password)}</Senha>'
          '<Sufixo>${_feedXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String feedingSqlDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data do trato inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data do trato inválida: $value');
  }
  return "'$normalized'";
}

String feedingCreateSql({
  int id = -1,
  required int dietCode,
  required String date,
  required int employeeCode,
  required int assistantCode,
  required int animalCount,
}) {
  if (dietCode <= 0 ||
      employeeCode <= 0 ||
      assistantCode <= 0 ||
      animalCount <= 0) {
    throw ArgumentError('Informe dieta, funcionários e quantidade de animais.');
  }
  return 'EXEC SP_TB_TRATO_INSERT2 $id, $dietCode, ${feedingSqlDate(date)}, '
      '$employeeCode, $assistantCode, $animalCount;';
}

String feedingDischargeSql({
  required String date,
  required int feedingCode,
  required int lotCode,
  required double total,
}) {
  if (feedingCode <= 0 || lotCode <= 0 || total <= 0) {
    throw ArgumentError('Informe trato, lote e quantidade válida.');
  }
  return 'EXEC SP_TB_CONSUMO_INSERT -1, ${feedingSqlDate(date)}, '
      '$feedingCode, $lotCode, ${total.toStringAsFixed(2)};';
}

String feedingDischargeUpdateSql({
  required int dischargeCode,
  required String date,
  required int feedingCode,
  required int lotCode,
  required double total,
}) {
  if (dischargeCode <= 0 || feedingCode <= 0 || lotCode <= 0 || total <= 0) {
    throw ArgumentError('Informe descarga, trato, lote e quantidade válida.');
  }
  return 'EXEC SP_TB_CONSUMO_UPDATE $dischargeCode, ${feedingSqlDate(date)}, '
      '$feedingCode, $lotCode, ${total.toStringAsFixed(2)};';
}

int _feedPositive(int value) {
  if (value <= 0) throw ArgumentError.value(value, 'id');
  return value;
}

dynamic _feedField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _feedInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _feedDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _feedXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
