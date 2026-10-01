import 'package:flutter/material.dart';

import 'data/animal_bst_application_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalBstApplicationPage extends StatefulWidget {
  const AnimalBstApplicationPage({super.key});

  @override
  State<AnimalBstApplicationPage> createState() =>
      _AnimalBstApplicationPageState();
}

class _AnimalBstApplicationPageState extends State<AnimalBstApplicationPage> {
  late final SoapClient _client;
  late final AnimalBstApplicationRepository _repository;
  DateTime _date = DateTime.now();
  List<BstApplicationLot> _lots = const [];
  List<BstApplicationRecord> _records = const [];
  int? _lotCode;
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalBstApplicationRepository(soapClient: _client);
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
      final lots = await _repository.fetchLots();
      final records = await _repository.fetchApplications(
        _sqlDate(_date),
        lotCode: _lotCode,
      );
      if (!mounted) return;
      setState(() {
        _lots = lots;
        _records = records;
        _lotCode = _lots.any((lot) => lot.code == _lotCode) ? _lotCode : null;
        _loading = false;
      });
      if (records.isEmpty && _lotCode == null) {
        await _offerListCreation();
      }
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadFiltered() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _repository.fetchApplications(
        _sqlDate(_date),
        lotCode: _lotCode,
      );
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
      if (records.isEmpty && _lotCode == null) {
        await _offerListCreation();
      }
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _offerListCreation() async {
    if (!mounted || _creating) return;
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lista BST vazia'),
        content: Text(
          'Deseja criar a lista de aplicação para ${_displayDate(_date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Criar lista'),
          ),
        ],
      ),
    );
    if (create == true) await _createList();
  }

  Future<void> _createList() async {
    setState(() {
      _creating = true;
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository.createApplicationList(_sqlDate(_date));
      if (!mounted) return;
      if (result != 1) {
        setState(() {
          _error =
              'Data inválida. O dia configurado para aplicação é '
              '${_weekdayName(result)}.';
          _creating = false;
          _loading = false;
        });
        return;
      }
      setState(() => _creating = false);
      await _loadFiltered();
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _creating = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    setState(() => _date = date);
    await _loadFiltered();
  }

  Future<void> _markApplied(BstApplicationRecord record) async {
    try {
      await _repository.markApplied(record.id);
      await _loadFiltered();
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _delete(BstApplicationRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar animal do BST?'),
        content: Text(
          'O brinco ${record.tag} será removido da lista pendente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deletePending(record.id);
      await _loadFiltered();
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final completed = _records.where((record) => record.applied).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aplicar BST'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Criar lista BST',
            onPressed: _loading || _creating ? null : _createList,
            icon: const Icon(Icons.playlist_add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _loading ? null : _chooseDate,
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data da aplicação',
                            prefixIcon: Icon(Icons.calendar_month_outlined),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_displayDate(_date)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: 'Pesquisar aplicações',
                      onPressed: _loading ? null : _loadFiltered,
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: _lotCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Lote',
                    prefixIcon: Icon(Icons.grid_view_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos os lotes'),
                    ),
                    ..._lots.map(
                      (lot) => DropdownMenuItem<int?>(
                        value: lot.code,
                        child: Text(lot.name),
                      ),
                    ),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _lotCode = value);
                          _loadFiltered();
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
              child: Row(
                children: [
                  Text('${_records.length} animais'),
                  const Spacer(),
                  Text('$completed aplicadas'),
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle_outline, size: 18),
                ],
              ),
            ),
          Expanded(
            child: _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.medical_services_outlined, size: 42),
                        const SizedBox(height: 12),
                        const Text('Nenhuma aplicação BST nesta data.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _creating ? null : _createList,
                          icon: const Icon(Icons.playlist_add),
                          label: Text(_creating ? 'Criando...' : 'Criar lista'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: _records.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      final done = record.applied;
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: done
                                ? colors.primaryContainer
                                : colors.secondaryContainer,
                            child: Icon(
                              done
                                  ? Icons.check
                                  : Icons.medical_services_outlined,
                              color: done ? colors.primary : colors.secondary,
                            ),
                          ),
                          title: Text(
                            'Brinco ${record.tag}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${record.hormone} · ${_quantity(record.quantity)} dose(s)\n'
                            '${record.lot} · ${record.productionStatus} · ${record.reproductiveStatus}'
                            '${record.expectedDryOff.isEmpty ? '' : '\nSecagem: ${record.expectedDryOff}'}',
                          ),
                          isThreeLine: true,
                          trailing: done
                              ? const Tooltip(
                                  message: 'Aplicação concluída',
                                  child: Icon(Icons.check_circle),
                                )
                              : PopupMenuButton<String>(
                                  tooltip: 'Ações da aplicação',
                                  onSelected: (action) {
                                    if (action == 'apply') _markApplied(record);
                                    if (action == 'remove') _delete(record);
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'apply',
                                      child: Text('Marcar aplicada'),
                                    ),
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Retirar da lista'),
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

  String _sqlDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _quantity(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  String _weekdayName(int weekday) => switch (weekday) {
    1 => 'segunda-feira',
    2 => 'terça-feira',
    3 => 'quarta-feira',
    4 => 'quinta-feira',
    5 => 'sexta-feira',
    6 => 'sábado',
    7 => 'domingo',
    _ => 'não identificado',
  };
}
