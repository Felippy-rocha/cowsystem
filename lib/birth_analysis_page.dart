import 'package:flutter/material.dart';

import 'data/birth_analysis_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class BirthAnalysisPage extends StatefulWidget {
  const BirthAnalysisPage({super.key});

  @override
  State<BirthAnalysisPage> createState() => _BirthAnalysisPageState();
}

class _BirthAnalysisPageState extends State<BirthAnalysisPage> {
  late final SoapClient _client;
  late final BirthAnalysisRepository _repository;
  final _dateStartController = TextEditingController();
  final _dateEndController = TextEditingController();
  List<BirthAnalysisRecord> _records = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = BirthAnalysisRepository(soapClient: _client);
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
      final records = await _repository.fetchRecords();
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
      await _repository.generate(
        _dateStartController.text,
        _dateEndController.text,
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
      await _generate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise de partos'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Gerar relatório',
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
                    controller: _dateStartController,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Data inicial',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onTap: () => _pickDate(true),
                    onSubmitted: (_) => _generate(),
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
                    onSubmitted: (_) => _generate(),
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
          if (_records.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${_records.length} faixa(s)'),
              ),
            ),
          Expanded(
            child: _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma faixa de parto no período selecionado.',
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
                          leading: CircleAvatar(child: Text('${record.order}')),
                          title: Text(
                            record.description,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: Text('${record.quantity}'),
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
