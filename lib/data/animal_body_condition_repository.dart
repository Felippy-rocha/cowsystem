import 'dart:convert';

import 'soap_client.dart';

class BodyConditionEmployee {
  const BodyConditionEmployee({required this.code, required this.name});

  final int code;
  final String name;

  factory BodyConditionEmployee.fromJson(Map<String, dynamic> json) =>
      BodyConditionEmployee(
        code: _bodyConditionInt(_bodyConditionField(json, 'CODFUNCIONARIO')),
        name: '${_bodyConditionField(json, 'FUNCIONARIO') ?? ''}'.trim(),
      );
}

class BodyConditionSession {
  const BodyConditionSession({
    required this.code,
    required this.date,
    required this.employee,
  });

  final int code;
  final String date;
  final String employee;

  factory BodyConditionSession.fromJson(Map<String, dynamic> json) =>
      BodyConditionSession(
        code: _bodyConditionInt(_bodyConditionField(json, 'CODESCORE')),
        date: '${_bodyConditionField(json, 'DATA') ?? ''}'.trim(),
        employee: '${_bodyConditionField(json, 'FUNCIONARIO') ?? ''}'.trim(),
      );
}

class BodyConditionRecord {
  const BodyConditionRecord({
    required this.id,
    required this.sessionCode,
    required this.animalCode,
    required this.tag,
    required this.score,
    required this.lactation,
    required this.lot,
    required this.daysInMilk,
    required this.reproductiveStatus,
    required this.productionStatus,
  });

  final int id;
  final int sessionCode;
  final int animalCode;
  final String tag;
  final double score;
  final String lactation;
  final String lot;
  final int daysInMilk;
  final String reproductiveStatus;
  final String productionStatus;

  factory BodyConditionRecord.fromJson(Map<String, dynamic> json) =>
      BodyConditionRecord(
        id: _bodyConditionInt(_bodyConditionField(json, 'ID')),
        sessionCode: _bodyConditionInt(_bodyConditionField(json, 'CODESCORE')),
        animalCode: _bodyConditionInt(_bodyConditionField(json, 'CODANIMAL')),
        tag: '${_bodyConditionField(json, 'BRINCO') ?? ''}'.trim(),
        score: _bodyConditionDouble(_bodyConditionField(json, 'ESCORE')),
        lactation: '${_bodyConditionField(json, 'CODLACTACAO') ?? ''}'.trim(),
        lot: '${_bodyConditionField(json, 'LOTE') ?? ''}'.trim(),
        daysInMilk: _bodyConditionInt(_bodyConditionField(json, 'DEL')),
        reproductiveStatus:
            '${_bodyConditionField(json, 'STATUSREPRODUCAO') ?? ''}'.trim(),
        productionStatus: '${_bodyConditionField(json, 'STATUSPRODUCAO') ?? ''}'
            .trim(),
      );
}

class AnimalBodyConditionRepository {
  AnimalBodyConditionRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<BodyConditionEmployee>> fetchEmployees() async => (await _query(
    'SELECT CODFUNCIONARIO, FUNCIONARIO FROM TB_FUNCIONARIOS ORDER BY FUNCIONARIO',
  )).map(BodyConditionEmployee.fromJson).toList(growable: false);

  Future<List<BodyConditionSession>> fetchSessions() async => (await _query(
    'SELECT S.CODESCORE, S.DATA, F.FUNCIONARIO FROM TB_ESCORE S '
    'INNER JOIN TB_FUNCIONARIOS F ON F.CODFUNCIONARIO = S.CODFUNCIONARIO '
    'ORDER BY S.CODESCORE DESC',
  )).map(BodyConditionSession.fromJson).toList(growable: false);

  Future<List<BodyConditionRecord>> fetchRecords(int sessionCode) async =>
      (await _query('''
SELECT D.ID, D.CODESCORE, D.CODANIMAL, A.BRINCO, D.ESCORE,
  D.CODLACTACAO, L.LOTE, D.DEL, D.STATUSREPRODUCAO, D.STATUSPRODUCAO
FROM TB_ESCORE_DETALHES D
INNER JOIN TB_ANIMAIS A ON A.CODANIMAL = D.CODANIMAL
INNER JOIN TB_LOTES L ON L.CODLOTE = D.CODLOTE
WHERE D.CODESCORE = $sessionCode
ORDER BY D.STATUSPRODUCAO, D.CODLOTE, TRY_CONVERT(INT, A.BRINCO), A.BRINCO'''))
          .map(BodyConditionRecord.fromJson)
          .toList(growable: false);

  Future<void> createSession(String date, int employeeCode) =>
      _execute(bodyConditionCreateSessionSql(date, employeeCode));

  Future<void> updateScore(int detailId, double score) =>
      _execute(bodyConditionUpdateScoreSql(detailId, score));

  Future<void> deleteDetail(int detailId) =>
      _execute('DELETE FROM TB_ESCORE_DETALHES WHERE ID = $detailId;');

  Future<void> deleteSession(int sessionCode) =>
      _execute('EXEC SP_TB_ESCORE_DELETE $sessionCode;');

  Future<bool> canDeleteSession(int sessionCode) async {
    final rows = await _query(
      'SELECT COUNT(*) AS AVALIADOS FROM TB_ESCORE_DETALHES '
      'WHERE CODESCORE = $sessionCode AND ESCORE > 0',
    );
    if (rows.isEmpty) return true;
    return _bodyConditionInt(_bodyConditionField(rows.first, 'AVALIADOS')) == 0;
  }

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_bodyConditionXmlEscape(sql)}</xSql>'
          '<Sufixo>${_bodyConditionXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_bodyConditionXmlEscape(sql)}</xSql>'
          '<Login>${_bodyConditionXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_bodyConditionXmlEscape(password)}</Senha>'
          '<Sufixo>${_bodyConditionXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String bodyConditionCreateSessionSql(String date, int employeeCode) =>
    'EXEC SP_TB_ESCORE_INSERT ${_bodyConditionSqlDate(date)}, $employeeCode;';

String bodyConditionUpdateScoreSql(int detailId, double score) {
  if (score < 0 || !score.isFinite) {
    throw ArgumentError.value(score, 'score', 'Escore inválido.');
  }
  return 'EXEC SP_TB_ESCORE_UPDATE $detailId, ${score.toStringAsFixed(2)};';
}

String _bodyConditionSqlDate(String value) {
  final trimmed = value.trim();
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = br == null
      ? trimmed
      : '${br.group(3)}-${br.group(2)}-${br.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data do ECC inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw FormatException('Data do ECC inválida: $value');
  }
  return "'$normalized'";
}

dynamic _bodyConditionField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _bodyConditionInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _bodyConditionDouble(Object? value) =>
    double.tryParse('${value ?? 0}') ?? 0;

String _bodyConditionXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
