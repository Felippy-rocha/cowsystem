class ClientRoutingSession {
  static String deviceId = '';
  static String suffix = '';
  static int profileCode = 0;
  static String profileDescription = '';
  static String company = '';
  static String username = '';
  static String appVersion = '';
  static bool canGrantPermissions = false;
}

class ClientRoutingRecord {
  const ClientRoutingRecord({
    required this.deviceId,
    required this.suffix,
    this.code = 0,
    this.company = '',
    this.username = '',
    this.profileCode = 0,
    this.appVersion = '',
    this.clientName = '',
    this.active = true,
  });

  final String deviceId;
  final String suffix;
  final int code;
  final String company;
  final String username;
  final int profileCode;
  final String appVersion;
  final String clientName;
  final bool active;

  factory ClientRoutingRecord.fromJson(Map<String, dynamic> json) {
    String value(List<String> keys) {
      for (final key in keys) {
        final entry = json.entries.where(
          (item) => item.key.toUpperCase() == key.toUpperCase(),
        );
        if (entry.isNotEmpty && entry.first.value != null) {
          return '${entry.first.value}'.trim();
        }
      }
      return '';
    }

    final activeValue = value(['ATIVO', 'ACTIVE']);
    final number = (String raw) => int.tryParse(raw) ?? 0;
    return ClientRoutingRecord(
      deviceId: value(['DISPOSITIVO', 'DEVICE_ID', 'DEVICE']),
      suffix: value(['SUFIXO', 'SUFFIX']),
      code: number(value(['CODIGO', 'CODIGOCLIENTE'])),
      company: value(['EMPRESA', 'COMPANY']),
      username: value(['NOMEUSUARIO', 'NOME_USUARIO', 'USERNAME']),
      profileCode: number(value(['CODPERFIL', 'PROFILE_CODE'])),
      appVersion: value(['VERSAOAPP', 'VERSAO_APP', 'APP_VERSION']),
      clientName: value(['CLIENTE', 'NOME', 'DESCRICAO', 'CLIENT_NAME']),
      active:
          activeValue.isEmpty ||
          activeValue == '1' ||
          activeValue.toLowerCase() == 'true',
    );
  }
}
