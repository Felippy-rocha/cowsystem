import 'package:flutter/material.dart';

import 'data/animal_protocol_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalProtocolPage extends StatefulWidget {
  const AnimalProtocolPage({this.animalCode, this.tag = '', super.key});

  final int? animalCode;
  final String tag;

  @override
  State<AnimalProtocolPage> createState() => _AnimalProtocolPageState();
}

class _AnimalProtocolPageState extends State<AnimalProtocolPage> {
  late final SoapClient _client;
  late final AnimalProtocolRepository _repository;
  final _tagController = TextEditingController();
  List<ProtocolOption> _protocols = const [];
  List<ProtocolGroup> _groups = const [];
  int? _protocolCode;
  int? _animalCode;
  bool _pendingOnly = true;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animalCode = widget.animalCode;
    _tagController.text = widget.tag;
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalProtocolRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _tagController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final protocols = await _repository.fetchProtocols();
      final groups = await _repository.fetchGroups(
        pendingOnly: _pendingOnly,
        protocolCode: _protocolCode,
        animalCode: _animalCode,
      );
      if (!mounted) return;
      setState(() {
        _protocols = protocols;
        _groups = groups;
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

  Future<void> _applyTagFilter() async {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) {
      setState(() => _animalCode = widget.animalCode);
      await _load();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await _repository.findAnimalCode(tag);
      if (code == null) {
        if (!mounted) return;
        setState(() {
          _animalCode = -1;
          _groups = const [];
          _loading = false;
          _error = 'Brinco não encontrado.';
        });
        return;
      }
      _animalCode = code;
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

  Future<void> _createProtocol() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProtocolApplicationFormPage(
          repository: _repository,
          protocols: _protocols,
          initialAnimalCode: widget.animalCode,
          initialTag: widget.tag,
        ),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _openGroup(ProtocolGroup group) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProtocolDetailsPage(group: group, repository: _repository),
      ),
    );
    await _load();
  }

