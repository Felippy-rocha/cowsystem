import 'package:flutter/material.dart';

import 'data/animal_insemination_repository.dart';
import 'data/animal_record.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalInseminationPage extends StatefulWidget {
  const AnimalInseminationPage({super.key});

  @override
  State<AnimalInseminationPage> createState() => _AnimalInseminationPageState();
}

class _AnimalInseminationPageState extends State<AnimalInseminationPage> {
  static const _pageSize = 200;

  late final SoapClient _client;
  late final AnimalInseminationRepository _repository;
  final _tagController = TextEditingController();
  List<AnimalRecord> _animals = const [];
  List<InseminationOption> _employees = const [];
  List<InseminationOption> _types = const [];
  List<InseminationOption> _donors = const [];
  bool _includeAll = false;
  bool _loading = true;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalInseminationRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _tagController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _animals = const [];
    });
    try {
      final lookups = await Future.wait<dynamic>([
        _repository.fetchEmployees(),
        _repository.fetchTypes(),
        _repository.fetchDonors(),
      ]);
      final animals = await _repository.fetchAnimals(
        tag: _tagController.text,
        includeAll: _includeAll,
        offset: reset ? 0 : _animals.length,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _employees = lookups[0] as List<InseminationOption>;
        _types = lookups[1] as List<InseminationOption>;
        _donors = lookups[2] as List<InseminationOption>;
        _animals = reset ? animals : [..._animals, ...animals];
        _hasMore = animals.length == _pageSize;
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

  Future<void> _loadMore() => _load(reset: false);

  Future<void> _openForm([AnimalRecord? selectedAnimal]) async {
    if (_employees.isEmpty || _types.isEmpty) {
      _showMessage('Cadastre inseminadores e tipos de IA antes de continuar.');
      return;
    }
    List<AnimalRecord> animals;
    try {
      animals = selectedAnimal == null
          ? await _repository.fetchAllAnimalOptions()
          : [selectedAnimal];
    } on SoapException catch (error) {
      if (mounted) _showMessage(error.message);
      return;
    }
    if (!mounted) return;
    final draft = await showDialog<_InseminationDraft>(
      context: context,
      builder: (context) => _InseminationForm(
        animals: animals,
        selectedAnimal: selectedAnimal,
        employees: _employees,
        types: _types,
        donors: _donors,
        loadBulls: _repository.fetchBulls,
      ),
    );
    if (draft == null || !mounted) return;
    try {
      setState(() => _loading = true);
      await _repository.insertInsemination(
        animalCode: draft.animalCode,
        date: draft.date,
        employeeCode: draft.employeeCode,
        bullCode: draft.bullCode,
        typeCode: draft.typeCode,
        comment: draft.comment,
        donorCode: draft.donorCode,
      );
      await _load();
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inseminações'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _tagController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Brinco',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Pesquisar animal',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.search),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _load(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incluir animais fora do filtro padrão'),
                  value: _includeAll,
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _includeAll = value);
                          _load();
                        },
                ),
                Row(
                  children: [
                    Expanded(child: Text('${_animals.length} animais aptos')),
                    TextButton.icon(
                      onPressed: _loading ? null : () => _openForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('Incluir IA'),
                    ),
                  ],
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
            child: _animals.isEmpty && !_loading
                ? const Center(
                    child: Text('Nenhum animal apto para inseminação.'),
                  )
                : ListView.separated(
                    itemCount: _animals.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == _animals.length) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _loadMore,
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Carregar mais'),
                          ),
                        );
                      }
                      return _animalTile(_animals[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _animalTile(AnimalRecord animal) => ListTile(
    onTap: () => _openForm(animal),
    leading: CircleAvatar(child: Text(animal.tag)),
    title: Text(
      animal.tag,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      '${animal.reproductiveStatus} · ${animal.productionStatus}'
      ' · ${animal.inseminationCount} IA'
      '${animal.lastInseminationDate.isEmpty ? '' : ' · Última IA ${animal.lastInseminationDate}'}'
      '${animal.displayLot.isEmpty ? '' : ' · Lote ${animal.displayLot}'}',
    ),
    trailing: const Icon(Icons.science_outlined),
  );
}

class _InseminationDraft {
  const _InseminationDraft({
    required this.animalCode,
    required this.date,
    required this.employeeCode,
    required this.bullCode,
    required this.typeCode,
    required this.comment,
    required this.donorCode,
  });

  final int animalCode;
  final String date;
  final int employeeCode;
  final int bullCode;
  final int typeCode;
  final String comment;
  final int donorCode;
}

class _InseminationForm extends StatefulWidget {
  const _InseminationForm({
    required this.animals,
    required this.selectedAnimal,
    required this.employees,
    required this.types,
    required this.donors,
    required this.loadBulls,
  });

  final List<AnimalRecord> animals;
  final AnimalRecord? selectedAnimal;
  final List<InseminationOption> employees;
  final List<InseminationOption> types;
  final List<InseminationOption> donors;
  final Future<List<InseminationBull>> Function({
    required int animalCode,
    required bool embryo,
  })
  loadBulls;

  @override
  State<_InseminationForm> createState() => _InseminationFormState();
}

class _InseminationFormState extends State<_InseminationForm> {
  int? _animalCode;
  int? _employeeCode;
  int? _typeCode;
  int? _bullCode;
  int? _donorCode;
  DateTime _date = DateTime.now();
  List<InseminationBull> _bulls = const [];
  bool _loadingBulls = false;
  String _comment = '';

  @override
  void initState() {
    super.initState();
    _animalCode = widget.selectedAnimal?.animalCode;
    _employeeCode = widget.employees.first.code;
  }

  Future<void> _selectType(int? code) async {
    if (code == null) return;
    setState(() {
      _typeCode = code;
      _bullCode = null;
      _bulls = const [];
      _loadingBulls = _animalCode != null;
    });
    final type = widget.types.where((item) => item.code == code).firstOrNull;
    final animalCode = _animalCode;
    if (type == null || animalCode == null) return;
    try {
      final bulls = await widget.loadBulls(
        animalCode: animalCode,
        embryo: type.name.toUpperCase() == 'TE',
      );
      if (mounted) {
        setState(() {
          _bulls = bulls;
          _loadingBulls = false;
        });
      }
    } on SoapException catch (error) {
      if (mounted) {
        setState(() => _loadingBulls = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final animals = widget.selectedAnimal == null
        ? widget.animals
        : [widget.selectedAnimal!];
    final requiresDonor = _typeCode == 3;
    return AlertDialog(
      title: const Text('Incluir inseminação'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue:
                    animals.any((item) => item.animalCode == _animalCode)
                    ? _animalCode
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Animal',
                  border: OutlineInputBorder(),
                ),
                items: animals
                    .map(
                      (animal) => DropdownMenuItem(
                        value: animal.animalCode,
                        child: Text('${animal.tag} · ${animal.displayLot}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: widget.selectedAnimal == null
                    ? (value) {
                        setState(() {
                          _animalCode = value;
                          _typeCode = null;
                          _bullCode = null;
                          _bulls = const [];
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data da inseminação'),
                subtitle: Text(_displayDate(_date)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _date = date);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _employeeCode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Inseminador',
                  border: OutlineInputBorder(),
                ),
                items: widget.employees
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.code,
                        child: Text(item.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _employeeCode = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _typeCode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tipo de IA',
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
                onChanged: _selectType,
              ),
              const SizedBox(height: 12),
              if (_loadingBulls) const LinearProgressIndicator(),
              DropdownButtonFormField<int>(
                initialValue: _bulls.any((item) => item.code == _bullCode)
                    ? _bullCode
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Touro',
                  border: OutlineInputBorder(),
                ),
                items: _bulls
                    .map(
                      (bull) => DropdownMenuItem(
                        value: bull.code,
                        child: Text(
                          '${bull.recommended ? 'Recomendado · ' : ''}'
                          '${bull.name} · estoque ${bull.stock}',
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _loadingBulls || _animalCode == null
                    ? null
                    : (value) => setState(() => _bullCode = value),
              ),
              if (requiresDonor) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _donorCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Doadora',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.donors
                      .map(
                        (donor) => DropdownMenuItem(
                          value: donor.code,
                          child: Text(donor.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _donorCode = value),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Comentário',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => _comment = value,
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
          onPressed: _canSave(requiresDonor)
              ? () => Navigator.pop(
                  context,
                  _InseminationDraft(
                    animalCode: _animalCode!,
                    date: _formatDate(_date),
                    employeeCode: _employeeCode!,
                    bullCode: _bullCode!,
                    typeCode: _typeCode!,
                    comment: _comment,
                    donorCode: requiresDonor ? _donorCode! : 0,
                  ),
                )
              : null,
          child: const Text('Salvar IA'),
        ),
      ],
    );
  }

  bool _canSave(bool requiresDonor) =>
      _animalCode != null &&
      _employeeCode != null &&
      _typeCode != null &&
      _bullCode != null &&
      (!requiresDonor || _donorCode != null) &&
      !_loadingBulls;

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
