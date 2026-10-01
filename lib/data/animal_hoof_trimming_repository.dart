import 'dart:convert';

import 'soap_client.dart';

class HoofTrimmingAnimal {
  const HoofTrimmingAnimal({
    required this.code,
    required this.tag,
    required this.reproductiveStatus,
    required this.productionStatus,
    required this.lactationCode,
    required this.daysInMilk,
    required this.pregnancyDays,
    required this.lastCalvingDate,
    required this.lastInseminationDate,
  });

  final int code;
  final String tag;
  final String reproductiveStatus;
  final String productionStatus;
  final String lactationCode;
  final int daysInMilk;
  final int pregnancyDays;
  final String lastCalvingDate;
  final String lastInseminationDate;

  factory HoofTrimmingAnimal.fromJson(Map<String, dynamic> json) =>
      HoofTrimmingAnimal(
        code: _hoofInt(_hoofField(json, 'CODANIMAL')),
        tag: '${_hoofField(json, 'BRINCO') ?? ''}'.trim(),
        reproductiveStatus: '${_hoofField(json, 'STATUSREPRODUCAO') ?? ''}'
            .trim(),
        productionStatus: '${_hoofField(json, 'STATUSPRODUCAO') ?? ''}'.trim(),
        lactationCode: '${_hoofField(json, 'CODLACTACAO') ?? ''}'.trim(),
        daysInMilk: _hoofInt(_hoofField(json, 'DEL')),
        pregnancyDays: _hoofInt(_hoofField(json, 'DP')),
        lastCalvingDate: '${_hoofField(json, 'ULTIMOPARTO') ?? ''}'.trim(),
        lastInseminationDate: '${_hoofField(json, 'DATAIA') ?? ''}'.trim(),
      );
}

class HoofTrimmingOption {
  const HoofTrimmingOption({required this.code, required this.name});

  final int code;
  final String name;

  factory HoofTrimmingOption.fromJson(Map<String, dynamic> json) =>
      HoofTrimmingOption(
        code: _hoofInt(_hoofField(json, 'CODIGO')),
        name: '${_hoofField(json, 'NOME') ?? ''}'.trim(),
      );
}

class HoofTrimmingRecord {
  const HoofTrimmingRecord({
    required this.id,
    required this.date,
    required this.typeCode,
    required this.typeName,
    required this.employeeCode,
    required this.assistantCode,
    required this.comment,
    required this.lactationCode,
    required this.daysInMilk,
    required this.pregnancyDays,
  });

  final int id;
  final String date;
  final int typeCode;
  final String typeName;
  final int employeeCode;
  final int assistantCode;
  final String comment;
  final String lactationCode;
  final int daysInMilk;
  final int pregnancyDays;

  factory HoofTrimmingRecord.fromJson(Map<String, dynamic> json) =>
      HoofTrimmingRecord(
        id: _hoofInt(_hoofField(json, 'ID')),
        date: '${_hoofField(json, 'DATA') ?? ''}'.trim(),
        typeCode: _hoofInt(_hoofField(json, 'CODTIPO')),
        typeName: '${_hoofField(json, 'TIPO') ?? ''}'.trim(),
        employeeCode: _hoofInt(_hoofField(json, 'CODFUNCIONARIO')),
        assistantCode: _hoofInt(_hoofField(json, 'CODAJUDANTE')),
        comment: '${_hoofField(json, 'COMENTARIO') ?? ''}'.trim(),
        lactationCode: '${_hoofField(json, 'CODLACTACAO') ?? ''}'.trim(),
        daysInMilk: _hoofInt(_hoofField(json, 'DEL')),
        pregnancyDays: _hoofInt(_hoofField(json, 'DP')),
      );
}

