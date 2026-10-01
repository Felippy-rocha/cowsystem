import 'dart:convert';

import 'soap_client.dart';

class TouchSession {
  const TouchSession({
    required this.code,
    required this.date,
    required this.employeeCode,
    required this.employee,
  });

  final int code;
  final String date;
  final int employeeCode;
  final String employee;

  factory TouchSession.fromJson(Map<String, dynamic> json) => TouchSession(
    code: _touchInt(_touchField(json, 'CODTOQUE')),
    date: '${_touchField(json, 'DATA') ?? ''}'.trim(),
    employeeCode: _touchInt(_touchField(json, 'CODFUNCIONARIO')),
    employee: '${_touchField(json, 'FUNCIONARIO') ?? ''}'.trim(),
  );
}

class TouchAnimal {
  const TouchAnimal({
    required this.id,
    required this.touchCode,
    required this.animalCode,
    required this.tag,
    required this.lot,
    required this.type,
    required this.resultCode,
    required this.result,
    required this.daysSinceInsemination,
    required this.daysInMilk,
    required this.inseminationCount,
    required this.cowHeifer,
    required this.productionStatus,
    required this.reproductiveStatus,
    required this.weight,
    required this.comment,
  });

  final int id;
  final int touchCode;
  final int animalCode;
  final String tag;
  final String lot;
  final String type;
  final int resultCode;
  final String result;
  final int daysSinceInsemination;
  final int daysInMilk;
  final int inseminationCount;
  final String cowHeifer;
  final String productionStatus;
  final String reproductiveStatus;
  final double weight;
  final String comment;

  factory TouchAnimal.fromJson(Map<String, dynamic> json) => TouchAnimal(
    id: _touchInt(_touchField(json, 'ID')),
    touchCode: _touchInt(_touchField(json, 'CODTOQUE')),
    animalCode: _touchInt(_touchField(json, 'CODANIMAL')),
    tag: '${_touchField(json, 'BRINCO') ?? ''}'.trim(),
    lot: '${_touchField(json, 'LOTE') ?? ''}'.trim(),
    type: '${_touchField(json, 'TIPOTOQUE') ?? ''}'.trim(),
    resultCode: _touchInt(_touchField(json, 'RESULTADOTOQUE')),
    result: '${_touchField(json, 'RESULTADOTOQUE_DESC') ?? ''}'.trim(),
    daysSinceInsemination: _touchInt(_touchField(json, 'DIASDEINSEMINADA')),
    daysInMilk: _touchInt(_touchField(json, 'DEL')),
    inseminationCount: _touchInt(_touchField(json, 'NUMIAS')),
    cowHeifer: '${_touchField(json, 'VACANOVILHA') ?? ''}'.trim(),
    productionStatus: '${_touchField(json, 'STATUSPRODUCAO') ?? ''}'.trim(),
    reproductiveStatus: '${_touchField(json, 'STATUSREPRODUCAO') ?? ''}'.trim(),
    weight: _touchDouble(_touchField(json, 'PESO')),
    comment: '${_touchField(json, 'COMENTARIO') ?? ''}'.trim(),
  );
}

class TouchResultOption {
  const TouchResultOption({required this.code, required this.name});

  final int code;
  final String name;

  factory TouchResultOption.fromJson(Map<String, dynamic> json) =>
      TouchResultOption(
        code: _touchInt(_touchField(json, 'CODRESULTADOTOQUE')),
        name: '${_touchField(json, 'RESULTADOTOQUE') ?? ''}'.trim(),
      );
}

class TouchSessionRepository {
  TouchSessionRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<TouchSession>> fetchSessions() async {
    final rows = await _query('''
SELECT T.CODTOQUE, T.DATA, T.CODFUNCIONARIO, F.FUNCIONARIO
FROM TB_TOQUE T
INNER JOIN TB_FUNCIONARIOS F ON F.CODFUNCIONARIO = T.CODFUNCIONARIO
ORDER BY T.CODTOQUE DESC''');
    return rows.map(TouchSession.fromJson).toList(growable: false);
  }

  Future<List<TouchAnimal>> fetchAnimals(int touchCode) async {
    final rows = await _query('''
SELECT D.ID, D.CODTOQUE, D.ID_INSEMINACAO, D.CODANIMAL, D.BRINCO,
  D.CODLOTE, D.TIPOTOQUE, D.RESULTADOTOQUE,
  R.RESULTADOTOQUE AS RESULTADOTOQUE_DESC,
  D.DIASDEINSEMINADA, D.DEL, D.NUMIAS, D.VACANOVILHA,
  D.DATANASCIMENTO, D.ULTIMOPARTO, D.DATAULTIMAIA, D.CODLACTACAO,
  D.LOTE, D.STATUSPRODUCAO, D.STATUSREPRODUCAO, D.COMENTARIO, D.PESO
FROM TB_TOQUE_DETALHES D
LEFT JOIN TB_RESULTADOTOQUE R ON R.CODRESULTADOTOQUE = D.RESULTADOTOQUE
WHERE D.CODTOQUE = ${_touchPositive(touchCode)}
ORDER BY D.STATUSPRODUCAO, D.CODLOTE, TRY_CONVERT(int, D.BRINCO), D.BRINCO''');
    return rows.map(TouchAnimal.fromJson).toList(growable: false);
  }

