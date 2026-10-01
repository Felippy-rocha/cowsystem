import 'package:flutter/material.dart';

import 'data/animal_body_condition_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalBodyConditionPage extends StatefulWidget {
  const AnimalBodyConditionPage({super.key});

  @override
  State<AnimalBodyConditionPage> createState() =>
      _AnimalBodyConditionPageState();
}

class _AnimalBodyConditionPageState extends State<AnimalBodyConditionPage> {
  late final SoapClient _client;
  late final AnimalBodyConditionRepository _repository;
  List<BodyConditionEmployee> _employees = const [];
  List<BodyConditionSession> _sessions = const [];
  List<BodyConditionRecord> _records = const [];
  int? _selectedSession;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalBodyConditionRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _filterController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load({int? preferredSession}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.fetchEmployees(),
        _repository.fetchSessions(),
      ]);
      final employees = results[0] as List<BodyConditionEmployee>;
      final sessions = results[1] as List<BodyConditionSession>;
      final current = preferredSession ?? _selectedSession;
      final selected = sessions.any((item) => item.code == current)
          ? current
          : null;
      final records = selected == null
          ? const <BodyConditionRecord>[]
          : await _repository.fetchRecords(selected);
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _sessions = sessions;
        _selectedSession = selected;
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

  Future<void> _createSession() async {
    if (_employees.isEmpty) {
      _showMessage('Nenhum funcionário cadastrado.');
      return;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Data da avaliação ECC',
    );
    if (date == null || !mounted) return;
    final employeeCode = await _chooseEmployee();
    if (employeeCode == null || !mounted) return;
    try {
      setState(() => _loading = true);
      await _repository.createSession(_formatDate(date), employeeCode);
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

  Future<int?> _chooseEmployee() {
    var selected = _employees.first.code;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Funcionário'),
          content: DropdownButtonFormField<int>(
            initialValue: selected,
            isExpanded: true,
            items: _employees
                .map(
                  (employee) => DropdownMenuItem(
                    value: employee.code,
                    child: Text(employee.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectSession(int? sessionCode) async {
    if (sessionCode == null) return;
    setState(() {
      _selectedSession = sessionCode;
      _loading = true;
    });
    try {
      final records = await _repository.fetchRecords(sessionCode);
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

  Future<void> _editScore(BodyConditionRecord record) async {
    final controller = TextEditingController(
      text: record.score == 0 ? '' : _scoreText(record.score),
    );
    final score = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ECC · brinco ${record.tag}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Escore corporal',
            hintText: 'Ex.: 3,0',
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
              if (parsed != null && parsed >= 0) {
                Navigator.pop(context, parsed);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (score == null || !mounted) return;
    try {
      setState(() => _loading = true);
      await _repository.updateScore(record.id, score);
      await _load(preferredSession: record.sessionCode);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _removeAnimal(BodyConditionRecord record) async {
    final remove = await _confirm(
      title: 'Retirar animal da avaliação?',
      message: 'O brinco ${record.tag} será removido desta lista.',
      action: 'Retirar',
    );
    if (!remove || !mounted) return;
    try {
      setState(() => _loading = true);
      await _repository.deleteDetail(record.id);
      await _load(preferredSession: record.sessionCode);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteSession(BodyConditionSession session) async {
    final allowed = await _repository.canDeleteSession(session.code);
    if (!mounted) return;
    if (!allowed) {
      _showMessage('Já há ECC registrado; esta sessão não pode ser excluída.');
      return;
    }
    final remove = await _confirm(
      title: 'Excluir avaliação?',
      message: 'A avaliação de ${_displayDate(session.date)} será excluída.',
      action: 'Excluir',
    );
    if (!remove || !mounted) return;
    try {
      setState(() => _loading = true);
      await _repository.deleteSession(session.code);
      _selectedSession = null;
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

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentSession = _sessions.where(
      (session) => session.code == _selectedSession,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliação ECC'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Nova avaliação',
            onPressed: _loading ? null : _createSession,
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
                  child: DropdownButtonFormField<int>(
                    initialValue:
                        _sessions.any((item) => item.code == _selectedSession)
                        ? _selectedSession
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sessão de avaliação',
                      prefixIcon: Icon(Icons.monitor_weight_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _sessions
                        .map(
                          (session) => DropdownMenuItem(
                            value: session.code,
                            child: Text(
                              '${_displayDate(session.date)} · ${session.employee}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _loading ? null : _selectSession,
                  ),
                ),
                IconButton(
                  tooltip: 'Excluir sessão',
                  onPressed: _loading || currentSession.isEmpty
                      ? null
                      : () => _deleteSession(currentSession.first),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          if (_selectedSession != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _filterController,
                decoration: InputDecoration(
                  labelText: 'Brinco',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Pesquisar animal',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.search),
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _load(preferredSession: _selectedSession),
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
            child: _selectedSession == null && !_loading
                ? const Center(child: Text('Crie uma sessão de avaliação ECC.'))
                : _records.isEmpty && !_loading
                ? const Center(child: Text('Nenhum animal nesta avaliação.'))
                : ListView.separated(
                    itemCount: _visibleRecords.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _recordTile(_visibleRecords[index]),
                  ),
          ),
        ],
      ),
    );
  }

  final _filterController = TextEditingController();

  List<BodyConditionRecord> get _visibleRecords {
    final query = _filterController.text.trim().toLowerCase();
    if (query.isEmpty) return _records;
    return _records
        .where((record) => record.tag.toLowerCase().contains(query))
        .toList(growable: false);
  }

  Widget _recordTile(BodyConditionRecord record) {
    final rated = record.score > 0;
    return ListTile(
      onTap: () => _editScore(record),
      leading: CircleAvatar(
        backgroundColor: rated
            ? _scoreColor(context, record.score).withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(record.tag),
      ),
      title: Text(
        'ECC ${rated ? _scoreText(record.score) : 'Pendente'}',
        style: TextStyle(
          color: rated ? _scoreColor(context, record.score) : null,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${record.productionStatus} · ${record.reproductiveStatus}'
        ' · DEL ${record.daysInMilk}'
        '${record.lot.isEmpty ? '' : ' · Lote ${record.lot}'}'
        '${record.lactation.isEmpty ? '' : ' · Lactação ${record.lactation}'}',
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Ações da avaliação',
        onSelected: (action) {
          if (action == 'edit') _editScore(record);
          if (action == 'remove') _removeAnimal(record);
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Text(rated ? 'Alterar ECC' : 'Registrar ECC'),
          ),
          const PopupMenuItem(value: 'remove', child: Text('Retirar da lista')),
        ],
      ),
    );
  }

  Color _scoreColor(BuildContext context, double score) {
    final colors = Theme.of(context).colorScheme;
    if (score < 2 || score > 5) return colors.error;
    if (score == 3) return colors.primary;
    if (score < 3) return colors.tertiary;
    return colors.secondary;
  }

  String _scoreText(double score) =>
      score.toStringAsFixed(score.truncateToDouble() == score ? 0 : 1);

  String _displayDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return '${parsed.day.toString().padLeft(2, '0')}/'
          '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    }
    return value;
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
