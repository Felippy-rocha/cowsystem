import 'dart:convert';

import 'soap_client.dart';

class OpenTaskRecord {
  const OpenTaskRecord({
    required this.code,
    required this.tag,
    required this.date,
    required this.taskType,
    required this.protocol,
    required this.task,
  });

  final int code;
  final String tag;
  final String date;
  final String taskType;
  final String protocol;
  final String task;

  factory OpenTaskRecord.fromJson(Map<String, dynamic> json) => OpenTaskRecord(
    code: _openTaskInt(_openTaskField(json, 'CODTAREFA')),
    tag: '${_openTaskField(json, 'BRINCO') ?? ''}'.trim(),
    date: '${_openTaskField(json, 'DATATAREFA') ?? ''}'.trim(),
    taskType: '${_openTaskField(json, 'TIPOTAREFA') ?? ''}'.trim(),
    protocol: '${_openTaskField(json, 'PROTOCOLO') ?? ''}'.trim(),
    task: '${_openTaskField(json, 'TAREFA') ?? ''}'.trim(),
  );
}

class OpenTaskRepository {
  OpenTaskRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<({int code, String name})>> fetchExecutions() async {
    final rows = await _query(
      'SELECT CODIGO, DESCRICAO FROM TB_EXECUCAO ORDER BY DESCRICAO',
    );
    return rows
        .map(
          (row) => (
            code: _openTaskInt(_openTaskField(row, 'CODIGO')),
            name: '${_openTaskField(row, 'DESCRICAO') ?? ''}'.trim(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<OpenTaskRecord>> fetchTasks({
    required String dateStart,
    required String dateEnd,
    required String execution,
  }) async {
    final rows = await _query(
      'SELECT CODTAREFA, BRINCO, DATATAREFA, TIPOTAREFA, PROTOCOLO, TAREFA '
      'FROM DBO.REL_TAREFASEMABERTO(${_openTaskSqlDate(dateStart)}, ${_openTaskSqlDate(dateEnd)}, ${_openTaskSqlText(execution)}) '
      'ORDER BY DATATAREFA',
    );
    return rows.map(OpenTaskRecord.fromJson).toList(growable: false);
  }

  Future<void> generate({
    required String dateStart,
    required String dateEnd,
    required String execution,
  }) => _execute(
    openTasksGenerateSql(
      dateStart: dateStart,
      dateEnd: dateEnd,
      execution: execution,
    ),
    action: 'ExecSql',
  );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_openTaskXmlEscape(sql)}</xSql>'
          '<Sufixo>${_openTaskXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_openTaskXmlEscape(sql)}</xSql>'
          '<Login>${_openTaskXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_openTaskXmlEscape(password)}</Senha>'
          '<Sufixo>${_openTaskXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String openTasksGenerateSql({
  required String dateStart,
  required String dateEnd,
  required String execution,
}) {
  if (execution.trim().isEmpty) {
    throw ArgumentError('Informe a execução do relatório.');
  }
  return 'EXEC SP_TB_TAREFAS_EM_ABERTO ${_openTaskSqlDate(dateStart)}, '
      '${_openTaskSqlDate(dateEnd)}, ${_openTaskSqlText(execution)};';
}

String _openTaskSqlDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data do relatório inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data do relatório inválida: $value');
  }
  return "'$normalized'";
}

dynamic _openTaskField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _openTaskInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

String _openTaskSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

String _openTaskXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
