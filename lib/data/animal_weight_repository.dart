import 'dart:convert';

import 'soap_client.dart';

class AnimalWeightSession {
  const AnimalWeightSession({required this.code, required this.date});

  final int code;
  final String date;

  factory AnimalWeightSession.fromJson(Map<String, dynamic> json) =>
      AnimalWeightSession(
        code: _weightInt(_weightField(json, 'CODPESO')),
        date: '${_weightField(json, 'DATA') ?? ''}'.trim(),
      );
}

class AnimalWeightRecord {
  const AnimalWeightRecord({
    required this.weightCode,
    required this.animalCode,
    required this.tag,
    required this.birthDate,
    required this.daysOld,
    required this.idealWeight,
    required this.weight,
    required this.birthWeight,
    required this.lot,
    required this.taskCode,
  });

  final int weightCode;
  final int animalCode;
  final String tag;
  final String birthDate;
  final int daysOld;
  final double idealWeight;
  final double weight;
  final double birthWeight;
  final String lot;
  final int taskCode;

  factory AnimalWeightRecord.fromJson(Map<String, dynamic> json) =>
      AnimalWeightRecord(
        weightCode: _weightInt(_weightField(json, 'CODPESO')),
        animalCode: _weightInt(_weightField(json, 'CODANIMAL')),
        tag: '${_weightField(json, 'BRINCO') ?? ''}'.trim(),
        birthDate: '${_weightField(json, 'DATANASCIMENTO') ?? ''}'.trim(),
        daysOld: _weightInt(_weightField(json, 'DIAS')),
        idealWeight: _weightDouble(_weightField(json, 'PESOIDEAL')),
        weight: _weightDouble(_weightField(json, 'PESO')),
        birthWeight: _weightDouble(_weightField(json, 'PESONASCIMENTO')),
        lot: '${_weightField(json, 'LOTE') ?? ''}'.trim(),
        taskCode: _weightInt(_weightField(json, 'CODTAREFA')),
      );
}

class AnimalWeightRepository {
  AnimalWeightRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<AnimalWeightSession>> fetchSessions() async {
    final rows = await _query(
      'SELECT MAX(CODPESO) AS CODPESO, DATA FROM TB_PESOS_ANIMAIS '
      'GROUP BY DATA ORDER BY MAX(CODPESO) DESC',
    );
    return rows.map(AnimalWeightSession.fromJson).toList(growable: false);
  }

  Future<List<AnimalWeightRecord>> fetchWeights(
    String date, {
    String tag = '',
    bool onlyMissing = false,
  }) async {
    final dateSql = weightSqlDate(date);
    final filters = <String>['P.DATA = $dateSql'];
    if (tag.trim().isNotEmpty) {
      filters.add('A.BRINCO = ${weightSqlText(tag.trim())}');
    }
    if (onlyMissing) filters.add('P.PESO = 0');
    final query =
        '''
SELECT P.CODPESO, P.DATA, A.CODANIMAL, A.BRINCO, A.DATANASCIMENTO,
  DATEDIFF(day,
    COALESCE(TRY_CONVERT(date, A.DATANASCIMENTO, 103), TRY_CONVERT(date, A.DATANASCIMENTO, 23)),
    COALESCE(TRY_CONVERT(date, P.DATA, 103), TRY_CONVERT(date, P.DATA, 23))) AS DIAS,
  P.PESOIDEAL, P.PESO,
  ISNULL((SELECT MAX(PR.PESOCRIA) FROM TB_PARTOS PR
    WHERE PR.CODANIMAL_NOVO = A.CODANIMAL), 0) AS PESONASCIMENTO,
  ISNULL((SELECT MAX(T.CODTAREFA) FROM TB_TAREFAS T
    WHERE T.CODANIMAL = A.CODANIMAL AND T.CONCLUIDO = 0
      AND T.EXECUCAO IN ('PESAGEM', 'DIARIA')), 0) AS CODTAREFA,
  L.LOTE
FROM TB_PESOS_ANIMAIS P
INNER JOIN TB_ANIMAIS A ON A.CODANIMAL = P.CODANIMAL
INNER JOIN TB_LOTES L ON L.CODLOTE = A.CODLOTE
WHERE ${filters.join(' AND ')}
ORDER BY TRY_CONVERT(int, A.BRINCO), A.BRINCO''';
    final rows = await _query(query);
    return rows.map(AnimalWeightRecord.fromJson).toList(growable: false);
  }

  Future<void> createSession(String date) =>
      _execute(animalWeightCreateSessionSql(date));

  Future<void> addAnimal(String date, String tag) =>
      _execute(animalWeightAddSql(date, tag));

  Future<void> updateWeight(int weightCode, double weight) =>
      _execute(animalWeightUpdateSql(weightCode, weight));

  Future<void> deleteWeight(int weightCode) =>
      _execute(animalWeightDeleteSql(weightCode));

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_weightXmlEscape(sql)}</xSql>'
          '<Sufixo>${_weightXmlEscape(soapClient.suffix)}</Sufixo>'
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
    await soapClient.callResult(
      action: 'ExecSql',
      password: password,
      body:
          '<xSql>${_weightXmlEscape(sql)}</xSql>'
          '<Login>${_weightXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_weightXmlEscape(password)}</Senha>'
          '<Sufixo>${_weightXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
  }
}

String weightSqlDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  late final String normalized;
  if (brazilian != null) {
    normalized =
        '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  } else if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
    normalized = trimmed;
  } else {
    throw FormatException('Data de pesagem inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data de pesagem inválida: $value');
  }
  return "'$normalized'";
}

String weightSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

String animalWeightCreateSessionSql(String date) =>
    'EXEC SP_TB_PESOS_ANIMAIS_INSERT ${weightSqlDate(date)};';

String animalWeightAddSql(String date, String tag) =>
    'EXEC SP_TB_PESOS_ANIMAIS_INSERT_INDIVIDUAL '
    '${weightSqlDate(date)}, ${weightSqlText(tag.trim())};';

String animalWeightUpdateSql(int code, double weight) =>
    'EXEC SP_TB_PESOS_ANIMAIS_UPDATE $code, ${weight.toStringAsFixed(2)};';

String animalWeightDeleteSql(int code) =>
    'EXEC SP_TB_PESOS_ANIMAIS_DELETE $code;';

dynamic _weightField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _weightInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _weightDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _weightXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
