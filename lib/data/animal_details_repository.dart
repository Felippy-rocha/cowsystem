import 'dart:convert';

import 'animal_record.dart';
import 'soap_client.dart';

class AnimalMilkSummary {
  const AnimalMilkSummary({
    required this.totalMilk,
    required this.averageMilk,
    required this.daughterCount,
  });

  final double totalMilk;
  final double averageMilk;
  final int daughterCount;
}

class AnimalClosedLactation {
  const AnimalClosedLactation({
    required this.code,
    required this.daysInMilk,
    required this.total305,
    required this.average305,
    required this.totalMilk,
  });

  final String code;
  final int daysInMilk;
  final double total305;
  final double average305;
  final double totalMilk;
}

class AnimalDetailsRepository {
  AnimalDetailsRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<AnimalMilkSummary> fetchMilkSummary(AnimalRecord animal) async {
    final lactation = animal.lactationCode.trim().isEmpty
        ? '0000000000'
        : animal.lactationCode.trim();
    final milkQuery =
        "SELECT ROUND(ISNULL(SUM(TOTAL_LEITE), 0), 1) AS TOTALLEITE, "
        "ROUND(ISNULL(AVG(TOTAL_LEITE), 0), 1) AS MEDIALEITE "
        "FROM dbo.RESUMO_LEITE_ANIMAL(${animal.animalCode}, N'${_sqlEscape(lactation)}')";
    final results = await Future.wait([
      _query(milkQuery),
      _query(
        'SELECT COUNT(*) AS FILHAS FROM TB_ANIMAIS '
        'WHERE ATIVO = 1 AND CODMAE = ${animal.animalCode}',
      ),
    ]);
    final milk = results[0].isEmpty
        ? const <String, dynamic>{}
        : results[0].first;
    final daughters = results[1].isEmpty
        ? const <String, dynamic>{}
        : results[1].first;
    return AnimalMilkSummary(
      totalMilk: _number(_field(milk, 'TOTALLEITE')),
      averageMilk: _number(_field(milk, 'MEDIALEITE')),
      daughterCount: _integer(_field(daughters, 'FILHAS')),
    );
  }

  Future<List<AnimalClosedLactation>> fetchClosedLactations(
    int animalCode,
  ) async {
    final rows = await _query(
      'SELECT CODLACTACAO, DEL, ISNULL(TOTAL305, 0) AS TOTAL305, '
      'ISNULL(TOTAL305, 0) / 305.0 AS MEDIA305, '
      'ISNULL(TOTALGERAL, 0) AS TOTALGERAL '
      'FROM TB_SECAGEM WHERE CODANIMAL = $animalCode ORDER BY ID',
    );
    return rows
        .map(
          (row) => AnimalClosedLactation(
            code: '${_field(row, 'CODLACTACAO') ?? ''}'.trim(),
            daysInMilk: _integer(_field(row, 'DEL')),
            total305: _number(_field(row, 'TOTAL305')),
            average305: _number(_field(row, 'MEDIA305')),
            totalMilk: _number(_field(row, 'TOTALGERAL')),
          ),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_xmlEscape(sql)}</xSql>'
          '<Sufixo>${_xmlEscape(soapClient.suffix)}</Sufixo>'
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
        return decoded.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );
      }
      if (decoded is Map<String, dynamic>) return [decoded];
    } on FormatException {
      throw SoapException(value.isEmpty ? 'Resposta vazia do Azure.' : value);
    }
    if (value.isEmpty) return const [];
    throw SoapException(value);
  }

  dynamic _field(Map<String, dynamic> row, String name) {
    for (final entry in row.entries) {
      if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
    }
    return null;
  }

  double _number(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

  int _integer(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

  String _sqlEscape(String value) => value.replaceAll("'", "''");

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
