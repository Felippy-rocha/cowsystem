import 'dart:convert';

import 'animal_birth_repository.dart' show BirthOption;
import 'soap_client.dart';

class AnimalDryOffCandidate {
  const AnimalDryOffCandidate({
    required this.animalCode,
    required this.tag,
    required this.birthDate,
    required this.lastCalving,
    required this.lastInsemination,
    required this.inseminationCount,
    required this.reproductiveStatus,
    required this.predictedDate,
    required this.lot,
  });

  final int animalCode;
  final String tag;
  final String birthDate;
  final String lastCalving;
  final String lastInsemination;
  final int inseminationCount;
  final String reproductiveStatus;
  final String predictedDate;
  final String lot;

  factory AnimalDryOffCandidate.fromJson(Map<String, dynamic> json) =>
      AnimalDryOffCandidate(
        animalCode: _dryOffInt(_dryOffField(json, 'CODANIMAL')),
        tag: '${_dryOffField(json, 'BRINCO') ?? ''}'.trim(),
        birthDate: '${_dryOffField(json, 'DATANASCIMENTO') ?? ''}'.trim(),
        lastCalving: '${_dryOffField(json, 'ULTIMOPARTO') ?? ''}'.trim(),
        lastInsemination: '${_dryOffField(json, 'DATAIA') ?? ''}'.trim(),
        inseminationCount: _dryOffInt(_dryOffField(json, 'NUMIA')),
        reproductiveStatus: '${_dryOffField(json, 'STATUSREPRODUCAO') ?? ''}'
            .trim(),
        predictedDate: '${_dryOffField(json, 'PREVISAOSECAGEM') ?? ''}'.trim(),
        lot: '${_dryOffField(json, 'LOTE') ?? ''}'.trim(),
      );
}

class AnimalDryOffRepository {
  AnimalDryOffRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<AnimalDryOffCandidate>> fetchCandidates({String tag = ''}) async {
    final rows = await _query(animalDryOffQuery(tag: tag));
    return rows.map(AnimalDryOffCandidate.fromJson).toList(growable: false);
  }

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

  Future<List<BirthOption>> fetchDryOffMedications() async =>
      (await _query(
            'SELECT CODMEDICAMENTO, MEDICAMENTO FROM TB_MEDICAMENTOS_NOVO '
            'WHERE CODTIPOMEDICAMENTO = 22 ORDER BY MEDICAMENTO',
          ))
          .map(
            (row) => BirthOption.fromJson(
              row,
              codeColumn: 'CODMEDICAMENTO',
              nameColumn: 'MEDICAMENTO',
            ),
          )
          .toList(growable: false);

  Future<void> dryOff({
    required int animalCode,
    required String date,
    required int destinationLotCode,
    required String comment,
    required int medicationCode,
  }) => _execute(
    animalDryOffSql(
      animalCode: animalCode,
      date: date,
      destinationLotCode: destinationLotCode,
      comment: comment,
      medicationCode: medicationCode,
    ),
  );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_dryOffXmlEscape(sql)}</xSql>'
          '<Sufixo>${_dryOffXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_dryOffXmlEscape(sql)}</xSql>'
          '<Login>${_dryOffXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_dryOffXmlEscape(password)}</Senha>'
          '<Sufixo>${_dryOffXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String animalDryOffQuery({String tag = ''}) {
  final tagFilter = tag.trim().isEmpty
      ? ''
      : ' AND UPPER(A.BRINCO) LIKE ${_dryOffSqlText('%${tag.trim().toUpperCase()}%')}';
  return '''
SELECT A.CODANIMAL, A.BRINCO, A.STATUSREPRODUCAO, A.DATANASCIMENTO,
  A.STATUSPRODUCAO, A.ULTIMOPARTO, A.CODLACTACAOATUAL,
  I.NUMIA, CONVERT(VARCHAR(10), I.DATA, 103) AS DATAIA,
  CONVERT(VARCHAR(10), DATEADD(day, ISNULL(L.DIAS_SECAGEM, 0),
    TRY_CONVERT(date, I.DATA, 103)), 103) AS PREVISAOSECAGEM,
  L.LOTE
FROM TB_ANIMAIS A
INNER JOIN TB_LOTES L ON L.CODLOTE = A.CODLOTE
LEFT JOIN TB_PRENHEZES P ON P.CODANIMAL = A.CODANIMAL
  AND P.CODLACTACAO = A.CODLACTACAOATUAL
LEFT JOIN TB_INSEMINACOES I ON I.ID = P.ID_INSEMINACAO
WHERE A.STATUSPRODUCAO = 'EM LEITE'$tagFilter
ORDER BY TRY_CONVERT(date, PREVISAOSECAGEM, 103), A.BRINCO''';
}

String animalDryOffSql({
  required int animalCode,
  required String date,
  required int destinationLotCode,
  required String comment,
  required int medicationCode,
}) =>
    'EXEC SP_TB_ANIMAIS_SECAR $animalCode, ${_dryOffSqlDate(date)}, '
    "$destinationLotCode, ${_dryOffSqlText(comment.toUpperCase())}, $medicationCode;";

String _dryOffSqlDate(String value) {
  final trimmed = value.trim();
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = br == null
      ? trimmed
      : '${br.group(3)}-${br.group(2)}-${br.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data de secagem inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw FormatException('Data de secagem inválida: $value');
  }
  return "'$normalized'";
}

String _dryOffSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

dynamic _dryOffField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _dryOffInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

String _dryOffXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
