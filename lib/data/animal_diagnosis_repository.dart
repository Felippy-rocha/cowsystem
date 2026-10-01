import 'dart:convert';

import 'soap_client.dart';

class DiagnosisEmployee {
  const DiagnosisEmployee({required this.code, required this.name});

  final int code;
  final String name;

  factory DiagnosisEmployee.fromJson(Map<String, dynamic> json) =>
      DiagnosisEmployee(
        code: _diagnosisInt(_diagnosisField(json, 'CODFUNCIONARIO')),
        name: '${_diagnosisField(json, 'FUNCIONARIO') ?? ''}'.trim(),
      );
}

class AnimalDiagnosisSession {
  const AnimalDiagnosisSession({
    required this.code,
    required this.date,
    required this.employee,
  });

  final int code;
  final String date;
  final String employee;

  factory AnimalDiagnosisSession.fromJson(Map<String, dynamic> json) =>
      AnimalDiagnosisSession(
        code: _diagnosisInt(_diagnosisField(json, 'CODTOQUE')),
        date: '${_diagnosisField(json, 'DATA') ?? ''}'.trim(),
        employee: '${_diagnosisField(json, 'FUNCIONARIO') ?? ''}'.trim(),
      );
}

class AnimalDiagnosisRecord {
  const AnimalDiagnosisRecord({
    required this.id,
    required this.sessionCode,
    required this.animalCode,
    required this.tag,
    required this.lot,
    required this.type,
    required this.reproductiveStatus,
    required this.productionStatus,
    required this.daysSinceInsemination,
    required this.daysInMilk,
    required this.inseminationCount,
    required this.lastInsemination,
    required this.lastCalving,
    required this.resultCode,
    required this.result,
    required this.comment,
    required this.active,
    required this.discard,
  });

  final int id;
  final int sessionCode;
  final int animalCode;
  final String tag;
  final String lot;
  final String type;
  final String reproductiveStatus;
  final String productionStatus;
  final int daysSinceInsemination;
  final int daysInMilk;
  final int inseminationCount;
  final String lastInsemination;
  final String lastCalving;
  final int resultCode;
  final String result;
  final String comment;
  final bool active;
  final bool discard;

  factory AnimalDiagnosisRecord.fromJson(
    Map<String, dynamic> json,
  ) => AnimalDiagnosisRecord(
    id: _diagnosisInt(_diagnosisField(json, 'ID')),
    sessionCode: _diagnosisInt(_diagnosisField(json, 'CODTOQUE')),
    animalCode: _diagnosisInt(_diagnosisField(json, 'CODANIMAL')),
    tag: '${_diagnosisField(json, 'BRINCO') ?? ''}'.trim(),
    lot: '${_diagnosisField(json, 'LOTE') ?? ''}'.trim(),
    type: '${_diagnosisField(json, 'TIPOTOQUE') ?? ''}'.trim(),
    reproductiveStatus: '${_diagnosisField(json, 'STATUSREPRODUCAO') ?? ''}'
        .trim(),
    productionStatus: '${_diagnosisField(json, 'STATUSPRODUCAO') ?? ''}'.trim(),
    daysSinceInsemination: _diagnosisInt(
      _diagnosisField(json, 'DIASDEINSEMINADA'),
    ),
    daysInMilk: _diagnosisInt(_diagnosisField(json, 'DEL')),
    inseminationCount: _diagnosisInt(_diagnosisField(json, 'NUMIAS')),
    lastInsemination: '${_diagnosisField(json, 'DATAULTIMAIA') ?? ''}'.trim(),
    lastCalving: '${_diagnosisField(json, 'ULTIMOPARTO') ?? ''}'.trim(),
    resultCode: _diagnosisInt(_diagnosisField(json, 'RESULTADOTOQUE')),
    result: '${_diagnosisField(json, 'RESULTADO') ?? ''}'.trim(),
    comment: '${_diagnosisField(json, 'COMENTARIO') ?? ''}'.trim(),
    active: _diagnosisInt(_diagnosisField(json, 'ATIVO')) == 1,
    discard: _diagnosisInt(_diagnosisField(json, 'ADESCARTAR')) == 1,
  );
}

class DiagnosisResultOption {
  const DiagnosisResultOption({required this.code, required this.label});

  final int code;
  final String label;

  factory DiagnosisResultOption.fromJson(Map<String, dynamic> json) =>
      DiagnosisResultOption(
        code: _diagnosisInt(_diagnosisField(json, 'CODRESULTADOTOQUE')),
        label: '${_diagnosisField(json, 'RESULTADOTOQUE') ?? ''}'.trim(),
      );
}

class AnimalDiagnosisRepository {
  AnimalDiagnosisRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<DiagnosisEmployee>> fetchEmployees() async => (await _query(
    'SELECT CODFUNCIONARIO, FUNCIONARIO FROM TB_FUNCIONARIOS ORDER BY FUNCIONARIO',
  )).map(DiagnosisEmployee.fromJson).toList(growable: false);

  Future<List<AnimalDiagnosisSession>> fetchSessions() async => (await _query(
    'SELECT T.CODTOQUE, T.DATA, F.FUNCIONARIO FROM TB_TOQUE T '
    'INNER JOIN TB_FUNCIONARIOS F ON F.CODFUNCIONARIO = T.CODFUNCIONARIO '
    'ORDER BY T.CODTOQUE DESC',
  )).map(AnimalDiagnosisSession.fromJson).toList(growable: false);

