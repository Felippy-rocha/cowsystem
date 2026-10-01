import 'package:flutter/material.dart';

import 'data/animal_weight_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalWeightPage extends StatefulWidget {
  const AnimalWeightPage({super.key});

  @override
  State<AnimalWeightPage> createState() => _AnimalWeightPageState();
}

class _AnimalWeightPageState extends State<AnimalWeightPage> {
  late final SoapClient _client;
  late final AnimalWeightRepository _repository;
  final _tagController = TextEditingController();
  List<AnimalWeightSession> _sessions = const [];
  List<AnimalWeightRecord> _weights = const [];
  String? _selectedDate;
  bool _loading = true;
  bool _onlyMissing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalWeightRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _tagController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load({String? preferredDate}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await _repository.fetchSessions();
      final date = preferredDate ?? _selectedDate;
      final selected = sessions.any((session) => session.date == date)
          ? date
          : sessions.isEmpty
          ? null
          : sessions.first.date;
      final weights = selected == null
          ? const <AnimalWeightRecord>[]
          : await _repository.fetchWeights(
              selected,
              tag: _tagController.text,
              onlyMissing: _onlyMissing,
            );
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _selectedDate = selected;
        _weights = weights;
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

  Future<void> _createSession() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Data da pesagem',
    );
    if (date == null || !mounted) return;
    final value = _formatDate(date);
    setState(() => _loading = true);
    try {
      await _repository.createSession(value);
      await _load(preferredDate: value);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _addAnimal() async {
    final date = _selectedDate;
    if (date == null) return;
    final tag = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Adicionar animal'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Brinco',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
    if (tag == null || tag.isEmpty || !mounted) return;
    setState(() => _loading = true);
    try {
      await _repository.addAnimal(date, tag);
      await _load(preferredDate: date);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _editWeight(AnimalWeightRecord record) async {
    final controller = TextEditingController(
      text: record.weight == 0 ? '' : record.weight.toString(),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Peso do brinco ${record.tag}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Peso em kg',
            suffixText: 'kg',
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
              final parsed = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (parsed != null && parsed > 0) {
                Navigator.pop(context, parsed);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    setState(() => _loading = true);
    try {
      await _repository.updateWeight(record.weightCode, value);
      await _load(preferredDate: _selectedDate);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteWeight(AnimalWeightRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover da pesagem?'),
        content: Text('Brinco ${record.tag} será removido desta lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await _repository.deleteWeight(record.weightCode);
      await _load(preferredDate: _selectedDate);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _applyFilters() async {
    final date = _selectedDate;
    if (date == null) return;
    setState(() => _loading = true);
    try {
      final rows = await _repository.fetchWeights(
        date,
        tag: _tagController.text,
        onlyMissing: _onlyMissing,
      );
      if (!mounted) return;
      setState(() {
        _weights = rows;
        _loading = false;
        _error = null;
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesagem'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Criar lista de pesagem',
            onPressed: _loading ? null : _createSession,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue:
                      _sessions.any((session) => session.date == _selectedDate)
                      ? _selectedDate
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Data da pesagem',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _sessions
                      .map(
                        (session) => DropdownMenuItem(
                          value: session.date,
                          child: Text(_displayDate(session.date)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _loading
                      ? null
                      : (date) {
                          if (date != null) _load(preferredDate: date);
                        },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Brinco',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pesquisar brinco',
                      onPressed: _loading ? null : _applyFilters,
                      icon: const Icon(Icons.search),
                    ),
                    IconButton(
                      tooltip: _onlyMissing
                          ? 'Mostrar todos os pesos'
                          : 'Mostrar pesos pendentes',
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() => _onlyMissing = !_onlyMissing);
                              _applyFilters();
                            },
                      icon: Icon(
                        _onlyMissing
                            ? Icons.filter_alt
                            : Icons.filter_alt_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('${_weights.length} animais')),
                    TextButton.icon(
                      onPressed: _loading || _selectedDate == null
                          ? null
                          : _addAnimal,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar animal'),
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
            child: _sessions.isEmpty && !_loading
                ? const Center(
                    child: Text('Crie uma lista para iniciar a pesagem.'),
                  )
                : _weights.isEmpty && !_loading
                ? const Center(child: Text('Nenhum animal nesta seleção.'))
                : ListView.separated(
                    itemCount: _weights.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _weightTile(_weights[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _weightTile(AnimalWeightRecord record) {
    final recorded = record.weight > 0;
    final belowTarget =
        recorded &&
        record.idealWeight > 0 &&
        record.weight < record.idealWeight;
    return ListTile(
      onTap: () => _editWeight(record),
      leading: CircleAvatar(
        backgroundColor: recorded
            ? Theme.of(context).colorScheme.tertiaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(record.tag),
      ),
      title: Text(
        record.weight == 0 ? 'Pendente' : '${_number(record.weight)} kg',
        style: TextStyle(
          color: belowTarget ? Theme.of(context).colorScheme.error : null,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        'Idade: ${record.daysOld} dias (${record.daysOld ~/ 30} meses)'
        ' · Ideal ${_number(record.idealWeight)} kg'
        ' · Nascimento ${_number(record.birthWeight)} kg'
        '${record.lot.isEmpty ? '' : ' · Lote ${record.lot}'}',
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Ações da pesagem',
        onSelected: (action) {
          if (action == 'edit') _editWeight(record);
          if (action == 'remove') _deleteWeight(record);
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Registrar peso')),
          PopupMenuItem(value: 'remove', child: Text('Remover da lista')),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return '${parsed.day.toString().padLeft(2, '0')}/'
          '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    }
    return value;
  }

  String _number(double value) =>
      value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
}
