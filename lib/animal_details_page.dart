import 'package:flutter/material.dart';

import 'animal_lactation_grid.dart';
import 'data/animal_details_repository.dart';
import 'data/animal_record.dart';
import 'data/client_routing.dart';
import 'data/number_format.dart';
import 'data/soap_client.dart';

class AnimalDetailsPage extends StatefulWidget {
  const AnimalDetailsPage({required this.animal, super.key});

  final AnimalRecord animal;

  @override
  State<AnimalDetailsPage> createState() => _AnimalDetailsPageState();
}

class _AnimalDetailsPageState extends State<AnimalDetailsPage> {
  late final SoapClient _client;
  late final AnimalDetailsRepository _repository;
  AnimalMilkSummary? _summary;
  List<AnimalClosedLactation> _closedLactations = const [];
  bool _loadingSummary = true;
  bool _loadingLactations = true;
  String? _summaryError;
  String? _lactationError;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalDetailsRepository(soapClient: _client);
    _loadDetails();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    await Future.wait([_loadSummary(), _loadClosedLactations()]);
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });
    try {
      final summary = await _repository.fetchMilkSummary(widget.animal);
      if (!mounted) return;
      setState(() => _summary = summary);
    } on SoapException catch (error) {
      if (mounted) setState(() => _summaryError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _summaryError = 'Nao foi possivel carregar o resumo.');
      }
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _loadClosedLactations() async {
    setState(() {
      _loadingLactations = true;
      _lactationError = null;
    });
    try {
      final lactations = await _repository.fetchClosedLactations(
        widget.animal.animalCode,
      );
      if (!mounted) return;
      setState(() => _closedLactations = lactations);
    } on SoapException catch (error) {
      if (mounted) setState(() => _lactationError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _lactationError = 'Nao foi possivel carregar as lactacoes.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLactations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animal = widget.animal;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informações do animal'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar informações',
            onPressed: _loadDetails,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _AnimalIdentityHeader(animal: animal),
          const SizedBox(height: 22),
          _sectionTitle(context, 'Dados do animal'),
          _DetailRow(label: 'Raça', value: animal.breed),
          _DetailRow(
            label: 'Status reprodução',
            value: animal.reproductiveStatus,
          ),
          _DetailRow(label: 'Status produção', value: animal.productionStatus),
          _DetailRow(
            label: 'Data último parto',
            value: _date(animal.lastCalvingDate),
          ),
          _DetailRow(label: 'Lactação atual', value: animal.lactationCode),
          _DetailRow(label: 'DEL', value: '${animal.daysInMilk} dias'),
          _DetailRow(
            label: 'Última inseminação',
            value: _date(animal.lastInseminationDate),
          ),
          _DetailRow(
            label: 'Número de IAs',
            value: '${animal.inseminationCount}',
          ),
          const SizedBox(height: 22),
          _sectionTitle(context, 'Produção leiteira'),
          _summaryMetrics(context),
          const SizedBox(height: 22),
          _sectionTitle(context, 'Lactações encerradas'),
          _closedLactationsTable(context),
        ],
      ),
    );
  }

  Widget _summaryMetrics(BuildContext context) {
    if (_loadingSummary) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_summaryError != null) {
      return _InlineLoadError(message: _summaryError!, onRetry: _loadSummary);
    }
    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final metrics = [
          _MetricValue(
            label: 'Total leite',
            value: _number(summary.totalMilk),
            icon: Icons.water_drop_outlined,
          ),
          _MetricValue(
            label: 'Média diária',
            value: _number(summary.averageMilk),
            icon: Icons.show_chart,
          ),
          _MetricValue(
            label: 'Filhas',
            value: '${summary.daughterCount}',
            icon: Icons.pets_outlined,
          ),
        ];
        if (compact) {
          return Column(
            children: [
              for (final metric in metrics)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: metric,
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < metrics.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(child: metrics[index]),
            ],
          ],
        );
      },
    );
  }

  Widget _closedLactationsTable(BuildContext context) {
    if (_loadingLactations) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_lactationError != null) {
      return _InlineLoadError(
        message: _lactationError!,
        onRetry: _loadClosedLactations,
      );
    }
    if (_closedLactations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Nenhuma lactação encerrada.'),
      );
    }

    return AnimalLactationGrid(lactations: _closedLactations);
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  String _date(String value) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return value.isEmpty ? 'Nao informado' : value;
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _number(double value) => formatBrazilianNumber(value);
}

class _AnimalIdentityHeader extends StatelessWidget {
  const _AnimalIdentityHeader({required this.animal});

  final AnimalRecord animal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colors.surface,
            child: Icon(Icons.pets_outlined, color: colors.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Brinco', style: Theme.of(context).textTheme.labelMedium),
                Text(
                  animal.tag,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (animal.discardCode == 1)
            const Tooltip(
              message: 'Animal marcado a descartar',
              child: Icon(Icons.warning_amber_rounded, color: Colors.amber),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      trailing: Text(
        value.isEmpty ? 'Nao informado' : value,
        textAlign: TextAlign.right,
      ),
    );
  }
}

class _MetricValue extends StatelessWidget {
  const _MetricValue({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff1f5f2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLoadError extends StatelessWidget {
  const _InlineLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(message)),
        IconButton(
          tooltip: 'Tentar novamente',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}
