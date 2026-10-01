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
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _rows = const [];
  Map<int, bool> _access = const {};
  List<PermissionDefinitionRecord> _permissionCatalog = const [];
  bool _loading = true;
  bool _searching = false;
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
    _searchController.dispose();
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
    final query = _searchController.text.trim().toLowerCase();
    final visibleRows = _rows
        .where((row) {
          if (query.isEmpty) return true;
          return widget.config.fields.any(
            (field) => '${row[field.key] ?? ''}'.toLowerCase().contains(query),
          );
        })
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Pesquisar',
                  border: InputBorder.none,
                ),
              )
            : Text(widget.config.title),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _searching ? 'Fechar pesquisa' : 'Pesquisar',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchController.clear();
            }),
            icon: Icon(_searching ? Icons.close : Icons.search),
          ),
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
          : visibleRows.isEmpty
          ? Center(
              child: Text(
                query.isEmpty
                    ? 'Nenhum registro cadastrado.'
                    : 'Nenhum registro encontrado.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: visibleRows.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (context, index) => _rowTile(visibleRows[index]),
            ),
    );
  }

  Widget _rowTile(Map<String, dynamic> row) {
    final id = int.tryParse('${row[widget.config.idColumn] ?? 0}') ?? 0;
    final primary = '${row[widget.config.fields.first.key] ?? 'Registro'}';
    return ListTile(
      title: Text(primary, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        (widget.config.listColumns.isEmpty
                ? widget.config.fields.skip(1).take(2).map((field) => field.key)
                : widget.config.listColumns)
            .map((key) {
              final field = widget.config.fields.firstWhere(
                (field) => field.key == key,
              );
              final value = field.date
                  ? displayDate(row[field.key])
                  : row[field.key] ?? '';
              return '${field.label}: $value';
            })
            .join(' | '),
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (_) => [
          if (widget.config.childConfig != null)
            const PopupMenuItem(value: 'details', child: Text('Itens do protocolo')),
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
          if (action == 'details') {
            final childConfig = widget.config.childConfig?.call(id);
            if (childConfig != null) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AgroCatalogPage(config: childConfig),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _editRow([Map<String, dynamic>? row]) async {
    final values = <String, String>{
      for (final field in widget.config.fields)
        field.key: '${row?[field.key] ?? ''}',
    };
    final options = <String, Map<String, String>>{};
    try {
      for (final field in widget.config.fields) {
        if (field.optionsQuery != null && field.optionsValueColumn != null) {
          options[field.key] = await _repository.fetchOptions(
            field.optionsQuery!,
            field.optionsValueColumn!,
            field.optionsLabelColumn ?? field.optionsValueColumn!,
          );
        } else if (field.options.isNotEmpty) {
          options[field.key] = {
            for (final value in field.options) value: value,
          };
        }
      }
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
      return;
    }
    if (!mounted) return;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) =>
          _AgroForm(config: widget.config, values: values, options: options),
    );
    if (result == null || !mounted) return;
    try {
      final id = int.tryParse('${row?[widget.config.idColumn] ?? 0}') ?? 0;
      final uniqueColumn = widget.config.uniqueColumn;
      if (uniqueColumn != null) {
        final value = (result[uniqueColumn] ?? '').trim().toLowerCase();
        final duplicate = _rows.any(
          (existing) =>
              int.tryParse('${existing[widget.config.idColumn] ?? 0}') != id &&
              '${existing[uniqueColumn] ?? ''}'.trim().toLowerCase() == value,
        );
        if (duplicate) {
          setState(() => _error = '${widget.config.title} já cadastrado.');
          return;
        }
      }
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
  const _AgroForm({
    required this.config,
    required this.values,
    required this.options,
  });

  final AgroEntityConfig config;
  final Map<String, String> values;
  final Map<String, Map<String, String>> options;

  @override
  State<_AgroForm> createState() => _AgroFormState();
}

class _AgroFormState extends State<_AgroForm> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.config.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in widget.config.fields.where(
                (field) => field.showInForm,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: field.date
                      ? _dateField(context, field)
                      : widget.options.containsKey(field.key)
                      ? _optionField(field)
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
                          validator: field.required
                              ? (value) => value == null || value.trim().isEmpty
                                    ? 'Preenchimento obrigatório'
                                    : null
                              : null,
                          onChanged: (value) =>
                              widget.values[field.key] = value,
                        ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, widget.values);
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _optionField(AgroField field) {
    final values = {...widget.options[field.key]!};
    final current = widget.values[field.key];
    if (current != null && current.isNotEmpty && !values.containsKey(current)) {
      values[current] = current;
    }
    return DropdownButtonFormField<String>(
      initialValue: values.containsKey(current) ? current : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: field.label),
      items: values.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(growable: false),
      validator: field.required
          ? (value) => value == null ? 'Preenchimento obrigatório' : null
          : null,
      onChanged: (value) {
        if (value != null) widget.values[field.key] = value;
      },
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

AgroEntityConfig simpleTableCatalogConfig({
  required String title,
  required String table,
  required String idColumn,
  required String descriptionColumn,
}) => AgroEntityConfig(
  title: title,
  table: table,
  idColumn: idColumn,
  query:
      'SELECT $idColumn, $descriptionColumn FROM $table ORDER BY $descriptionColumn',
  fields: [AgroField(descriptionColumn, title)],
  saveSql: (id, values) =>
      'EXEC SP_TB_TABELAS_INSERT_UPDATE $table, $id, ${sqlText(values[descriptionColumn] ?? '')};',
  deleteSql: (id) => "EXEC SP_TB_TABELAS_DELETE '$table', $id;",
);

AgroEntityConfig suppliersConfig() => AgroEntityConfig(
  title: 'Fornecedores',
  table: 'TB_FORNECEDORES',
  idColumn: 'CODFORNECEDOR',
  uniqueColumn: 'FORNECEDOR',
  listColumns: const ['ENDERECOWEB', 'CONTATO', 'CELULAR', 'TIPOINSUMO'],
  query: 'SELECT CODFORNECEDOR, FORNECEDOR, TIPO, ENDERECOWEB, USUARIO, CONTATO, TELEFONE, CELULAR, TIPOINSUMO FROM TB_FORNECEDORES ORDER BY FORNECEDOR',
  fields: const [
    AgroField('FORNECEDOR', 'Fornecedor', required: true),
    AgroField('TIPO', 'Tipo', required: true, options: ['INTERNET', 'LOCAL']),
    AgroField('ENDERECOWEB', 'Endereço web'),
    AgroField('USUARIO', 'Usuário'),
    AgroField('CONTATO', 'Contato'),
    AgroField('TELEFONE', 'Telefone'),
    AgroField('CELULAR', 'Celular'),
    AgroField(
      'TIPOINSUMO',
      'Tipo de insumo',
      required: true,
      optionsQuery: 'SELECT INSUMO FROM TB_TIPOINSUMOS ORDER BY INSUMO',
      optionsValueColumn: 'INSUMO',
    ),
  ],
  saveSql: (id, values) =>
      'EXEC SP_TB_FORNECEDORES_INSERT_UPDATE $id, ${sqlText(values['FORNECEDOR'] ?? '')}, ${sqlText(values['TIPO'] ?? '')}, ${sqlText(values['ENDERECOWEB'] ?? '')}, ${sqlText(values['USUARIO'] ?? '')}, ${sqlText(values['CONTATO'] ?? '')}, ${sqlText(values['TELEFONE'] ?? '')}, ${sqlText(values['CELULAR'] ?? '')}, ${sqlText(values['TIPOINSUMO'] ?? '')};',
  deleteSql: (id) => 'DELETE FROM TB_FORNECEDORES WHERE CODFORNECEDOR = $id;',
);

AgroEntityConfig treatmentsConfig() => AgroEntityConfig(
  title: 'Tratamentos',
  table: 'TB_TRATAMENTOS',
  idColumn: 'CODTRATAMENTO',
  uniqueColumn: 'TRATAMENTO',
  listColumns: const ['DOENCA', 'CARENCIA'],
  query: 'SELECT T.CODTRATAMENTO, T.TRATAMENTO, T.COMENTARIO, T.CARENCIA, T.CODDOENCA, D.DOENCA FROM TB_TRATAMENTOS T INNER JOIN TB_DOENCAS D ON D.CODDOENCA = T.CODDOENCA ORDER BY T.TRATAMENTO',
  fields: const [
    AgroField('TRATAMENTO', 'Tratamento', required: true),
    AgroField('COMENTARIO', 'Comentário'),
    AgroField(
      'CODDOENCA',
      'Doença',
      required: true,
      optionsQuery: 'SELECT CODDOENCA, DOENCA FROM TB_DOENCAS ORDER BY DOENCA',
      optionsValueColumn: 'CODDOENCA',
      optionsLabelColumn: 'DOENCA',
    ),
    AgroField('CARENCIA', 'Carência em dias', numeric: true),
    AgroField('DOENCA', 'Doença', showInForm: false),
  ],
  childConfig: treatmentDetailsConfig,
  saveSql: (id, values) =>
      'EXEC SP_TB_TRATAMENTOS_INSERT_UPDATE $id, ${sqlText(values['TRATAMENTO'] ?? '')}, ${sqlText(values['COMENTARIO'] ?? '')}, ${sqlNumber(values['CODDOENCA'] ?? '')}, ${sqlNumber(values['CARENCIA'] ?? '')};',
  deleteSql: (id) => 'EXEC SP_TB_TRATAMENTOS_DELETE $id;',
);

AgroEntityConfig treatmentDetailsConfig(int treatmentCode) => AgroEntityConfig(
  title: 'Itens do tratamento',
  table: 'TB_TRATAMENTOS_DETALHES',
  idColumn: 'ID',
  query: 'SELECT ID, CODTRATAMENTO, DESCRICAO, LINHADETEMPO, TEMPO FROM TB_TRATAMENTOS_DETALHES WHERE CODTRATAMENTO = $treatmentCode ORDER BY TEMPO',
  fields: const [
    AgroField('DESCRICAO', 'Descrição', required: true),
    AgroField('LINHADETEMPO', 'Linha do tempo', required: true),
    AgroField('TEMPO', 'Tempo/ordem', numeric: true, required: true),
  ],
  saveSql: (id, values) =>
      'EXEC SP_TB_TRATAMENTOS_DETALHES_INSERT_UPDATE $id, $treatmentCode, ${sqlText(values['DESCRICAO'] ?? '')}, ${sqlText(values['LINHADETEMPO'] ?? '')}, ${sqlNumber(values['TEMPO'] ?? '')};',
  deleteSql: (id) => 'EXEC SP_TB_TRATAMENTOS_DETALHES_DELETE $id;',
);

AgroEntityConfig inseminationTypesConfig() => simpleTableCatalogConfig(
  title: 'Tipos de IA',
  table: 'TB_TIPOIA',
  idColumn: 'CODTIPOIA',
  descriptionColumn: 'TIPOIA',
);

AgroEntityConfig breedsConfig() => AgroEntityConfig(
  title: 'Raças',
  table: 'TB_RACA',
  idColumn: 'CODRACA',
  uniqueColumn: 'RACA',
  listColumns: const ['FRACAO'],
  query: 'SELECT R.CODRACA, R.RACA, R.IDGRAUSANGUE, G.FRACAO FROM TB_RACA R INNER JOIN TB_GRAUSANGUE G ON R.IDGRAUSANGUE = G.IDGRAUSANGUE ORDER BY R.IDGRAUSANGUE',
  fields: const [
    AgroField('RACA', 'Raça', required: true),
    AgroField(
      'IDGRAUSANGUE',
      'Grau de sangue',
      required: true,
      optionsQuery: 'SELECT IDGRAUSANGUE, FRACAO FROM TB_GRAUSANGUE ORDER BY DECIMAL, FRACAO',
      optionsValueColumn: 'IDGRAUSANGUE',
      optionsLabelColumn: 'FRACAO',
    ),
    AgroField('FRACAO', 'Grau de sangue', showInForm: false),
  ],
  saveSql: (id, values) =>
      'EXEC SP_TB_RACA_INSERT_UPDATE $id, ${sqlText((values['RACA'] ?? '').toUpperCase())}, ${sqlNumber(values['IDGRAUSANGUE'] ?? '')};',
  deleteSql: (id) => 'EXEC SP_TB_RACA_DELETE $id;',
);
