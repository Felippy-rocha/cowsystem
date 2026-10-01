import 'dart:convert';

import 'soap_client.dart';

class ProtocolOption {
  const ProtocolOption({required this.code, required this.name});

  final int code;
  final String name;

  factory ProtocolOption.fromJson(Map<String, dynamic> json) => ProtocolOption(
    code: _protocolInt(_protocolField(json, 'CODPROTOCOLO')),
    name: '${_protocolField(json, 'PROTOCOLO') ?? ''}'.trim(),
  );
}

class ProtocolGroup {
  const ProtocolGroup({
    required this.animalCode,
    required this.tag,
    required this.originCode,
    required this.protocolCode,
    required this.protocolName,
    required this.launchDate,
    required this.activeTaskCount,
    required this.taskTypeCode,
    required this.execution,
  });

  final int animalCode;
  final String tag;
  final int originCode;
  final int protocolCode;
  final String protocolName;
  final String launchDate;
  final int activeTaskCount;
  final int taskTypeCode;
  final String execution;

  factory ProtocolGroup.fromJson(Map<String, dynamic> json) => ProtocolGroup(
    animalCode: _protocolInt(_protocolField(json, 'CODANIMAL')),
    tag: '${_protocolField(json, 'BRINCO') ?? ''}'.trim(),
    originCode: _protocolInt(_protocolField(json, 'CODORIGEM')),
    protocolCode: _protocolInt(_protocolField(json, 'CODPROTOCOLO')),
    protocolName: '${_protocolField(json, 'PROTOCOLO') ?? ''}'.trim(),
    launchDate: '${_protocolField(json, 'DATALANCAMENTO') ?? ''}'.trim(),
    activeTaskCount: _protocolInt(_protocolField(json, 'ATIVO')),
    taskTypeCode: _protocolInt(_protocolField(json, 'CODTIPOTAREFA')),
    execution: '${_protocolField(json, 'EXECUCAO') ?? ''}'.trim(),
  );
}

class ProtocolTask {
  const ProtocolTask({
    required this.code,
    required this.date,
    required this.time,
    required this.description,
    required this.completed,
  });

  final int code;
  final String date;
  final String time;
  final String description;
  final bool completed;

  factory ProtocolTask.fromJson(Map<String, dynamic> json) => ProtocolTask(
    code: _protocolInt(_protocolField(json, 'CODTAREFA')),
    date: '${_protocolField(json, 'DATATAREFA') ?? ''}'.trim(),
    time: '${_protocolField(json, 'HORARIO') ?? ''}'.trim(),
    description: '${_protocolField(json, 'TAREFA') ?? ''}'.trim(),
    completed: _protocolInt(_protocolField(json, 'CONCLUIDO')) == 1,
  );
}

class AnimalProtocolRepository {
  AnimalProtocolRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<ProtocolOption>> fetchProtocols() async {
    final rows = await _query(
      'SELECT CODPROTOCOLO, PROTOCOLO FROM TB_PROTOCOLOS ORDER BY PROTOCOLO',
    );
    return rows.map(ProtocolOption.fromJson).toList(growable: false);
  }

  Future<int?> findAnimalCode(String tag) async {
    final rows = await _query(
      'SELECT CODANIMAL FROM dbo.LISTA_ANIMAIS() '
      'WHERE BRINCO = ${_protocolSqlText(tag.trim())}',
    );
    return rows.isEmpty
        ? null
        : _protocolInt(_protocolField(rows.first, 'CODANIMAL'));
  }

  Future<List<ProtocolGroup>> fetchGroups({
    bool pendingOnly = true,
    int? protocolCode,
    int? animalCode,
  }) async {
    final filters = <String>['T.CODTIPOTAREFA = 2'];
    if (pendingOnly) filters.add('T.CONCLUIDO = 0');
    if (protocolCode != null && protocolCode > 0) {
      filters.add('T.CODPROTOCOLO = $protocolCode');
    }
    if (animalCode != null && animalCode > 0) {
      filters.add('T.CODANIMAL = $animalCode');
    }
    final rows = await _query('''
SELECT DISTINCT A.CODANIMAL, A.BRINCO, T.CODORIGEM, T.CODPROTOCOLO,
  T.DATALANCAMENTO, P.PROTOCOLO, T.CODTIPOTAREFA, T.EXECUCAO,
  (SELECT COUNT(*) FROM TB_TAREFAS X
    WHERE X.CODORIGEM = T.CODORIGEM AND X.CONCLUIDO = 0) AS ATIVO
FROM TB_ANIMAIS A
INNER JOIN TB_TAREFAS T ON T.CODANIMAL = A.CODANIMAL
INNER JOIN TB_PROTOCOLOS P ON P.CODPROTOCOLO = T.CODPROTOCOLO
WHERE ${filters.join(' AND ')}
ORDER BY TRY_CONVERT(int, A.BRINCO), A.BRINCO''');
    return rows.map(ProtocolGroup.fromJson).toList(growable: false);
  }

  Future<List<ProtocolTask>> fetchTasks({
    required int originCode,
    required int animalCode,
  }) async {
    final rows = await _query(
      '''
SELECT CODTAREFA, DATATAREFA, HORARIO, TAREFA, CONCLUIDO
FROM TB_TAREFAS
WHERE CODORIGEM = $originCode AND CODANIMAL = $animalCode
ORDER BY COALESCE(TRY_CONVERT(date, DATATAREFA, 103), TRY_CONVERT(date, DATATAREFA, 23)), CODTAREFA''',
    );
    return rows.map(ProtocolTask.fromJson).toList(growable: false);
  }

