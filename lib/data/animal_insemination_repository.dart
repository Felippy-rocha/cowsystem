import 'dart:convert';

import 'animal_record.dart';
import 'soap_client.dart';

class InseminationOption {
  const InseminationOption({required this.code, required this.name});

  final int code;
  final String name;

  factory InseminationOption.fromJson(
    Map<String, dynamic> json, {
    required String codeColumn,
    required String nameColumn,
  }) => InseminationOption(
    code: _inseminationInt(_inseminationField(json, codeColumn)),
    name: '${_inseminationField(json, nameColumn) ?? ''}'.trim(),
  );
}

class InseminationBull extends InseminationOption {
  const InseminationBull({
    required super.code,
    required super.name,
    required this.stock,
    required this.recommended,
  });

  final int stock;
  final bool recommended;

  factory InseminationBull.fromJson(Map<String, dynamic> json) =>
      InseminationBull(
        code: _inseminationInt(_inseminationField(json, 'CODTOURO')),
        name: '${_inseminationField(json, 'TOURO') ?? ''}'.trim(),
        stock: _inseminationInt(_inseminationField(json, 'ESTOQUE')),
        recommended:
            _inseminationInt(_inseminationField(json, 'RECOMENDADO')) == 1,
      );
}

class AnimalInseminationRepository {
  AnimalInseminationRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<AnimalRecord>> fetchAnimals({
    String tag = '',
    bool includeAll = false,
    int offset = 0,
    int limit = 200,
  }) async {
    final rows = await _query(
      inseminationAnimalQuery(
        tag: tag,
        includeAll: includeAll,
        offset: offset,
        limit: limit,
      ),
    );
    return rows.map(AnimalRecord.fromJson).toList(growable: false);
  }

  Future<List<AnimalRecord>> fetchAllAnimalOptions() async {
    final rows = await _query(
      'SELECT * FROM dbo.LISTA_ANIMAIS() '
      'ORDER BY TRY_CONVERT(INT, BRINCO), BRINCO',
    );
    return rows.map(AnimalRecord.fromJson).toList(growable: false);
  }

  Future<List<InseminationOption>> fetchEmployees() async =>
      (await _query(
            'SELECT CODFUNCIONARIO, FUNCIONARIO FROM TB_FUNCIONARIOS ORDER BY FUNCIONARIO',
          ))
          .map(
            (row) => InseminationOption.fromJson(
              row,
              codeColumn: 'CODFUNCIONARIO',
              nameColumn: 'FUNCIONARIO',
            ),
          )
          .toList(growable: false);

  Future<List<InseminationOption>> fetchTypes() async =>
      (await _query('SELECT CODTIPOIA, TIPOIA FROM TB_TIPOIA ORDER BY TIPOIA'))
          .map(
            (row) => InseminationOption.fromJson(
              row,
              codeColumn: 'CODTIPOIA',
              nameColumn: 'TIPOIA',
            ),
          )
          .toList(growable: false);

  Future<List<InseminationOption>> fetchDonors() async =>
      (await _query(
            "SELECT CODANIMAL, BRINCO FROM TB_ANIMAIS "
            'WHERE DOADORA IN (1, 3) ORDER BY TRY_CONVERT(INT, BRINCO), BRINCO',
          ))
          .map(
            (row) => InseminationOption.fromJson(
              row,
              codeColumn: 'CODANIMAL',
              nameColumn: 'BRINCO',
            ),
          )
          .toList(growable: false);

  Future<List<InseminationBull>> fetchBulls({
    required int animalCode,
    required bool embryo,
  }) async {
    final embryoCode = embryo ? 1 : 2;
    final query =
        '''
SELECT T.CODTOURO, T.TOURO, T.ESTOQUE,
  CASE WHEN SUBSTRING(T.CODNAAB, 2, 9) IN (
    SELECT OPCAO_1 FROM TB_PLANOGENETICO WHERE CODANIMAL = $animalCode AND OPCAO_1 <> 0
    UNION SELECT OPCAO_2 FROM TB_PLANOGENETICO WHERE CODANIMAL = $animalCode AND OPCAO_2 <> 0
    UNION SELECT OPCAO_3 FROM TB_PLANOGENETICO WHERE CODANIMAL = $animalCode AND OPCAO_3 <> 0
  ) THEN 1 ELSE 0 END AS RECOMENDADO
FROM TB_TOUROS T
WHERE T.ESTOQUE > 0 AND T.EMBRIAO = $embryoCode
ORDER BY RECOMENDADO DESC, T.TOURO''';
    return (await _query(query))
        .map(InseminationBull.fromJson)
        .toList(growable: false);
  }

  Future<void> insertInsemination({
    required int animalCode,
    required String date,
    required int employeeCode,
    required int bullCode,
    required int typeCode,
    required String comment,
    required int donorCode,
  }) => _execute(
    inseminationInsertSql(
      animalCode: animalCode,
      date: date,
      employeeCode: employeeCode,
      bullCode: bullCode,
      typeCode: typeCode,
      comment: comment,
      donorCode: donorCode,
    ),
  );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_inseminationXmlEscape(sql)}</xSql>'
          '<Sufixo>${_inseminationXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_inseminationXmlEscape(sql)}</xSql>'
          '<Login>${_inseminationXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_inseminationXmlEscape(password)}</Senha>'
          '<Sufixo>${_inseminationXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String inseminationAnimalQuery({
  String tag = '',
  bool includeAll = false,
  int offset = 0,
  int limit = 200,
}) {
  if (offset < 0 || limit < 1 || limit > 500) {
    throw ArgumentError('Paginação de inseminação inválida.');
  }
  final filters = <String>[];
  if (tag.trim().isNotEmpty) {
    filters.add("BRINCO = ${_inseminationSqlText(tag.trim())}");
  }
  if (!includeAll) {
    filters.add('ATIVO = 1');
    filters.add("STATUSREPRODUCAO NOT IN ('PRENHA', 'PEV')");
    filters.add('ADESCARTAR = 2');
    filters.add('DOADORA IN (2, 3)');
    filters.add(
      'DATEDIFF(day, TRY_CONVERT(date, DATANASCIMENTO, 103), GETDATE()) >= 365',
    );
  }
  return 'SELECT * FROM dbo.LISTA_ANIMAIS() '
      '${filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')} '} '
      'ORDER BY TRY_CONVERT(INT, BRINCO), BRINCO '
      'OFFSET $offset ROWS FETCH NEXT $limit ROWS ONLY';
}

String inseminationInsertSql({
  required int animalCode,
  required String date,
  required int employeeCode,
  required int bullCode,
  required int typeCode,
  required String comment,
  required int donorCode,
}) =>
    'EXEC SP_TB_INSEMINACAO_INSERT_1 '
    '@CODANIMAL = $animalCode, '
    '@DATA = ${_inseminationSqlDate(date)}, '
    '@CODFUNCIONARIO = $employeeCode, '
    '@CODTOURO = $bullCode, '
    '@CODTIPOIA = $typeCode, '
    '@COMENTARIO = ${_inseminationSqlText(comment.toUpperCase())}, '
    '@CODDOADORA = $donorCode;';

String _inseminationSqlDate(String value) {
  final trimmed = value.trim();
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = br == null
      ? trimmed
      : '${br.group(3)}-${br.group(2)}-${br.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data de inseminação inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw FormatException('Data de inseminação inválida: $value');
  }
  return "'$normalized'";
}

String _inseminationSqlText(String value) =>
    "N'${value.replaceAll("'", "''")}'";

dynamic _inseminationField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _inseminationInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

String _inseminationXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
