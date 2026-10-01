import 'dart:convert';

import 'permission_repository.dart';
import 'soap_client.dart';

class AbortionOption {
  const AbortionOption({required this.code, required this.name});

  final int code;
  final String name;

  factory AbortionOption.fromJson(
    Map<String, dynamic> json, {
    required String codeColumn,
    required String nameColumn,
  }) => AbortionOption(
    code: _abortionInt(_abortionField(json, codeColumn)),
    name: '${_abortionField(json, nameColumn) ?? ''}'.trim(),
  );
}

class AbortionAnimal {
  const AbortionAnimal({
    required this.code,
    required this.tag,
    required this.lactationCode,
    required this.inseminationId,
    required this.pregnancyId,
  });

  final int code;
  final String tag;
  final String lactationCode;
  final int inseminationId;
  final int pregnancyId;
}

class AnimalAbortionRepository {
  AnimalAbortionRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<Map<String, bool>> fetchPermissions(int profileCode) async {
    if (profileCode <= 0) return const {};
    final permissions = PermissionRepository(soapClient: soapClient);
    final results = await Future.wait([
      permissions.fetchPermissionCatalog(),
      permissions.fetchProfilePermissions(profileCode),
    ]);
    final catalog = results[0] as List<PermissionDefinitionRecord>;
    final access = results[1] as Map<int, bool>;
    return {
      for (final permission in catalog.where(
        (item) => item.routine.toUpperCase() == 'ABORTOS',
      ))
        permission.action: access[permission.code] == true,
    };
  }

  Future<AbortionAnimal?> findAnimal(String tag) async {
    final rows = await _query('''
SELECT TOP 1 A.CODANIMAL, A.BRINCO, A.CODLACTACAOATUAL,
  ISNULL(P.ID_INSEMINACAO, 0) AS ID_INSEMINACAO,
  ISNULL(P.ID, 0) AS ID_PRENHEZ
FROM TB_ANIMAIS A
LEFT JOIN TB_PRENHEZES P ON P.CODANIMAL = A.CODANIMAL
  AND P.CODLACTACAO = A.CODLACTACAOATUAL AND P.DATAPARTO IS NULL
WHERE A.BRINCO = ${_abortionSqlText(tag.trim())}
ORDER BY P.ID DESC''');
    if (rows.isEmpty) return null;
    final row = rows.first;
    return AbortionAnimal(
      code: _abortionInt(_abortionField(row, 'CODANIMAL')),
      tag: '${_abortionField(row, 'BRINCO') ?? ''}'.trim(),
      lactationCode: '${_abortionField(row, 'CODLACTACAOATUAL') ?? ''}'.trim(),
      inseminationId: _abortionInt(_abortionField(row, 'ID_INSEMINACAO')),
      pregnancyId: _abortionInt(_abortionField(row, 'ID_PRENHEZ')),
    );
  }

  Future<List<AbortionOption>> fetchLots() async =>
      (await _query('SELECT CODLOTE, LOTE FROM TB_LOTES ORDER BY LOTE'))
          .map(
            (row) => AbortionOption.fromJson(
              row,
              codeColumn: 'CODLOTE',
              nameColumn: 'LOTE',
            ),
          )
          .toList(growable: false);

  Future<List<AbortionOption>> fetchYesNo() async =>
      (await _query('SELECT CODIGO, DESCRICAO FROM TB_SIMNAO ORDER BY CODIGO'))
          .map(
            (row) => AbortionOption.fromJson(
              row,
              codeColumn: 'CODIGO',
              nameColumn: 'DESCRICAO',
            ),
          )
          .toList(growable: false);

  Future<List<AbortionOption>> fetchProductionStatuses() async =>
      (await _query(
            'SELECT CODSTATUSPRODUCAO, STATUSPRODUCAO FROM TB_STATUSPRODUCAO '
            'ORDER BY STATUSPRODUCAO',
          ))
          .map(
            (row) => AbortionOption.fromJson(
              row,
              codeColumn: 'CODSTATUSPRODUCAO',
              nameColumn: 'STATUSPRODUCAO',
            ),
          )
          .toList(growable: false);

  Future<List<AbortionOption>> fetchReproductiveStatuses() async =>
      (await _query(
            'SELECT CODSTATUSREPRODUCAO, STATUSREPRODUCAO '
            'FROM TB_STATUSREPRODUCAO ORDER BY STATUSREPRODUCAO',
          ))
          .map(
            (row) => AbortionOption.fromJson(
              row,
              codeColumn: 'CODSTATUSREPRODUCAO',
              nameColumn: 'STATUSREPRODUCAO',
            ),
          )
          .toList(growable: false);

  Future<void> registerAbortion({
    required String date,
    required int animalCode,
    required int withLactation,
    required String comment,
    required int destinationLot,
    required int newLactation,
  }) => _execute(
    abortionRegisterSql(
      date: date,
      animalCode: animalCode,
      withLactation: withLactation,
      comment: comment,
      destinationLot: destinationLot,
      newLactation: newLactation,
    ),
  );

  Future<void> reverseAbortion({
    required String date,
    required int animalCode,
    required String productionStatus,
    required String reproductiveStatus,
    required int keepPregnancy,
    required int destinationLot,
    required String comment,
  }) => _execute(
    abortionReverseSql(
      date: date,
      animalCode: animalCode,
      productionStatus: productionStatus,
      reproductiveStatus: reproductiveStatus,
      keepPregnancy: keepPregnancy,
      destinationLot: destinationLot,
      comment: comment,
    ),
  );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_abortionXmlEscape(sql)}</xSql>'
          '<Sufixo>${_abortionXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_abortionXmlEscape(sql)}</xSql>'
          '<Login>${_abortionXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_abortionXmlEscape(password)}</Senha>'
          '<Sufixo>${_abortionXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String abortionRegisterSql({
  required String date,
  required int animalCode,
  required int withLactation,
  required String comment,
  required int destinationLot,
  required int newLactation,
}) =>
    'EXEC SP_TB_ABORTO_INSERT ${_abortionSqlDate(date)}, $animalCode, '
    '$withLactation, ${_abortionSqlText(comment)}, '
    '$destinationLot, $newLactation;';

String abortionReverseSql({
  required String date,
  required int animalCode,
  required String productionStatus,
  required String reproductiveStatus,
  required int keepPregnancy,
  required int destinationLot,
  required String comment,
}) =>
    'EXEC SP_TB_ABORTO_ESTORNO ${_abortionSqlDate(date)}, $animalCode, '
    '${_abortionSqlText(productionStatus)}, '
    '${_abortionSqlText(reproductiveStatus)}, $keepPregnancy, '
    '$destinationLot, ${_abortionSqlText(comment)};';

String _abortionSqlDate(String value) {
  final trimmed = value.trim();
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = br == null
      ? trimmed
      : '${br.group(3)}-${br.group(2)}-${br.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data de aborto inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw FormatException('Data de aborto inválida: $value');
  }
  return "'$normalized'";
}

String _abortionSqlText(String value) => "N'${value.replaceAll("'", "''")}'";

dynamic _abortionField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _abortionInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

String _abortionXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
