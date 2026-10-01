import 'package:flutter/material.dart';

import 'data/animal_birth_repository.dart' show BirthOption;
import 'data/animal_precalving_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalPrecalvingPage extends StatefulWidget {
  const AnimalPrecalvingPage({super.key});

  @override
  State<AnimalPrecalvingPage> createState() => _AnimalPrecalvingPageState();
}

class _AnimalPrecalvingPageState extends State<AnimalPrecalvingPage> {
  late final SoapClient _client;
  late final AnimalPrecalvingRepository _repository;
  final _tagController = TextEditingController();
  List<AnimalPrecalvingCandidate> _animals = const [];
  List<BirthOption> _lots = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalPrecalvingRepository(soapClient: _client);
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
      final results = await Future.wait<dynamic>([
        _repository.fetchCandidates(tag: _tagController.text),
        _repository.fetchLots(),
      ]);
      if (!mounted) return;
      setState(() {
        _animals = results[0] as List<AnimalPrecalvingCandidate>;
        _lots = results[1] as List<BirthOption>;
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

  Future<void> _addToPrecalving(AnimalPrecalvingCandidate animal) async {
    if (_lots.isEmpty) {
      _showMessage(
        'Cadastre um lote de destino antes de incluir no pré-parto.',
      );
      return;
    }
    final draft = await showDialog<_PrecalvingDraft>(
      context: context,
      builder: (context) => _PrecalvingForm(animal: animal, lots: _lots),
    );
    if (draft == null || !mounted) return;
    try {
      setState(() => _loading = true);
      await _repository.addToPrecalving(
        animalCode: animal.animalCode,
        date: draft.date,
        destinationLotCode: draft.lotCode,
        comment: draft.comment,
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pré-Parto'),
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
            child: TextField(
              controller: _tagController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Brinco',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Pesquisar brinco',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.search),
                ),
                border: const OutlineInputBorder(),
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
          Expanded(
            child: _animals.isEmpty && !_loading
                ? const Center(child: Text('Nenhuma vaca apta para pré-parto.'))
                : ListView.separated(
                    itemCount: _animals.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _animalTile(_animals[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _animalTile(AnimalPrecalvingCandidate animal) {
    final overdue = _isPast(animal.predictedDate);
    return ListTile(
      onTap: () => _addToPrecalving(animal),
      leading: CircleAvatar(
        backgroundColor: overdue
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.event_available_outlined,
          color: overdue ? Theme.of(context).colorScheme.error : null,
        ),
      ),
      title: Text(
        animal.tag,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Entrada prevista: ${animal.predictedDate.isEmpty ? 'N/D' : animal.predictedDate}'
        ' · ${animal.productionStatus} · ${animal.reproductiveStatus}'
        '${animal.lastInsemination.isEmpty ? '' : ' · Última IA ${animal.lastInsemination}'}'
        '${animal.lot.isEmpty ? '' : ' · Lote ${animal.lot}'}',
        style: TextStyle(
          color: overdue ? Theme.of(context).colorScheme.error : null,
        ),
      ),
      trailing: IconButton(
        tooltip: 'Incluir no pré-parto',
        onPressed: () => _addToPrecalving(animal),
        icon: const Icon(Icons.add_circle_outline),
      ),
    );
  }

  bool _isPast(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
    if (match == null) return false;
    final date = DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
    final today = DateTime.now();
    return date.isBefore(DateTime(today.year, today.month, today.day));
  }
}

class _PrecalvingDraft {
  const _PrecalvingDraft({
    required this.date,
    required this.lotCode,
    required this.comment,
  });

  final String date;
  final int lotCode;
  final String comment;
}

class _PrecalvingForm extends StatefulWidget {
  const _PrecalvingForm({required this.animal, required this.lots});

  final AnimalPrecalvingCandidate animal;
  final List<BirthOption> lots;

  @override
  State<_PrecalvingForm> createState() => _PrecalvingFormState();
}

class _PrecalvingFormState extends State<_PrecalvingForm> {
  DateTime _date = DateTime.now();
  int? _lotCode;
  String _comment = '';
  String? _error;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Incluir brinco ${widget.animal.tag} no pré-parto'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Data de entrada'),
          subtitle: Text(_displayDate(_date)),
          trailing: const Icon(Icons.calendar_month_outlined),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) setState(() => _date = date);
          },
        ),
        DropdownButtonFormField<int>(
          initialValue: widget.lots.any((item) => item.code == _lotCode)
              ? _lotCode
              : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Lote de destino'),
          items: widget.lots
              .map(
                (item) =>
                    DropdownMenuItem(value: item.code, child: Text(item.name)),
              )
              .toList(growable: false),
          onChanged: (value) => setState(() => _lotCode = value),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Comentário',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _comment = value,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _save, child: const Text('Salvar pré-parto')),
    ],
  );

  void _save() {
    if (_lotCode == null) {
      setState(() => _error = 'Selecione o lote de destino.');
      return;
    }
    Navigator.pop(
      context,
      _PrecalvingDraft(
        date: _formatDate(_date),
        lotCode: _lotCode!,
        comment: _comment,
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