  Future<List<AnimalDiagnosisRecord>> fetchRecords(int sessionCode) async =>
      (await _query('''
SELECT D.ID, D.CODTOQUE, D.ID_INSEMINACAO, D.CODANIMAL, D.BRINCO, D.CODLOTE,
  D.TIPOTOQUE, D.DIASDEINSEMINADA, D.DEL, D.NUMIAS, D.VACANOVILHA,
  D.DATANASCIMENTO, D.ULTIMOPARTO, D.DATAULTIMAIA, D.CODLACTACAO, D.LOTE,
  D.STATUSPRODUCAO, D.STATUSREPRODUCAO, D.RESULTADOTOQUE, D.COMENTARIO,
  D.PESO, A.ATIVO, A.ADESCARTAR, R.RESULTADOTOQUE AS RESULTADO
FROM TB_TOQUE_DETALHES D
INNER JOIN TB_ANIMAIS A ON A.CODANIMAL = D.CODANIMAL
LEFT JOIN TB_RESULTADOTOQUE R ON R.CODRESULTADOTOQUE = D.RESULTADOTOQUE
WHERE D.CODTOQUE = $sessionCode
ORDER BY D.STATUSPRODUCAO, D.CODLOTE, TRY_CONVERT(INT, D.BRINCO), D.BRINCO'''))
          .map(AnimalDiagnosisRecord.fromJson)
          .toList(growable: false);

  Future<List<DiagnosisResultOption>> fetchResults(
    String type,
    String reproductiveStatus,
  ) async {
    final ids = diagnosisResultIds(type, reproductiveStatus);
    final rows = await _query(
      'SELECT CODRESULTADOTOQUE, RESULTADOTOQUE FROM TB_RESULTADOTOQUE '
      'WHERE CODRESULTADOTOQUE IN (${ids.join(', ')}) '
      'ORDER BY CODRESULTADOTOQUE',
    );
    return rows.map(DiagnosisResultOption.fromJson).toList(growable: false);
  }

  Future<int?> findAnimalCode(String tag) async {
    final rows = await _query(
      'SELECT TOP 1 CODANIMAL FROM TB_ANIMAIS '
      'WHERE BRINCO = ${_diagnosisSqlText(tag.trim())}',
    );
    if (rows.isEmpty) return null;
    return _diagnosisInt(_diagnosisField(rows.first, 'CODANIMAL'));
  }

  Future<void> createSession(String date, int employeeCode) =>
      _execute(diagnosisCreateSessionSql(date, employeeCode));

  Future<void> addAnimal(int sessionCode, int animalCode) =>
      _execute(diagnosisAddAnimalSql(sessionCode, animalCode));

  Future<void> saveResult({
    required int detailId,
    required String date,
    required int resultCode,
    required String comment,
  }) => _execute(diagnosisSaveResultSql(detailId, date, resultCode, comment));

  Future<void> deleteDetail(int detailId) =>
      _execute(diagnosisDeleteDetailSql(detailId));

  Future<void> undoResult(int detailId) =>
      _execute(diagnosisUndoResultSql(detailId));

  Future<void> deleteSession(int sessionCode) =>
      _execute('EXEC SP_TB_TOQUE_DELETE $sessionCode;');

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_diagnosisXmlEscape(sql)}</xSql>'
          '<Sufixo>${_diagnosisXmlEscape(soapClient.suffix)}</Sufixo>'
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
      action: 'ExecSql',
      password: password,
      body:
          '<xSql>${_diagnosisXmlEscape(sql)}</xSql>'
          '<Login>${_diagnosisXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_diagnosisXmlEscape(password)}</Senha>'
          '<Sufixo>${_diagnosisXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

List<int> diagnosisResultIds(String type, String reproductiveStatus) {
  if (reproductiveStatus.toUpperCase() == 'TETF') return [2, 4, 5, 6];
  return switch (type.toUpperCase()) {
    'PEV' => [4, 5],
    'VAZIA' => [2, 4, 5],
    'AVALIAÇÃO' => [6],
    _ => [1, 2, 3],
  };
}

String diagnosisCreateSessionSql(String date, int employeeCode) =>
    'EXEC SP_TB_TOQUE_INSERT @DATA = ${_diagnosisSqlDate(date)}, '
    '@CODFUNCIONARIO = $employeeCode;';

String diagnosisAddAnimalSql(int sessionCode, int animalCode) =>
    'EXEC SP_TB_TOQUE_INSERT_INDIVIDUAL '
    '@CODTOQUE = $sessionCode, @CODANIMAL = $animalCode;';

String diagnosisSaveResultSql(
  int detailId,
  String date,
  int resultCode,
  String comment,
) =>
    'EXEC SP_TB_TOQUE_CADASTRAR @ID_TOQUE_DETALHES = $detailId, '
    '@DATATOQUE = ${_diagnosisSqlDate(date)}, '
    '@RESULTADOTOQUE = $resultCode, '
    '@COMENTARIO = ${_diagnosisSqlText(comment.toUpperCase())};';

String diagnosisUndoResultSql(int detailId) =>
    'EXEC SP_TB_TOQUE_DESFAZER @ID_TOQUE_DETALHES = $detailId;';

String diagnosisDeleteDetailSql(int detailId) =>
    'DELETE FROM TB_TOQUE_DETALHES WHERE ID = $detailId;';

String _diagnosisSqlDate(String value) {
  final text = value.trim();
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
  final normalized = br == null
      ? text
      : '${br.group(3)}-${br.group(2)}-${br.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data de diagnóstico inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw FormatException('Data de diagnóstico inválida: $value');
  }
  return "'$normalized'";
}

String _diagnosisSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

dynamic _diagnosisField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _diagnosisInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

String _diagnosisXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
