import 'dart:convert';

import 'birth_analysis_repository.dart' show birthSqlDate;
import 'soap_client.dart';

class GeneticPlanRecord {
  const GeneticPlanRecord({
    required this.id,
    required this.date,
    required this.animalCode,
    required this.opr,
    required this.cow,
    required this.option1,
    required this.option2,
    required this.option3,
    required this.sexed,
    required this.conventional,
    required this.mating,
  });

  final int id;
  final String date;
  final int animalCode;
  final int opr;
  final String cow;
  final String option1;
  final String option2;
  final String option3;
  final int sexed;
  final int conventional;
  final String mating;

  factory GeneticPlanRecord.fromJson(Map<String, dynamic> json) =>
      GeneticPlanRecord(
        id: _planInt(_planField(json, 'ID')),
        date: '${_planField(json, 'DATA') ?? ''}'.trim(),
        animalCode: _planInt(_planField(json, 'CODANIMAL')),
        opr: _planInt(_planField(json, 'OPR')),
        cow: '${_planField(json, 'VACA') ?? ''}'.trim(),
        option1: '${_planField(json, 'OPCAO_1') ?? ''}'.trim(),
        option2: '${_planField(json, 'OPCAO_2') ?? ''}'.trim(),
        option3: '${_planField(json, 'OPCAO_3') ?? ''}'.trim(),
        sexed: _planInt(_planField(json, 'SEXADO')),
        conventional: _planInt(_planField(json, 'CONVENCIONAL')),
        mating: '${_planField(json, 'ACASALAMENTO') ?? ''}'.trim(),
      );
}

class GeneticPlanRepository {
  GeneticPlanRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<GeneticPlanRecord>> fetchRecords({
    String? date,
    String? cow,
  }) async {
    final filters = <String>[];
    if (date != null && date.trim().isNotEmpty) {
      filters.add('DATA = ${_planSqlText(date.trim())}');
    }
    if (cow != null && cow.trim().isNotEmpty) {
      filters.add('VACA LIKE ${_planSqlText('%${cow.trim()}%')}');
    }
    final where = filters.isEmpty ? '' : ' WHERE ${filters.join(' AND ')}';
    final rows = await _query(
      'SELECT ID, DATA, CODANIMAL, OPR, VACA, OPCAO_1, OPCAO_2, OPCAO_3, '
      'SEXADO, CONVENCIONAL, HORA_DO_REGISTRO, ACASALAMENTO '
      'FROM TB_PLANOGENETICO$where ORDER BY ID DESC',
    );
    return rows.map(GeneticPlanRecord.fromJson).toList(growable: false);
  }

  Future<void> generate(String date) =>
      _execute(geneticPlanGenerateSql(date), action: 'ExecSP');

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_planXmlEscape(sql)}</xSql>'
          '<Sufixo>${_planXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_planXmlEscape(sql)}</xSql>'
          '<Login>${_planXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_planXmlEscape(password)}</Senha>'
          '<Sufixo>${_planXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String geneticPlanGenerateSql(String date) =>
    'EXEC SP_GERAR_PLANOGENETICO ${birthSqlDate(date)}';

dynamic _planField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _planInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

String _planSqlText(String value) => "'${value.replaceAll("'", "''")}'";

String _planXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
