import 'package:flutter/material.dart';

import 'data/animal_hoof_trimming_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalHoofTrimmingPage extends StatefulWidget {
  const AnimalHoofTrimmingPage({super.key});

  @override
  State<AnimalHoofTrimmingPage> createState() => _AnimalHoofTrimmingPageState();
}

class _AnimalHoofTrimmingPageState extends State<AnimalHoofTrimmingPage> {
  late final SoapClient _client;
  late final AnimalHoofTrimmingRepository _repository;
  final _searchController = TextEditingController();
  List<HoofTrimmingAnimal> _animals = const [];
  List<HoofTrimmingOption> _employees = const [];
  List<HoofTrimmingOption> _types = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalHoofTrimmingRepository(soapClient: _client);
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
      final employees = await _repository.fetchEmployees();
      final types = await _repository.fetchTypes();
      final animals = await _repository.fetchAnimals(
        tag: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _types = types;
        _animals = animals;
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

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final animals = await _repository.fetchAnimals(
        tag: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _animals = animals;
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

  Future<void> _openAnimal(HoofTrimmingAnimal animal) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HoofTrimmingHistoryPage(
          animal: animal,
          repository: _repository,
          employees: _employees,
          types: _types,
        ),
      ),
    );
    await _search();
  }

  Future<void> _chooseAnimalAndCreate() async {
    if (_animals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Busque um animal pelo brinco primeiro.')),
      );
      return;
    }
    final animal = _animals.length == 1
        ? _animals.first
        : await showDialog<HoofTrimmingAnimal>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Selecionar animal'),
              children: _animals
                  .map(
                    (item) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, item),
                      child: Text('${item.tag}  ${item.productionStatus}'),
                    ),
                  )
                  .toList(growable: false),
            ),
          );
    if (animal != null && mounted) await _createRecord(animal);
  }

  Future<void> _createRecord(HoofTrimmingAnimal animal) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => HoofTrimmingFormPage(
          animal: animal,
          repository: _repository,
          employees: _employees,
          types: _types,
        ),
      ),
    );
    if (saved == true) await _search();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Casqueamento'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Incluir casqueamento',
            onPressed: _loading ? null : _chooseAnimalAndCreate,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Brinco',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar busca',
                              onPressed: () {
                                _searchController.clear();
                                _search();
                              },
                              icon: const Icon(Icons.close),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Buscar animais',
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search),
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
          Expanded(
            child: _loading && _animals.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _animals.isEmpty
                ? const Center(child: Text('Nenhum animal encontrado.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: _animals.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final animal = _animals[index];
                      final postpartumDue =
                          animal.daysInMilk >= 120 && animal.daysInMilk <= 180;
                      final pregnancyDue =
                          animal.reproductiveStatus.toUpperCase() == 'PRENHA' &&
                          animal.pregnancyDays >= 180 &&
                          animal.pregnancyDays <= 220;
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: postpartumDue || pregnancyDue
                                ? colors.errorContainer
                                : colors.secondaryContainer,
                            child: Icon(
                              Icons.content_cut_outlined,
                              color: postpartumDue || pregnancyDue
                                  ? colors.error
                                  : colors.secondary,
                            ),
                          ),
                          title: Text(
                            'Brinco ${animal.tag}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${animal.reproductiveStatus} · ${animal.productionStatus}\n'
                            'DEL ${animal.daysInMilk} · Prenhez ${animal.pregnancyDays} dias',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openAnimal(animal),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class HoofTrimmingHistoryPage extends StatefulWidget {
  const HoofTrimmingHistoryPage({
    required this.animal,
    required this.repository,
    required this.employees,
    required this.types,
    super.key,
  });

  final HoofTrimmingAnimal animal;
  final AnimalHoofTrimmingRepository repository;
  final List<HoofTrimmingOption> employees;
  final List<HoofTrimmingOption> types;

  @override
  State<HoofTrimmingHistoryPage> createState() =>
      _HoofTrimmingHistoryPageState();
}

class _HoofTrimmingHistoryPageState extends State<HoofTrimmingHistoryPage> {
  List<HoofTrimmingRecord> _records = const [];
  String? _lactation;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await widget.repository.fetchHistory(widget.animal.code);
      if (!mounted) return;
      setState(() {
        _records = records;
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

  Future<void> _editRecord([HoofTrimmingRecord? record]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => HoofTrimmingFormPage(
          animal: widget.animal,
          repository: widget.repository,
          employees: widget.employees,
          types: widget.types,
          record: record,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _deleteRecord(HoofTrimmingRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir casqueamento?'),
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
    if (confirm != true) return;
    try {
      await widget.repository.deleteRecord(record.id);
      await _load();
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lactations = _records
        .map((record) => record.lactationCode)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final records = _lactation == null
        ? _records
        : _records
              .where((record) => record.lactationCode == _lactation)
              .toList();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Casqueamento · ${widget.animal.tag}'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Incluir registro',
            onPressed: () => _editRecord(),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (lactations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: DropdownButtonFormField<String?>(
                initialValue: _lactation,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Lactação',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas as lactações'),
                  ),
                  ...lactations.map(
                    (value) => DropdownMenuItem<String?>(
                      value: value,
                      child: Text(value),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _lactation = value),
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
          Expanded(
            child: _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : records.isEmpty
                ? const Center(child: Text('Nenhum casqueamento registrado.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: records.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          title: Text(record.typeName),
                          subtitle: Text(
                            '${record.date} · Lactação ${record.lactationCode}\n'
                            'DEL ${record.daysInMilk} · Prenhez ${record.pregnancyDays} dias'
                            '${record.comment.isEmpty ? '' : '\n${record.comment}'}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Ações do registro',
                            onSelected: (action) {
                              if (action == 'edit') _editRecord(record);
                              if (action == 'delete') _deleteRecord(record);
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class HoofTrimmingFormPage extends StatefulWidget {
  const HoofTrimmingFormPage({
    required this.animal,
    required this.repository,
    required this.employees,
    required this.types,
    this.record,
    super.key,
  });

  final HoofTrimmingAnimal animal;
  final AnimalHoofTrimmingRepository repository;
  final List<HoofTrimmingOption> employees;
  final List<HoofTrimmingOption> types;
  final HoofTrimmingRecord? record;

  @override
  State<HoofTrimmingFormPage> createState() => _HoofTrimmingFormPageState();
}

class _HoofTrimmingFormPageState extends State<HoofTrimmingFormPage> {
  final _commentController = TextEditingController();
  late DateTime _date;
  int? _employeeCode;
  int? _assistantCode;
  int? _typeCode;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _date = record == null ? DateTime.now() : _parseDate(record.date);
    _employeeCode = record?.employeeCode ?? _firstCode(widget.employees);
    _assistantCode = record?.assistantCode ?? _firstCode(widget.employees);
    _typeCode = record?.typeCode ?? _firstCode(widget.types);
    _commentController.text = record?.comment ?? '';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _save() async {
    if (_employeeCode == null || _assistantCode == null || _typeCode == null) {
      setState(() => _error = 'Selecione funcionário, ajudante e tipo.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveRecord(
        id: widget.record?.id ?? -1,
        date: _sqlDate(_date),
        animalCode: widget.animal.code,
        employeeCode: _employeeCode!,
        assistantCode: _assistantCode!,
        typeCode: _typeCode!,
        comment: _commentController.text.trim(),
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
              ? 'Incluir casqueamento'
              : 'Editar casqueamento',
        ),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.pets_outlined),
            title: const Text('Animal'),
            subtitle: Text('Brinco ${widget.animal.tag}'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data'),
            subtitle: Text(_displayDate(_date)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _saving ? null : _chooseDate,
          ),
          const SizedBox(height: 8),
          _optionField(
            label: 'Funcionário',
            options: widget.employees,
            value: _employeeCode,
            onChanged: (value) => setState(() => _employeeCode = value),
          ),
          const SizedBox(height: 12),
          _optionField(
            label: 'Ajudante',
            options: widget.employees,
            value: _assistantCode,
            onChanged: (value) => setState(() => _assistantCode = value),
          ),
          const SizedBox(height: 12),
          _optionField(
            label: 'Tipo de casqueamento',
            options: widget.types,
            value: _typeCode,
            onChanged: (value) => setState(() => _typeCode = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Comentário',
              alignLabelWithHint: true,
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

  Widget _optionField({
    required String label,
    required List<HoofTrimmingOption> options,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) => DropdownButtonFormField<int>(
    initialValue: options.any((item) => item.code == value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: options
        .map(
          (item) => DropdownMenuItem(value: item.code, child: Text(item.name)),
        )
        .toList(growable: false),
    onChanged: _saving ? null : onChanged,
  );
}

int? _firstCode(List<HoofTrimmingOption> options) =>
    options.isEmpty ? null : options.first.code;

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

String _sqlDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _displayDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';
