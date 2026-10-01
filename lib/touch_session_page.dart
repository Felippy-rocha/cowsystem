import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/soap_client.dart';
import 'data/touch_session_repository.dart';

class TouchSessionsPage extends StatefulWidget {
  const TouchSessionsPage({super.key});

  @override
  State<TouchSessionsPage> createState() => _TouchSessionsPageState();
}

class _TouchSessionsPageState extends State<TouchSessionsPage> {
  late final SoapClient _client;
  late final TouchSessionRepository _repository;
  List<TouchSession> _sessions = const [];
  List<TouchAnimal> _animals = const [];
  List<({int code, String name})> _employees = const [];
  TouchSession? _selected;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = TouchSessionRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
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
      final sessions = await _repository.fetchSessions();
      final selected = _selected;
      final animals = selected == null
          ? <TouchAnimal>[]
          : await _repository.fetchAnimals(selected.code);
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _sessions = sessions;
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

  Future<void> _openSession(TouchSession session) async {
    setState(() {
      _selected = session;
      _loading = true;
    });
    try {
      final animals = await _repository.fetchAnimals(session.code);
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

  Future<void> _createSession() async {
    final employee = _employees.firstOrNull;
    if (employee == null) return;
    final created = await showDialog<TouchSession>(
      context: context,
      builder: (context) =>
          TouchSessionFormPage(repository: _repository, employees: _employees),
    );
    if (created != null) await _load();
  }

  Future<void> _addAnimal(TouchSession session) async {
    final tag = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Incluir animal no toque'),
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
    if (tag == null || tag.isEmpty) return;
    try {
      final code = await _repository.findAnimalCode(tag);
      if (code == null) {
        if (mounted) setState(() => _error = 'Brinco não encontrado.');
        return;
      }
      await _repository.addAnimal(touchCode: session.code, animalCode: code);
      await _openSession(session);
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _deleteSession(TouchSession session) async {
    final confirmed = await _confirm(
      'Excluir diagnóstico?',
      'A sessão ${session.code} e seus animais serão excluídos.',
    );
    if (!confirmed) return;
    try {
      await _repository.deleteSession(session.code);
      await _load();
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _deleteAnimal(TouchAnimal animal) async {
    final confirmed = await _confirm(
      'Excluir animal do toque?',
      'O brinco ${animal.tag} será removido da lista.',
    );
    if (!confirmed) return;
    try {
      await _repository.deleteAnimal(animal.id);
      final selected = _selected;
      if (selected != null) await _openSession(selected);
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toques e diagnósticos'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Incluir toque',
            onPressed: _loading ? null : _createSession,
            icon: const Icon(Icons.add),
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
            child: _loading && _sessions.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _sessions.isEmpty
                ? const Center(child: Text('Nenhum diagnóstico cadastrado.'))
                : Row(
                    children: [
                      SizedBox(
                        width: 280,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _sessions.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            final active = selected?.code == session.code;
                            return Card(
                              margin: EdgeInsets.zero,
                              color: active ? colors.primaryContainer : null,
                              child: ListTile(
                                title: Text(session.date),
                                subtitle: Text(session.employee),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openSession(session),
                              ),
                            );
                          },
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: selected == null
                            ? const Center(
                                child: Text('Selecione uma sessão de toque.'),
                              )
                            : Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      8,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${selected.date} · ${selected.employee}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          tooltip: 'Incluir animal',
                                          onPressed: _loading
                                              ? null
                                              : () => _addAnimal(selected),
                                          icon: const Icon(Icons.add),
                                        ),
                                        PopupMenuButton<String>(
                                          tooltip: 'Ações do diagnóstico',
                                          onSelected: (action) {
                                            if (action == 'delete') {
                                              _deleteSession(selected);
                                            }
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text(
                                                'Excluir diagnóstico',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_animals.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        6,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${_animals.length} animal(is)',
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: _loading && _animals.isEmpty
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : _animals.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'Nenhum animal nesta sessão.',
                                            ),
                                          )
                                        : ListView.separated(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              4,
                                              16,
                                              20,
                                            ),
                                            itemCount: _animals.length,
                                            separatorBuilder: (_, index) =>
                                                const SizedBox(height: 6),
                                            itemBuilder: (context, index) {
                                              final animal = _animals[index];
                                              return Card(
                                                margin: EdgeInsets.zero,
                                                child: ListTile(
                                                  leading: CircleAvatar(
                                                    backgroundColor:
                                                        animal.resultCode > 0
                                                        ? colors
                                                              .primaryContainer
                                                        : colors
                                                              .secondaryContainer,
                                                    child: Icon(
                                                      animal.resultCode > 0
                                                          ? Icons.check
                                                          : Icons.pets_outlined,
                                                    ),
                                                  ),
                                                  title: Text(
                                                    'Brinco ${animal.tag}',
                                                  ),
                                                  subtitle: Text(
                                                    '${animal.lot} · ${animal.productionStatus} · ${animal.reproductiveStatus}\n'
                                                    'DEL ${animal.daysInMilk} · dias pós IA ${animal.daysSinceInsemination} · ${animal.inseminationCount} IA(s)'
                                                    '${animal.result.isEmpty ? '' : '\nResultado: ${animal.result}'}'
                                                    '${animal.comment.isEmpty ? '' : '\n${animal.comment}'}',
                                                  ),
                                                  isThreeLine: true,
                                                  trailing:
                                                      PopupMenuButton<String>(
                                                        tooltip:
                                                            'Ações do animal',
                                                        onSelected: (action) {
                                                          if (action ==
                                                              'delete') {
                                                            _deleteAnimal(
                                                              animal,
                                                            );
                                                          }
                                                        },
                                                        itemBuilder:
                                                            (context) => const [
                                                              PopupMenuItem(
                                                                value: 'delete',
                                                                child: Text(
                                                                  'Remover da lista',
                                                                ),
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
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class TouchSessionFormPage extends StatefulWidget {
  const TouchSessionFormPage({
    required this.repository,
    required this.employees,
    super.key,
  });

  final TouchSessionRepository repository;
  final List<({int code, String name})> employees;

  @override
  State<TouchSessionFormPage> createState() => _TouchSessionFormPageState();
}

class _TouchSessionFormPageState extends State<TouchSessionFormPage> {
  late DateTime _date;
  int? _employeeCode;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _employeeCode = widget.employees.firstOrNull?.code;
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) {
      setState(() => _date = value);
    }
  }

  Future<void> _save() async {
    final employee = _employeeCode;
    if (employee == null) {
      setState(() => _error = 'Selecione o funcionário.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createSession(
        date: _sqlDate(_date),
        employeeCode: employee,
      );
      if (mounted) {
        Navigator.pop(
          context,
          TouchSession(code: 0, date: '', employeeCode: employee, employee: ''),
        );
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
    return AlertDialog(
      title: const Text('Incluir diagnóstico'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data'),
            subtitle: Text(_displayDate(_date)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _saving ? null : _pickDate,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue:
                widget.employees.any((item) => item.code == _employeeCode)
                ? _employeeCode
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Funcionário',
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
            onChanged: _saving
                ? null
                : (value) => setState(() => _employeeCode = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Salvando...' : 'Salvar'),
        ),
      ],
    );
  }

  String _sqlDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
