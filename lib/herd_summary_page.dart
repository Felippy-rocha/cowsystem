import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/herd_summary_repository.dart';
import 'data/soap_client.dart';

class HerdSummaryPage extends StatefulWidget {
  const HerdSummaryPage({super.key});

  @override
  State<HerdSummaryPage> createState() => _HerdSummaryPageState();
}

class _HerdSummaryPageState extends State<HerdSummaryPage> {
  late final SoapClient _client;
  late final HerdSummaryRepository _repository;
  final _searchController = TextEditingController();
  List<HerdSummaryRecord> _records = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = HerdSummaryRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _repository.fetchSummary(_searchController.text);
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
      await _repository.generateSummary(_searchController.text);
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

  Future<void> _openDetail(HerdSummaryRecord record) async {
    final detail = await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HerdSummaryDetailPage(
          title: record.description,
          sql: record.sql,
          repository: _repository,
        ),
      ),
    );
    return detail;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo do rebanho'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Descrição da faixa',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Gerar resumo',
                  onPressed: _loading ? null : _generate,
                  icon: const Icon(Icons.analytics_outlined),
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
                ? const Center(child: Text('Nenhum resumo encontrado.'))
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
                          subtitle: Text('${record.quantity} animais'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openDetail(record),
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

class HerdSummaryDetailPage extends StatefulWidget {
  const HerdSummaryDetailPage({
    required this.title,
    required this.sql,
    required this.repository,
    super.key,
  });

  final String title;
  final String sql;
  final HerdSummaryRepository repository;

  @override
  State<HerdSummaryDetailPage> createState() => _HerdSummaryDetailPageState();
}

class _HerdSummaryDetailPageState extends State<HerdSummaryDetailPage> {
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
      await widget.repository.openDetail(widget.sql);
      if (mounted) setState(() => _loading = false);
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
        title: Text(widget.title),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _error != null
            ? Text(_error!, style: TextStyle(color: colors.error))
            : const Text('Detalhe aberto no B4A.'),
      ),
    );
  }
}
