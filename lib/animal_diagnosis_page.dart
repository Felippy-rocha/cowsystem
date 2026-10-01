import 'package:flutter/material.dart';

import 'data/animal_diagnosis_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalDiagnosisPage extends StatefulWidget {
  const AnimalDiagnosisPage({super.key});

  @override
  State<AnimalDiagnosisPage> createState() => _AnimalDiagnosisPageState();
}

class _AnimalDiagnosisPageState extends State<AnimalDiagnosisPage> {
  late final SoapClient _client;
  late final AnimalDiagnosisRepository _repository;
  List<DiagnosisEmployee> _employees = const [];
  List<AnimalDiagnosisSession> _sessions = const [];
  List<AnimalDiagnosisRecord> _records = const [];
  int? _selectedSessionCode;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalDiagnosisRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
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
      final employees = results[0] as List<DiagnosisEmployee>;
      final sessions = results[1] as List<AnimalDiagnosisSession>;
      final current = preferredSession ?? _selectedSessionCode;
      final selected = sessions.any((item) => item.code == current)
          ? current
          : sessions.isEmpty
          ? null
          : sessions.first.code;
      final records = selected == null
          ? const <AnimalDiagnosisRecord>[]
          : await _repository.fetchRecords(selected);
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _sessions = sessions;
        _selectedSessionCode = selected;
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
      _showMessage('Nenhum veterinário cadastrado.');
      return;
    }
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Data do diagnóstico',
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
          title: const Text('Veterinário'),
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

  Future<void> _addAnimal() async {
    final sessionCode = _selectedSessionCode;
    if (sessionCode == null) return;
    final tag = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Incluir animal no diagnóstico'),
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
              child: const Text('Incluir'),
            ),
          ],
        );
      },
    );
    if (tag == null || tag.isEmpty || !mounted) return;
    try {
      setState(() => _loading = true);
      final animalCode = await _repository.findAnimalCode(tag);
      if (animalCode == null || animalCode <= 0) {
        setState(() => _loading = false);
        _showMessage('Brinco não encontrado.');
        return;
      }
      await _repository.addAnimal(sessionCode, animalCode);
      await _load(preferredSession: sessionCode);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _registerResult(AnimalDiagnosisRecord record) async {
    List<DiagnosisResultOption> options;
    try {
      options = await _repository.fetchResults(
        record.type,
        record.reproductiveStatus,
      );
    } on SoapException catch (error) {
      if (mounted) _showMessage(error.message);
      return;
    }
    if (!mounted) return;
    if (options.isEmpty) {
      _showMessage('Não há resultados configurados para este diagnóstico.');
      return;
    }
    final session = _sessions.where((item) => item.code == record.sessionCode);
    var date = session.isEmpty
        ? DateTime.now()
        : _parseDate(session.first.date);
    var resultCode = options.any((item) => item.code == record.resultCode)
        ? record.resultCode
        : options.first.code;
    final commentController = TextEditingController(text: record.comment);
    final result = await showDialog<Map<String, Object>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Diagnóstico do brinco ${record.tag}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data do exame'),
                  subtitle: Text(_displayDate(date)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (selected != null) setDialogState(() => date = selected);
                  },
                ),
                DropdownButtonFormField<int>(
                  initialValue: resultCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Resultado',
                    border: OutlineInputBorder(),
                  ),
                  items: options
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.code,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => resultCode = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
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
              onPressed: () => Navigator.pop(context, {
                'date': _formatDate(date),
                'result': resultCode,
                'comment': commentController.text,
              }),
              child: const Text('Salvar resultado'),
            ),
          ],
        ),
      ),
    );
    commentController.dispose();
    if (result == null || !mounted) return;
    try {
      setState(() => _loading = true);
      await _repository.saveResult(
        detailId: record.id,
        date: result['date']! as String,
        resultCode: result['result']! as int,
        comment: result['comment']! as String,
      );
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

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    return await showDialog<bool>(
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
  }

  Future<void> _removeAnimal(AnimalDiagnosisRecord record) async {
    final remove = await _confirm(
      title: 'Remover animal?',
      message: 'O brinco ${record.tag} será removido deste diagnóstico.',
      action: 'Remover',
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

  Future<void> _undoDiagnosis(AnimalDiagnosisRecord record) async {
    final undo = await _confirm(
      title: 'Desfazer diagnóstico?',
      message: 'O resultado do brinco ${record.tag} será desfeito.',
      action: 'Desfazer',
    );
    if (!undo || !mounted) return;
    try {
      setState(() => _loading = true);
      await _repository.undoResult(record.id);
      if (!mounted) return;
      setState(() => _loading = false);
      final remove = await _confirm(
        title: 'Remover animal da lista?',
        message: 'Deseja retirar o brinco ${record.tag} deste diagnóstico?',
        action: 'Remover',
      );
      if (remove && mounted) {
        setState(() => _loading = true);
        await _repository.deleteDetail(record.id);
      }
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

  Future<void> _deleteSession() async {
    final code = _selectedSessionCode;
    if (code == null) return;
    final remove = await _confirm(
      title: 'Excluir diagnóstico?',
      message: 'Esta sessão de diagnóstico será excluída.',
      action: 'Excluir',
    );
    if (!remove || !mounted) return;
    try {
      setState(() => _loading = true);
      await _repository.deleteSession(code);
      _selectedSessionCode = null;
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
        title: const Text('Diagnóstico gestacional'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Criar diagnóstico',
            onPressed: _loading ? null : _createSession,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue:
                      _sessions.any((item) => item.code == _selectedSessionCode)
                      ? _selectedSessionCode
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Diagnóstico',
                    prefixIcon: Icon(Icons.monitor_heart_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _sessions
                      .map(
                        (session) => DropdownMenuItem(
                          value: session.code,
                          child: Text(
                            '${_displayDate(_parseDate(session.date))}'
                            ' · ${session.employee}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _loading
                      ? null
                      : (code) {
                          if (code != null) _load(preferredSession: code);
                        },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('${_records.length} animais')),
                    IconButton(
                      tooltip: 'Excluir diagnóstico',
                      onPressed: _loading || _selectedSessionCode == null
                          ? null
                          : _deleteSession,
                      icon: const Icon(Icons.delete_outline),
                    ),
                    TextButton.icon(
                      onPressed: _loading || _selectedSessionCode == null
                          ? null
                          : _addAnimal,
                      icon: const Icon(Icons.add),
                      label: const Text('Incluir animal'),
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
                ? const Center(child: Text('Crie um diagnóstico para iniciar.'))
                : _records.isEmpty && !_loading
                ? const Center(
                    child: Text('Nenhum animal nesta lista de diagnóstico.'),
                  )
                : ListView.separated(
                    itemCount: _records.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _diagnosisTile(_records[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosisTile(AnimalDiagnosisRecord record) {
    final diagnosed = record.resultCode != 0;
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () => _registerResult(record),
      leading: CircleAvatar(
        backgroundColor: diagnosed
            ? colors.tertiaryContainer
            : colors.surfaceContainerHighest,
        child: Text(record.tag),
      ),
      title: Text(
        diagnosed ? record.result : 'Pendente · ${record.type}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${record.reproductiveStatus} · ${record.productionStatus}'
        ' · ${record.daysSinceInsemination} dias da IA'
        '${record.lot.isEmpty ? '' : ' · Lote ${record.lot}'}'
        '${record.comment.isEmpty ? '' : '\n${record.comment}'}',
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Ações do diagnóstico',
        onSelected: (action) {
          if (action == 'result') _registerResult(record);
          if (action == 'undo') _undoDiagnosis(record);
          if (action == 'remove') _removeAnimal(record);
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'result',
            child: Text(
              diagnosed ? 'Alterar resultado' : 'Registrar resultado',
            ),
          ),
          if (diagnosed)
            const PopupMenuItem(
              value: 'undo',
              child: Text('Desfazer diagnóstico'),
            )
          else
            const PopupMenuItem(
              value: 'remove',
              child: Text('Remover da lista'),
            ),
        ],
      ),
    );
  }

  DateTime _parseDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
    if (match != null) {
      return DateTime(
        int.parse(match.group(3)!),
        int.parse(match.group(2)!),
        int.parse(match.group(1)!),
      );
    }
    return DateTime.now();
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