  Future<void> createProtocolApplication({
    required String date,
    required String time,
    required int protocolCode,
    required int animalCode,
    required bool completed,
  }) => _execute(
    protocolApplicationSql(
      date: date,
      time: time,
      protocolCode: protocolCode,
      animalCode: animalCode,
      completed: completed,
    ),
  );

  Future<void> completeTask(int id) =>
      _execute(protocolTaskActionSql('CONCLUIR', id));

  Future<void> reopenTask(int id) =>
      _execute(protocolTaskActionSql('DESFAZER_CONCLUIR', id));

  Future<void> deleteTask(int id) =>
      _execute(protocolTaskActionSql('EXCLUIR', id));

  Future<void> deleteProtocol(int originCode) =>
      _execute(protocolDeleteGroupSql(originCode));

  Future<void> editTask({
    required int taskCode,
    required int taskTypeCode,
    required String date,
    required String time,
    required int animalCode,
    required String description,
    required String execution,
  }) => _execute(
    protocolTaskUpdateSql(
      taskCode: taskCode,
      taskTypeCode: taskTypeCode,
      date: date,
      time: time,
      animalCode: animalCode,
      description: description,
      execution: execution,
    ),
  );

  Future<void> addStep({
    required int originCode,
    required int taskTypeCode,
    required String date,
    required String time,
    required int animalCode,
    required String description,
    required String execution,
    required int protocolCode,
  }) => _execute(
    protocolStepInsertSql(
      originCode: originCode,
      taskTypeCode: taskTypeCode,
      date: date,
      time: time,
      animalCode: animalCode,
      description: description,
      execution: execution,
      protocolCode: protocolCode,
    ),
  );

  Future<void> _execute(String sql) async {
    final password = const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD');
    final response = await soapClient.callResult(
      action: 'ExecSP',
      password: password,
      body:
          '<xSql>${_protocolXmlEscape(sql)}</xSql>'
          '<Login>${_protocolXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_protocolXmlEscape(password)}</Senha>'
          '<Sufixo>${_protocolXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_protocolXmlEscape(sql)}</xSql>'
          '<Sufixo>${_protocolXmlEscape(soapClient.suffix)}</Sufixo>'
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

String protocolApplicationSql({
  required String date,
  required String time,
  required int protocolCode,
  required int animalCode,
  required bool completed,
}) {
  final normalizedDate = _protocolDate(date);
  final normalizedTime = _protocolTime(time);
  if (protocolCode <= 0 || animalCode <= 0) {
    throw ArgumentError('Selecione protocolo e animal.');
  }
  return 'EXEC SP_TB_TAREFAS_INSERT_PROTOCOLO '
      "'${_protocolDateDisplay(normalizedDate)} $normalizedTime', "
      "'$normalizedTime', $protocolCode, $animalCode, ${completed ? 1 : 0};";
}

String protocolTaskActionSql(String action, int taskCode) {
  const procedures = {
    'CONCLUIR': 'SP_TB_TAREFAS_CONCLUIR',
    'DESFAZER_CONCLUIR': 'SP_TB_TAREFAS_DESFAZER_CONCLUIR',
    'EXCLUIR': 'SP_TB_TAREFAS_EXCLUIR',
  };
  final procedure = procedures[action];
  if (procedure == null) throw ArgumentError.value(action, 'action');
  if (taskCode <= 0) throw ArgumentError.value(taskCode, 'taskCode');
  return 'EXEC $procedure $taskCode;';
}

String protocolDeleteGroupSql(int originCode) {
  if (originCode <= 0) throw ArgumentError.value(originCode, 'originCode');
  return 'EXEC SP_TB_TAREFAS_DELETE $originCode, 0;';
}

String protocolTaskUpdateSql({
  required int taskCode,
  required int taskTypeCode,
  required String date,
  required String time,
  required int animalCode,
  required String description,
  required String execution,
}) {
  if (taskCode <= 0 ||
      taskTypeCode <= 0 ||
      animalCode <= 0 ||
      description.trim().isEmpty ||
      execution.trim().isEmpty) {
    throw ArgumentError('Informe os dados obrigatórios da tarefa.');
  }
  return 'EXEC SP_TB_TAREFAS_INSERT_UPDATE $taskCode, $taskTypeCode, '
      "'${_protocolDate(date)}', ${_protocolSqlText(_protocolTime(time))}, "
      '$animalCode, ${_protocolSqlText(description.trim())}, '
      '${_protocolSqlText(execution.trim())};';
}

String protocolStepInsertSql({
  required int originCode,
  required int taskTypeCode,
  required String date,
  required String time,
  required int animalCode,
  required String description,
  required String execution,
  required int protocolCode,
}) {
  if (originCode <= 0 ||
      taskTypeCode <= 0 ||
      animalCode <= 0 ||
      protocolCode <= 0 ||
      description.trim().isEmpty ||
      execution.trim().isEmpty) {
    throw ArgumentError('Informe os dados obrigatórios da tarefa.');
  }
  return 'EXEC SP_TB_TAREFAS_INSERT $originCode, $taskTypeCode, '
      "'${_protocolDate(date)}', ${_protocolSqlText(_protocolTime(time))}, "
      '$animalCode, ${_protocolSqlText(description.trim())}, '
      '${_protocolSqlText(execution.trim())}, 0, $protocolCode;';
}

String _protocolDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data da tarefa inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data da tarefa inválida: $value');
  }
  return normalized;
}

String _protocolDateDisplay(String isoDate) {
  final parts = isoDate.split('-');
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String _protocolTime(String value) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value.trim());
  if (match == null ||
      int.parse(match.group(1)!) > 23 ||
      int.parse(match.group(2)!) > 59) {
    throw FormatException('Horário inválido: $value');
  }
  return value.trim();
}

dynamic _protocolField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _protocolInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

String _protocolSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

String _protocolXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
