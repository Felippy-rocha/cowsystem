import 'dart:convert';

import 'soap_client.dart';

class PermissionRepository {
  PermissionRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<PermissionDefinitionRecord>> fetchPermissionCatalog() async {
    const query =
        'SELECT CODPERMISSAO, GRUPO, ROTINA, PERMISSAO '
        'FROM TB_PERMISSOES_NEW ORDER BY GRUPO, ROTINA, CODPERMISSAO';
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_xmlEscape(query)}</xSql>'
          '<Sufixo>${_xmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    return _parseRows(response)
        .map(
          (row) => PermissionDefinitionRecord(
            code: int.tryParse('${_field(row, 'CODPERMISSAO') ?? ''}') ?? 0,
            group: '${_field(row, 'GRUPO') ?? ''}'.trim(),
            routine: '${_field(row, 'ROTINA') ?? ''}'.trim(),
            action: '${_field(row, 'PERMISSAO') ?? ''}'.trim(),
          ),
        )
        .where(
          (permission) =>
              permission.code > 0 &&
              permission.group.isNotEmpty &&
              permission.routine.isNotEmpty &&
              permission.action.isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<void> saveProfile({int code = 0, required String description}) async {
    final value = description.trim().replaceAll("'", "''");
    if (value.isEmpty) {
      throw const SoapException('Informe a descricao do perfil.');
    }
    await _execProcedure(
      'EXEC SP_TB_PERFIL_INSERT_UPDATE @CODPERFIL = $code, '
      "@DESCRICAO = N'$value';",
    );
  }

  Future<void> deleteProfile(int code) async {
    if (code <= 1) {
      throw const SoapException(
        'O perfil Administrador nao pode ser excluido.',
      );
    }
    await _execProcedure('EXEC SP_TB_PERFIL_DELETE @CODPERFIL = $code;');

    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_xmlEscape('SELECT CODPERFIL FROM TB_PERFIL WHERE CODPERFIL = $code')}</xSql>'
          '<Sufixo>${_xmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (_parseRows(response).isNotEmpty) {
      throw const SoapException('O banco nao confirmou a exclusao do perfil.');
    }
  }

  Future<void> _execProcedure(String sql) async {
    const password = String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD');
    await soapClient.callResult(
      action: 'ExecSP',
      password: password,
      body:
          '<xSql>${_xmlEscape(sql)}</xSql>'
          '<Login>${_xmlEscape(soapClient.username)}</Login>'
          '<Senha>${_xmlEscape(password)}</Senha>'
          '<Sufixo>${_xmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
  }

  Future<List<PermissionProfileRecord>> fetchProfiles() async {
    const query =
        'SELECT CODPERFIL, DESCRICAO FROM TB_PERFIL '
        'ORDER BY DESCRICAO';
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_xmlEscape(query)}</xSql>'
          '<Sufixo>${_xmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    return _parseRows(response)
        .map(
          (row) => PermissionProfileRecord(
            code: int.tryParse('${_field(row, 'CODPERFIL') ?? ''}') ?? 0,
            description: '${_field(row, 'DESCRICAO') ?? ''}'.trim(),
          ),
        )
        .where((profile) => profile.code > 0 && profile.description.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<int, bool>> fetchProfilePermissions(int profileCode) async {
    final query =
        'SELECT CODPERMISSAO, PERMITIDO '
        'FROM TB_PERFILPERMISSOES_NEW '
        'WHERE CODPERFIL = $profileCode';
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_xmlEscape(query)}</xSql>'
          '<Sufixo>${_xmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    final permissions = <int, bool>{};
    for (final row in _parseRows(response)) {
      final code = int.tryParse('${_field(row, 'CODPERMISSAO') ?? ''}');
      final rawAllowed = _field(row, 'PERMITIDO');
      final allowed =
          rawAllowed == true ||
          rawAllowed == 1 ||
          '$rawAllowed'.trim() == '1' ||
          '$rawAllowed'.trim().toLowerCase() == 'true';
      if (code != null) permissions[code] = allowed;
    }
    return permissions;
  }

  dynamic _field(Map<String, dynamic> row, String name) {
    for (final entry in row.entries) {
      if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
    }
    return null;
  }

  Future<void> updatePermission({
    required int profileCode,
    required int permissionCode,
    required bool allowed,
  }) async {
    const headerPassword = String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD');
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: headerPassword,
      body:
          '<xSql>${_xmlEscape(_permissionIdQuery(profileCode, permissionCode))}</xSql>'
          '<Sufixo>${_xmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    final rows = _parseRows(response);
    if (rows.isEmpty) {
      throw const SoapException('Permissao nao encontrada para atualizacao.');
    }

    final id = int.tryParse('${_field(rows.first, 'ID') ?? ''}');
    if (id == null || id <= 0) {
      throw const SoapException('ID da permissao invalido.');
    }

    await soapClient.callResult(
      action: 'ExecSP',
      password: headerPassword,
      body:
          '<xSql>${_xmlEscape('EXEC SP_TB_PERFILPERMISSOES_NEW_UPDATE @ID = $id, @PERMITIDO = ${allowed ? 1 : 0};')}</xSql>'
          '<Login>${_xmlEscape(soapClient.username)}</Login>'
          '<Senha>${_xmlEscape(headerPassword)}</Senha>'
          '<Sufixo>${_xmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );

    final verification = await soapClient.callResult(
      action: 'Importar_Json',
      password: headerPassword,
      body:
          '<xSql>${_xmlEscape('''SELECT PERMITIDO
FROM TB_PERFILPERMISSOES_NEW
WHERE ID = $id
AND CODPERFIL = $profileCode
AND CODPERMISSAO = $permissionCode''')}</xSql>'
          '<Sufixo>${_xmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    final verificationRows = _parseRows(verification);
    if (verificationRows.isEmpty) {
      throw const SoapException(
        'Nao foi possivel verificar a permissao gravada.',
      );
    }
    final saved = _field(verificationRows.first, 'PERMITIDO');
    final savedValue =
        saved == true ||
        saved == 1 ||
        '$saved'.trim() == '1' ||
        '$saved'.trim().toLowerCase() == 'true';
    if (savedValue != allowed) {
      throw SoapException(
        'Banco nao confirmou: ID=$id, perfil=$profileCode, '
        'permissao=$permissionCode, solicitado=${allowed ? 1 : 0}, '
        'retornado=$saved',
      );
    }
  }

  String _permissionIdQuery(int profileCode, int permissionCode) {
    return "SELECT TOP 1 PP.ID FROM TB_PERFILPERMISSOES_NEW PP "
        "WHERE PP.CODPERFIL = $profileCode AND PP.CODPERMISSAO = $permissionCode";
  }

  List<Map<String, dynamic>> _parseRows(String response) {
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
      throw SoapException(value);
    }
    throw SoapException(value.isEmpty ? 'Resposta vazia do Azure.' : value);
  }

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

class PermissionProfileRecord {
  const PermissionProfileRecord({
    required this.code,
    required this.description,
  });

  final int code;
  final String description;
}

class PermissionDefinitionRecord {
  const PermissionDefinitionRecord({
    required this.code,
    required this.group,
    required this.routine,
    required this.action,
  });

  final int code;
  final String group;
  final String routine;
  final String action;
}
