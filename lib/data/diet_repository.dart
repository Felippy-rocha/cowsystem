import 'dart:convert';

import 'soap_client.dart';

class DietRecord {
  const DietRecord({
    required this.code,
    required this.description,
    required this.date,
    required this.formulator,
    required this.active,
    required this.totalCost,
    required this.total,
    required this.totalDryMatter,
    required this.dryMatterDate,
    required this.realDryMatter,
    required this.quantityPerDay,
    required this.calculatedDryMatter,
  });

  final int code;
  final String description;
  final String date;
  final String formulator;
  final int active;
  final double totalCost;
  final double total;
  final double totalDryMatter;
  final String dryMatterDate;
  final double realDryMatter;
  final int quantityPerDay;
  final double calculatedDryMatter;

  factory DietRecord.fromJson(Map<String, dynamic> json) => DietRecord(
    code: _dietInt(_dietField(json, 'CODDIETA')),
    description: '${_dietField(json, 'DESCRICAO') ?? ''}'.trim(),
    date: '${_dietField(json, 'DATA') ?? ''}'.trim(),
    formulator: '${_dietField(json, 'FORMULADOR') ?? ''}'.trim(),
    active: _dietInt(_dietField(json, 'ATIVO')),
    totalCost: _dietDouble(_dietField(json, 'TOTALCUSTO')),
    total: _dietDouble(_dietField(json, 'TOTAL')),
    totalDryMatter: _dietDouble(_dietField(json, 'TOTALMS')),
    dryMatterDate: '${_dietField(json, 'DATAMS') ?? ''}'.trim(),
    realDryMatter: _dietDouble(_dietField(json, 'MSREAL')),
    quantityPerDay: _dietInt(_dietField(json, 'QTDDIETADIA')),
    calculatedDryMatter: _dietDouble(_dietField(json, 'MSCALCULADA')),
  );
}

class DietIngredient {
  const DietIngredient({
    required this.id,
    required this.dietCode,
    required this.ingredientCode,
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
    required this.order,
    required this.cropYear,
    required this.realDryMatter,
    required this.dryMatterQuantity,
  });

  final int id;
  final int dietCode;
  final int ingredientCode;
  final String name;
  final double quantity;
  final double price;
  final double total;
  final int order;
  final String cropYear;
  final double realDryMatter;
  final double dryMatterQuantity;

  factory DietIngredient.fromJson(Map<String, dynamic> json) => DietIngredient(
    id: _dietInt(_dietField(json, 'ID')),
    dietCode: _dietInt(_dietField(json, 'CODDIETA')),
    ingredientCode: _dietInt(_dietField(json, 'CODINGREDIENTE')),
    name: '${_dietField(json, 'INGREDIENTE') ?? ''}'.trim(),
    quantity: _dietDouble(_dietField(json, 'QTD')),
    price: _dietDouble(_dietField(json, 'PRECO')),
    total: _dietDouble(_dietField(json, 'TOTAL')),
    order: _dietInt(_dietField(json, 'ORDEM')),
    cropYear: '${_dietField(json, 'SAFRA') ?? ''}'.trim(),
    realDryMatter: _dietDouble(_dietField(json, 'MSREAL')),
    dryMatterQuantity: _dietDouble(_dietField(json, 'QTDMS')),
  );
}

class DietChoice {
  const DietChoice({required this.code, required this.name});

  final int code;
  final String name;

  factory DietChoice.fromJson(Map<String, dynamic> json) => DietChoice(
    code: _dietInt(_dietField(json, 'CODIGO')),
    name: '${_dietField(json, 'NOME') ?? ''}'.trim(),
  );
}

class DietRepository {
  DietRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<DietRecord>> fetchDiets() async {
    final rows = await _query('''
SELECT CODDIETA, DESCRICAO, DATA, FORMULADOR, ATIVO, TOTALCUSTO, TOTAL,
  TOTALMS, DATAMS, MSREAL, QTDDIETADIA, MSCALCULADA
FROM TB_DIETA ORDER BY DESCRICAO''');
    return rows.map(DietRecord.fromJson).toList(growable: false);
  }

  Future<List<DietIngredient>> fetchIngredients(int dietCode) async {
    final rows = await _query('''
SELECT D.ID, D.CODDIETA, D.CODINGREDIENTE, D.INGREDIENTE, D.QTD, D.PRECO,
  D.TOTAL, D.ORDEM, S.SAFRA, D.MSREAL, D.QTDMS
FROM TB_DIETA_INGREDIENTES D
LEFT JOIN TB_SAFRA S ON S.CODSAFRA = D.CODSAFRA
WHERE D.CODDIETA = ${_dietPositive(dietCode)}
ORDER BY D.ORDEM''');
    return rows.map(DietIngredient.fromJson).toList(growable: false);
  }

