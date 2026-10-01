import 'dart:convert';

import 'animal_record.dart';
import 'soap_client.dart';

class AnimalRepository {
  AnimalRepository({required this._soapClient});

  final SoapClient _soapClient;
  final List<AnimalRecord> _cache = [];

  List<AnimalRecord> get cachedAnimals => List.unmodifiable(_cache);

  Future<List<AnimalRecord>> fetchAnimals({String where = ''}) async {
    final response = await _soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_escape(_animalsQuery(where))}</xSql>'
          '<Sufixo>${_escape(_soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );

    final animals = _parseJsonRows(response);
    _cache
      ..clear()
      ..addAll(animals);
    return List.unmodifiable(animals);
  }

  Future<void> insertAnimal(AnimalRecord animal) async {
    await _soapClient.callResult(
      action: 'ExecSql',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_escape(_insertSql(animal))}</xSql>'
          '<Login>FVR</Login>'
          '<Senha>${_escape(const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'))}</Senha>'
          '<Sufixo>${_escape(_soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    _cache.add(animal);
  }

  Future<void> changeLots({
    required List<AnimalRecord> animals,
    required int destinationLotCode,
  }) async {
    final sql = animalLotTransferSql(
      animalCodes: animals.map((animal) => animal.animalCode).toList(),
      destinationLotCode: destinationLotCode,
      currentLotCode: animals.length == 1 ? animals.single.lotCode : null,
    );
    await _soapClient.callResult(
      action: 'ExecSql',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_escape(sql)}</xSql>'
          '<Login>FVR</Login>'
          '<Senha>${_escape(const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'))}</Senha>'
          '<Sufixo>${_escape(_soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
  }

  String _animalsQuery(String where) {
    final condition = where.trim().isEmpty ? 'WHERE ATIVO = 1' : where;
    return 'SELECT * FROM dbo.LISTA_ANIMAIS() $condition '
        'ORDER BY TRY_CONVERT(INT, BRINCO), BRINCO';
  }

  List<AnimalRecord> _parseJsonRows(String response) {
    final value = response.trim();
    if (value.startsWith('#ic#')) {
      final message = value.replaceFirst('#ic#', '').replaceFirst('#fc#', '');
      throw SoapException(message);
    }
    if (!value.startsWith('[')) {
      throw SoapException(value.isEmpty ? 'Resposta vazia do Azure.' : value);
    }
    late final dynamic decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      throw SoapException('Azure retornou JSON invalido: $value');
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AnimalRecord.fromJson)
        .toList(growable: false);
  }

  String _insertSql(AnimalRecord animal) {
    final data = animal.toJson();
    return 'EXEC SP_TB_ANIMAIS_INSERT '
        "@BRINCO = '${_sqlEscape(data['BRINCO'] as String)}', "
        "@BRINCOELETRONICO = '${_sqlEscape(data['BRINCOELETRONICO'] as String)}', "
        '@DOADORA = ${data['DOADORA']}, @CODMAE = 0, @CODPAI = 0, '
        '@CODAVOMATERNO = 0, @CODBISAVOMATERNO = 0, @CODLOTE = 0, '
        '@DATANASCIMENTO = NULL, @NUMLACTACOES = 0, @ULTIMOPARTO = NULL, '
        "@STATUSREPRODUCAO = '${_sqlEscape(data['STATUSREPRODUCAO'] as String)}', "
        "@STATUSPRODUCAO = '${_sqlEscape(data['STATUSPRODUCAO'] as String)}', "
        '@ATIVO = 1, @CODRACA = 0, '
        "@ORIGEM = '${_sqlEscape(data['ORIGEM'] as String)}', "
        "@BETACASEINA = '${_sqlEscape(data['BETACASEINA'] as String)}'";
  }

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _sqlEscape(String value) => value.replaceAll("'", "''");
}

String animalLotTransferSql({
  required List<int> animalCodes,
  required int destinationLotCode,
  int? currentLotCode,
}) {
  if (animalCodes.isEmpty || animalCodes.any((code) => code <= 0)) {
    throw ArgumentError('Selecione pelo menos um animal válido.');
  }
  if (destinationLotCode <= 0) {
    throw ArgumentError.value(destinationLotCode, 'destinationLotCode');
  }
  final codes = animalCodes.toSet().toList(growable: false);
  final animals = codes.join(', ');
  final currentLotFilter = currentLotCode == null
      ? ''
      : ' AND CODLOTE = $currentLotCode';
  return 'UPDATE TB_ANIMAIS SET CODLOTE = $destinationLotCode, '
      'HORA_DO_REGISTRO = dbo.cHORA_DO_REGISTRO() '
      'WHERE CODANIMAL ${codes.length == 1 ? '= ${codes.single}' : 'IN ($animals)'}'
      '$currentLotFilter;';
}
