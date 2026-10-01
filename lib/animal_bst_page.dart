import 'package:flutter/material.dart';

import 'data/animal_bst_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalBstPage extends StatefulWidget {
  const AnimalBstPage({super.key});

  @override
  State<AnimalBstPage> createState() => _AnimalBstPageState();
}

class _AnimalBstPageState extends State<AnimalBstPage>
    with SingleTickerProviderStateMixin {
  late final SoapClient _client;
  late final AnimalBstRepository _repository;
  late final TabController _tabController;
  final _tagController = TextEditingController();
  List<BstAnimalOption> _eligible = const [];
  List<BstAnimalOption> _active = const [];
  List<BstChoice> _hormones = const [];
  List<BstChoice> _weeks = const [];
  String? _weekFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalBstRepository(soapClient: _client);
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_tabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_tabChanged)
      ..dispose();
    _tagController.dispose();
    _client.close();
    super.dispose();
  }

  void _tabChanged() {
    if (_tabController.indexIsChanging || !mounted) return;
    setState(() {});
    if (_tabController.index == 1) _loadActive();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.fetchEligibleAnimals(tag: _tagController.text),
        _repository.fetchHormones(),
        _repository.fetchWeeks(),
      ]);
      final eligible = results[0] as List<BstAnimalOption>;
      final hormones = results[1] as List<BstChoice>;
      final weeks = results[2] as List<BstChoice>;
      final active = await _repository.fetchActiveAnimals(
        week: _weekFilter ?? '',
      );
      if (!mounted) return;
      setState(() {
        _eligible = eligible;
        _active = active;
        _hormones = hormones;
        _weeks = weeks;
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

  Future<void> _loadEligible() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final eligible = await _repository.fetchEligibleAnimals(
        tag: _tagController.text,
      );
      if (!mounted) return;
      setState(() {
        _eligible = eligible;
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

  Future<void> _loadActive() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final active = await _repository.fetchActiveAnimals(
        week: _weekFilter ?? '',
      );
      if (!mounted) return;
      setState(() {
        _active = active;
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

  Future<void> _openForm(BstAnimalOption animal, {bool editing = false}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BstCycleFormPage(
          animal: animal,
          repository: _repository,
          hormones: _hormones,
          weeks: _weeks,
          editing: editing,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _deactivate(BstAnimalOption animal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar animal do BST?'),
        content: Text('O ciclo ativo do brinco ${animal.tag} será encerrado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deactivateCycle(animal.cycleCode);
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
        title: const Text('BST'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Animais aptos'),
            Tab(text: 'Animais incluídos'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_tabController.index == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _tagController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Brinco',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _tagController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          onPressed: () {
                            _tagController.clear();
                            _loadEligible();
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _loadEligible(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: DropdownButtonFormField<String?>(
                initialValue: _weekFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Semana',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas as semanas'),
                  ),
                  ..._weeks.map(
                    (week) => DropdownMenuItem<String?>(
                      value: week.name,
                      child: Text(week.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _weekFilter = value);
                  _loadActive();
                },
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
            child: TabBarView(
              controller: _tabController,
              children: [
                _animalList(
                  _eligible,
                  emptyText: 'Nenhum animal apto para inclusão.',
                  onTap: (animal) => _openForm(animal),
                  active: false,
                ),
                _animalList(
                  _active,
                  emptyText: 'Nenhum animal incluído no BST.',
                  onTap: (animal) => _openForm(animal, editing: true),
                  active: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _animalList(
    List<BstAnimalOption> animals, {
    required String emptyText,
    required ValueChanged<BstAnimalOption> onTap,
    required bool active,
  }) {
    if (_loading && animals.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (animals.isEmpty) return Center(child: Text(emptyText));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      itemCount: animals.length,
      separatorBuilder: (_, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final animal = animals[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                animal.score == 0 ? 'BST' : animal.score.toStringAsFixed(1),
              ),
            ),
            title: Text(
              'Brinco ${animal.tag}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              active
                  ? '${animal.hormone} · Semana ${animal.week}\n'
                        'Desde ${animal.entryDate} · DEL ${animal.daysInMilk}'
                  : '${animal.reproductiveStatus} · ${animal.productionStatus}\n'
                        'DEL ${animal.daysInMilk} · Lactação ${animal.lactationCode}',
            ),
            isThreeLine: true,
            trailing: active
                ? PopupMenuButton<String>(
                    tooltip: 'Ações do ciclo BST',
                    onSelected: (action) {
                      if (action == 'edit') onTap(animal);
                      if (action == 'remove') _deactivate(animal);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Editar hormônio/semana'),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('Retirar do BST'),
                      ),
                    ],
                  )
                : const Icon(Icons.add_circle_outline),
            onTap: active ? null : () => onTap(animal),
          ),
        );
      },
    );
  }
}

class BstCycleFormPage extends StatefulWidget {
  const BstCycleFormPage({
    required this.animal,
    required this.repository,
    required this.hormones,
    required this.weeks,
    required this.editing,
    super.key,
  });

  final BstAnimalOption animal;
  final AnimalBstRepository repository;
  final List<BstChoice> hormones;
  final List<BstChoice> weeks;
  final bool editing;

  @override
  State<BstCycleFormPage> createState() => _BstCycleFormPageState();
}

class _BstCycleFormPageState extends State<BstCycleFormPage> {
  late DateTime _entryDate;
  int? _hormoneCode;
  String? _week;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _entryDate = widget.editing
        ? _parseDate(widget.animal.entryDate)
        : DateTime.now();
    _hormoneCode = widget.editing
        ? widget.animal.hormoneCode
        : _firstChoice(widget.hormones)?.code;
    _week = widget.editing
        ? widget.animal.week
        : _firstChoice(widget.weeks)?.name;
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _entryDate = date);
  }

  Future<void> _save() async {
    if (_hormoneCode == null || _week == null || _week!.isEmpty) {
      setState(() => _error = 'Selecione hormônio e semana.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveCycle(
        animalCode: widget.animal.animalCode,
        entryDate: _sqlDate(_entryDate),
        hormoneCode: _hormoneCode!,
        lactationCode: widget.animal.lactationCode,
        week: _week!,
        cycleCode: widget.editing ? widget.animal.cycleCode : null,
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
        title: Text(widget.editing ? 'Editar BST' : 'Incluir animal BST'),
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
            title: const Text('Data de entrada'),
            subtitle: Text(_displayDate(_entryDate)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: widget.editing || _saving ? null : _chooseDate,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue:
                widget.hormones.any((item) => item.code == _hormoneCode)
                ? _hormoneCode
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Hormônio',
              border: OutlineInputBorder(),
            ),
            items: widget.hormones
                .map(
                  (item) => DropdownMenuItem(
                    value: item.code,
                    child: Text(item.name),
                  ),
                )
                .toList(growable: false),
            onChanged: _saving
                ? null
                : (value) => setState(() => _hormoneCode = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: widget.weeks.any((item) => item.name == _week)
                ? _week
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Semana de aplicação',
              border: OutlineInputBorder(),
            ),
            items: widget.weeks
                .map(
                  (item) => DropdownMenuItem(
                    value: item.name,
                    child: Text(item.name),
                  ),
                )
                .toList(growable: false),
            onChanged: _saving
                ? null
                : (value) => setState(() => _week = value),
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
}

BstChoice? _firstChoice(List<BstChoice> choices) =>
    choices.isEmpty ? null : choices.first;

String _sqlDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _displayDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

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
