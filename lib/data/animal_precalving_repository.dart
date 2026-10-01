import 'dart:convert';

import 'animal_birth_repository.dart' show BirthOption;
import 'soap_client.dart';

class AnimalPrecalvingCandidate {
  const AnimalPrecalvingCandidate({
    required this.animalCode,
    required this.tag,
    required this.reproductiveStatus,
    required this.productionStatus,
    required this.lastCalving,
    required this.lastInsemination,
    required this.inseminationCount,
    required this.predictedDate,
    required this.lot,
  });

  final int animalCode;
  final String tag;
  final String reproductiveStatus;
  final String productionStatus;
  final String lastCalving;
  final String lastInsemination;
  final int inseminationCount;
  final String predictedDate;
  final String lot;

  factory AnimalPrecalvingCandidate.fromJson(Map<String, dynamic> json) =>
      AnimalPrecalvingCandidate(
        animalCode: _precalvingInt(_precalvingField(json, 'CODANIMAL')),
        tag: '${_precalvingField(json, 'BRINCO') ?? ''}'.trim(),
        reproductiveStatus:
            '${_precalvingField(json, 'STATUSREPRODUCAO') ?? ''}'.trim(),
        productionStatus: '${_precalvingField(json, 'STATUSPRODUCAO') ?? ''}'
            .trim(),
        lastCalving: '${_precalvingField(json, 'ULTIMOPARTO') ?? ''}'.trim(),
        lastInsemination: '${_precalvingField(json, 'DATAIA') ?? ''}'.trim(),
        inseminationCount: _precalvingInt(_precalvingField(json, 'NUMIA')),
        predictedDate: '${_precalvingField(json, 'PREVISAOPREPARTO') ?? ''}'
            .trim(),
        lot: '${_precalvingField(json, 'LOTE') ?? ''}'.trim(),
      );
}

class AnimalPrecalvingRepository {
  AnimalPrecalvingRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<AnimalPrecalvingCandidate>> fetchCandidates({
    String tag = '',
  }) async =>
      (await _query(animalPrecalvingQuery(tag: tag)))
          .map(AnimalPrecalvingCandidate.fromJson)
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

  Future<void> addToPrecalving({
    required int animalCode,
    required String date,
    required int destinationLotCode,
    required String comment,
  }) => _execute(
    animalPrecalvingInsertSql(
      animalCode: animalCode,
      date: date,
      destinationLotCode: destinationLotCode,
      comment: comment,
    ),
  );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_precalvingXmlEscape(sql)}</xSql>'
          '<Sufixo>${_precalvingXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_precalvingXmlEscape(sql)}</xSql>'
          '<Login>${_precalvingXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_precalvingXmlEscape(password)}</Senha>'
          '<Sufixo>${_precalvingXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String animalPrecalvingQuery({String tag = ''}) {
  final tagFilter = tag.trim().isEmpty
      ? ''
      : ' AND UPPER(A.BRINCO) LIKE ${_precalvingSqlText('%${tag.trim().toUpperCase()}%')}';
  return '''
SELECT A.CODANIMAL, A.BRINCO, A.STATUSREPRODUCAO, A.DATANASCIMENTO,
  A.STATUSPRODUCAO, A.ULTIMOPARTO, A.CODLACTACAOATUAL,
  I.NUMIA, CONVERT(VARCHAR(10), I.DATA, 103) AS DATAIA,
  CONVERT(VARCHAR(10), DATEADD(day, ISNULL(L.DIAS_PREPARTO, 0),
    TRY_CONVERT(date, I.DATA, 103)), 103) AS PREVISAOPREPARTO,
  L.LOTE
FROM TB_ANIMAIS A
INNER JOIN TB_LOTES L ON L.CODLOTE = A.CODLOTE
INNER JOIN TB_PRENHEZES P ON P.CODANIMAL = A.CODANIMAL
  AND P.CODLACTACAO = A.CODLACTACAOATUAL AND P.DATAPARTO IS NULL
INNER JOIN TB_INSEMINACOES I ON I.ID = P.ID_INSEMINACAO
WHERE A.STATUSPRODUCAO IN ('SECA', 'N/D')
  AND A.CODANIMAL NOT IN (
    SELECT CODANIMAL FROM TB_PREPARTO WHERE DATASAIDA IS NULL
  )$tagFilter
ORDER BY TRY_CONVERT(date, PREVISAOPREPARTO, 103), A.BRINCO''';
}

String animalPrecalvingInsertSql({
  required int animalCode,
  required String date,
  required int destinationLotCode,
  required String comment,
}) =>
    'EXEC SP_TB_ANIMAIS_PREPARTO_INSERT $animalCode, '
    '${_precalvingSqlDate(date)}, $destinationLotCode, '
    '${_precalvingSqlText(comment.toUpperCase())};';

String _precalvingSqlDate(String value) {
  final trimmed = value.trim();
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = br == null
      ? trimmed
      : '${br.group(3)}-${br.group(2)}-${br.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data de pré-parto inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw FormatException('Data de pré-parto inválida: $value');
  }
  return "'$normalized'";
}

String _precalvingSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

dynamic _precalvingField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _precalvingInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

String _precalvingXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