  Future<List<TouchResultOption>> fetchResults(String type) async {
    final normalized = type.trim().toUpperCase();
    final codes = normalized == 'PEV'
        ? '(4, 5)'
        : normalized == 'VAZIA'
        ? '(2, 4, 5)'
        : normalized == 'AVALIAÇÃO'
        ? '(6)'
        : '(1, 2, 3)';
    final rows = await _query(
      'SELECT CODRESULTADOTOQUE, RESULTADOTOQUE FROM TB_RESULTADOTOQUE '
      'WHERE CODRESULTADOTOQUE IN $codes ORDER BY CODRESULTADOTOQUE',
    );
    return rows.map(TouchResultOption.fromJson).toList(growable: false);
  }

  Future<List<({int code, String name})>> fetchEmployees() async {
    final rows = await _query(
      'SELECT CODFUNCIONARIO, FUNCIONARIO FROM TB_FUNCIONARIOS ORDER BY FUNCIONARIO',
    );
    return rows
        .map(
          (row) => (
            code: _touchInt(_touchField(row, 'CODFUNCIONARIO')),
            name: '${_touchField(row, 'FUNCIONARIO') ?? ''}'.trim(),
          ),
        )
        .toList(growable: false);
  }

  Future<int?> findAnimalCode(String tag) async {
    final rows = await _query(
      'SELECT CODANIMAL FROM dbo.LISTA_ANIMAIS() '
      'WHERE BRINCO = ${_touchSqlText(tag.trim())}',
    );
    return rows.isEmpty
        ? null
        : _touchInt(_touchField(rows.first, 'CODANIMAL'));
  }

  Future<void> createSession({
    required String date,
    required int employeeCode,
  }) => _execute(
    touchSessionCreateSql(date: date, employeeCode: employeeCode),
    action: 'ExecSql',
  );

  Future<void> addAnimal({required int touchCode, required int animalCode}) =>
      _execute(
        touchAnimalInsertSql(touchCode: touchCode, animalCode: animalCode),
        action: 'ExecSql',
      );

  Future<void> saveResult({
    required int id,
    required String date,
    required int resultCode,
    required String comment,
  }) => _execute(
    touchResultSql(
      id: id,
      date: date,
      resultCode: resultCode,
      comment: comment,
    ),
    action: 'ExecSql',
  );

  Future<void> deleteSession(int code) =>
      _execute('EXEC SP_TB_TOQUE_DELETE ${_touchPositive(code)};');

  Future<void> deleteAnimal(int id) => _execute(
    'DELETE FROM TB_TOQUE_DETALHES WHERE ID = ${_touchPositive(id)};',
    action: 'ExecSql',
  );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_touchXmlEscape(sql)}</xSql>'
          '<Sufixo>${_touchXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_touchXmlEscape(sql)}</xSql>'
          '<Login>${_touchXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_touchXmlEscape(password)}</Senha>'
          '<Sufixo>${_touchXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String touchSqlDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data do toque inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data do toque inválida: $value');
  }
  return "'$normalized'";
}

String touchSessionCreateSql({
  required String date,
  required int employeeCode,
}) {
  if (employeeCode <= 0) {
    throw ArgumentError.value(employeeCode, 'employeeCode');
  }
  return 'EXEC SP_TB_TOQUE_INSERT @DATA = ${touchSqlDate(date)}, @CODFUNCIONARIO = $employeeCode;';
}

String touchAnimalInsertSql({required int touchCode, required int animalCode}) {
  if (touchCode <= 0 || animalCode <= 0) {
    throw ArgumentError('Informe toque e animal válidos.');
  }
  return 'EXEC SP_TB_TOQUE_INSERT_INDIVIDUAL @CODTOQUE = $touchCode, @CODANIMAL = $animalCode;';
}

String touchResultSql({
  required int id,
  required String date,
  required int resultCode,
  required String comment,
}) {
  if (id <= 0 || resultCode <= 0) {
    throw ArgumentError('Informe registro e resultado do toque.');
  }
  return 'EXEC SP_TB_TOQUE_CADASTRAR @ID_TOQUE_DETALHES = $id, '
      '@DATA = ${touchSqlDate(date)}, @RESULTADOTOQUE = $resultCode, '
      '@COMENTARIO = ${_touchSqlText(comment.trim())};';
}

int _touchPositive(int value) {
  if (value <= 0) throw ArgumentError.value(value, 'id');
  return value;
}

dynamic _touchField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _touchInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _touchDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _touchSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

String _touchXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
