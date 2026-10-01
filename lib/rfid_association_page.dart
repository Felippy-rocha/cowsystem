import 'package:flutter/material.dart';

import 'data/animal_record.dart';
import 'data/animal_repository.dart';
import 'data/client_routing.dart';
import 'data/permission_repository.dart';
import 'data/soap_client.dart';

class RfidAssociationPage extends StatefulWidget {
  const RfidAssociationPage({super.key});

  @override
  State<RfidAssociationPage> createState() => _RfidAssociationPageState();
}

class _RfidAssociationPageState extends State<RfidAssociationPage> {
  late final SoapClient _client;
  late final AnimalRepository _repository;
  late final PermissionRepository _permissions;
  final _tagController = TextEditingController();
  final _chipController = TextEditingController();
  List<AnimalRecord> _animals = const [];
  AnimalRecord? _selected;
  bool _loading = true;
  bool _authorized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalRepository(soapClient: _client);
    _permissions = PermissionRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _tagController.dispose();
    _chipController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = ClientRoutingSession.profileCode;
      if (profile <= 0) {
        if (!mounted) return;
        setState(() {
          _authorized = false;
          _error = 'Seu perfil não autoriza associar chips.';
          _loading = false;
        });
        return;
      }
      final catalog = await _permissions.fetchPermissionCatalog();
      final definitions = catalog
          .where((permission) {
            final routine = permission.routine.trim().toUpperCase();
            final action = permission.action.trim().toUpperCase();
            return routine == 'ANIMAIS' &&
                (action.contains('CHIP') || action.contains('RFID'));
          })
          .toList(growable: false);
      final profilePermissions = await _permissions.fetchProfilePermissions(
        profile,
      );
      final allowed = definitions.any(
        (permission) => profilePermissions[permission.code] == true,
      );
      if (!allowed) {
        if (!mounted) return;
        setState(() {
          _authorized = false;
          _error = 'Seu perfil não autoriza associar chips.';
          _loading = false;
        });
        return;
      }
      final animals = await _repository.fetchAnimals(
        where: "WHERE ATIVO = 1 AND DOADORA IN (2, 3) AND STATUSPRODUCAO = 'EM LEITE'",
      );
      if (!mounted) return;
      setState(() {
        _authorized = true;
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

  Future<void> _selectAnimal(AnimalRecord animal) async {
    setState(() {
      _selected = animal;
      _tagController.text = animal.tag;
      _chipController.text = animal.electronicTag;
      _error = null;
    });
  }

  Future<void> _save() async {
    final animal = _selected;
    final chip = _chipController.text.trim();
    if (animal == null || chip.isEmpty) {
      setState(() => _error = 'Informe o brinco e o código do chip RFID.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repository.associateChip(
        animalCode: animal.animalCode,
        chipCode: chip,
      );
      if (!mounted) return;
      setState(() {
        _chipController.clear();
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chip associado ao brinco ${animal.tag}.')),
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
    final query = _tagController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _animals
        : _animals
              .where(
                (animal) =>
                    animal.tag.toLowerCase().contains(query) ||
                    animal.electronicTag.toLowerCase().contains(query),
              )
              .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Associar chip RFID'),
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
            child: Column(
              children: [
                TextField(
                  controller: _tagController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Buscar brinco ou chip',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _chipController,
                  keyboardType: TextInputType.number,
                  enabled: _authorized && !_loading,
                  decoration: InputDecoration(
                    labelText: _selected == null
                        ? 'Selecione um animal'
                        : 'Chip RFID do brinco ${_selected!.tag}',
                    prefixIcon: const Icon(Icons.memory_outlined),
                    border: const OutlineInputBorder(),
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
          if (_selected != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: FilledButton.icon(
                onPressed: _loading || !_authorized ? null : _save,
                icon: const Icon(Icons.link),
                label: Text(
                  _loading
                      ? 'Associando...'
                      : 'Associar ao brinco ${_selected!.tag}',
                ),
              ),
            ),
          Expanded(
            child: _loading && _animals.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? const Center(child: Text('Nenhum animal encontrado.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final animal = filtered[index];
                      final selected =
                          animal.animalCode == _selected?.animalCode;
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: selected
                                ? colors.primaryContainer
                                : colors.secondaryContainer,
                            child: Icon(
                              animal.electronicTag.isEmpty
                                  ? Icons.nfc_outlined
                                  : Icons.check_circle,
                            ),
                          ),
                          title: Text(
                            'Brinco ${animal.tag}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${animal.electronicTag.isEmpty ? 'Sem chip associado' : 'Chip ${animal.electronicTag}'}\n${animal.reproductiveStatus} · ${animal.productionStatus}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _selectAnimal(animal),
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
