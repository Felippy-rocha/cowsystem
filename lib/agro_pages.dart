import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/agro_repository.dart';
import 'data/client_routing.dart';
import 'data/permission_repository.dart';
import 'data/soap_client.dart';

class AgroCatalogPage extends StatefulWidget {
  const AgroCatalogPage({required this.config, super.key});

  final AgroEntityConfig config;

  @override
  State<AgroCatalogPage> createState() => _AgroCatalogPageState();
}

class _AgroCatalogPageState extends State<AgroCatalogPage> {
  late final SoapClient _client;
  late final AgroRepository _repository;
  late final PermissionRepository _permissions;
  List<Map<String, dynamic>> _rows = const [];
  Map<int, bool> _access = const {};
  List<PermissionDefinitionRecord> _permissionCatalog = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AgroRepository(soapClient: _client);
    _permissions = PermissionRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.fetch(widget.config),
        _loadPermissions(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = results[0] as List<Map<String, dynamic>>;
        _access = results[1] as Map<int, bool>;
        _loading = false;
      });
    } on SoapException catch (error) {
      if (mounted)
        setState(() {
          _error = error.message;
          _loading = false;
        });
    }
  }

  Future<Map<int, bool>> _loadPermissions() async {
    final profile = ClientRoutingSession.profileCode;
    if (profile <= 0) return const {};
    final catalog = await _permissions.fetchPermissionCatalog();
    _permissionCatalog = catalog;
    final codes = catalog.where(
      (item) => item.routine.toUpperCase() == widget.config.title.toUpperCase(),
    );
    final values = await _permissions.fetchProfilePermissions(profile);
    return {for (final item in codes) item.code: values[item.code] ?? false};
  }

  String _normalize(String value) => value
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('Ã', 'A')
      .replaceAll('Â', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Ê', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ô', 'O')
      .replaceAll('Õ', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ç', 'C');

  bool _actionAllowed(String action) {
    final catalog = _permissionCatalogForAction(action);
    return catalog.any((item) => _access[item.code] == true);
  }

  List<PermissionDefinitionRecord> _permissionCatalogForAction(String action) {
    return _permissionCatalog
        .where(
          (item) =>
              _normalize(item.routine) == _normalize(widget.config.title) &&
              _normalize(item.action).startsWith(_normalize(action)),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = _actionAllowed('INCLUIR');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config.title),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Incluir registro',
            onPressed: canCreate ? () => _editRow() : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _rows.isEmpty
          ? const Center(child: Text('Nenhum registro cadastrado.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _rows.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (context, index) => _rowTile(_rows[index]),
            ),
    );
  }

  Widget _rowTile(Map<String, dynamic> row) {
    final id = int.tryParse('${row[widget.config.idColumn] ?? 0}') ?? 0;
    final primary = '${row[widget.config.fields.first.key] ?? 'Registro'}';
    return ListTile(
      title: Text(primary, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        widget.config.fields
            .skip(1)
            .take(2)
            .map((f) {
              final value = f.date ? displayDate(row[f.key]) : row[f.key] ?? '';
              return '${f.label}: $value';
            })
            .join(' | '),
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'edit',
            enabled: _actionAllowed('ALTERAR'),
            child: const Text('Alterar'),
          ),
          PopupMenuItem(
            value: 'delete',
            enabled: _actionAllowed('EXCLUIR'),
            child: const Text('Excluir'),
          ),
        ],
        onSelected: (action) {
          if (action == 'edit') _editRow(row);
          if (action == 'delete') _deleteRow(id);
        },
      ),
    );
  }

  Future<void> _editRow([Map<String, dynamic>? row]) async {
    final values = <String, String>{
      for (final field in widget.config.fields)
        field.key: '${row?[field.key] ?? ''}',
    };
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _AgroForm(config: widget.config, values: values),
    );
    if (result == null || !mounted) return;
    try {
      final id = int.tryParse('${row?[widget.config.idColumn] ?? 0}') ?? 0;
      await _repository.save(widget.config, id, result);
      await _load();
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _deleteRow(int id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir registro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await _repository.delete(widget.config, id);
      await _load();
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }
}

class _AgroForm extends StatefulWidget {
  const _AgroForm({required this.config, required this.values});

  final AgroEntityConfig config;
  final Map<String, String> values;

  @override
  State<_AgroForm> createState() => _AgroFormState();
}

class _AgroFormState extends State<_AgroForm> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.config.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in widget.config.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: field.date
                    ? _dateField(context, field)
                    : TextFormField(
                        initialValue: widget.values[field.key],
                        keyboardType:
                            field.numeric || field.currency || field.percent
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.text,
                        inputFormatters:
                            field.numeric || field.currency || field.percent
                            ? [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ]
                            : null,
                        decoration: InputDecoration(
                          labelText: field.label,
                          prefixText: field.currency ? r'R$ ' : null,
                          suffixText: field.percent ? '%' : null,
                        ),
                        onChanged: (value) => widget.values[field.key] = value,
                      ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, widget.values),
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _dateField(BuildContext context, AgroField field) {
    return TextFormField(
      initialValue: displayDate(widget.values[field.key]),
      readOnly: true,
      decoration: InputDecoration(
        labelText: field.label,
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      onTap: () async {
        final initial =
            DateTime.tryParse(widget.values[field.key] ?? '') ?? DateTime.now();
        final selected = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(1950),
          lastDate: DateTime(2100),
        );
        if (selected == null) return;
        final text =
            '${selected.day.toString().padLeft(2, '0')}/'
            '${selected.month.toString().padLeft(2, '0')}/${selected.year}';
        setState(() => widget.values[field.key] = text);
      },
    );
  }
}

