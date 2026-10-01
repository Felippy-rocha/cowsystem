import 'dart:convert';

import 'animal_record.dart';
import 'soap_client.dart';

class AnimalCarencyRecord {
  const AnimalCarencyRecord({
    required this.animal,
    required this.type,
    required this.exitDate,
    required this.totalTreatment,
    required this.treatmentUdder,
    required this.treatmentRight,
    required this.discardUdder,
    required this.discardRight,
  });

  final AnimalRecord animal;
  final String type;
  final String exitDate;
  final int totalTreatment;
  final int treatmentUdder;
  final int treatmentRight;
  final int discardUdder;
  final int discardRight;

  factory AnimalCarencyRecord.fromJson(Map<String, dynamic> json) {
    final activeCode = _carencyInt(_carencyField(json, 'ATIVO'));
    final discardCode = _carencyInt(_carencyField(json, 'ADESCARTAR'));
    final animal = AnimalRecord(
      animalCode: _carencyInt(_carencyField(json, 'CODANIMAL')),
      tag: '${_carencyField(json, 'BRINCO') ?? ''}'.trim(),
      donor: '0',
      breed: '${_carencyField(json, 'RACA') ?? ''}'.trim(),
      reproductiveStatus: '${_carencyField(json, 'STATUSREPRODUCAO') ?? ''}'
          .trim(),
      productionStatus: '${_carencyField(json, 'STATUSPRODUCAO') ?? ''}'.trim(),
      lot: '${_carencyField(json, 'CODLOTE') ?? ''}'.trim(),
      lotName: '${_carencyField(json, 'LOTE') ?? ''}'.trim(),
      birthDate: '${_carencyField(json, 'DATANASCIMENTO') ?? ''}'.trim(),
      lactationCode: '${_carencyField(json, 'CODLACTACAO') ?? ''}'.trim(),
      lastCalvingDate: '${_carencyField(json, 'ULTIMOPARTO') ?? ''}'.trim(),
      daysInMilk: _carencyInt(_carencyField(json, 'DEL')),
      activeCode: activeCode,
      discardCode: discardCode,
      active: activeCode == 1,
    );
    return AnimalCarencyRecord(
      animal: animal,
      type: '${_carencyField(json, 'TIPO') ?? ''}'.trim(),
      exitDate: '${_carencyField(json, 'DATA_SAIDA') ?? ''}'.trim(),
      totalTreatment: _carencyInt(_carencyField(json, 'TT')),
      treatmentUdder: _carencyInt(_carencyField(json, 'TE')),
      treatmentRight: _carencyInt(_carencyField(json, 'TD')),
      discardUdder: _carencyInt(_carencyField(json, 'DE')),
      discardRight: _carencyInt(_carencyField(json, 'DD')),
    );
  }
}

class AnimalCarencyRepository {
  AnimalCarencyRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<String>> fetchTypes() async {
    final rows = await _query(
      "SELECT DISTINCT TIPO FROM dbo.LISTA_ANIMAIS_CARENCIA() "
      "WHERE ISNULL(TIPO, '') <> '' ORDER BY TIPO",
    );
    return rows
        .map((row) => '${_carencyField(row, 'TIPO') ?? ''}'.trim())
        .where((type) => type.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<AnimalCarencyRecord>> fetchAnimals({
    String tag = '',
    String? type,
    int offset = 0,
    int limit = 200,
  }) async {
    final rows = await _query(
      animalCarencyQuery(tag: tag, type: type, offset: offset, limit: limit),
    );
    return rows.map(AnimalCarencyRecord.fromJson).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_carencyXmlEscape(sql)}</xSql>'
          '<Sufixo>${_carencyXmlEscape(soapClient.suffix)}</Sufixo>'
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
}

String animalCarencyQuery({
  String tag = '',
  String? type,
  int offset = 0,
  int limit = 200,
}) {
  if (offset < 0 || limit < 1 || limit > 500) {
    throw ArgumentError('Paginação de carência inválida.');
  }
  final filters = <String>[];
  if (tag.trim().isNotEmpty) {
    filters.add("BRINCO = ${_carencySqlText(tag.trim())}");
  }
  if (type != null && type.trim().isNotEmpty) {
    filters.add("TIPO = ${_carencySqlText(type.trim())}");
  }
  final where = filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')} ';
  return 'SELECT * FROM dbo.LISTA_ANIMAIS_CARENCIA() $where'
      'ORDER BY TRY_CONVERT(date, DATA_SAIDA, 103), CODANIMAL '
      'OFFSET $offset ROWS FETCH NEXT $limit ROWS ONLY';
}

dynamic _carencyField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _carencyInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

String _carencySqlText(String value) => "N'${value.replaceAll("'", "''")}'";

String _carencyXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
