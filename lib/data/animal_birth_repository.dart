import 'dart:convert';

import 'animal_record.dart';
import 'soap_client.dart';

class BirthOption {
  const BirthOption({required this.code, required this.name});

  final int code;
  final String name;

  factory BirthOption.fromJson(
    Map<String, dynamic> json, {
    required String codeColumn,
    required String nameColumn,
  }) => BirthOption(
    code: _birthInt(_birthField(json, codeColumn)),
    name: '${_birthField(json, nameColumn) ?? ''}'.trim(),
  );
}

class AnimalBirthCandidate {
  const AnimalBirthCandidate({
    required this.animal,
    required this.expectedDate,
    required this.lastInsemination,
    required this.inseminationCount,
  });

  final AnimalRecord animal;
  final String expectedDate;
  final String lastInsemination;
  final int inseminationCount;

  factory AnimalBirthCandidate.fromJson(Map<String, dynamic> json) {
    final animal = AnimalRecord.fromJson(json);
    return AnimalBirthCandidate(
      animal: animal,
      expectedDate: '${_birthField(json, 'PREVISAOPARTO') ?? ''}'.trim(),
      lastInsemination: '${_birthField(json, 'DATAIA') ?? ''}'.trim(),
      inseminationCount: _birthInt(_birthField(json, 'NUMIA')),
    );
  }
}

class WeaningCandidate {
  const WeaningCandidate({
    required this.animalCode,
    required this.tag,
    required this.birthDate,
    required this.lot,
    required this.daysOld,
    required this.weaned,
  });

  final int animalCode;
  final String tag;
  final String birthDate;
  final String lot;
  final int daysOld;
  final bool weaned;

  factory WeaningCandidate.fromJson(Map<String, dynamic> json) =>
      WeaningCandidate(
        animalCode: _birthInt(_birthField(json, 'CODANIMAL')),
        tag: '${_birthField(json, 'BRINCO') ?? ''}'.trim(),
        birthDate: '${_birthField(json, 'DATANASCIMENTO') ?? ''}'.trim(),
        lot: '${_birthField(json, 'LOTE') ?? ''}'.trim(),
        daysOld: _birthInt(_birthField(json, 'DIASNASCIDA')),
        weaned: _birthDouble(_birthField(json, 'PESODESMAME')) > 0,
      );
}

class AnimalBirthRepository {
  AnimalBirthRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<AnimalBirthCandidate>> fetchCandidates({String tag = ''}) async {
    final rows = await _query(animalBirthCandidatesQuery(tag: tag));
    return rows.map(AnimalBirthCandidate.fromJson).toList(growable: false);
  }

  Future<List<WeaningCandidate>> fetchWeaningCandidates({
    String tag = '',
    bool includeWeaned = false,
  }) async => (await _query(
    weaningCandidateQuery(tag: tag, includeWeaned: includeWeaned),
  )).map(WeaningCandidate.fromJson).toList(growable: false);

  Future<List<BirthOption>> fetchSexes() async =>
      (await _query('SELECT CODSEXO, SEXO FROM TB_SEXO ORDER BY SEXO'))
          .map(
            (row) => BirthOption.fromJson(
              row,
              codeColumn: 'CODSEXO',
              nameColumn: 'SEXO',
            ),
          )
          .toList(growable: false);

  Future<List<BirthOption>> fetchLots() async =>
      (await _query('SELECT CODLOTE, LOTE FROM TB_LOTES ORDER BY LOTE'))
          .map(
            (row) => BirthOption.fromJson(
              row,
              codeColumn: 'CODLOTE',
              nameColumn: 'LOTE',
            ),
          )
          .toList(growable: false);

  Future<List<BirthOption>> fetchBreeds() async =>
      (await _query('SELECT CODRACA, RACA FROM TB_RACA ORDER BY RACA'))
          .map(
            (row) => BirthOption.fromJson(
              row,
              codeColumn: 'CODRACA',
              nameColumn: 'RACA',
            ),
          )
          .toList(growable: false);

