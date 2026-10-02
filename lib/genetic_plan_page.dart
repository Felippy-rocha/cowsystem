import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/genetic_plan_repository.dart';
import 'data/soap_client.dart';

class GeneticPlanPage extends StatefulWidget {
  const GeneticPlanPage({super.key});

  @override
  State<GeneticPlanPage> createState() => _GeneticPlanPageState();
}

class _GeneticPlanPageState extends State<GeneticPlanPage> {
  late final SoapClient _client;
  late final GeneticPlanRepository _repository;
  final TextEditingController _cowController = TextEditingController();
  List<GeneticPlanRecord> _records = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = GeneticPlanRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _cowController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _repository.fetchRecords(
        cow: _cowController.text.trim(),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null) return;
    final date =
        '${picked.day.toString().padLeft(2, '0')}/'
        '${picked.month.toString().padLeft(2, '0')}/'
        '${picked.year}';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repository.generate(date);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plano genético gerado para $date.')),
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano genético'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Gerar plano',
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.playlist_add_outlined),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _cowController,
              decoration: InputDecoration(
                labelText: 'Vaca (brinco)',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _cowController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _cowController.clear();
                          _load();
                        },
                      ),
              ),
              onSubmitted: (_) => _load(),
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
                child: Text('${_records.length} registro(s)'),
              ),
            ),
          Expanded(
            child: _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(child: Text('Nenhum plano genético gerado.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: _records.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(child: Text(record.cow)),
                          title: Text(
                            '${record.date} · OPR ${record.opr}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '1ª ${record.option1.isEmpty ? '—' : record.option1}\n'
                            '2ª ${record.option2.isEmpty ? '—' : record.option2} · '
                            '3ª ${record.option3.isEmpty ? '—' : record.option3}\n'
                            'Sexado ${record.sexed} · Convencional ${record.conventional}'
                            '${record.mating.isEmpty ? '' : ' · ${record.mating}'}',
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
}
