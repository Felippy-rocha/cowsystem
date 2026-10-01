import 'dart:convert';

import 'soap_client.dart';

class ReproductiveCycle {
  const ReproductiveCycle({
    required this.code,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.serviceRate,
    required this.conceptionRate,
    required this.pregnancyRate,
    required this.pregnancyLoss,
    required this.withoutDiagnosis,
    required this.pregnantCount,
    required this.totalCount,
    required this.servedCount,
  });

  final int code;
  final String name;
  final String startDate;
  final String endDate;
  final double serviceRate;
  final double conceptionRate;
  final double pregnancyRate;
  final double pregnancyLoss;
  final int withoutDiagnosis;
  final int pregnantCount;
  final int totalCount;
  final int servedCount;

  factory ReproductiveCycle.fromJson(Map<String, dynamic> json) =>
      ReproductiveCycle(
        code: _cycleInt(_cycleField(json, 'CODCICLO')),
        name: '${_cycleField(json, 'CICLO') ?? ''}'.trim(),
        startDate: '${_cycleField(json, 'DATA_INICIO') ?? ''}'.trim(),
        endDate: '${_cycleField(json, 'DATA_FINAL') ?? ''}'.trim(),
        serviceRate: _cycleDouble(_cycleField(json, 'TAXA_SERVICO')),
        conceptionRate: _cycleDouble(_cycleField(json, 'TAXA_CONCEPCAO')),
        pregnancyRate: _cycleDouble(_cycleField(json, 'TAXA_PRENHEZ')),
        pregnancyLoss: _cycleDouble(_cycleField(json, 'PERDA_PRENHEZ')),
        withoutDiagnosis: _cycleInt(_cycleField(json, 'SEMDIAGNOSTICO')),
        pregnantCount: _cycleInt(_cycleField(json, 'TOTAL_PRENHAZ')),
        totalCount: _cycleInt(_cycleField(json, 'TOTAL_GERAL')),
        servedCount: _cycleInt(_cycleField(json, 'TOTAL_SERVIDAS')),
      );
}

class CycleAnimalRecord {
  const CycleAnimalRecord({
    required this.id,
    required this.animalCode,
    required this.tag,
    required this.entryDate,
    required this.serviceCount,
    required this.lactations,
    required this.servedDate,
    required this.inseminationStatus,
    required this.pregnancyLossDate,
  });

  final int id;
  final int animalCode;
  final String tag;
  final String entryDate;
  final int serviceCount;
  final int lactations;
  final String servedDate;
  final String inseminationStatus;
  final String pregnancyLossDate;

  factory CycleAnimalRecord.fromJson(Map<String, dynamic> json) =>
      CycleAnimalRecord(
        id: _cycleInt(_cycleField(json, 'ID')),
        animalCode: _cycleInt(_cycleField(json, 'CODANIMAL')),
        tag: '${_cycleField(json, 'BRINCO') ?? ''}'.trim(),
        entryDate: '${_cycleField(json, 'DATA_ENTRADA') ?? ''}'.trim(),
        serviceCount: _cycleInt(_cycleField(json, 'SERVICOS')),
        lactations: _cycleInt(_cycleField(json, 'NUMLACTACOES')),
        servedDate: '${_cycleField(json, 'DATA_SERVIDA') ?? ''}'.trim(),
        inseminationStatus: '${_cycleField(json, 'STATUS_INS') ?? ''}'.trim(),
        pregnancyLossDate: '${_cycleField(json, 'DATA_PERDA_PRENHEZ') ?? ''}'
            .trim(),
      );
}

class AnimalCyclesRepository {
  AnimalCyclesRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<String>> fetchYears() async {
    final rows = await _query(
      'SELECT DISTINCT LEFT(CICLO, 4) AS ANO FROM TB_CICLOS '
      'WHERE ISNUMERIC(LEFT(CICLO, 4)) = 1 ORDER BY ANO DESC',
    );
    return rows
        .map((row) => '${_cycleField(row, 'ANO') ?? ''}'.trim())
        .where((year) => year.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<ReproductiveCycle>> fetchCycles({String year = ''}) async {
    final filter = year.trim().isEmpty
        ? ''
        : 'WHERE LEFT(CICLO, 4) = ${_cycleSqlText(year.trim())}';
    final rows = await _query('''
SELECT CODCICLO, CICLO, DATA_INICIO, DATA_FINAL, TAXA_SERVICO,
  TAXA_CONCEPCAO, TAXA_PRENHEZ, PERDA_PRENHEZ, SEMDIAGNOSTICO,
  TOTAL_GERAL, TOTAL_PRENHAZ, TOTAL_SERVIDAS
FROM TB_CICLOS
$filter
ORDER BY CICLO DESC''');
    return rows.map(ReproductiveCycle.fromJson).toList(growable: false);
  }

  Future<List<CycleAnimalRecord>> fetchCycleAnimals(int cycleCode) async {
    final rows = await _query('''
SELECT D.ID, D.CODCICLO, D.DATA_ENTRADA, D.CODANIMAL, A.BRINCO,
  D.SERVICOS, D.NUMLACTACOES, D.DATA_SERVIDA, D.ID_INSEMINACAO,
  CASE WHEN D.STATUS_INSEMINACAO = 0 THEN '' ELSE D.STATUS_INSEMINACAO END AS STATUS_INS,
  D.DATA_PERDA_PRENHEZ
FROM TB_CICLOS_DETALHES D
INNER JOIN TB_ANIMAIS A ON A.CODANIMAL = D.CODANIMAL
WHERE D.CODCICLO = ${_cyclePositive(cycleCode)}
ORDER BY TRY_CONVERT(int, A.BRINCO), A.BRINCO''');
    return rows.map(CycleAnimalRecord.fromJson).toList(growable: false);
  }

  Future<void> recalculate(int cycleCode) =>
      _execute(cycleCalculateSql(cycleCode));

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_cycleXmlEscape(sql)}</xSql>'
          '<Sufixo>${_cycleXmlEscape(soapClient.suffix)}</Sufixo>'
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
      action: 'ExecSP',
      password: password,
      body:
          '<xSql>${_cycleXmlEscape(sql)}</xSql>'
          '<Login>${_cycleXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_cycleXmlEscape(password)}</Senha>'
          '<Sufixo>${_cycleXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String cycleCalculateSql(int cycleCode) {
  if (cycleCode <= 0) throw ArgumentError.value(cycleCode, 'cycleCode');
  return 'EXEC SP_TB_CICLOS_CALCULAR $cycleCode;';
}

dynamic _cycleField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _cycleInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _cycleDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

int _cyclePositive(int value) {
  if (value <= 0) throw ArgumentError.value(value, 'cycleCode');
  return value;
}

String _cycleSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

String _cycleXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
