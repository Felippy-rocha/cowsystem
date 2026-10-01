import 'dart:convert';

import 'soap_client.dart';

class AnimalCommentType {
  const AnimalCommentType({required this.code, required this.name});

  final int code;
  final String name;

  factory AnimalCommentType.fromJson(Map<String, dynamic> json) =>
      AnimalCommentType(
        code: int.tryParse('${_commentField(json, 'CODTIPO') ?? 0}') ?? 0,
        name: '${_commentField(json, 'TIPOCOMENTARIO') ?? ''}'.trim(),
      );
}

class AnimalCommentRecord {
  const AnimalCommentRecord({
    required this.id,
    required this.animalCode,
    required this.date,
    required this.type,
    required this.comment,
  });

  final int id;
  final int animalCode;
  final String date;
  final String type;
  final String comment;

  factory AnimalCommentRecord.fromJson(Map<String, dynamic> json) =>
      AnimalCommentRecord(
        id: int.tryParse('${_commentField(json, 'ID') ?? 0}') ?? 0,
        animalCode:
            int.tryParse('${_commentField(json, 'CODANIMAL') ?? 0}') ?? 0,
        date: '${_commentField(json, 'DATA') ?? ''}'.trim(),
        type: '${_commentField(json, 'TIPO') ?? ''}'.trim(),
        comment: '${_commentField(json, 'COMENTARIO') ?? ''}'.trim(),
      );
}

class AnimalCommentRepository {
  AnimalCommentRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<AnimalCommentType>> fetchTypes() async => (await _query(
    'SELECT CODTIPO, TIPOCOMENTARIO FROM TB_TIPOCOMENTARIO '
    'ORDER BY TIPOCOMENTARIO',
  )).map(AnimalCommentType.fromJson).toList(growable: false);

  Future<List<AnimalCommentRecord>> fetchComments(int animalCode) async =>
      (await _query('''
SELECT ID, CODANIMAL, DATA, TIPO, COMENTARIO
FROM TB_COMENTARIOS
WHERE CODANIMAL = $animalCode
ORDER BY ID DESC''')).map(AnimalCommentRecord.fromJson).toList(growable: false);

  Future<void> save({
    required int? id,
    required int animalCode,
    required String date,
    required String type,
    required String comment,
  }) => _execute(
    animalCommentSaveSql(
      id: id,
      animalCode: animalCode,
      date: date,
      type: type,
      comment: comment,
    ),
  );

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_commentXmlEscape(sql)}</xSql>'
          '<Sufixo>${_commentXmlEscape(soapClient.suffix)}</Sufixo>'
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
      action: 'ExecSql',
      password: password,
      body:
          '<xSql>${_commentXmlEscape(sql)}</xSql>'
          '<Login>${_commentXmlEscape(soapClient.username)}</Login>'
          '<Senha>${_commentXmlEscape(password)}</Senha>'
          '<Sufixo>${_commentXmlEscape(soapClient.suffix)}</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.contains('#ic#-1#fc#')) {
      throw SoapException(
        response.replaceFirst('#ic#', '').replaceFirst('#fc#', ''),
      );
    }
  }
}

String animalCommentSaveSql({
  required int? id,
  required int animalCode,
  required String date,
  required String type,
  required String comment,
}) {
  if (animalCode <= 0 || type.trim().isEmpty || comment.trim().isEmpty) {
    throw ArgumentError('Animal, tipo e comentário são obrigatórios.');
  }
  final sqlDate = _commentSqlDate(date);
  final sqlType = _commentSqlText(type);
  final sqlComment = _commentSqlText(comment.toUpperCase());
  if (id != null && id > 0) {
    return '''
UPDATE TB_COMENTARIOS SET CODANIMAL = $animalCode, DATA = $sqlDate,
  TIPO = $sqlType, COMENTARIO = $sqlComment,
  HORA_DO_REGISTRO = dbo.cHORA_DO_REGISTRO()
WHERE ID = $id;''';
  }
  return '''
DECLARE @ID INT;
SELECT @ID = ISNULL(MAX(ID) + 1, 1) FROM TB_COMENTARIOS;
INSERT INTO TB_COMENTARIOS
  (ID, CODANIMAL, DATA, TIPO, COMENTARIO, HORA_DO_REGISTRO)
VALUES
  (@ID, $animalCode, $sqlDate, $sqlType, $sqlComment, dbo.cHORA_DO_REGISTRO());''';
}

String _commentSqlDate(String value) {
  final trimmed = value.trim();
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  final normalized = br == null
      ? trimmed
      : '${br.group(3)}-${br.group(2)}-${br.group(1)}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    throw FormatException('Data do comentário inválida: $value');
  }
  final parts = normalized.split('-').map(int.parse).toList(growable: false);
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw FormatException('Data do comentário inválida: $value');
  }
  return "'$normalized'";
}

String _commentSqlText(String value) =>
    "N'${value.trim().replaceAll("'", "''")}'";

dynamic _commentField(Map<String, dynamic> row, String name) {
  for (final entry in row.entries) {
    if (entry.key.toUpperCase() == name.toUpperCase()) return entry.value;
  }
  return null;
}

String _commentXmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
