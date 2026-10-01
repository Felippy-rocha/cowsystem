import 'dart:convert';

import 'soap_client.dart';

class BstAnimalOption {
  const BstAnimalOption({
    required this.animalCode,
    this.cycleCode = 0,
    required this.tag,
    required this.productionStatus,
    required this.reproductiveStatus,
    required this.lactationCode,
    required this.lastCalvingDate,
    required this.daysInMilk,
    required this.hormoneCode,
    required this.hormone,
    required this.entryDate,
    required this.week,
    required this.score,
  });

  final int animalCode;
  final int cycleCode;
  final String tag;
  final String productionStatus;
  final String reproductiveStatus;
  final String lactationCode;
  final String lastCalvingDate;
  final int daysInMilk;
  final int hormoneCode;
  final String hormone;
  final String entryDate;
  final String week;
  final double score;

  factory BstAnimalOption.fromJson(Map<String, dynamic> json) =>
      BstAnimalOption(
        animalCode: _bstValueInt(_bstValue(json, 'CODANIMAL')),
        cycleCode: _bstValueInt(_bstValue(json, 'CODBST')),
        tag: '${_bstValue(json, 'BRINCO') ?? ''}'.trim(),
        productionStatus: '${_bstValue(json, 'STATUSPRODUCAO') ?? ''}'.trim(),
        reproductiveStatus: '${_bstValue(json, 'STATUSREPRODUCAO') ?? ''}'
            .trim(),
        lactationCode: '${_bstValue(json, 'CODLACTACAO') ?? ''}'.trim(),
        lastCalvingDate: '${_bstValue(json, 'ULTIMOPARTO') ?? ''}'.trim(),
        daysInMilk: _bstValueInt(_bstValue(json, 'DEL')),
        hormoneCode: _bstValueInt(_bstValue(json, 'CODHORMONIO')),
        hormone: '${_bstValue(json, 'MEDICAMENTO') ?? ''}'.trim(),
        entryDate: '${_bstValue(json, 'DATAENTRADA') ?? ''}'.trim(),
        week: '${_bstValue(json, 'SEMANA') ?? ''}'.trim(),
        score: _bstValueDouble(_bstValue(json, 'ESCORE')),
      );
}

class BstChoice {
  const BstChoice({required this.code, required this.name});

  final int code;
  final String name;

  factory BstChoice.fromJson(Map<String, dynamic> json) => BstChoice(
    code: _bstValueInt(_bstValue(json, 'CODIGO')),
    name: '${_bstValue(json, 'NOME') ?? ''}'.trim(),
  );
}

class AnimalBstRepository {
  AnimalBstRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<BstAnimalOption>> fetchEligibleAnimals({String tag = ''}) async {
    final trimmed = tag.trim();
    final filters = <String>[
      "A.STATUSREPRODUCAO IN ('INSEMINADA', 'VAZIA', 'PRENHA', 'PEV')",
      "A.STATUSPRODUCAO = 'EM LEITE'",
      'DATEDIFF(day, TRY_CONVERT(date, A.ULTIMOPARTO, 103), CONVERT(date, GETDATE())) BETWEEN 60 AND 200',
      'A.ATIVO = 1',
      'A.DOADORA IN (2, 3)',
      'NOT EXISTS (SELECT 1 FROM TB_BST B WHERE B.CODANIMAL = A.CODANIMAL AND B.ATIVO = 1)',
    ];
    if (trimmed.isNotEmpty) filters.add('A.BRINCO = ${_bstSqlText(trimmed)}');
    final rows = await _query('''
SELECT A.CODANIMAL, A.BRINCO, A.STATUSPRODUCAO, A.STATUSREPRODUCAO,
  A.CODLACTACAOATUAL AS CODLACTACAO, A.ULTIMOPARTO,
  DATEDIFF(day, TRY_CONVERT(date, A.ULTIMOPARTO, 103), CONVERT(date, GETDATE())) AS DEL,
  ISNULL(S.NUMIA, 0) AS NUMIA, ISNULL(S.DATA, '') AS DATAIA,
  ISNULL(E.ESCORE, 0) AS ESCORE, R.RACA
FROM TB_ANIMAIS A
INNER JOIN TB_RACA R ON R.CODRACA = A.CODRACA
LEFT JOIN TB_INSEMINACOES S ON S.CODANIMAL = A.CODANIMAL
  AND S.CODLACTACAO = A.CODLACTACAOATUAL
  AND S.NUMIA = (SELECT MAX(S2.NUMIA) FROM TB_INSEMINACOES S2
    WHERE S2.CODANIMAL = A.CODANIMAL AND S2.CODLACTACAO = A.CODLACTACAOATUAL)
LEFT JOIN TB_ESCORE_DETALHES E ON E.CODANIMAL = A.CODANIMAL
  AND E.ID = (SELECT MAX(E2.ID) FROM TB_ESCORE_DETALHES E2
    WHERE E2.CODANIMAL = A.CODANIMAL)
WHERE ${filters.join(' AND ')}
ORDER BY TRY_CONVERT(int, A.BRINCO), A.BRINCO''');
    return rows.map(BstAnimalOption.fromJson).toList(growable: false);
  }