AgroEntityConfig ingredientsConfig() => AgroEntityConfig(
  title: 'Ingredientes',
  table: 'TB_INGREDIENTES',
  idColumn: 'CODINGREDIENTE',
  query: 'SELECT CODINGREDIENTE, INGREDIENTE, TIPO, PRECO, DATAMS, MS FROM TB_INGREDIENTES ORDER BY INGREDIENTE',
  fields: const [
    AgroField('INGREDIENTE', 'Ingrediente'),
    AgroField('TIPO', 'Tipo'),
    AgroField('PRECO', 'Preço', numeric: true, currency: true),
    AgroField('DATAMS', 'Data MS', date: true),
    AgroField('MS', 'MS', numeric: true, percent: true),
  ],
  saveSql: (id, v) =>
      'EXEC SP_TB_INGREDIENTES_INSERT @CODINGREDIENTE=$id, @INGREDIENTE=${sqlText(v['INGREDIENTE'] ?? '')}, @TIPO=${sqlText(v['TIPO'] ?? '')}, @PRECO=${sqlNumber(v['PRECO'] ?? '')}, @DATAMS=${sqlDate(v['DATAMS'] ?? '')}, @MS=${sqlNumber(v['MS'] ?? '')};',
  deleteSql: (id) => 'EXEC SP_TB_INGREDIENTES_DELETE @CODINGREDIENTE=$id;',
);

AgroEntityConfig plantiosConfig() => AgroEntityConfig(
  title: 'Plantios',
  table: 'TB_PLANTIOS',
  idColumn: 'CODPLANTIO',
  query: 'SELECT CODPLANTIO, DATAPLANTIO, CULTURA, CODTALHAO, DATACOLHEITA FROM TB_PLANTIOS ORDER BY DATAPLANTIO DESC',
  fields: const [
    AgroField('DATAPLANTIO', 'Data do plantio', date: true),
    AgroField('CULTURA', 'Cultura'),
    AgroField('CODTALHAO', 'Talhão', numeric: true),
  ],
  saveSql: (id, v) =>
      'EXEC SP_TB_PLANTIOS_INSERT_UPDATE @CODPLANTIO=$id, @DATAPLANTIO=${sqlDate(v['DATAPLANTIO'] ?? '')}, @CULTURA=${sqlText(v['CULTURA'] ?? '')}, @CODTALHAO=${sqlNumber(v['CODTALHAO'] ?? '')};',
  deleteSql: (id) => 'EXEC SP_TB_PLANTIOS_DELETE @CODPLANTIO=$id;',
);

AgroEntityConfig safraConfig() => AgroEntityConfig(
  title: 'Safras',
  table: 'TB_SAFRA',
  idColumn: 'CODSAFRA',
  query: 'SELECT CODSAFRA, SAFRA, CODPLANTIO, CODSILO, DATAENSILADO, DATATERMINO FROM TB_SAFRA ORDER BY DATAENSILADO DESC',
  fields: const [
    AgroField('CODPLANTIO', 'Plantio', numeric: true),
    AgroField('CODSILO', 'Silo', numeric: true),
    AgroField('DATAENSILADO', 'Data ensilado', date: true),
  ],
  saveSql: (id, v) =>
      'EXEC SP_TB_SAFRA_INSERT @CODSAFRA=$id, @CODPLANTIO=${sqlNumber(v['CODPLANTIO'] ?? '')}, @CODSILO=${sqlNumber(v['CODSILO'] ?? '')}, @DATAENSILADO=${sqlDate(v['DATAENSILADO'] ?? '')};',
  deleteSql: (id) => 'EXEC SP_TB_SAFRA_DELETE @CODSAFRA=$id;',
);

AgroEntityConfig siloConfig() => AgroEntityConfig(
  title: 'Silos',
  table: 'TB_SILO',
  idColumn: 'CODSILO',
  query: 'SELECT CODSILO, SILO, AREA FROM TB_SILO ORDER BY SILO',
  fields: const [
    AgroField('SILO', 'Silo'),
    AgroField('AREA', 'Area', numeric: true),
  ],
  saveSql: (id, v) =>
      'EXEC SP_TB_SILO_INSERT_UPDATE @CODSILO=$id, @SILO=${sqlText(v['SILO'] ?? '')}, @AREA=${sqlNumber(v['AREA'] ?? '')};',
  deleteSql: (id) => 'EXEC SP_TB_SILO_DELETE @CODSILO=$id;',
);

AgroEntityConfig talhoesConfig() => AgroEntityConfig(
  title: 'Talhões',
  table: 'TB_TALHOES',
  idColumn: 'CODTALHAO',
  query: 'SELECT CODTALHAO, TALHAO, AREA, ATIVO FROM TB_TALHOES WHERE ISNULL(ATIVO, 1) = 1 ORDER BY TALHAO',
  fields: const [
    AgroField('TALHAO', 'Talhão'),
    AgroField('AREA', 'Área', numeric: true),
  ],
  saveSql: (id, v) =>
      'EXEC SP_TB_TALHOES_INSERT_UPDATE @CODTALHAO=$id, @TALHAO=${sqlText(v['TALHAO'] ?? '')}, @AREA=${sqlNumber(v['AREA'] ?? '')};',
  deleteSql: (id) => 'EXEC SP_TB_TALHOES_DELETE @CODTALHAO=$id;',
);
