import 'dart:convert';

import 'soap_client.dart';

class GeneralSupplyInventoryDate {
  const GeneralSupplyInventoryDate({required this.id, required this.date});

  final int id;
  final String date;

  factory GeneralSupplyInventoryDate.fromJson(Map<String, dynamic> json) =>
      GeneralSupplyInventoryDate(
        id: _generalInt(_generalField(json, 'ID')),
        date: '${_generalField(json, 'DATA') ?? ''}'.trim(),
      );
}

class GeneralSupplyInventoryItem {
  const GeneralSupplyInventoryItem({
    required this.id,
    required this.date,
    required this.itemCode,
    required this.description,
    required this.description2,
    required this.description3,
    required this.application,
    required this.type,
    required this.minimumStock,
    required this.stock,
    required this.purchaseQuantity,
    required this.lastPurchasePrice,
    required this.confirmed,
  });

  final int id;
  final String date;
  final int itemCode;
  final String description;
  final String description2;
  final String description3;
  final String application;
  final String type;
  final double minimumStock;
  final double stock;
  final double purchaseQuantity;
  final double lastPurchasePrice;
  final bool confirmed;

  factory GeneralSupplyInventoryItem.fromJson(Map<String, dynamic> json) =>
      GeneralSupplyInventoryItem(
        id: _generalInt(_generalField(json, 'ID')),
        date: '${_generalField(json, 'DATA') ?? ''}'.trim(),
        itemCode: _generalInt(_generalField(json, 'CODITEM')),
        description: '${_generalField(json, 'DESCRICAO') ?? ''}'.trim(),
        description2: '${_generalField(json, 'DESCRICAO2') ?? ''}'.trim(),
        description3: '${_generalField(json, 'DESCRICAO3') ?? ''}'.trim(),
        application: '${_generalField(json, 'APLICACAO') ?? ''}'.trim(),
        type: '${_generalField(json, 'TIPO') ?? ''}'.trim(),
        minimumStock: _generalDouble(_generalField(json, 'ESTOQUEMINIMO')),
        stock: _generalDouble(_generalField(json, 'ESTOQUE')),
        purchaseQuantity: _generalDouble(_generalField(json, 'QTDCOMPRA')),
        lastPurchasePrice: _generalDouble(_generalField(json, 'ULTPRCCOMPRA')),
        confirmed: _generalInt(_generalField(json, 'CONFERIDO')) == 1,
      );
}

class GeneralSupplyApplication {
  const GeneralSupplyApplication({required this.code, required this.name});

  final int code;
  final String name;

  factory GeneralSupplyApplication.fromJson(Map<String, dynamic> json) =>
      GeneralSupplyApplication(
        code: _generalInt(_generalField(json, 'CODAPLICACAO')),
        name: '${_generalField(json, 'APLICACAO') ?? ''}'.trim(),
      );
}

class GeneralSupplyInventoryRepository {
  GeneralSupplyInventoryRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<GeneralSupplyInventoryDate>> fetchDates() async {
    final rows = await _query('''
SELECT MAX(ID) AS ID, DATA
FROM TB_INVENTARIO_INSUMOSGERAIS
GROUP BY DATA
ORDER BY MAX(ID) DESC''');
    return rows
        .map(GeneralSupplyInventoryDate.fromJson)
        .toList(growable: false);
  }

  Future<List<GeneralSupplyApplication>> fetchApplications() async {
    final rows = await _query(
      'SELECT CODAPLICACAO, APLICACAO FROM TB_APLICACAO ORDER BY APLICACAO',
    );
    return rows.map(GeneralSupplyApplication.fromJson).toList(growable: false);
  }

  Future<List<GeneralSupplyInventoryItem>> fetchItems({
    required String date,
    required int applicationCode,
  }) async {
    final rows = await _query('''
SELECT I.ID, I.DATA, I.CODITEM, G.DESCRICAO, G.DESCRICAO2, G.DESCRICAO3,
  A.APLICACAO, G.TIPO, G.ESTOQUEMINIMO, I.ESTOQUE, I.QTDCOMPRA,
  I.CONFERIDO, G.ULTPRCCOMPRA
FROM TB_INVENTARIO_INSUMOSGERAIS I
INNER JOIN TB_INSUMOSGERAIS G ON G.CODITEM = I.CODITEM
INNER JOIN TB_APLICACAO A ON A.CODAPLICACAO = G.CODAPLICACAO
WHERE TRY_CONVERT(date, I.DATA, 103) = ${generalInventorySqlDate(date)}
  AND G.CODAPLICACAO = $applicationCode
ORDER BY G.DESCRICAO''');
    return rows
        .map(GeneralSupplyInventoryItem.fromJson)
        .toList(growable: false);
  }

  Future<void> createInventory(int applicationCode) => _execute(
    generalSupplyInventoryCreateSql(applicationCode),
    action: 'ExecSql',
  );

  Future<void> confirmItem({
    required int id,
    required String description,
    required String description2,
    required String description3,
    required String type,
    required double minimumStock,
    required double stock,
  }) => _execute(
    generalSupplyInventoryConfirmSql(
      id: id,
      description: description,
      description2: description2,
      description3: description3,
      type: type,
      minimumStock: minimumStock,
      stock: stock,
    ),
    action: 'ExecSql',
  );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_generalXmlEscape(sql)}</xSql>'
          '<Sufixo>${_generalXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_generalXmlEscape(sql)}</xSql>'
          '<Login>${_generalXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_generalXmlEscape(password)}</Senha>'
          '<Sufixo>${_generalXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String generalInventorySqlDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data do inventário inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data do inventário inválida: $value');
  }
  return "'$normalized'";
}

String generalSupplyInventoryCreateSql(int applicationCode) {
  if (applicationCode <= 0) {
    throw ArgumentError.value(applicationCode, 'applicationCode');
  }
  return 'EXEC SP_TB_INVENTARIO_INSUMOSGERAIS_CRIAR $applicationCode;';
}

String generalSupplyInventoryConfirmSql({
  required int id,
  required String description,
  required String description2,
  required String description3,
  required String type,
  required double minimumStock,
  required double stock,
}) {
  if (id <= 0 ||
      description.trim().isEmpty ||
      type.trim().isEmpty ||
      minimumStock < 0 ||
      stock < 0) {
    throw ArgumentError(
      'Informe descrição, tipo, estoque mínimo e estoque contado.',
    );
  }
  return 'EXEC SP_TB_INVENTARIO_INSUMOSGERAIS_CONFERIR $id, '
      '${_generalSqlText(description)}, ${_generalSqlText(description2)}, '
      '${_generalSqlText(description3)}, ${_generalSqlText(type)}, '
      '${minimumStock.toStringAsFixed(2)}, ${stock.toStringAsFixed(2)};';
}

dynamic _generalField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _generalInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _generalDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _generalSqlText(String value) =>
    "N'${value.trim().replaceAll("'", "''")}'";

String _generalXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