  Future<List<BstAnimalOption>> fetchActiveAnimals({String week = ''}) async {
    final filters = <String>['A.ATIVO = 1', 'B.ATIVO = 1'];
    if (week.trim().isNotEmpty) {
      filters.add('B.SEMANA = ${_bstSqlText(week.trim())}');
    }
    final rows = await _query('''
SELECT A.CODANIMAL, B.CODBST, A.BRINCO, A.STATUSPRODUCAO, A.STATUSREPRODUCAO,
  A.CODLACTACAOATUAL AS CODLACTACAO, A.ULTIMOPARTO,
  DATEDIFF(day, TRY_CONVERT(date, A.ULTIMOPARTO, 103), CONVERT(date, GETDATE())) AS DEL,
  B.CODHORMONIO, M.MEDICAMENTO, B.DATAENTRADA, B.SEMANA,
  ISNULL(E.ESCORE, 0) AS ESCORE
FROM TB_BST B
INNER JOIN TB_ANIMAIS A ON A.CODANIMAL = B.CODANIMAL
INNER JOIN TB_MEDICAMENTOS_NOVO M ON M.CODMEDICAMENTO = B.CODHORMONIO
LEFT JOIN TB_ESCORE_DETALHES E ON E.CODANIMAL = A.CODANIMAL
  AND E.ID = (SELECT MAX(E2.ID) FROM TB_ESCORE_DETALHES E2
    WHERE E2.CODANIMAL = A.CODANIMAL)
WHERE ${filters.join(' AND ')}
ORDER BY TRY_CONVERT(int, A.BRINCO), A.BRINCO''');
    return rows.map(BstAnimalOption.fromJson).toList(growable: false);
  }

  Future<List<BstChoice>> fetchHormones() async {
    final rows = await _query(
      'SELECT CODMEDICAMENTO AS CODIGO, MEDICAMENTO AS NOME '
      'FROM TB_MEDICAMENTOS_NOVO WHERE CODTIPOMEDICAMENTO = 1 '
      'ORDER BY MEDICAMENTO',
    );
    return rows.map(BstChoice.fromJson).toList(growable: false);
  }

  Future<List<BstChoice>> fetchWeeks() async {
    final rows = await _query(
      'SELECT CODIGO, DESCRICAO AS NOME FROM TB_SEMANA ORDER BY CODIGO',
    );
    return rows.map(BstChoice.fromJson).toList(growable: false);
  }

  Future<void> saveCycle({
    required int animalCode,
    required String entryDate,
    required int hormoneCode,
    required String lactationCode,
    required String week,
    int? cycleCode,
  }) => _execute(
    cycleCode == null
        ? bstCycleInsertSql(
            animalCode: animalCode,
            entryDate: entryDate,
            hormoneCode: hormoneCode,
            lactationCode: lactationCode,
            week: week,
          )
        : bstCycleUpdateSql(
            cycleCode: cycleCode,
            hormoneCode: hormoneCode,
            week: week,
          ),
  );

  Future<void> deactivateCycle(int cycleCode) =>
      _execute(bstCycleDeactivateSql(cycleCode));

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

  Future<void> _execute(String sql) async {
    final password = const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD');
    final response = await soapClient.callResult(
      action: 'ExecSql',
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
  }
}

String bstCycleInsertSql({
  required int animalCode,
  required String entryDate,
  required int hormoneCode,
  required String lactationCode,
  required String week,
}) {
  if (animalCode <= 0 ||
      hormoneCode <= 0 ||
      lactationCode.trim().isEmpty ||
      week.trim().isEmpty) {
    throw ArgumentError('Informe animal, lactação, hormônio e semana.');
  }
  return 'INSERT INTO TB_BST (CODANIMAL, DATAENTRADA, DATASAIDA, CODHORMONIO, '
      'ATIVO, HORA_DO_REGISTRO, CODLACTACAO, SEMANA) VALUES '
      '($animalCode, ${_bstDateSql(entryDate)}, NULL, $hormoneCode, 1, '
      'dbo.cHORA_DO_REGISTRO(), ${_bstSqlText(lactationCode.trim())}, '
      '${_bstSqlText(week.trim())});';
}

String bstCycleUpdateSql({
  required int cycleCode,
  required int hormoneCode,
  required String week,
}) {
  if (cycleCode <= 0 || hormoneCode <= 0 || week.trim().isEmpty) {
    throw ArgumentError('Informe ciclo, hormônio e semana.');
  }
  return 'UPDATE TB_BST SET CODHORMONIO = $hormoneCode, '
      'HORA_DO_REGISTRO = dbo.cHORA_DO_REGISTRO(), '
      'SEMANA = ${_bstSqlText(week.trim())} WHERE CODBST = $cycleCode AND ATIVO = 1;';
}

String bstCycleDeactivateSql(int cycleCode) {
  if (cycleCode <= 0) throw ArgumentError.value(cycleCode, 'cycleCode');
  return 'UPDATE TB_BST SET ATIVO = 2, DATASAIDA = GETDATE(), '
      'HORA_DO_REGISTRO = dbo.cHORA_DO_REGISTRO() '
      'WHERE CODBST = $cycleCode AND ATIVO = 1;';
}

String _bstDateSql(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data de entrada BST inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data de entrada BST inválida: $value');
  }
  return "'$normalized'";
}

dynamic _bstValue(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _bstValueInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _bstValueDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _bstSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

String _bstXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