class AnimalHoofTrimmingRepository {
  AnimalHoofTrimmingRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<HoofTrimmingAnimal>> fetchAnimals({String tag = ''}) async {
    final search = tag.trim();
    final searchFilter = search.isNotEmpty
        ? 'WHERE Q.BRINCO LIKE ${_hoofSqlText('%$search%')}'
        : '''WHERE Q.ATIVO = 1 AND Q.DOADORA IN (2, 3) AND Q.ADESCARTAR = 2
  AND ((Q.DEL BETWEEN 120 AND 180)
    OR (Q.STATUSREPRODUCAO = 'PRENHA' AND Q.DP BETWEEN 180 AND 220))''';
    final rows = await _query('''
SELECT Q.CODANIMAL, Q.BRINCO, Q.STATUSREPRODUCAO, Q.STATUSPRODUCAO,
  Q.CODLACTACAO, Q.DEL, Q.DP, Q.ULTIMOPARTO, Q.DATAIA
FROM (
  SELECT A.CODANIMAL, A.BRINCO, A.STATUSREPRODUCAO, A.STATUSPRODUCAO,
    A.CODLACTACAOATUAL AS CODLACTACAO, A.ATIVO, A.DOADORA, A.ADESCARTAR,
    A.ULTIMOPARTO,
    COALESCE(DATEDIFF(day,
      COALESCE(TRY_CONVERT(date, A.ULTIMOPARTO, 103), TRY_CONVERT(date, A.ULTIMOPARTO, 23)),
      CONVERT(date, GETDATE())), 0) AS DEL,
    COALESCE(I.DATA, '') AS DATAIA,
    COALESCE(DATEDIFF(day,
      COALESCE(TRY_CONVERT(date, I.DATA, 103), TRY_CONVERT(date, I.DATA, 23)),
      CONVERT(date, GETDATE())), 0) AS DP
  FROM TB_ANIMAIS A
  LEFT JOIN TB_INSEMINACOES I ON I.ID = (
    SELECT MAX(I2.ID) FROM TB_INSEMINACOES I2
    WHERE I2.CODANIMAL = A.CODANIMAL
      AND I2.CODLACTACAO = A.CODLACTACAOATUAL)
) Q
$searchFilter
ORDER BY TRY_CONVERT(int, Q.BRINCO), Q.BRINCO''');
    return rows.map(HoofTrimmingAnimal.fromJson).toList(growable: false);
  }

  Future<List<HoofTrimmingOption>> fetchEmployees() async {
    final rows = await _query(
      'SELECT CODFUNCIONARIO AS CODIGO, FUNCIONARIO AS NOME '
      'FROM TB_FUNCIONARIOS ORDER BY FUNCIONARIO',
    );
    return rows.map(HoofTrimmingOption.fromJson).toList(growable: false);
  }

  Future<List<HoofTrimmingOption>> fetchTypes() async {
    final rows = await _query(
      'SELECT CODIGO, DESCRICAO AS NOME FROM TB_TIPOCASQUEAMENTO '
      'ORDER BY DESCRICAO',
    );
    return rows.map(HoofTrimmingOption.fromJson).toList(growable: false);
  }

  Future<List<HoofTrimmingRecord>> fetchHistory(
    int animalCode, {
    String? lactationCode,
  }) async {
    final filters = <String>['C.CODANIMAL = $animalCode'];
    if (lactationCode != null && lactationCode.isNotEmpty) {
      filters.add('C.CODLACTACAO = ${_hoofSqlText(lactationCode)}');
    }
    final rows = await _query('''
SELECT C.ID, C.DATA, C.CODTIPO, T.DESCRICAO AS TIPO,
  C.CODFUNCIONARIO, C.CODAJUDANTE, C.COMENTARIO, C.CODLACTACAO,
  C.DEL, C.DP
FROM TB_CASQUEAMENTO C
INNER JOIN TB_TIPOCASQUEAMENTO T ON T.CODIGO = C.CODTIPO
WHERE ${filters.join(' AND ')}
ORDER BY C.ID DESC''');
    return rows.map(HoofTrimmingRecord.fromJson).toList(growable: false);
  }

  Future<void> saveRecord({
    int id = -1,
    required String date,
    required int animalCode,
    required int employeeCode,
    required int assistantCode,
    required int typeCode,
    required String comment,
  }) => _execute(
    hoofTrimmingInsertSql(
      id: id,
      date: date,
      animalCode: animalCode,
      employeeCode: employeeCode,
      assistantCode: assistantCode,
      typeCode: typeCode,
      comment: comment,
    ),
  );

  Future<void> deleteRecord(int id) => _execute(
    'DELETE FROM TB_CASQUEAMENTO WHERE ID = ${_positiveCode(id)};',
    action: 'ExecSql',
  );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_hoofXmlEscape(sql)}</xSql>'
          '<Sufixo>${_hoofXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_hoofXmlEscape(sql)}</xSql>'
          '<Login>${_hoofXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_hoofXmlEscape(password)}</Senha>'
          '<Sufixo>${_hoofXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String hoofTrimmingInsertSql({
  int id = -1,
  required String date,
  required int animalCode,
  required int employeeCode,
  required int assistantCode,
  required int typeCode,
  required String comment,
}) {
  if (id < -1 ||
      animalCode <= 0 ||
      employeeCode <= 0 ||
      assistantCode <= 0 ||
      typeCode <= 0) {
    throw ArgumentError('Informe animal, funcionário, ajudante e tipo.');
  }
  final parsedDate = _hoofDate(date);
  return 'EXEC SP_TB_CASQUEAMENTO_INSERT $id, \'$parsedDate\', '
      '$animalCode, $employeeCode, $assistantCode, $typeCode, '
      '${_hoofSqlText(comment)};';
}

int _positiveCode(int value) {
  if (value <= 0) throw ArgumentError.value(value, 'id');
  return value;
}

String _hoofDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data do casqueamento inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data do casqueamento inválida: $value');
  }
  return normalized;
}

dynamic _hoofField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _hoofInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

String _hoofSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

String _hoofXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
