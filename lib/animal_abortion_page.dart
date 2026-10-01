import 'package:flutter/material.dart';

import 'data/animal_abortion_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

enum _AbortionMode { register, reverse }

class AnimalAbortionPage extends StatefulWidget {
  const AnimalAbortionPage({this.reverse = false, super.key});

  final bool reverse;

  @override
  State<AnimalAbortionPage> createState() => _AnimalAbortionPageState();
}

class _AnimalAbortionPageState extends State<AnimalAbortionPage> {
  late final SoapClient _client;
  late final AnimalAbortionRepository _repository;
  final _tagController = TextEditingController();
  final _commentController = TextEditingController();
  List<AbortionOption> _lots = const [];
  List<AbortionOption> _yesNo = const [];
  List<AbortionOption> _productionStatuses = const [];
  List<AbortionOption> _reproductiveStatuses = const [];
  Map<String, bool> _permissions = const {};
  AbortionAnimal? _animal;
  DateTime _date = DateTime.now();
  int? _destinationLot;
  int? _withLactation;
  int? _newLactation;
  int? _keepPregnancy;
  String? _productionStatus;
  String? _reproductiveStatus;
  _AbortionMode _mode = _AbortionMode.register;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mode = widget.reverse ? _AbortionMode.reverse : _AbortionMode.register;
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalAbortionRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _tagController.dispose();
    _commentController.dispose();
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
        _repository.fetchLots(),
        _repository.fetchYesNo(),
        _repository.fetchProductionStatuses(),
        _repository.fetchReproductiveStatuses(),
        _repository.fetchPermissions(ClientRoutingSession.profileCode),
      ]);
      if (!mounted) return;
      setState(() {
        _lots = results[0] as List<AbortionOption>;
        _yesNo = results[1] as List<AbortionOption>;
        _productionStatuses = results[2] as List<AbortionOption>;
        _reproductiveStatuses = results[3] as List<AbortionOption>;
        _permissions = results[4] as Map<String, bool>;
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

  String get _requiredPermission =>
      _mode == _AbortionMode.register ? 'Registrar aborto' : 'Estornar aborto';

  bool get _allowed {
    for (final entry in _permissions.entries) {
      if (entry.key.trim().toUpperCase() == _requiredPermission.toUpperCase()) {
        return entry.value;
      }
    }
    return false;
  }

  Future<void> _findAnimal() async {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) return;
    try {
      final animal = await _repository.findAnimal(tag);
      if (!mounted) return;
      setState(() {
        _animal = animal;
        _commentController.clear();
        _error = animal == null ? 'Brinco não encontrado.' : null;
      });
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _save() async {
    final animal = _animal;
    if (animal == null || _destinationLot == null || !_allowed) return;
    if (_mode == _AbortionMode.register &&
        (_withLactation == null || _newLactation == null)) {
      setState(() => _error = 'Informe as opções de lactação.');
      return;
    }
    if (_mode == _AbortionMode.reverse &&
        (_productionStatus == null ||
            _reproductiveStatus == null ||
            _keepPregnancy == null)) {
      setState(() => _error = 'Informe os status e se mantém a prenhez.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_mode == _AbortionMode.register) {
        await _repository.registerAbortion(
          date: _formatDate(_date),
          animalCode: animal.code,
          withLactation: _withLactation!,
          comment: _commentController.text,
          destinationLot: _destinationLot!,
          newLactation: _newLactation!,
        );
      } else {
        await _repository.reverseAbortion(
          date: _formatDate(_date),
          animalCode: animal.code,
          productionStatus: _productionStatus!,
          reproductiveStatus: _reproductiveStatus!,
          keepPregnancy: _keepPregnancy!,
          destinationLot: _destinationLot!,
          comment: _commentController.text,
        );
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _animal = null;
        _tagController.clear();
        _commentController.clear();
      });
      _showMessage(
        _mode == _AbortionMode.register
            ? 'Aborto registrado.'
            : 'Estorno de aborto registrado.',
      );
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
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
        title: const Text('Abortos'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar opções',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<_AbortionMode>(
                  segments: const [
                    ButtonSegment(
                      value: _AbortionMode.register,
                      label: Text('Registrar'),
                      icon: Icon(Icons.add),
                    ),
                    ButtonSegment(
                      value: _AbortionMode.reverse,
                      label: Text('Estornar'),
                      icon: Icon(Icons.undo),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _mode = selection.first;
                      _animal = null;
                      _tagController.clear();
                      _error = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (!_allowed)
                  MaterialBanner(
                    content: Text(
                      'Seu perfil não tem permissão para $_requiredPermission.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: _load,
                        child: const Text('Atualizar'),
                      ),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Brinco',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _findAnimal(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Buscar animal',
                      onPressed: _findAnimal,
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
                if (_animal != null) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.pets_outlined),
                    title: Text(_animal!.tag),
                    subtitle: Text('Lactação ${_animal!.lactationCode}'),
                    trailing: IconButton(
                      tooltip: 'Limpar animal',
                      onPressed: () => setState(() => _animal = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  if (_mode == _AbortionMode.register) ...[
                    if (_animal!.inseminationId == 0 ||
                        _animal!.pregnancyId == 0)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text('Prenhez atual não localizada.'),
                      )
                    else
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('IA ${_animal!.inseminationId}'),
                        subtitle: Text('Prenhez ${_animal!.pregnancyId}'),
                      ),
                  ],
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data'),
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
                  _optionField(
                    'Lote de destino',
                    _destinationLot,
                    _lots,
                    (value) => setState(() => _destinationLot = value),
                  ),
                  const SizedBox(height: 12),
                  if (_mode == _AbortionMode.register) ...[
                    _optionField(
                      'Manter lactação atual',
                      _withLactation,
                      _yesNo,
                      (value) => setState(() => _withLactation = value),
                    ),
                    const SizedBox(height: 12),
                    _optionField(
                      'Iniciar nova lactação',
                      _newLactation,
                      _yesNo,
                      (value) => setState(() => _newLactation = value),
                    ),
                  ] else ...[
                    _optionField(
                      'Status de produção',
                      _statusCode(_productionStatuses, _productionStatus),
                      _productionStatuses,
                      (value) => setState(
                        () => _productionStatus = _optionName(
                          _productionStatuses,
                          value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _optionField(
                      'Status reprodutivo',
                      _statusCode(_reproductiveStatuses, _reproductiveStatus),
                      _reproductiveStatuses,
                      (value) => setState(
                        () => _reproductiveStatus = _optionName(
                          _reproductiveStatuses,
                          value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _optionField(
                      'Manter prenhez',
                      _keepPregnancy,
                      _yesNo,
                      (value) => setState(() => _keepPregnancy = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Comentário',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: colors.error)),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: !_allowed || _saving || _animal == null
                      ? null
                      : _save,
                  icon: Icon(
                    _mode == _AbortionMode.register ? Icons.save : Icons.undo,
                  ),
                  label: Text(
                    _saving
                        ? 'Salvando...'
                        : _mode == _AbortionMode.register
                        ? 'Registrar aborto'
                        : 'Estornar aborto',
                  ),
                ),
              ],
            ),
    );
  }

  Widget _optionField(
    String label,
    int? value,
    List<AbortionOption> options,
    ValueChanged<int?> onChanged,
  ) => DropdownButtonFormField<int>(
    initialValue: options.any((option) => option.code == value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: options
        .map(
          (option) =>
              DropdownMenuItem(value: option.code, child: Text(option.name)),
        )
        .toList(growable: false),
    onChanged: onChanged,
  );

  int? _statusCode(List<AbortionOption> options, String? status) {
    final matches = options.where((option) => option.name == status);
    return matches.isEmpty ? null : matches.first.code;
  }

  String? _optionName(List<AbortionOption> options, int? code) {
    final matches = options.where((option) => option.code == code);
    return matches.isEmpty ? null : matches.first.name;
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
