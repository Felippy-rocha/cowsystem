import 'dart:convert';

import 'animal_record.dart';
import 'soap_client.dart';

class TreatmentOption {
  const TreatmentOption({required this.code, required this.name});

  final int code;
  final String name;

  factory TreatmentOption.fromJson(Map<String, dynamic> json) =>
      TreatmentOption(
        code:
            int.tryParse('${_treatmentField(json, 'CODTRATAMENTO') ?? 0}') ?? 0,
        name: '${_treatmentField(json, 'TRATAMENTO') ?? ''}'.trim(),
      );
}

class AnimalTreatmentRepository {
  AnimalTreatmentRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<TreatmentOption>> fetchTreatments() async => (await _query(
    'SELECT CODTRATAMENTO, TRATAMENTO FROM TB_TRATAMENTOS ORDER BY TRATAMENTO',
  )).map(TreatmentOption.fromJson).toList(growable: false);

  Future<AnimalRecord?> findAnimal(String tag) async {
    final rows = await _query(
      'SELECT * FROM dbo.LISTA_ANIMAIS() '
      'WHERE BRINCO = ${_treatmentSqlText(tag.trim())}',
    );
    return rows.isEmpty ? null : AnimalRecord.fromJson(rows.first);
  }

  Future<void> createApplicationTask({
    required String date,
    required String time,
    required int treatmentCode,
    required int animalCode,
  }) => _execute(
    animalTreatmentTaskSql(
      date: date,
      time: time,
      treatmentCode: treatmentCode,
      animalCode: animalCode,
    ),
  );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_treatmentXmlEscape(sql)}</xSql>'
          '<Sufixo>${_treatmentXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_treatmentXmlEscape(sql)}</xSql>'
          '<Login>${_treatmentXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_treatmentXmlEscape(password)}</Senha>'
          '<Sufixo>${_treatmentXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String animalTreatmentTaskSql({
  required String date,
  required String time,
  required int treatmentCode,
  required int animalCode,
}) {
  final parsedDate = _treatmentDate(date);
  final parsedTime = _treatmentTime(time);
  if (treatmentCode <= 0 || animalCode <= 0) {
    throw ArgumentError('Selecione animal e tratamento.');
  }
  final dateTime = '${parsedDate}T$parsedTime:00';
  return 'EXEC SP_TB_TAREFAS_INSERT_TRATAMENTO '
      "'$dateTime', '$parsedTime', $treatmentCode, $animalCode;";
}

String _treatmentDate(String value) {
  final trimmed = value.trim();
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = br == null
      ? trimmed
      : '${br.group(3)}-${br.group(2)}-${br.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data da tarefa inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw FormatException('Data da tarefa inválida: $value');
  }
  return normalized;
}

String _treatmentTime(String value) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value.trim());
  if (match == null ||
      int.parse(match.group(1)!) > 23 ||
      int.parse(match.group(2)!) > 59) {
    throw FormatException('Horário inválido: $value');
  }
  return value.trim();
}

dynamic _treatmentField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

String _treatmentSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

String _treatmentXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
