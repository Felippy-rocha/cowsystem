import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/prevision_touch_repository.dart';
import 'data/soap_client.dart';

class PrevisionTouchPage extends StatefulWidget {
  const PrevisionTouchPage({super.key});

  @override
  State<PrevisionTouchPage> createState() => _PrevisionTouchPageState();
}

class _PrevisionTouchPageState extends State<PrevisionTouchPage> {
  late final SoapClient _client;
  late final PrevisionTouchRepository _repository;
  final _dateController = TextEditingController();
  List<PrevisionTouchRecord> _records = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = PrevisionTouchRepository(soapClient: _client);
    _dateController.text = _formatDate(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _repository.fetchRecords(_dateController.text);
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repository.generate(_dateController.text);
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

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) {
      setState(() => _dateController.text = _formatDate(value));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previsão de toque'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Gerar previsão',
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.analytics_outlined),
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
                  child: TextField(
                    controller: _dateController,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Data da previsão',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Escolher data',
                  onPressed: _loading ? null : _pickDate,
                  icon: const Icon(Icons.edit_calendar_outlined),
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
                child: Text('${_records.length} animal(is) previstos'),
              ),
            ),
          Expanded(
            child: _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(
                    child: Text('Nenhum animal previsto nesta data.'),
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
                          leading: CircleAvatar(
                            child: Text(record.daysInMilk.toString()),
                          ),
                          title: Text(
                            'Brinco ${record.tag}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${record.lot} · ${record.type}\n'
                            'DEL ${record.daysInMilk} · Dias IA ${record.daysSinceInsemination} · ${record.inseminationCount} IA(s)',
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