  Future<List<BirthOption>> fetchBirthTypes() async =>
      (await _query(
            'SELECT CODTIPOPARTO, TIPOPARTO FROM TB_TIPOPARTO ORDER BY TIPOPARTO',
          ))
          .map(
            (row) => BirthOption.fromJson(
              row,
              codeColumn: 'CODTIPOPARTO',
              nameColumn: 'TIPOPARTO',
            ),
          )
          .toList(growable: false);

  Future<void> insertBirth({
    required String date,
    required int motherCode,
    required int sexCode,
    required String calfTag,
    required int calfLotCode,
    required int motherLotCode,
    required int breedCode,
    required double calfWeight,
    required String comment,
    required int birthTypeCode,
  }) => _execute(
    animalBirthInsertSql(
      date: date,
      motherCode: motherCode,
      sexCode: sexCode,
      calfTag: calfTag,
      calfLotCode: calfLotCode,
      motherLotCode: motherLotCode,
      breedCode: breedCode,
      calfWeight: calfWeight,
      comment: comment,
      birthTypeCode: birthTypeCode,
    ),
  );

  Future<void> induceLactation({
    required int animalCode,
    required String date,
    required int destinationLotCode,
    required String comment,
  }) => _execute(
    animalInductionSql(
      animalCode: animalCode,
      date: date,
      destinationLotCode: destinationLotCode,
      comment: comment,
    ),
  );

  Future<void> registerWeaning({
    required int calfCode,
    required String date,
    required double weight,
    required int destinationLotCode,
  }) => _execute(
    animalWeaningSql(
      calfCode: calfCode,
      date: date,
      weight: weight,
      destinationLotCode: destinationLotCode,
    ),
  );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_birthXmlEscape(sql)}</xSql>'
          '<Sufixo>${_birthXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_birthXmlEscape(sql)}</xSql>'
          '<Login>${_birthXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_birthXmlEscape(password)}</Senha>'
          '<Sufixo>${_birthXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String animalBirthCandidatesQuery({String tag = ''}) {
  final tagFilter = tag.trim().isEmpty
      ? ''
      : ' AND UPPER(A.BRINCO) LIKE ${_birthSqlText('%${tag.trim().toUpperCase()}%')}';
  return '''
SELECT * FROM (
  SELECT A.CODANIMAL, A.BRINCO, A.STATUSREPRODUCAO, A.DATANASCIMENTO,
    A.STATUSPRODUCAO, A.ULTIMOPARTO, A.CODLACTACAOATUAL, I.NUMIA,
    CONVERT(VARCHAR(10), I.DATA, 103) AS DATAIA,
    CONVERT(VARCHAR(10), P.PREVISAOPARTO, 103) AS PREVISAOPARTO,
    A.CODLOTE, L.LOTE, A.RACA, A.DOADORA, A.ATIVO, A.ADESCARTAR
  FROM TB_ANIMAIS A
  INNER JOIN TB_LOTES L ON L.CODLOTE = A.CODLOTE
  INNER JOIN TB_PRENHEZES P ON P.CODANIMAL = A.CODANIMAL
    AND P.CODLACTACAO = A.CODLACTACAOATUAL AND P.DATAPARTO IS NULL
  INNER JOIN TB_INSEMINACOES I ON I.ID = P.ID_INSEMINACAO
  WHERE A.STATUSPRODUCAO IN ('PRE-PARTO', 'N/D')
    AND A.CODANIMAL IN (
      SELECT CODANIMAL FROM TB_PREPARTO WHERE DATASAIDA IS NULL
    )$tagFilter
  UNION
  SELECT A.CODANIMAL, A.BRINCO, A.STATUSREPRODUCAO, A.DATANASCIMENTO,
    A.STATUSPRODUCAO, A.ULTIMOPARTO, A.CODLACTACAOATUAL, 0 AS NUMIA,
    CAST('' AS VARCHAR(10)) AS DATAIA,
    CAST('' AS VARCHAR(10)) AS PREVISAOPARTO,
    A.CODLOTE, L.LOTE, A.RACA, A.DOADORA, A.ATIVO, A.ADESCARTAR
  FROM TB_ANIMAIS A
  INNER JOIN TB_LOTES L ON L.CODLOTE = A.CODLOTE
  WHERE A.STATUSREPRODUCAO = 'INDUCAO'$tagFilter
) CANDIDATAS
ORDER BY TRY_CONVERT(DATE, PREVISAOPARTO, 103), TRY_CONVERT(INT, BRINCO), BRINCO''';
}

