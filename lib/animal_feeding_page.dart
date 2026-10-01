import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/feeding_repository.dart';
import 'data/permission_repository.dart';
import 'data/soap_client.dart';

class AnimalFeedingPage extends StatefulWidget {
  const AnimalFeedingPage({super.key});

  @override
  State<AnimalFeedingPage> createState() => _AnimalFeedingPageState();
}

class _AnimalFeedingPageState extends State<AnimalFeedingPage>
    with SingleTickerProviderStateMixin {
  late final SoapClient _client;
  late final FeedingRepository _repository;
  late final PermissionRepository _permissionRepository;
  late final TabController _tabs;
  DateTime _date = DateTime.now();
  List<FeedingRecord> _feedings = const [];
  List<FeedingIngredient> _ingredients = const [];
  List<FeedingDischarge> _discharges = const [];
  List<FeedingChoice> _diets = const [];
  List<FeedingChoice> _employees = const [];
  List<PermissionDefinitionRecord> _permissionCatalog = const [];
  Map<int, bool> _permissions = const {};
  FeedingRecord? _selected;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = FeedingRepository(soapClient: _client);
    _permissionRepository = PermissionRepository(soapClient: _client);
    _tabs = TabController(length: 3, vsync: this)..addListener(_tabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_tabChanged)
      ..dispose();
    _client.close();
    super.dispose();
  }

  void _tabChanged() {
    if (_tabs.indexIsChanging || !mounted) {
      return;
    }
    setState(() {});
    final selected = _selected;
    if (selected == null) {
      return;
    }
    if (_tabs.index == 1) {
      _loadIngredients(selected);
    }
    if (_tabs.index == 2) {
      _loadDischarges(selected);
    }
  }

  bool _allowed(String action) {
    final entry = _permissionCatalog.where(
      (permission) =>
          permission.routine.toUpperCase() == 'TRATOS' &&
          permission.action.toUpperCase() == action.toUpperCase(),
    );
    return entry.isNotEmpty && _permissions[entry.first.code] == true;
  }

  bool _hasAccessFor(
    List<PermissionDefinitionRecord> catalog,
    Map<int, bool> permissions,
  ) => catalog.any(
    (permission) =>
        permission.routine.toUpperCase() == 'TRATOS' &&
        const {
          'INCLUIR TRATO',
          'ALTERAR TRATO',
          'CONSULTAR TRATO',
          'EXCLUIR TRATO',
        }.contains(permission.action.toUpperCase()) &&
        permissions[permission.code] == true,
  );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = ClientRoutingSession.profileCode;
      final permissionData = profile > 0
          ? await Future.wait([
              _permissionRepository.fetchPermissionCatalog(),
              _permissionRepository.fetchProfilePermissions(profile),
            ])
          : <dynamic>[<PermissionDefinitionRecord>[], <int, bool>{}];
      final catalog = permissionData[0] as List<PermissionDefinitionRecord>;
      final permissions = permissionData[1] as Map<int, bool>;
      if (!_hasAccessFor(catalog, permissions)) {
        if (!mounted) {
          return;
        }
        setState(() {
          _permissionCatalog = catalog;
          _permissions = permissions;
          _error = 'Seu perfil não tem permissão para acessar os tratos.';
          _loading = false;
        });
        return;
      }
      final diets = await _repository.fetchDiets();
      final employees = await _repository.fetchEmployees();
      final feedings = await _repository.fetchFeedings(_sqlDate(_date));
      if (!mounted) {
        return;
      }
      setState(() {
        _permissionCatalog = catalog;
        _permissions = permissions;
        _diets = diets;
        _employees = employees;
        _feedings = feedings;
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

  Future<void> _loadIngredients(FeedingRecord feeding) async {
    setState(() {
      _loading = true;
      _selected = feeding;
    });
    try {
      final rows = await _repository.fetchIngredients(feeding.code);
      if (!mounted) {
        return;
      }
      setState(() {
        _ingredients = rows;
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

  Future<void> _loadDischarges(FeedingRecord feeding) async {
    setState(() {
      _loading = true;
      _selected = feeding;
    });
    try {
      final rows = await _repository.fetchDischarges(feeding.code);
      if (!mounted) {
        return;
      }
      setState(() {
        _discharges = rows;
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
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value == null) {
      return;
    }
    setState(() => _date = value);
    await _load();
  }

  Future<void> _openFeedingForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FeedingFormPage(
          repository: _repository,
          diets: _diets,
          employees: _employees,
        ),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _openDischargeForm({FeedingDischarge? discharge}) async {
    final feeding = _selected;
    if (feeding == null) {
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DischargeFormPage(
          repository: _repository,
          feeding: feeding,
          discharge: discharge,
        ),
      ),
    );
    if (saved == true) await _loadDischarges(feeding);
  }

  Future<void> _deleteFeeding(FeedingRecord feeding) async {
    if (!_allowed('EXCLUIR TRATO')) {
      _message('Seu perfil não tem permissão para excluir tratos.');
      return;
    }
    final confirmed = await _confirm(
      'Excluir trato?',
      'O trato ${feeding.code} e suas informações vinculadas serão excluídos.',
    );
    if (!confirmed) {
      return;
    }
    try {
      await _repository.deleteFeeding(feeding.code);
      await _load();
    } on SoapException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    }
  }

  Future<void> _deleteDischarge(FeedingDischarge discharge) async {
    if (!_allowed('Excluir descarga')) {
      _message('Seu perfil não tem permissão para excluir descargas.');
      return;
    }
    final confirmed = await _confirm(
      'Excluir descarga?',
      'A descarga do lote ${discharge.lot} será removida.',
    );
    if (!confirmed) {
      return;
    }
    try {
      await _repository.deleteDischarge(discharge.code);
      final feeding = _selected;
      if (feeding != null) await _loadDischarges(feeding);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    }
  }

  Future<bool> _confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;

  void _message(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tratos'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          if (_tabs.index == 0 && _allowed('INCLUIR TRATO'))
            IconButton(
              tooltip: 'Incluir trato',
              onPressed: _loading ? null : _openFeedingForm,
              icon: const Icon(Icons.add),
            ),
          if (_tabs.index == 2 && _allowed('Descarregar trato'))
            IconButton(
              tooltip: 'Incluir descarga',
              onPressed: _loading || selected == null
                  ? null
                  : () => _openDischargeForm(),
              icon: const Icon(Icons.add_box_outlined),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Tratos'),
            Tab(text: 'Ingredientes'),
            Tab(text: 'Descargas'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _loading ? null : _chooseDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data do trato',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_dateDisplay(_date)),
                    ),
                  ),
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
            child: TabBarView(
              controller: _tabs,
              children: [
                _feedingList(colors),
                _ingredientList(colors),
                _dischargeList(colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedingList(ColorScheme colors) {
    if (_loading && _feedings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_feedings.isEmpty) {
      return const Center(child: Text('Nenhum trato nesta data.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      itemCount: _feedings.length,
      separatorBuilder: (_, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final feeding = _feedings[index];
        final remaining = feeding.remainingWeight;
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: remaining <= 0
                  ? colors.primaryContainer
                  : colors.tertiaryContainer,
              child: Icon(
                remaining <= 0 ? Icons.check : Icons.restaurant_outlined,
                color: remaining <= 0 ? colors.primary : colors.tertiary,
              ),
            ),
            title: Text(
              feeding.diet,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${feeding.employee} · ajudante ${feeding.assistant}\n'
              'Peso ${_quantity(feeding.totalWeight)} kg · MS ${_quantity(feeding.totalDryMatter)} kg · ${_quantity(feeding.dryMatterPercent)}%\n'
              '${feeding.animalCount} animais · descarregado ${_quantity(feeding.totalConsumption)} kg',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              tooltip: 'Ações do trato',
              onSelected: (action) {
                if (action == 'ingredients') {
                  _selected = feeding;
                  _tabs.animateTo(1);
                  _loadIngredients(feeding);
                }
                if (action == 'discharges') {
                  _selected = feeding;
                  _tabs.animateTo(2);
                  _loadDischarges(feeding);
                }
                if (action == 'delete') _deleteFeeding(feeding);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'ingredients',
                  child: Text('Ver ingredientes'),
                ),
                const PopupMenuItem(
                  value: 'discharges',
                  child: Text('Ver descargas'),
                ),
                if (_allowed('EXCLUIR TRATO'))
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Excluir trato'),
                  ),
              ],
            ),
            onTap: () {
              setState(() => _selected = feeding);
              _tabs.animateTo(1);
              _loadIngredients(feeding);
            },
          ),
        );
      },
    );
  }

  Widget _ingredientList(ColorScheme colors) {
    final selected = _selected;
    if (selected == null) {
      return const Center(child: Text('Selecione um trato.'));
    }
    if (_loading && _ingredients.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ingredients.isEmpty) {
      return const Center(
        child: Text('Nenhum ingrediente cadastrado neste trato.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      itemCount: _ingredients.length,
      separatorBuilder: (_, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final ingredient = _ingredients[index];
        final complete =
            ingredient.includedQuantity >= ingredient.expectedQuantity;
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: complete
                  ? colors.primaryContainer
                  : colors.secondaryContainer,
              child: Text('${ingredient.order}'),
            ),
            title: Text(ingredient.name),
            subtitle: Text(
              'Previsto ${_quantity(ingredient.expectedQuantity)} kg · Carregado ${_quantity(ingredient.includedQuantity)} kg',
            ),
            trailing: Icon(
              complete ? Icons.check_circle : Icons.pending_outlined,
            ),
          ),
        );
      },
    );
  }

  Widget _dischargeList(ColorScheme colors) {
    final selected = _selected;
    if (selected == null) {
      return const Center(child: Text('Selecione um trato.'));
    }
    if (_loading && _discharges.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_discharges.isEmpty) {
      return const Center(child: Text('Nenhuma descarga lançada.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      itemCount: _discharges.length,
      separatorBuilder: (_, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final discharge = _discharges[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.local_shipping_outlined),
            ),
            title: Text(discharge.lot),
            subtitle: Text(
              '${_dateDisplay(_parseDate(discharge.date))} · ${discharge.animalCount} animais\n'
              '${_quantity(discharge.total)} kg · ${_quantity(discharge.animalCount == 0 ? 0 : discharge.total / discharge.animalCount)} kg/animal',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              tooltip: 'Ações da descarga',
              onSelected: (action) {
                if (action == 'change') {
                  _openDischargeForm(discharge: discharge);
                }
                if (action == 'delete') _deleteDischarge(discharge);
              },
              itemBuilder: (context) => [
                if (_allowed('Trocar trato entre lotes'))
                  const PopupMenuItem(
                    value: 'change',
                    child: Text('Trocar lote'),
                  ),
                if (_allowed('Excluir descarga'))
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Excluir descarga'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FeedingFormPage extends StatefulWidget {
  const FeedingFormPage({
    required this.repository,
    required this.diets,
    required this.employees,
    super.key,
  });

  final FeedingRepository repository;
  final List<FeedingChoice> diets;
  final List<FeedingChoice> employees;

  @override
  State<FeedingFormPage> createState() => _FeedingFormPageState();
}

class _FeedingFormPageState extends State<FeedingFormPage> {
  final _animalCountController = TextEditingController();
  late DateTime _date;
  int? _dietCode;
  int? _employeeCode;
  int? _assistantCode;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _dietCode = widget.diets.firstOrNull?.code;
    _employeeCode = widget.employees.firstOrNull?.code;
    _assistantCode = widget.employees.firstOrNull?.code;
  }

  @override
  void dispose() {
    _animalCountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _save() async {
    final count = int.tryParse(_animalCountController.text.trim());
    if (_dietCode == null ||
        _employeeCode == null ||
        _assistantCode == null ||
        count == null ||
        count <= 0) {
      setState(
        () => _error =
            'Informe dieta, tratador, ajudante e quantidade de animais.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createFeeding(
        dietCode: _dietCode!,
        date: _sqlDate(_date),
        employeeCode: _employeeCode!,
        assistantCode: _assistantCode!,
        animalCount: count,
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
        title: const Text('Incluir trato'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data'),
            subtitle: Text(_dateDisplay(_date)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _saving ? null : _pickDate,
          ),
          _feedingChoiceField(
            'Dieta',
            widget.diets,
            _dietCode,
            (value) => setState(() => _dietCode = value),
          ),
          const SizedBox(height: 12),
          _feedingChoiceField(
            'Tratador',
            widget.employees,
            _employeeCode,
            (value) => setState(() => _employeeCode = value),
          ),
          const SizedBox(height: 12),
          _feedingChoiceField(
            'Ajudante',
            widget.employees,
            _assistantCode,
            (value) => setState(() => _assistantCode = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _animalCountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantidade de animais',
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
            label: Text(_saving ? 'Salvando...' : 'Salvar trato'),
          ),
        ],
      ),
    );
  }
}

class DischargeFormPage extends StatefulWidget {
  const DischargeFormPage({
    required this.repository,
    required this.feeding,
    this.discharge,
    super.key,
  });

  final FeedingRepository repository;
  final FeedingRecord feeding;
  final FeedingDischarge? discharge;

  @override
  State<DischargeFormPage> createState() => _DischargeFormPageState();
}

class _DischargeFormPageState extends State<DischargeFormPage> {
  final _totalController = TextEditingController();
  List<FeedingChoice> _lots = const [];
  int? _lotCode;
  int _animalCount = 0;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lotCode = widget.discharge?.lotCode;
    _totalController.text = widget.discharge?.total.toString() ?? '';
    _loadLots();
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _loadLots() async {
    try {
      final lots = await widget.repository.fetchLots(widget.feeding.dietCode);
      if (!mounted) {
        return;
      }
      setState(() {
        _lots = lots;
        _loading = false;
        _lotCode ??= lots.firstOrNull?.code;
      });
      final lotCode = _lotCode;
      if (lotCode != null) {
        await _loadLotCount(lotCode);
      }
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadLotCount(int code) async {
    try {
      final count = await widget.repository.animalCountInLot(code);
      if (mounted) {
        setState(() => _animalCount = count);
      }
    } on SoapException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    }
  }

  Future<void> _save() async {
    final lotCode = _lotCode;
    final total = double.tryParse(
      _totalController.text.trim().replaceAll(',', '.'),
    );
    if (lotCode == null || total == null || total <= 0) {
      setState(
        () => _error = 'Selecione um lote e informe a quantidade descarregada.',
      );
      return;
    }
    final remaining =
        widget.feeding.remainingWeight + (widget.discharge?.total ?? 0);
    if (total > remaining) {
      setState(
        () => _error =
            'A descarga não pode exceder o peso restante de ${_quantity(remaining)} kg.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final current = widget.discharge;
      if (current == null) {
        await widget.repository.createDischarge(
          date: widget.feeding.date,
          feedingCode: widget.feeding.code,
          lotCode: lotCode,
          total: total,
        );
      } else {
        await widget.repository.updateDischargeLot(
          dischargeCode: current.code,
          date: current.date,
          feedingCode: current.feedingCode,
          lotCode: lotCode,
          total: total,
        );
      }
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
          widget.discharge == null
              ? 'Incluir descarga'
              : 'Trocar trato entre lotes',
        ),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Trato'),
                  subtitle: Text(
                    '${widget.feeding.diet} · ${widget.feeding.date}',
                  ),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _lots.any((lot) => lot.code == _lotCode)
                      ? _lotCode
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Lote',
                    border: OutlineInputBorder(),
                  ),
                  items: _lots
                      .map(
                        (lot) => DropdownMenuItem(
                          value: lot.code,
                          child: Text(lot.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() => _lotCode = value);
                          if (value != null) _loadLotCount(value);
                        },
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Animais no lote',
                    border: OutlineInputBorder(),
                  ),
                  child: Text('$_animalCount'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _totalController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Quantidade descarregada',
                    suffixText: 'kg',
                    helperText:
                        'Disponível: ${_quantity(widget.feeding.remainingWeight + (widget.discharge?.total ?? 0))} kg',
                    border: const OutlineInputBorder(),
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
                  label: Text(_saving ? 'Salvando...' : 'Salvar descarga'),
                ),
              ],
            ),
    );
  }
}

Widget _feedingChoiceField(
  String label,
  List<FeedingChoice> choices,
  int? value,
  ValueChanged<int?> onChanged,
) => DropdownButtonFormField<int>(
  initialValue: choices.any((item) => item.code == value) ? value : null,
  isExpanded: true,
  decoration: InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
  ),
  items: choices
      .map((item) => DropdownMenuItem(value: item.code, child: Text(item.name)))
      .toList(growable: false),
  onChanged: onChanged,
);

String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');

String _sqlDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _dateDisplay(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

DateTime _parseDate(String value) {
  final trimmed = value.trim();
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  if (match != null) {
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
  }
  return DateTime.tryParse(trimmed) ?? DateTime.now();
}
