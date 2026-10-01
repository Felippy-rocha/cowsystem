import 'dart:convert';

import 'soap_client.dart';

class MedicationInventoryDate {
  const MedicationInventoryDate({required this.id, required this.date});

  final int id;
  final String date;

  factory MedicationInventoryDate.fromJson(Map<String, dynamic> json) =>
      MedicationInventoryDate(
        id: _inventoryInt(_inventoryField(json, 'ID')),
        date: '${_inventoryField(json, 'DATA') ?? ''}'.trim(),
      );
}

class MedicationInventoryItem {
  const MedicationInventoryItem({
    required this.id,
    required this.date,
    required this.medicationCode,
    required this.medication,
    required this.option1,
    required this.option2,
    required this.option3,
    required this.minimumStock,
    required this.stock,
    required this.purchaseQuantity,
    required this.confirmed,
  });

  final int id;
  final String date;
  final int medicationCode;
  final String medication;
  final String option1;
  final String option2;
  final String option3;
  final double minimumStock;
  final double stock;
  final double purchaseQuantity;
  final bool confirmed;

  factory MedicationInventoryItem.fromJson(Map<String, dynamic> json) =>
      MedicationInventoryItem(
        id: _inventoryInt(_inventoryField(json, 'ID')),
        date: '${_inventoryField(json, 'DATA') ?? ''}'.trim(),
        medicationCode: _inventoryInt(_inventoryField(json, 'CODMEDICAMENTO')),
        medication: '${_inventoryField(json, 'MEDICAMENTO') ?? ''}'.trim(),
        option1: '${_inventoryField(json, 'OPCAO_1') ?? ''}'.trim(),
        option2: '${_inventoryField(json, 'OPCAO_2') ?? ''}'.trim(),
        option3: '${_inventoryField(json, 'OPCAO_3') ?? ''}'.trim(),
        minimumStock: _inventoryDouble(_inventoryField(json, 'ESTOQUEMINIMO')),
        stock: _inventoryDouble(_inventoryField(json, 'ESTOQUE')),
        purchaseQuantity: _inventoryDouble(_inventoryField(json, 'QTDCOMPRA')),
        confirmed: _inventoryInt(_inventoryField(json, 'CONFERIDO')) == 1,
      );
}

class MedicationInventoryRepository {
  MedicationInventoryRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<MedicationInventoryDate>> fetchDates() async {
    final rows = await _query('''
SELECT MAX(ID) AS ID, DATA
FROM TB_INVENTARIO_MEDICAMENTOS
GROUP BY DATA
ORDER BY MAX(ID) DESC''');
    return rows.map(MedicationInventoryDate.fromJson).toList(growable: false);
  }

  Future<List<MedicationInventoryItem>> fetchItems(String date) async {
    final rows = await _query('''
SELECT I.ID, I.DATA, I.CODMEDICAMENTO, M.MEDICAMENTO,
  M.OPCAO_1, M.OPCAO_2, M.OPCAO_3, M.ESTOQUEMINIMO,
  I.ESTOQUE, I.QTDCOMPRA, I.CONFERIDO
FROM TB_INVENTARIO_MEDICAMENTOS I
INNER JOIN TB_MEDICAMENTOS_NOVO M ON M.CODMEDICAMENTO = I.CODMEDICAMENTO
WHERE TRY_CONVERT(date, I.DATA, 103) = ${inventorySqlDate(date)}
ORDER BY M.MEDICAMENTO''');
    return rows.map(MedicationInventoryItem.fromJson).toList(growable: false);
  }

  Future<void> createInventory() =>
      _execute('EXEC SP_TB_INVENTARIO_MEDICAMENTOS_CRIAR;', action: 'ExecSql');

  Future<void> confirmItem({
    required int id,
    required String medication,
    required String option1,
    required String option2,
    required String option3,
    required double minimumStock,
    required double stock,
  }) => _execute(
    medicationInventoryConfirmSql(
      id: id,
      medication: medication,
      option1: option1,
      option2: option2,
      option3: option3,
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
          '<xSql>${_inventoryXmlEscape(sql)}</xSql>'
          '<Sufixo>${_inventoryXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_inventoryXmlEscape(sql)}</xSql>'
          '<Login>${_inventoryXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_inventoryXmlEscape(password)}</Senha>'
          '<Sufixo>${_inventoryXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String inventorySqlDate(String value) {
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

String medicationInventoryCreateSql() =>
    'EXEC SP_TB_INVENTARIO_MEDICAMENTOS_CRIAR;';

String medicationInventoryConfirmSql({
  required int id,
  required String medication,
  required String option1,
  required String option2,
  required String option3,
  required double minimumStock,
  required double stock,
}) {
  if (id <= 0 || medication.trim().isEmpty || minimumStock < 0 || stock < 0) {
    throw ArgumentError(
      'Informe medicamento, estoque mínimo e estoque contado.',
    );
  }
  return 'EXEC SP_TB_INVENTARIO_MEDICAMENTOS_CONFERIR $id, '
      '${_inventorySqlText(medication)}, ${_inventorySqlText(option1)}, '
      '${_inventorySqlText(option2)}, ${_inventorySqlText(option3)}, '
      '${minimumStock.toStringAsFixed(2)}, ${stock.toStringAsFixed(2)};';
}

dynamic _inventoryField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _inventoryInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _inventoryDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _inventorySqlText(String value) =>
    "N'${value.trim().replaceAll("'", "''")}'";

String _inventoryXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