String animalBirthInsertSql({
  required String date,
  required int motherCode,
  required int sexCode,
  required String calfTag,
  required int calfLotCode,
  required int motherLotCode,
  required int breedCode,
  required double calfWeight,
  required String comment,
  required int birthTypeCode,
}) =>
    'EXEC SP_TB_PARTO_INSERT '
    '@DATA = ${_birthSqlDate(date)}, '
    '@CODANIMAL = $motherCode, '
    '@SEXO = $sexCode, '
    '@BRINCO = ${_birthSqlText(calfTag)}, '
    '@CODLOTECRIA = $calfLotCode, '
    '@CODLOTEMAE = $motherLotCode, '
    '@CODRACA = $breedCode, '
    "@PESOCRIA = '${calfWeight.toStringAsFixed(2)}', "
    '@COMENTARIO = ${_birthSqlText(comment)}, '
    "@CODTIPOPARTO = '$birthTypeCode';";

String animalInductionSql({
  required int animalCode,
  required String date,
  required int destinationLotCode,
  required String comment,
}) =>
    'EXEC SP_TB_INDUCAO_INSERT @CODANIMAL = $animalCode, '
    '@DATA = ${_birthSqlDate(date)}, '
    '@CODLOTEDESTINO = $destinationLotCode, '
    '@COMENTARIO = ${_birthSqlText(comment.toUpperCase())};';

String weaningCandidateQuery({String tag = '', bool includeWeaned = false}) {
  final filters = <String>[];
  if (tag.trim().isNotEmpty) {
    filters.add("A.BRINCO = ${_birthSqlText(tag.trim().toUpperCase())}");
  }
  if (!includeWeaned) filters.add('ISNULL(P.PESODESMAME, 0) = 0');
  return '''
SELECT A.CODANIMAL, A.BRINCO, A.DATANASCIMENTO, L.LOTE, P.PESODESMAME,
  DATEDIFF(day,
    COALESCE(TRY_CONVERT(date, A.DATANASCIMENTO, 103), TRY_CONVERT(date, A.DATANASCIMENTO, 23)),
    GETDATE()) AS DIASNASCIDA
FROM TB_ANIMAIS A
INNER JOIN TB_PARTOS P ON P.CODANIMAL_NOVO = A.CODANIMAL
INNER JOIN TB_LOTES L ON L.CODLOTE = A.CODLOTE
${filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}'}
ORDER BY A.CODANIMAL''';
}

String animalWeaningSql({
  required int calfCode,
  required String date,
  required double weight,
  required int destinationLotCode,
}) =>
    'EXEC SP_TB_PARTO_DESMAME @DATA = ${_birthSqlDate(date)}, '
    '@CODANIMAL = $calfCode, @CODLOTEDESTINO = $destinationLotCode, '
    "@PESODESMAME = '${weight.toStringAsFixed(2)}';";

String _birthSqlDate(String value) {
  final trimmed = value.trim();
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = br == null
      ? trimmed
      : '${br.group(3)}-${br.group(2)}-${br.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data do parto inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw FormatException('Data do parto inválida: $value');
  }
  return "'$normalized'";
}

String _birthSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

dynamic _birthField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _birthInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _birthDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _birthXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