  Future<void> _deleteGroup(ProtocolGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir protocolo?'),
        content: Text(
          'Todas as tarefas deste protocolo para o brinco ${group.tag} serão excluídas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir protocolo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteProtocol(group.originCode);
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
        title: const Text('Protocolos ativos'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Incluir animal em protocolo',
            onPressed: _loading ? null : _createProtocol,
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
                DropdownButtonFormField<int?>(
                  initialValue: _protocolCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Protocolo',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos os protocolos'),
                    ),
                    ..._protocols.map(
                      (protocol) => DropdownMenuItem<int?>(
                        value: protocol.code,
                        child: Text(protocol.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _protocolCode = value);
                    _load();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        readOnly: widget.animalCode != null,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          labelText: 'Brinco',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _applyTagFilter(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Buscar por brinco',
                      onPressed: _loading ? null : _applyTagFilter,
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Somente protocolos pendentes'),
                  value: _pendingOnly,
                  onChanged: (value) {
                    setState(() => _pendingOnly = value);
                    _load();
                  },
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
          if (_groups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${_groups.length} protocolo(s)'),
              ),
            ),
          Expanded(
            child: _loading && _groups.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
                ? const Center(child: Text('Nenhum protocolo encontrado.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: _groups.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      final active = group.activeTaskCount > 0;
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: active
                                ? colors.secondaryContainer
                                : colors.errorContainer,
                            child: Icon(
                              active
                                  ? Icons.assignment_outlined
                                  : Icons.task_alt,
                              color: active ? colors.secondary : colors.error,
                            ),
                          ),
                          title: Text(
                            'Brinco ${group.tag} · ${group.protocolName}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${active ? 'Ativo · ${group.activeTaskCount} pendente(s)' : 'Finalizado'}\n'
                            'Lançamento: ${group.launchDate}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Ações do protocolo',
                            onSelected: (action) {
                              if (action == 'details') _openGroup(group);
                              if (action == 'delete') _deleteGroup(group);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'details',
                                child: Text('Detalhes'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Excluir protocolo'),
                              ),
                            ],
                          ),
                          onTap: () => _openGroup(group),
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

class ProtocolDetailsPage extends StatefulWidget {
  const ProtocolDetailsPage({
    required this.group,
    required this.repository,
    super.key,
  });

  final ProtocolGroup group;
  final AnimalProtocolRepository repository;

  @override
  State<ProtocolDetailsPage> createState() => _ProtocolDetailsPageState();
}

class _ProtocolDetailsPageState extends State<ProtocolDetailsPage> {
  List<ProtocolTask> _tasks = const [];
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
      final tasks = await widget.repository.fetchTasks(
        originCode: widget.group.originCode,
        animalCode: widget.group.animalCode,
      );
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
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

  Future<void> _changeTask(ProtocolTask task, String action) async {
    try {
      switch (action) {
        case 'complete':
          await widget.repository.completeTask(task.code);
        case 'reopen':
          await widget.repository.reopenTask(task.code);
        case 'delete':
          await widget.repository.deleteTask(task.code);
      }
      await _load();
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _addStep([ProtocolTask? task]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProtocolStepFormPage(
          group: widget.group,
          repository: widget.repository,
          task: task,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.group.protocolName} · ${widget.group.tag}'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Adicionar tarefa',
            onPressed: _loading ? null : _addStep,
            icon: const Icon(Icons.add_task),
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
            child: _loading && _tasks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                ? const Center(child: Text('Nenhuma tarefa no protocolo.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tasks.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: Icon(
                            task.completed
                                ? Icons.check_circle
                                : Icons.schedule,
                            color: task.completed
                                ? colors.primary
                                : colors.secondary,
                          ),
                          title: Text(task.description),
                          subtitle: Text('${task.date} · ${task.time}'),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Ações da tarefa',
                            onSelected: (action) {
                              if (action == 'edit') {
                                _addStep(task);
                              } else {
                                _changeTask(task, action);
                              }
                            },
                            itemBuilder: (context) => [
                              if (!task.completed)
                                const PopupMenuItem(
                                  value: 'complete',
                                  child: Text('Concluir tarefa'),
                                ),
                              if (task.completed)
                                const PopupMenuItem(
                                  value: 'reopen',
                                  child: Text('Desmarcar conclusão'),
                                ),
                              if (!task.completed)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar tarefa'),
                                ),
                              if (!task.completed)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Excluir tarefa'),
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

class ProtocolApplicationFormPage extends StatefulWidget {
  const ProtocolApplicationFormPage({
    required this.repository,
    required this.protocols,
    this.initialAnimalCode,
    this.initialTag = '',
    super.key,
  });

  final AnimalProtocolRepository repository;
  final List<ProtocolOption> protocols;
  final int? initialAnimalCode;
  final String initialTag;

  @override
  State<ProtocolApplicationFormPage> createState() =>
      _ProtocolApplicationFormPageState();
}

class _ProtocolApplicationFormPageState
    extends State<ProtocolApplicationFormPage> {
  final _tagController = TextEditingController();
  late DateTime _date;
  TimeOfDay? _time;
  int? _protocolCode;
  int? _animalCode;
  bool _completed = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _tagController.text = widget.initialTag;
    _animalCode = widget.initialAnimalCode;
    _protocolCode = widget.protocols.firstOrNull?.code;
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _findAnimal() async {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) return;
    try {
      final code = await widget.repository.findAnimalCode(tag);
      if (!mounted) return;
      setState(() {
        _animalCode = code;
        _error = code == null ? 'Brinco não encontrado.' : null;
      });
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
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

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (value != null) setState(() => _time = value);
  }

  Future<void> _save() async {
    final time = _time;
    if (_animalCode == null || _protocolCode == null || time == null) {
      setState(() => _error = 'Informe brinco, protocolo, data e horário.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createProtocolApplication(
        date: _dateSql(_date),
        time:
            '${time.hour.toString().padLeft(2, '0')}:'
            '${time.minute.toString().padLeft(2, '0')}',
        protocolCode: _protocolCode!,
        animalCode: _animalCode!,
        completed: _completed,
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
        title: const Text('Incluir animal em protocolo'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  readOnly: widget.initialAnimalCode != null,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Brinco',
                    prefixIcon: Icon(Icons.pets_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _findAnimal(),
                ),
              ),
              if (widget.initialAnimalCode == null)
                IconButton(
                  tooltip: 'Buscar animal',
                  onPressed: _findAnimal,
                  icon: const Icon(Icons.search),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue:
                widget.protocols.any((item) => item.code == _protocolCode)
                ? _protocolCode
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Protocolo',
              border: OutlineInputBorder(),
            ),
            items: widget.protocols
                .map(
                  (item) => DropdownMenuItem(
                    value: item.code,
                    child: Text(item.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => _protocolCode = value),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data da tarefa'),
            subtitle: Text(_dateDisplay(_date)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _saving ? null : _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Horário'),
            subtitle: Text(
              _time == null
                  ? 'Selecionar horário'
                  : '${_time!.hour.toString().padLeft(2, '0')}:'
                        '${_time!.minute.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.schedule_outlined),
            onTap: _saving ? null : _pickTime,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Concluir imediatamente'),
            value: _completed,
            onChanged: _saving
                ? null
                : (value) => setState(() => _completed = value ?? false),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Salvando...' : 'Incluir protocolo'),
          ),
        ],
      ),
    );
  }
}

class ProtocolStepFormPage extends StatefulWidget {
  const ProtocolStepFormPage({
    required this.group,
    required this.repository,
    this.task,
    super.key,
  });

  final ProtocolGroup group;
  final AnimalProtocolRepository repository;
  final ProtocolTask? task;

  @override
  State<ProtocolStepFormPage> createState() => _ProtocolStepFormPageState();
}

class _ProtocolStepFormPageState extends State<ProtocolStepFormPage> {
  final _descriptionController = TextEditingController();
  final _timeController = TextEditingController();
  late DateTime _date;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _date = task == null ? DateTime.now() : _parseProtocolDate(task.date);
    _timeController.text = task?.time ?? '08:00';
    _descriptionController.text = task?.description ?? '';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _timeController.dispose();
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
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final task = widget.task;
      if (task == null) {
        await widget.repository.addStep(
          originCode: widget.group.originCode,
          taskTypeCode: widget.group.taskTypeCode,
          date: _dateSql(_date),
          time: _timeController.text.trim(),
          animalCode: widget.group.animalCode,
          description: _descriptionController.text.trim(),
          execution: widget.group.execution,
          protocolCode: widget.group.protocolCode,
        );
      } else {
        await widget.repository.editTask(
          taskCode: task.code,
          taskTypeCode: widget.group.taskTypeCode,
          date: _dateSql(_date),
          time: _timeController.text.trim(),
          animalCode: widget.group.animalCode,
          description: _descriptionController.text.trim(),
          execution: widget.group.execution,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() {
          _error =
              error.message?.toString() ?? 'Confira os dados obrigatórios.';
          _saving = false;
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
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
          widget.task == null
              ? 'Adicionar tarefa ao protocolo'
              : 'Editar tarefa',
        ),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Brinco ${widget.group.tag} · ${widget.group.protocolName}'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data da tarefa'),
            subtitle: Text(_dateDisplay(_date)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _saving ? null : _pickDate,
          ),
          TextField(
            controller: _timeController,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Horário (HH:mm)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Tarefa',
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
            label: Text(
              _saving
                  ? 'Salvando...'
                  : widget.task == null
                  ? 'Salvar tarefa'
                  : 'Salvar alterações',
            ),
          ),
        ],
      ),
    );
  }
}

DateTime _parseProtocolDate(String value) {
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

String _dateSql(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _dateDisplay(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
