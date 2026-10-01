import 'package:flutter/material.dart';

import 'animal_selection_menu.dart';
import 'animal_details_page.dart';
import 'animal_comments_page.dart';
import 'animal_treatment_application_page.dart';
import 'animal_roster_grid.dart';
import 'animal_roster_filter_sheet.dart';
import 'data/animal_record.dart';
import 'data/animal_discard_repository.dart';
import 'data/animal_repository.dart';
import 'data/client_routing.dart';
import 'data/lot_record.dart';
import 'data/lot_repository.dart';
import 'data/permission_repository.dart';
import 'data/soap_client.dart';

class AnimalRosterPage extends StatefulWidget {
  const AnimalRosterPage({required this.openAnimalForm, super.key});

  final Future<AnimalRecord?> Function(BuildContext context) openAnimalForm;

  @override
  State<AnimalRosterPage> createState() => _AnimalRosterPageState();
}

class _AnimalRosterPageState extends State<AnimalRosterPage> {
  static const _pageSize = 50;
  static const _statuses = ['VAZIA', 'PRENHA', 'INSEMINADA'];

  final _searchController = TextEditingController();
  final List<AnimalRecord> _animals = [];
  final Set<int> _selectedAnimalCodes = {};
  final Set<String> _reproductiveFilters = {};
  final Set<String> _productionFilters = {};
  final Set<String> _lotFilters = {};
  final Set<String> _breedFilters = {};
  late final SoapClient _soapClient;
  late final AnimalRepository _repository;
  String _searchField = 'Brinco';
  int _page = 0;
  int _view = 0;
  String _registrationStatus = 'ATIVO';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _soapClient = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalRepository(soapClient: _soapClient);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _soapClient.close();
    super.dispose();
  }

  List<AnimalRecord> get _filteredAnimals {
    final query = _searchController.text.trim().toLowerCase();
    return _animals
        .where((animal) {
          final value = switch (_searchField) {
            'Lote' => animal.displayLot,
            'Raça' => animal.breed,
            _ => animal.tag,
          };
          return (query.isEmpty || value.toLowerCase().contains(query)) &&
              (_reproductiveFilters.isEmpty ||
                  _reproductiveFilters.contains(
                    animal.reproductiveStatus.toUpperCase(),
                  )) &&
              (_productionFilters.isEmpty ||
                  _productionFilters.contains(
                    animal.productionStatus.toUpperCase(),
                  )) &&
              (_lotFilters.isEmpty ||
                  _lotFilters.contains(animal.displayLot)) &&
              (_breedFilters.isEmpty || _breedFilters.contains(animal.breed)) &&
              _matchesRegistrationStatus(animal);
        })
        .toList(growable: false);
  }

  bool _matchesRegistrationStatus(AnimalRecord animal) {
    return animal.matchesRegistrationStatus(_registrationStatus);
  }

  List<AnimalRecord> get _visibleAnimals => _filteredAnimals
      .skip(_page * _pageSize)
      .take(_pageSize)
      .toList(growable: false);

  int get _pageEnd {
    final count = _filteredAnimals.length;
    final end = (_page + 1) * _pageSize;
    return end < count ? end : count;
  }

  bool get _hasFilters =>
      _registrationStatus != 'ATIVO' ||
      _reproductiveFilters.isNotEmpty ||
      _productionFilters.isNotEmpty ||
      _lotFilters.isNotEmpty ||
      _breedFilters.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final animals = _view == 0 ? _visibleAnimals : _filteredAnimals;
    final count = _filteredAnimals.length;
    final first = count == 0 ? 0 : _page * _pageSize + 1;
    final selectedCount = _filteredAnimals
        .where((animal) => _selectedAnimalCodes.contains(animal.animalCode))
        .length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rebanho'),
            Text(
              'Animais cadastrados',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Filtros',
            onPressed: _showFilters,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_alt_outlined),
                if (_hasFilters)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Adicionar animal',
            onPressed: () => _addAnimal(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: _RosterOverview(animals: _filteredAnimals),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Buscar por $_searchField',
              leading: const Icon(Icons.search),
              onChanged: (_) => setState(() {
                _page = 0;
                _selectedAnimalCodes.clear();
              }),
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              trailing: [
                PopupMenuButton<String>(
                  tooltip: 'Campo de busca: $_searchField',
                  onSelected: (field) => setState(() {
                    _searchField = field;
                    _page = 0;
                    _selectedAnimalCodes.clear();
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'Brinco', child: Text('Brinco')),
                    PopupMenuItem(value: 'Lote', child: Text('Lote')),
                    PopupMenuItem(value: 'Raça', child: Text('Raça')),
                  ],
                  icon: const Icon(Icons.manage_search_outlined),
                ),
                IconButton(
                  tooltip: 'Filtros avançados',
                  onPressed: _showFilters,
                  icon: const Icon(Icons.filter_list_outlined),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _reproductiveFilters.isEmpty,
                  onSelected: (_) => setState(() {
                    _reproductiveFilters.clear();
                    _page = 0;
                    _selectedAnimalCodes.clear();
                  }),
                ),
                const SizedBox(width: 8),
                for (final status in _statuses) ...[
                  FilterChip(
                    label: Text(status),
                    selected: _reproductiveFilters.contains(status),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _reproductiveFilters.add(status);
                      } else {
                        _reproductiveFilters.remove(status);
                      }
                      _page = 0;
                      _selectedAnimalCodes.clear();
                    }),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Lista'),
                  icon: Icon(Icons.view_agenda_outlined),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Grid'),
                  icon: Icon(Icons.view_module_outlined),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (selection) => setState(() {
                _view = selection.first;
                if (_view == 0) _selectedAnimalCodes.clear();
              }),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : animals.isEmpty
                ? _emptyState()
                : _view == 0
                ? ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: animals.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 0),
                    itemBuilder: (context, index) => _AnimalRosterCard(
                      animal: animals[index],
                      onTap: () => _showDetails(context, animals[index]),
                      onActions: () => _showAnimalActions([animals[index]]),
                    ),
                  )
                : AnimalRosterGrid(
                    animals: _filteredAnimals,
                    selectedAnimalCodes: _selectedAnimalCodes,
                    onAnimalTap: _toggleGridAnimal,
                  ),
          ),
          if (_view == 1 && _selectedAnimalCodes.isNotEmpty)
            SafeArea(
              top: false,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  border: const Border(top: BorderSide(color: Colors.black12)),
                ),
                child: Row(
                  children: [
                    Text(
                      '$selectedCount selecionado(s)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(_selectedAnimalCodes.clear),
                      icon: const Icon(Icons.close),
                      label: const Text('Limpar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _showSelectionMenu,
                      icon: const Icon(Icons.more_horiz),
                      label: const Text('Ações'),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Voltar ao início',
                    onPressed: () =>
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.home_outlined),
                  ),
                  const Spacer(),
                  Text(
                    _view == 0
                        ? '$first–$_pageEnd de $count registro(s)'
                        : _selectedAnimalCodes.isEmpty
                        ? '$count registros'
                        : '$selectedCount selecionados de $count',
                  ),
                  IconButton(
                    tooltip: 'Página anterior',
                    onPressed: _page == 0
                        ? null
                        : () => setState(() => _page--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Próxima página',
                    onPressed: _pageEnd >= count
                        ? null
                        : () => setState(() => _page++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    return const Center(child: Text('Nenhum animal encontrado.'));
  }

  void _showDetails(BuildContext context, AnimalRecord animal) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnimalDetailsPage(animal: animal),
      ),
    );
  }

  Future<void> _showFilters() async {
    final options = _animals;
    final result = await showAnimalRosterFilters(
      context: context,
      initial: AnimalRosterFilters(
        reproductive: _reproductiveFilters,
        production: _productionFilters,
        lots: _lotFilters,
        breeds: _breedFilters,
        registrationStatus: _registrationStatus,
      ),
      reproductiveOptions: _sortedAnimalOptions(
        options.map((animal) => animal.reproductiveStatus),
      ),
      productionOptions: _sortedAnimalOptions(
        options.map((animal) => animal.productionStatus),
      ),
      lotOptions: _sortedAnimalOptions(
        options.map((animal) => animal.displayLot),
      ),
      breedOptions: _sortedAnimalOptions(options.map((animal) => animal.breed)),
    );
    if (result == null || !mounted) return;
    setState(() {
      _reproductiveFilters
        ..clear()
        ..addAll(result.reproductive);
      _productionFilters
        ..clear()
        ..addAll(result.production);
      _lotFilters
        ..clear()
        ..addAll(result.lots);
      _breedFilters
        ..clear()
        ..addAll(result.breeds);
      _registrationStatus = result.registrationStatus;
      _page = 0;
      _selectedAnimalCodes.clear();
    });
  }

  Future<void> _showSelectionMenu() async {
    final selected = _filteredAnimals
        .where((animal) => _selectedAnimalCodes.contains(animal.animalCode))
        .toList(growable: false);
    await _showAnimalActions(selected);
  }

  Future<void> _showAnimalActions(List<AnimalRecord> animals) async {
    if (animals.isEmpty) return;
    final action = await showAnimalSelectionMenu(
      context: context,
      animals: animals,
    );
    if (action == null || !mounted) return;
    if (action == AnimalSelectionAction.animalInformation &&
        animals.length == 1) {
      setState(_selectedAnimalCodes.clear);
      _showDetails(context, animals.single);
      return;
    }
    if ((action == AnimalSelectionAction.addComment ||
            action == AnimalSelectionAction.consultComments) &&
        animals.length == 1) {
      setState(_selectedAnimalCodes.clear);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AnimalCommentsPage(
            animal: animals.single,
            openCreateOnLoad: action == AnimalSelectionAction.addComment,
          ),
        ),
      );
      return;
    }
    if (action == AnimalSelectionAction.changeLot) {
      await _changeLot(animals);
      return;
    }
    if (action == AnimalSelectionAction.discardAnimal && animals.length == 1) {
      await _discardAnimal(animals.single);
      return;
    }
    if (action == AnimalSelectionAction.associateChip && animals.length == 1) {
      await _associateChip(animals.single);
      return;
    }
    if (action == AnimalSelectionAction.addTreatment && animals.length == 1) {
      setState(_selectedAnimalCodes.clear);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              AnimalTreatmentApplicationPage(selectedAnimal: animals.single),
        ),
      );
      await _load();
      return;
    }
    final option = animalSelectionMenuOptions(animals)
        .firstWhere((item) => item.action == action);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${option.title}: a rotina desta ação ainda não foi portada para Flutter.',
          ),
        ),
      );
  }

  Future<void> _changeLot(List<AnimalRecord> animals) async {
    List<LotRecord> lots;
    try {
      lots = await LotRepository(soapClient: _soapClient).fetchLots();
    } on SoapException catch (error) {
      if (mounted) _showRosterMessage(error.message);
      return;
    }
    if (!mounted || lots.isEmpty) {
      if (mounted) _showRosterMessage('Nenhum lote ativo disponível.');
      return;
    }
    int? destination = lots.first.code;
    final destinationCode = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            animals.length == 1 ? 'Alterar lote' : 'Alterar lote dos animais',
          ),
          content: DropdownButtonFormField<int>(
            initialValue: destination,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Lote de destino',
              border: OutlineInputBorder(),
            ),
            items: lots
                .map(
                  (lot) =>
                      DropdownMenuItem(value: lot.code, child: Text(lot.name)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setDialogState(() => destination = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, destination),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
    if (destinationCode == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar troca de lote'),
        content: Text(
          '${animals.length} animal(is) será(ão) movido(s) para '
          '${lots.firstWhere((lot) => lot.code == destinationCode).name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Alterar lote'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await _repository.changeLots(
        animals: animals,
        destinationLotCode: destinationCode,
      );
      _selectedAnimalCodes.clear();
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

  void _showRosterMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _discardAnimal(AnimalRecord animal) async {
    final discardRepository = AnimalDiscardRepository(soapClient: _soapClient);
    try {
      if (!await discardRepository.canDiscard(
        ClientRoutingSession.profileCode,
      )) {
        if (mounted) {
          _showRosterMessage('Seu perfil não pode descartar animais.');
        }
        return;
      }
      final reasons = await discardRepository.fetchReasons();
      if (!mounted) return;
      if (reasons.isEmpty) {
        _showRosterMessage('Nenhum motivo de descarte cadastrado.');
        return;
      }
      final draft = await showDialog<Map<String, Object>>(
        context: context,
        builder: (context) {
          int? reasonCode;
          DateTime discardDate = DateTime.now();
          final commentController = TextEditingController();
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text('Descartar brinco ${animal.tag}?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: reasonCode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Motivo do descarte',
                        border: OutlineInputBorder(),
                      ),
                      items: reasons
                          .map(
                            (reason) => DropdownMenuItem(
                              value: reason.code,
                              child: Text(reason.description),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) =>
                          setDialogState(() => reasonCode = value),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Data do descarte'),
                      subtitle: Text(_formatDateForDisplay(discardDate)),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: discardDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (selected != null) {
                          setDialogState(() => discardDate = selected);
                        }
                      },
                    ),
                    TextField(
                      controller: commentController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Comentário',
                        border: OutlineInputBorder(),
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
                  onPressed: reasonCode == null
                      ? null
                      : () => Navigator.pop(context, {
                          'reason': reasonCode!,
                          'date': _formatDateForSql(discardDate),
                          'comment': commentController.text,
                        }),
                  child: const Text('Descartar animal'),
                ),
              ],
            ),
          );
        },
      );
      if (draft == null || !mounted) return;
      setState(() => _loading = true);
      await discardRepository.discard(
        animalCode: animal.animalCode,
        reasonCode: draft['reason']! as int,
        date: draft['date']! as String,
        comment: draft['comment']! as String,
      );
      _selectedAnimalCodes.remove(animal.animalCode);
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

  String _formatDateForSql(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _formatDateForDisplay(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _associateChip(AnimalRecord animal) async {
    final permissions = PermissionRepository(soapClient: _soapClient);
    try {
      if (ClientRoutingSession.profileCode <= 0) {
        _showRosterMessage('Seu perfil não autoriza associar chips.');
        return;
      }
      final catalog = await permissions.fetchPermissionCatalog();
      final definitions = catalog.where((permission) {
        final routine = permission.routine.trim().toUpperCase();
        final action = permission.action.trim().toUpperCase();
        return routine == 'ANIMAIS' &&
            (action.contains('CHIP') || action.contains('RFID'));
      });
      final profilePermissions = await permissions.fetchProfilePermissions(
        ClientRoutingSession.profileCode,
      );
      if (!mounted) return;
      final allowed = definitions.any(
        (permission) => profilePermissions[permission.code] == true,
      );
      if (!allowed) {
        _showRosterMessage('Seu perfil não autoriza associar chips.');
        return;
      }
      final controller = TextEditingController(text: animal.electronicTag);
      final chipCode = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Associar chip · brinco ${animal.tag}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Código do chip RFID',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(context, value);
              },
              child: const Text('Associar'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (chipCode == null || !mounted) return;
      setState(() => _loading = true);
      await _repository.associateChip(
        animalCode: animal.animalCode,
        chipCode: chipCode,
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

  void _toggleGridAnimal(AnimalRecord animal) {
    if (animal.animalCode <= 0) return;
    setState(() {
      if (!_selectedAnimalCodes.add(animal.animalCode)) {
        _selectedAnimalCodes.remove(animal.animalCode);
      }
    });
  }

  Future<void> _addAnimal(BuildContext context) async {
    final animal = await widget.openAnimalForm(context);
    if (animal != null && mounted) {
      setState(() {
        _animals.insert(0, animal);
        _page = 0;
      });
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final animals = await _repository.fetchAnimals(where: 'WHERE 1 = 1');
      if (!mounted) return;
      setState(() {
        _animals
          ..clear()
          ..addAll(animals);
      });
    } on SoapException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Nao foi possivel consultar o Azure.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _RosterOverview extends StatelessWidget {
  const _RosterOverview({required this.animals});

  final List<AnimalRecord> animals;

  @override
  Widget build(BuildContext context) {
    final milking = animals
        .where((animal) => animal.productionStatus.toUpperCase() == 'EM LEITE')
        .length;
    final pregnant = animals
        .where((animal) => animal.reproductiveStatus.toUpperCase() == 'PRENHA')
        .length;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xffedf3ef),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _RosterOverviewMetric(
            label: 'ANIMAIS',
            value: '${animals.length}',
            icon: Icons.pets_outlined,
          ),
          _RosterOverviewMetric(
            label: 'EM LEITE',
            value: '$milking',
            icon: Icons.water_drop_outlined,
          ),
          _RosterOverviewMetric(
            label: 'PRENHAS',
            value: '$pregnant',
            icon: Icons.pregnant_woman_outlined,
          ),
        ],
      ),
    );
  }
}

class _RosterOverviewMetric extends StatelessWidget {
  const _RosterOverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                label,
                style: const TextStyle(fontSize: 9, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimalRosterCard extends StatelessWidget {
  const _AnimalRosterCard({
    required this.animal,
    required this.onTap,
    required this.onActions,
  });

  final AnimalRecord animal;
  final VoidCallback onTap;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final status = animal.reproductiveStatus.trim();
    final statusColor = _animalStatusColor(status);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xffdce5df)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onActions,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BRINCO',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: Colors.black54),
                                ),
                                Text(
                                  animal.tag,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          _AnimalStatusBadge(
                            status: status,
                            color: statusColor,
                          ),
                          IconButton(
                            tooltip: 'Abrir ações do animal',
                            onPressed: onActions,
                            icon: const Icon(Icons.more_vert),
                          ),
                        ],
                      ),
                      if (animal.discardCode == 1) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xfffff4d6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: Color(0xff9a5b00),
                              ),
                              SizedBox(width: 7),
                              Text(
                                'A DESCARTAR',
                                style: TextStyle(
                                  color: Color(0xff794800),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.grid_view_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              animal.displayLot,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              animal.breed,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _AnimalMetric(
                            icon: Icons.science_outlined,
                            label: 'IAs',
                            value: '${animal.inseminationCount}',
                          ),
                          const SizedBox(width: 8),
                          _AnimalMetric(
                            icon: Icons.water_drop_outlined,
                            label: 'Lactação',
                            value: animal.lactationCode,
                          ),
                          const SizedBox(width: 8),
                          _AnimalMetric(
                            icon: Icons.timelapse_outlined,
                            label: 'DEL',
                            value: '${animal.daysInMilk} d',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 18,
                        runSpacing: 4,
                        children: [
                          _AnimalDateInfo(
                            label: 'Nascimento',
                            value: animal.birthDate,
                          ),
                          _AnimalDateInfo(
                            label: 'Última IA',
                            value: animal.lastInseminationDate,
                          ),
                          if (animal.lastCalvingDate.isNotEmpty)
                            _AnimalDateInfo(
                              label: 'Último parto',
                              value: animal.lastCalvingDate,
                            ),
                          if (status.toUpperCase() == 'PRENHA')
                            _AnimalDateInfo(
                              label: 'Prenhez',
                              value: '${animal.pregnancyDays} dias',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimalStatusBadge extends StatelessWidget {
  const _AnimalStatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status.isEmpty ? 'N/D' : status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimalMetric extends StatelessWidget {
  const _AnimalMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xfff2f6f3),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                  Text(
                    value.isEmpty ? 'N/D' : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimalDateInfo extends StatelessWidget {
  const _AnimalDateInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.bodySmall,
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(color: Colors.black54),
          ),
          TextSpan(text: _animalDate(value)),
        ],
      ),
    );
  }
}

List<String> _sortedAnimalOptions(Iterable<String> values) {
  final options = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  options.sort();
  return options;
}

Color _animalStatusColor(String status) {
  switch (status.trim().toUpperCase()) {
    case 'PRENHA':
      return Colors.green;
    case 'VAZIA':
      return Colors.red;
    case 'INSEMINADA':
      return Colors.amber;
    default:
      return Colors.grey;
  }
}

String _animalDate(String value) {
  final date = DateTime.tryParse(value.trim());
  if (date == null) return value.trim();
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
