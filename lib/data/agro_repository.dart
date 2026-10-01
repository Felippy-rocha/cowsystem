import 'dart:convert';

import 'soap_client.dart';

class AgroField {
  const AgroField(
    this.key,
    this.label, {
    this.numeric = false,
    this.date = false,
    this.currency = false,
    this.percent = false,
  });

  final String key;
  final String label;
  final bool numeric;
  final bool date;
  final bool currency;
  final bool percent;
}

class AgroEntityConfig {
  const AgroEntityConfig({
    required this.title,
    required this.table,
    required this.idColumn,
    required this.query,
    required this.fields,
    required this.saveSql,
    required this.deleteSql,
  });

  final String title;
  final String table;
  final String idColumn;
  final String query;
  final List<AgroField> fields;
  final String Function(int id, Map<String, String> values) saveSql;
  final String Function(int id) deleteSql;
}

class AgroRepository {
  AgroRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<Map<String, dynamic>>> fetch(AgroEntityConfig config) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_xmlEscape(config.query)}</xSql>'
          '<Sufixo>${_xmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    return _parseRows(response);
  }

  Future<void> save(
    AgroEntityConfig config,
    int id,
    Map<String, String> values,
  ) async {
    await _exec(config.saveSql(id, values));
  }

  Future<void> delete(AgroEntityConfig config, int id) async {
    await _exec(config.deleteSql(id));
  }

  Future<void> _exec(String sql) async {
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

  List<Map<String, dynamic>> _parseRows(String response) {
    final value = response.trim();
    if (value.startsWith('#ic#')) {
      throw SoapException(
        value.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is List)
        return decoded.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );
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

String sqlText(String value) => "N'${value.replaceAll("'", "''")}'";
String sqlNumber(String value) {
  final raw = value.trim();
  final text = raw.contains(',')
      ? raw.replaceAll('.', '').replaceAll(',', '.')
      : raw;
  return text.isEmpty ? '0' : text;
}

String sqlDate(String value) {
  final text = value.trim();
  if (text.isEmpty) return 'NULL';
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
  if (match != null) {
    return "'${match.group(3)}-${match.group(2)}-${match.group(1)}'";
  }
  return "'${text.replaceAll("'", "''")}'";
}

String displayDate(Object? value) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty || text == 'null') return '';
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (iso != null) return '${iso.group(3)}/${iso.group(2)}/${iso.group(1)}';
  return text;
}
