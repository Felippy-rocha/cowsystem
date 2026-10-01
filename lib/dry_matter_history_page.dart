import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/dry_matter_history_repository.dart';
import 'data/soap_client.dart';

class DryMatterHistoryPage extends StatefulWidget {
  const DryMatterHistoryPage({super.key});

  @override
  State<DryMatterHistoryPage> createState() => _DryMatterHistoryPageState();
}

class _DryMatterHistoryPageState extends State<DryMatterHistoryPage> {
  late final SoapClient _client;
  late final DryMatterHistoryRepository _repository;
  List<DryMatterHistoryRecord> _records = const [];
  List<DryMatterChoice> _types = const [];
  List<DryMatterChoice> _diets = const [];
  List<DryMatterChoice> _ingredients = const [];
  DateTime? _filterDate;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = DryMatterHistoryRepository(soapClient: _client);
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
        _repository.fetchHistory(
          date: _filterDate == null ? '' : _sqlDate(_filterDate!),
        ),
        _repository.fetchTypes(),
        _repository.fetchDiets(),
        _repository.fetchIngredients(),
      ]);
      if (!mounted) return;
      setState(() {
        _records = results[0] as List<DryMatterHistoryRecord>;
        _types = results[1] as List<DryMatterChoice>;
        _diets = results[2] as List<DryMatterChoice>;
        _ingredients = results[3] as List<DryMatterChoice>;
        _loading = false;
      });
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() => _filterDate = selected);
    await _load();
  }

  Future<void> _openForm([DryMatterHistoryRecord? record]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DryMatterHistoryFormPage(
          repository: _repository,
          types: _types,
          diets: _diets,
          ingredients: _ingredients,
          record: record,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(DryMatterHistoryRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir histórico?'),
        content: Text('O registro de ${record.date} será removido.'),
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
    if (confirmed != true) return;
    try {
      await _repository.delete(record.id);
      await _load();
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de MS'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Incluir atualização de MS',
            onPressed: _loading ? null : () => _openForm(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _loading ? null : _chooseDate,
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Filtrar por data',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _filterDate == null
                            ? 'Todas as datas'
                            : _displayDate(_filterDate!),
                      ),
                    ),
                  ),
                ),
                if (_filterDate != null)
                  IconButton(
                    tooltip: 'Limpar filtro',
                    onPressed: () {
                      setState(() => _filterDate = null);
                      _load();
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: _load,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          if (_records.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${_records.length} registro(s)'),
              ),
            ),
          Expanded(
            child: _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(
                    child: Text('Nenhuma atualização de MS registrada.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: _records.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.secondaryContainer,
                            child: const Icon(Icons.opacity_outlined),
                          ),
                          title: Text(
                            record.entityName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('${record.typeName} · ${record.date}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${_number(record.percentage)}%'),
                              PopupMenuButton<String>(
                                tooltip: 'Ações do registro',
                                onSelected: (action) {
                                  if (action == 'edit') _openForm(record);
                                  if (action == 'delete') _delete(record);
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Editar'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Excluir'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _sqlDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
}

class DryMatterHistoryFormPage extends StatefulWidget {
  const DryMatterHistoryFormPage({
    required this.repository,
    required this.types,
    required this.diets,
    required this.ingredients,
    this.record,
    super.key,
  });

  final DryMatterHistoryRepository repository;
  final List<DryMatterChoice> types;
  final List<DryMatterChoice> diets;
  final List<DryMatterChoice> ingredients;
  final DryMatterHistoryRecord? record;

  @override
  State<DryMatterHistoryFormPage> createState() =>
      _DryMatterHistoryFormPageState();
}

class _DryMatterHistoryFormPageState extends State<DryMatterHistoryFormPage> {
  final _percentageController = TextEditingController();
  late DateTime _date;
  int? _typeCode;
  int? _entityCode;
  bool _saving = false;
  String? _error;

  bool get _isDiet => _typeCode == 1;
  List<DryMatterChoice> get _entities =>
      _isDiet ? widget.diets : widget.ingredients;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _date = record == null ? DateTime.now() : _parseDate(record.date);
    _typeCode = record?.typeCode ?? widget.types.firstOrNull?.code;
    _entityCode = record == null
        ? null
        : record.typeCode == 1
        ? record.dietCode
        : record.ingredientCode;
    _percentageController.text = record?.percentage.toString() ?? '';
  }

  @override
  void dispose() {
    _percentageController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) setState(() => _date = selected);
  }

  void _changeType(int? value) {
    setState(() {
      _typeCode = value;
      _entityCode = null;
    });
  }

  Future<void> _save() async {
    final percentage = double.tryParse(
      _percentageController.text.trim().replaceAll(',', '.'),
    );
    if (_typeCode == null ||
        _entityCode == null ||
        percentage == null ||
        percentage <= 0) {
      setState(
        () => _error =
            'Informe tipo, dieta ou ingrediente e percentual MS válido.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        id: widget.record?.id ?? -1,
        typeCode: _typeCode!,
        date: _sqlDate(_date),
        ingredientCode: _isDiet ? 0 : _entityCode!,
        dietCode: _isDiet ? _entityCode! : 0,
        percentage: percentage,
      );
      if (mounted) Navigator.pop(context, true);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.record == null
              ? 'Incluir atualização MS'
              : 'Alterar histórico MS',
        ),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data'),
            subtitle: Text(_displayDate(_date)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _saving ? null : _chooseDate,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: widget.types.any((item) => item.code == _typeCode)
                ? _typeCode
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(),
            ),
            items: widget.types
                .map(
                  (item) => DropdownMenuItem(
                    value: item.code,
                    child: Text(item.name),
                  ),
                )
                .toList(growable: false),
            onChanged: _saving ? null : _changeType,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('$_typeCode-$_entityCode'),
            initialValue: _entities.any((item) => item.code == _entityCode)
                ? _entityCode
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _typeCode == 1 ? 'Dieta' : 'Ingrediente',
              border: const OutlineInputBorder(),
            ),
            items: _entities
                .map(
                  (item) => DropdownMenuItem(
                    value: item.code,
                    child: Text(item.name),
                  ),
                )
                .toList(growable: false),
            onChanged: _saving
                ? null
                : (value) => setState(() => _entityCode = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _percentageController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Matéria seca',
              suffixText: '%',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }

  String _sqlDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

DateTime _parseDate(String value) {
  final trimmed = value.trim();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  if (brazilian != null) {
    return DateTime(
      int.parse(brazilian.group(3)!),
      int.parse(brazilian.group(2)!),
      int.parse(brazilian.group(1)!),
    );
  }
  return DateTime.tryParse(trimmed) ?? DateTime.now();
}
