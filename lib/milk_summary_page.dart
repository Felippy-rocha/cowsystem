import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/milk_summary_repository.dart';
import 'data/soap_client.dart';

class MilkSummaryPage extends StatefulWidget {
  const MilkSummaryPage({super.key});

  @override
  State<MilkSummaryPage> createState() => _MilkSummaryPageState();
}

class _MilkSummaryPageState extends State<MilkSummaryPage>
    with SingleTickerProviderStateMixin {
  late final SoapClient _client;
  late final MilkSummaryRepository _repository;
  late final TabController _tabs;
  List<String> _periods = const [];
  List<MilkSummaryRecord> _records = const [];
  String? _period;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = MilkSummaryRepository(soapClient: _client);
    _tabs = TabController(length: 4, vsync: this)..addListener(_tabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_tabChanged)
      ..dispose();
    _client.close();
    super.dispose();
  }

  void _tabChanged() {
    if (_tabs.indexIsChanging || !mounted) return;
    setState(() {});
    final period = _period;
    if (period != null) _loadRecords(period);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final periods = await _repository.fetchPeriods();
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _period = periods.firstOrNull;
        _loading = false;
      });
      final period = _period;
      if (period != null) await _loadRecords(period);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRecords(String period) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = switch (_tabs.index) {
        0 => await _repository.fetchMonthly(period),
        1 => await _repository.fetchByLactation(period),
        2 => await _repository.fetchByBreed(period),
        3 => await _repository.fetchByLot(period),
        _ => await _repository.fetchMonthly(period),
      };
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

  Future<void> _openDailyDetail(MilkSummaryRecord record) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            MilkDailyDetailPage(date: record.date, repository: _repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo de leite'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Mensal'),
            Tab(text: 'Lactações'),
            Tab(text: 'Raça'),
            Tab(text: 'Lote'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: DropdownButtonFormField<String>(
              initialValue: _periods.contains(_period) ? _period : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Período',
                prefixIcon: Icon(Icons.calendar_month_outlined),
                border: OutlineInputBorder(),
              ),
              items: _periods
                  .map(
                    (period) =>
                        DropdownMenuItem(value: period, child: Text(period)),
                  )
                  .toList(growable: false),
              onChanged: _loading
                  ? null
                  : (value) {
                      setState(() => _period = value);
                      if (value != null) _loadRecords(value);
                    },
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
                ? const Center(
                    child: Text('Nenhum registro no período selecionado.'),
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
                            child: Text(record.del.toString()),
                          ),
                          title: Text(
                            record.date,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${record.animals} animais · ${_quantity(record.totalMilk)} kg\n'
                            'Média ${_quantity(record.average)} kg/animal · DEL ${record.del}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openDailyDetail(record),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
}

class MilkDailyDetailPage extends StatefulWidget {
  const MilkDailyDetailPage({
    required this.date,
    required this.repository,
    super.key,
  });

  final String date;
  final MilkSummaryRepository repository;

  @override
  State<MilkDailyDetailPage> createState() => _MilkDailyDetailPageState();
}

class _MilkDailyDetailPageState extends State<MilkDailyDetailPage> {
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
      await widget.repository.fetchMonthly(widget.date);
      if (!mounted) return;
      setState(() {
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.date),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: TextStyle(color: colors.error)),
            )
          : const Center(child: Text('Detalhe diário aberto no B4A.')),
    );
  }
}