  Future<List<DietChoice>> fetchSafra() async {
    final rows = await _query(
      'SELECT CODSAFRA AS CODIGO, SAFRA AS NOME FROM TB_SAFRA ORDER BY SAFRA DESC',
    );
    return rows.map(DietChoice.fromJson).toList(growable: false);
  }

  Future<int?> findDietCode(String description) async {
    final rows = await _query(
      'SELECT CODDIETA FROM TB_DIETA WHERE DESCRICAO = ${_dietSqlText(description)}',
    );
    return rows.isEmpty ? null : _dietInt(_dietField(rows.first, 'CODDIETA'));
  }

  Future<void> saveDiet({
    int code = -1,
    required String description,
    required String date,
    required String formulator,
    required int active,
    required String dryMatterDate,
    required double realDryMatter,
    required int quantityPerDay,
  }) => _execute(
    dietSaveSql(
      code: code,
      description: description,
      date: date,
      formulator: formulator,
      active: active,
      dryMatterDate: dryMatterDate,
      realDryMatter: realDryMatter,
      quantityPerDay: quantityPerDay,
    ),
  );

  Future<void> saveIngredient({
    int id = -1,
    required int dietCode,
    required int ingredientCode,
    required double quantity,
    required double price,
    required int order,
    required String cropYear,
    required double realDryMatter,
    required double dryMatterQuantity,
  }) => _execute(
    dietIngredientSaveSql(
      id: id,
      dietCode: dietCode,
      ingredientCode: ingredientCode,
      quantity: quantity,
      price: price,
      order: order,
      cropYear: cropYear,
      realDryMatter: realDryMatter,
      dryMatterQuantity: dryMatterQuantity,
    ),
  );

  Future<void> deleteIngredient(int id) => _execute(
    'DELETE FROM TB_DIETA_INGREDIENTES WHERE ID = ${_dietPositive(id)};',
  );

  Future<void> deleteDiet(int code) =>
      _execute('EXEC SP_TB_DIETA_DELETE ${_dietPositive(code)};');

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_dietXmlEscape(sql)}</xSql>'
          '<Sufixo>${_dietXmlEscape(soapClient.suffix)}</Sufixo>'
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
          '<xSql>${_dietXmlEscape(sql)}</xSql>'
          '<Login>${_dietXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_dietXmlEscape(password)}</Senha>'
          '<Sufixo>${_dietXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String dietSaveSql({
  int code = -1,
  required String description,
  required String date,
  required String formulator,
  required int active,
  required String dryMatterDate,
  required double realDryMatter,
  required int quantityPerDay,
}) {
  if (description.trim().isEmpty ||
      formulator.trim().isEmpty ||
      quantityPerDay <= 0 ||
      realDryMatter < 0) {
    throw ArgumentError(
      'Informe descrição, formulador e quantidade diária válidas.',
    );
  }
  return 'EXEC SP_TB_DIETA_INSERT $code, ${_dietSqlText(description.toUpperCase())}, '
      '${dietSqlDate(date)}, ${_dietSqlText(formulator.toUpperCase())}, $active, '
      '${dietSqlDate(dryMatterDate)}, ${_dietDoubleSql(realDryMatter)}, $quantityPerDay;';
}

String dietIngredientSaveSql({
  int id = -1,
  required int dietCode,
  required int ingredientCode,
  required double quantity,
  required double price,
  required int order,
  required String cropYear,
  required double realDryMatter,
  required double dryMatterQuantity,
}) {
  if (dietCode <= 0 ||
      ingredientCode <= 0 ||
      quantity <= 0 ||
      price < 0 ||
      order <= 0 ||
      realDryMatter < 0) {
    throw ArgumentError(
      'Informe ingrediente, quantidade, ordem e valores válidos.',
    );
  }
  final safeCrop = cropYear.trim().isEmpty
      ? 'NULL'
      : _dietSqlText(cropYear.trim());
  return 'EXEC SP_TB_DIETA_INGREDIENTES_INSERT $id, $dietCode, $ingredientCode, '
      '${_dietDoubleSql(quantity)}, ${_dietDoubleSql(price)}, $order, $safeCrop, '
      '${_dietDoubleSql(realDryMatter)}, ${_dietDoubleSql(dryMatterQuantity)};';
}

String dietSqlDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = brazilian == null
      ? trimmed
      : '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data da dieta inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Data da dieta inválida: $value');
  }
  return "'$normalized'";
}

String _dietDoubleSql(double value) => "'${value.toStringAsFixed(2)}'";

int _dietPositive(int value) {
  if (value <= 0) throw ArgumentError.value(value, 'id');
  return value;
}

dynamic _dietField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

int _dietInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double _dietDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _dietSqlText(String value) => "N'${value.trim().replaceAll("'", "''")}'";

String _dietXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
