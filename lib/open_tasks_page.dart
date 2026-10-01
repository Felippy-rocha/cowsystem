import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/open_tasks_repository.dart';
import 'data/soap_client.dart';

class OpenTasksPage extends StatefulWidget {
  const OpenTasksPage({super.key});

  @override
  State<OpenTasksPage> createState() => _OpenTasksPageState();
}

class _OpenTasksPageState extends State<OpenTasksPage> {
  late final SoapClient _client;
  late final OpenTaskRepository _repository;
  final _dateStartController = TextEditingController();
  final _dateEndController = TextEditingController();
  List<({int code, String name})> _executions = const [];
  List<OpenTaskRecord> _records = const [];
  int? _executionCode;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = OpenTaskRepository(soapClient: _client);
    final now = DateTime.now();
    _dateStartController.text = _formatDate(
      now.subtract(const Duration(days: 30)),
    );
    _dateEndController.text = _formatDate(now);
    _load();
  }

  @override
  void dispose() {
    _dateStartController.dispose();
    _dateEndController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final executions = await _repository.fetchExecutions();
      if (!mounted) return;
      setState(() {
        _executions = executions;
        _executionCode = executions.firstOrNull?.code;
        _loading = false;
      });
      final code = _executionCode;
      if (code != null) await _loadRecords(code);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRecords(int executionCode) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final execution = _executions.firstWhere(
        (item) => item.code == executionCode,
      );
      final records = await _repository.fetchTasks(
        dateStart: _dateStartController.text,
        dateEnd: _dateEndController.text,
        execution: execution.name,
      );
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

  Future<void> _generate() async {
    final execution = _executionCode;
    if (execution == null) return;
    final executionName = _executions
        .firstWhere((item) => item.code == execution)
        .name;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repository.generate(
        dateStart: _dateStartController.text,
        dateEnd: _dateEndController.text,
        execution: executionName,
      );
      await _loadRecords(execution);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart
        ? DateTime.now().subtract(const Duration(days: 30))
        : DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) {
      setState(() {
        if (isStart) {
          _dateStartController.text = _formatDate(value);
        } else {
          _dateEndController.text = _formatDate(value);
        }
      });
      final code = _executionCode;
      if (code != null) await _loadRecords(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefas em aberto'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Gerar relatório',
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.checklist_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dateStartController,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: 'Data inicial',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                          border: OutlineInputBorder(),
                        ),
                        onTap: () => _pickDate(true),
                        onSubmitted: (_) => _loadRecords(_executionCode ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _dateEndController,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: 'Data final',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                          border: OutlineInputBorder(),
                        ),
                        onTap: () => _pickDate(false),
                        onSubmitted: (_) => _loadRecords(_executionCode ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue:
                      _executions.any((item) => item.code == _executionCode)
                      ? _executionCode
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Execução',
                    border: OutlineInputBorder(),
                  ),
                  items: _executions
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.code,
                          child: Text(item.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _executionCode = value);
                          if (value != null) _loadRecords(value);
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
          if (_records.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${_records.length} tarefa(s) em aberto'),
              ),
            ),
          Expanded(
            child: _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma tarefa em aberto no período selecionado.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: _records.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(child: Text(record.date)),
                          title: Text(
                            record.tag,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${record.taskType} · ${record.protocol}\n${record.task}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
