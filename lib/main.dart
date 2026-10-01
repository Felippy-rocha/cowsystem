import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:android_id/android_id.dart';

import 'animals_roster_page.dart';
import 'animal_carency_page.dart';
import 'animal_diagnosis_page.dart';
import 'animal_birth_page.dart';
import 'animal_abortion_page.dart';
import 'animal_body_condition_page.dart';
import 'animal_dry_off_page.dart';
import 'animal_insemination_page.dart';
import 'animal_precalving_page.dart';
import 'animal_weight_page.dart';
import 'animal_weaning_page.dart';
import 'animal_treatment_application_page.dart';
import 'animal_hoof_trimming_page.dart';
import 'animal_bst_application_page.dart';
import 'animal_bst_page.dart';
import 'dry_matter_history_page.dart';
import 'animal_protocol_page.dart';
import 'animal_feeding_page.dart';
import 'data/animal_record.dart';
import 'data/animal_repository.dart';
import 'data/client_routing.dart';
import 'data/client_routing_repository.dart';
import 'data/lot_record.dart';
import 'data/lot_repository.dart';
import 'data/permission_repository.dart';
import 'data/soap_client.dart';
import 'agro_pages.dart';

void main() {
  runApp(const CowSystemApp());
}

class CowSystemApp extends StatelessWidget {
  const CowSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CowSystem',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff176b5b),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff3f7f5),
        useMaterial3: true,
      ),
      home: const ClientRoutingGate(),
    );
  }
}

class ClientRoutingGate extends StatefulWidget {
  const ClientRoutingGate({super.key});

  @override
  State<ClientRoutingGate> createState() => _ClientRoutingGateState();
}

class _ClientRoutingGateState extends State<ClientRoutingGate> {
  static const _enabled = bool.fromEnvironment(
    'COWSYSTEM_RESOLVE_CLIENT',
    defaultValue: true,
  );

  late Future<void> _routingFuture;
  String? _errorMessage;
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _routingFuture = _resolveRouting();
  }

  Future<void> _resolveRouting() async {
    if (!_enabled) return;
    final deviceId = await _readAndroidId();
    _deviceId = deviceId ?? '';
    if (deviceId == null || deviceId.isEmpty) {
      _errorMessage = 'Nao foi possivel identificar este dispositivo.';
      return;
    }

    final client = SoapClient(deviceId: deviceId);
    try {
      await ClientRoutingRepository(soapClient: client).resolveDevice();
    } on SoapException catch (error) {
      _errorMessage = error.message;
    } finally {
      client.close();
    }
  }

  Future<String?> _readAndroidId() async {
    try {
      return await const AndroidId().getId();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return const HomePage();
    return FutureBuilder<void>(
      future: _routingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (_errorMessage != null) {
          return DeviceAuthorizationPage(
            deviceId: _deviceId,
            message: _errorMessage!,
            onRetry: () => setState(() {
              _errorMessage = null;
              _routingFuture = _resolveRouting();
            }),
          );
        }
        return const HomePage();
      },
    );
  }
}

class DeviceAuthorizationPage extends StatelessWidget {
  const DeviceAuthorizationPage({
    required this.deviceId,
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String deviceId;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autorizar dispositivo'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phonelink_lock_outlined,
                size: 72,
                color: colors.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                'Este dispositivo ainda não está liberado.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              const Text('Envie este ID ao administrador:'),
              const SizedBox(height: 8),
              SelectableText(
                deviceId.isEmpty ? 'ID indisponível' : deviceId,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: deviceId.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: deviceId));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ID copiado.')),
                          );
                        }
                      },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copiar ID'),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = ClientRoutingSession.username.trim();
    final company = ClientRoutingSession.company.trim();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'CowSystem',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Notificações',
            onPressed: () => _showMessage(context, 'Nenhuma notificacao nova.'),
            icon: const Icon(Icons.notifications_none_outlined),
          ),
          IconButton(
            tooltip: 'Perfil',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UserProfilePage(),
                ),
              );
            },
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    username.isEmpty ? 'Olá' : 'Olá, $username',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (company.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      company,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Visao geral da fazenda',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Acompanhe o rebanho e as atividades do dia.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _StatusBanner(),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 620 ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: columns == 4 ? 1.45 : 1.3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: const [
                          _MetricCard(
                            label: 'Rebanho',
                            value: '--',
                            icon: Icons.pets_outlined,
                          ),
                          _MetricCard(
                            label: 'Leite hoje',
                            value: '-- L',
                            icon: Icons.water_drop_outlined,
                          ),
                          _MetricCard(
                            label: 'Tarefas abertas',
                            value: '--',
                            icon: Icons.checklist_outlined,
                          ),
                          _MetricCard(
                            label: 'Alertas',
                            value: '--',
                            icon: Icons.warning_amber_outlined,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Acesso rapido',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _QuickAccessGrid(),
                  const SizedBox(height: 24),
                  Text(
                    'Modulos',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _ModuleList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  String _value(String value, String fallback) =>
      value.trim().isEmpty ? fallback : value.trim();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final username = _value(ClientRoutingSession.username, 'Não informado');
    final company = _value(ClientRoutingSession.company, 'Não informada');
    final profile = _value(
      ClientRoutingSession.profileDescription,
      'Não informado',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: colors.primaryContainer,
            child: Icon(
              Icons.person_outline,
              size: 38,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              username,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 24),
          _profileField(context, 'Usuário', username, Icons.person_outline),
          _profileField(context, 'Empresa', company, Icons.business_outlined),
          _profileField(
            context,
            'Perfil de acesso',
            profile,
            Icons.security_outlined,
          ),
          _profileField(
            context,
            'Dispositivo',
            _value(ClientRoutingSession.deviceId ?? '', 'Não informado'),
            Icons.smartphone_outlined,
          ),
          const SizedBox(height: 16),
          Text(
            'As permissões são administradas pelo administrador.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (ClientRoutingSession.canGrantPermissions) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfilePermissionsPage(),
                ),
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Gerenciar perfis e permissões'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _profileField(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

class ModulePage extends StatelessWidget {
  const ModulePage({required this.title, super.key});

  final String title;

  List<_ModuleEntry> get _entries {
    switch (title) {
      case 'Cadastros':
        return const [
          _ModuleEntry('Animais', Icons.pets_outlined),
          _ModuleEntry('Lotes', Icons.grid_view_outlined),
          _ModuleEntry('Ingredientes', Icons.grass_outlined),
          _ModuleEntry('Plantios', Icons.agriculture_outlined),
          _ModuleEntry('Safras', Icons.calendar_month_outlined),
          _ModuleEntry('Silos', Icons.warehouse_outlined),
          _ModuleEntry('Talhões', Icons.landscape_outlined),
          _ModuleEntry('Fornecedores', Icons.local_shipping_outlined),
          _ModuleEntry('Insumos gerais', Icons.inventory_2_outlined),
          _ModuleEntry('Medicamentos', Icons.medication_outlined),
          _ModuleEntry('Protocolos', Icons.assignment_outlined),
          _ModuleEntry('Tratamentos', Icons.healing_outlined),
          _ModuleEntry('Touros', Icons.pets_outlined),
          _ModuleEntry('Doenças', Icons.health_and_safety_outlined),
          _ModuleEntry('Tipos de IAs', Icons.science_outlined),
          _ModuleEntry('Local de estocagem', Icons.warehouse_outlined),
          _ModuleEntry('Motivos de descarte', Icons.delete_outline),
          _ModuleEntry('Tipo comentário', Icons.comment_outlined),
          _ModuleEntry('Tipos de insumos', Icons.category_outlined),
          _ModuleEntry('Tipo medicamento', Icons.medication_outlined),
          _ModuleEntry('Tipos de tratamentos', Icons.healing_outlined),
          _ModuleEntry('Raças', Icons.pets_outlined),
        ];
      case 'Serviços':
        return const [
          _ModuleEntry('Registrar aborto', Icons.healing_outlined),
          _ModuleEntry('Estornar aborto', Icons.undo_outlined),
          _ModuleEntry('Animais carência', Icons.medical_services_outlined),
          _ModuleEntry('Controle leiteiro', Icons.water_drop_outlined),
          _ModuleEntry('Pesagem', Icons.monitor_weight_outlined),
          _ModuleEntry('Inseminação', Icons.science_outlined),
          _ModuleEntry('Incluir BST', Icons.medical_services_outlined),
          _ModuleEntry('Aplicar BST', Icons.medical_services_outlined),
          _ModuleEntry('Protocolar', Icons.assignment_outlined),
          _ModuleEntry('Tratos', Icons.restaurant_outlined),
          _ModuleEntry('Aplicar tratamento', Icons.medical_services_outlined),
          _ModuleEntry('Atualizar MS', Icons.opacity_outlined),
          _ModuleEntry('Avaliação de ECC', Icons.monitor_weight_outlined),
          _ModuleEntry('Diagnóstico gestacional', Icons.monitor_heart_outlined),
          _ModuleEntry('Parto', Icons.child_friendly_outlined),
          _ModuleEntry('Registrar desmame', Icons.swap_horiz_outlined),
          _ModuleEntry('Registrar secagem', Icons.opacity_outlined),
          _ModuleEntry('Pré-Parto', Icons.pregnant_woman_outlined),
          _ModuleEntry('Casqueamento', Icons.content_cut_outlined),
        ];
      case 'Relatorios':
        return const [
          _ModuleEntry('Resumo do rebanho', Icons.pets_outlined),
          _ModuleEntry('Resumo de leite', Icons.water_drop_outlined),
          _ModuleEntry('Analise de consumo', Icons.analytics_outlined),
          _ModuleEntry('Analise de partos', Icons.family_restroom_outlined),
          _ModuleEntry('Previsao de toque', Icons.event_available_outlined),
          _ModuleEntry('Tarefas em aberto', Icons.checklist_outlined),
        ];
      case 'Ajustes':
        return const [
          _ModuleEntry('Perfil', Icons.person_outline),
          _ModuleEntry('Sincronização', Icons.sync_outlined),
          _ModuleEntry('Notificações', Icons.notifications_none_outlined),
          _ModuleEntry('Configurações', Icons.settings_outlined),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return Card(
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 6,
              ),
              leading: Icon(entry.icon, color: colors.primary),
              title: Text(
                entry.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) {
                      if (entry.label == 'Animais') {
                        return AnimalRosterPage(
                          openAnimalForm: (formContext) =>
                              Navigator.of(formContext).push<AnimalRecord>(
                                MaterialPageRoute<AnimalRecord>(
                                  builder: (_) => const AnimalFormPage(),
                                ),
                              ),
                        );
                      }
                      if (entry.label == 'Lotes') return const LotsPage();
                      if (entry.label == 'Ingredientes') {
                        return AgroCatalogPage(config: ingredientsConfig());
                      }
                      if (entry.label == 'Plantios') {
                        return AgroCatalogPage(config: plantiosConfig());
                      }
                      if (entry.label == 'Safras') {
                        return AgroCatalogPage(config: safraConfig());
                      }
                      if (entry.label == 'Silos') {
                        return AgroCatalogPage(config: siloConfig());
                      }
                      if (entry.label == 'Talhões') {
                        return AgroCatalogPage(config: talhoesConfig());
                      }
                      if (entry.label == 'Fornecedores') {
                        return AgroCatalogPage(config: suppliersConfig());
                      }
                      if (entry.label == 'Tratamentos') {
                        return AgroCatalogPage(config: treatmentsConfig());
                      }
                      if (entry.label == 'Doenças') {
                        return AgroCatalogPage(
                          config: simpleTableCatalogConfig(
                            title: 'Doenças',
                            table: 'TB_DOENCAS',
                            idColumn: 'CODDOENCA',
                            descriptionColumn: 'DOENCA',
                          ),
                        );
                      }
                      if (entry.label == 'Tipos de IAs') {
                        return AgroCatalogPage(
                          config: inseminationTypesConfig(),
                        );
                      }
                      if (entry.label == 'Raças') {
                        return AgroCatalogPage(config: breedsConfig());
                      }
                      if (entry.label == 'Local de estocagem') {
                        return AgroCatalogPage(
                          config: simpleTableCatalogConfig(
                            title: 'Local',
                            table: 'TB_LOCALESTOQUE',
                            idColumn: 'CODLOCAL',
                            descriptionColumn: 'LOCAL',
                          ),
                        );
                      }
                      if (entry.label == 'Motivos de descarte') {
                        return AgroCatalogPage(
                          config: simpleTableCatalogConfig(
                            title: 'Motivo descarte',
                            table: 'TB_MOTIVODESCARTE',
                            idColumn: 'CODMOTIVODESCARTE',
                            descriptionColumn: 'MOTIVODESCARTE',
                          ),
                        );
                      }
                      if (entry.label == 'Tipo comentário') {
                        return AgroCatalogPage(
                          config: simpleTableCatalogConfig(
                            title: 'Tipo comentário',
                            table: 'TB_TIPOCOMENTARIO',
                            idColumn: 'CODTIPO',
                            descriptionColumn: 'TIPOCOMENTARIO',
                          ),
                        );
                      }
                      if (entry.label == 'Tipos de insumos') {
                        return AgroCatalogPage(
                          config: simpleTableCatalogConfig(
                            title: 'Insumos',
                            table: 'TB_TIPOINSUMOS',
                            idColumn: 'CODTIPOINSUMO',
                            descriptionColumn: 'INSUMO',
                          ),
                        );
                      }
                      if (entry.label == 'Tipo medicamento') {
                        return AgroCatalogPage(
                          config: simpleTableCatalogConfig(
                            title: 'Tipo medicamento',
                            table: 'TB_TIPOMEDICAMENTO',
                            idColumn: 'CODTIPOMEDICAMENTO',
                            descriptionColumn: 'TIPOMEDICAMENTO',
                          ),
                        );
                      }
                      if (entry.label == 'Tipos de tratamentos') {
                        return AgroCatalogPage(
                          config: simpleTableCatalogConfig(
                            title: 'Tipos de tratamentos',
                            table: 'TB_TIPOTRATAMENTO',
                            idColumn: 'CODTIPOTRATAMENTO',
                            descriptionColumn: 'TIPOTRATAMENTO',
                          ),
                        );
                      }
                      if (entry.label == 'Perfil') {
                        return const ProfilePermissionsPage();
                      }
                      if (entry.label == 'Animais carência') {
                        return const AnimalCarencyPage();
                      }
                      if (entry.label == 'Registrar aborto') {
                        return const AnimalAbortionPage();
                      }
                      if (entry.label == 'Estornar aborto') {
                        return const AnimalAbortionPage(reverse: true);
                      }
                      if (entry.label == 'Diagnóstico gestacional') {
                        return const AnimalDiagnosisPage();
                      }
                      if (entry.label == 'Avaliação de ECC') {
                        return const AnimalBodyConditionPage();
                      }
                      if (entry.label == 'Inseminação') {
                        return const AnimalInseminationPage();
                      }
                      if (entry.label == 'Incluir BST') {
                        return const AnimalBstPage();
                      }
                      if (entry.label == 'Aplicar BST') {
                        return const AnimalBstApplicationPage();
                      }
                      if (entry.label == 'Protocolar') {
                        return const AnimalProtocolPage();
                      }
                      if (entry.label == 'Tratos') {
                        return const AnimalFeedingPage();
                      }
                      if (entry.label == 'Aplicar tratamento') {
                        return const AnimalTreatmentApplicationPage();
                      }
                      if (entry.label == 'Atualizar MS') {
                        return const DryMatterHistoryPage();
                      }
                      if (entry.label == 'Parto') {
                        return const AnimalBirthPage();
                      }
                      if (entry.label == 'Registrar desmame') {
                        return const AnimalWeaningPage();
                      }
                      if (entry.label == 'Registrar secagem') {
                        return const AnimalDryOffPage();
                      }
                      if (entry.label == 'Pré-Parto') {
                        return const AnimalPrecalvingPage();
                      }
                      if (entry.label == 'Pesagem') {
                        return const AnimalWeightPage();
                      }
                      if (entry.label == 'Casqueamento') {
                        return const AnimalHoofTrimmingPage();
                      }
                      return ModulePage(title: entry.label);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ModuleEntry {
  const _ModuleEntry(this.label, this.icon);

  final String label;
  final IconData icon;
}

class LotsPage extends StatefulWidget {
  const LotsPage({super.key});

  @override
  State<LotsPage> createState() => _LotsPageState();
}

class _LotsPageState extends State<LotsPage> {
  final _searchController = TextEditingController();
  late final SoapClient _soapClient;
  late final LotRepository _repository;
  List<LotRecord> _lots = const [];
  int _selectedTab = 0;
  int? _selectedLotCode;
  bool _isLoading = false;
  String? _errorMessage;
  late final PermissionRepository _permissionRepository;
  Map<int, String> _feedingLocations = const {};
  Map<int, bool> _lotPermissions = const {};
  List<PermissionDefinitionRecord> _permissionCatalog = const [];

  @override
  void initState() {
    super.initState();
    _soapClient = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = LotRepository(soapClient: _soapClient);
    _permissionRepository = PermissionRepository(soapClient: _soapClient);
    _loadLots();
    _loadLotPermissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _soapClient.close();
    super.dispose();
  }

  bool _lotActionAllowed(String action) {
    final definition = _permissionCatalog.where(
      (item) =>
          item.routine.toUpperCase() == 'LOTES' &&
          item.action.toUpperCase().startsWith(action.toUpperCase()),
    );
    final code = definition.isEmpty ? null : definition.first.code;
    return code != null && _lotPermissions[code] == true;
  }

  Future<void> _loadLotPermissions() async {
    final profile = ClientRoutingSession.profileCode;
    if (profile <= 0) return;
    try {
      final catalog = await _permissionRepository.fetchPermissionCatalog();
      final permissions = await _permissionRepository.fetchProfilePermissions(
        profile,
      );
      if (!mounted) return;
      setState(() {
        _permissionCatalog = catalog;
        _lotPermissions = permissions;
      });
      try {
        final locations = await _repository.fetchFeedingLocations();
        if (mounted) setState(() => _feedingLocations = locations);
      } on SoapException catch (error) {
        if (mounted) setState(() => _errorMessage = error.message);
      }
    } on SoapException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    }
  }

  List<LotRecord> get _filteredLots {
    final query = _searchController.text.trim().toLowerCase();
    return _lots
        .where((lot) => lot.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loadLots,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Adicionar lote',
            onPressed: _lotActionAllowed('INCLUIR') ? _openLotForm : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Lote',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Lista')),
              ButtonSegment(value: 1, label: Text('Grid')),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (selection) {
              setState(() => _selectedTab = selection.first);
            },
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLots.isEmpty
                ? Center(
                    child: Text(
                      _errorMessage ?? 'Nenhum lote cadastrado',
                      textAlign: TextAlign.center,
                    ),
                  )
                : _selectedTab == 0
                ? ListView.separated(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
                    itemCount: _filteredLots.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _lotListTile(_filteredLots[index]),
                  )
                : _lotsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _lotListTile(LotRecord lot) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      title: Text(
        lot.name,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Status: ${_lotStatusLabel(lot)}\n'
        'Dieta: ${_lotDietLabel(lot)}\n'
        'DG: ${_binaryLabel(lot.pregnancyDiagnosis)} | '
        'Aleitamento: ${_binaryLabel(lot.milkFeeding)}',
        style: const TextStyle(fontSize: 15, height: 1.5),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opcoes do lote',
        onSelected: (action) {
          if (action == 'edit' && _lotActionAllowed('ALTERAR'))
            _openLotForm(lot);
          if (action == 'delete' && _lotActionAllowed('EXCLUIR'))
            _confirmDelete(lot);
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'edit',
            enabled: _lotActionAllowed('ALTERAR'),
            child: const Text('Alterar'),
          ),
          PopupMenuItem(
            value: 'delete',
            enabled: _lotActionAllowed('EXCLUIR'),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Widget _lotsGrid() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width,
          ),
          child: Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: IntrinsicColumnWidth(),
            },
            border: const TableBorder(
              horizontalInside: BorderSide(color: Color(0xff283593)),
              verticalInside: BorderSide(color: Color(0xff283593)),
              top: BorderSide(color: Color(0xff283593)),
              bottom: BorderSide(color: Color(0xff283593)),
              left: BorderSide(color: Color(0xff283593)),
              right: BorderSide(color: Color(0xff283593)),
            ),
            children: [
              _gridRow(const [Text('Lote'), Text('Status')], header: true),
              ..._filteredLots.map(
                (lot) => _gridRow(
                  [Text(lot.name, softWrap: false), _gridStatusCell(lot)],
                  selected: _selectedLotCode == lot.code,
                  onTap: () => setState(() => _selectedLotCode = lot.code),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gridStatusCell(LotRecord lot) {
    final status = _lotStatusLabel(lot);
    if (_selectedLotCode != lot.code) return Text(status, softWrap: false);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(status, softWrap: false),
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          tooltip: 'Acoes do lote',
          icon: const Icon(Icons.more_horiz, size: 24),
          onSelected: (action) {
            if (action == 'edit' && _lotActionAllowed('ALTERAR'))
              _openLotForm(lot);
            if (action == 'delete' && _lotActionAllowed('EXCLUIR'))
              _confirmDelete(lot);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit',
              enabled: _lotActionAllowed('ALTERAR'),
              child: const Text('Alterar'),
            ),
            PopupMenuItem(
              value: 'delete',
              enabled: _lotActionAllowed('EXCLUIR'),
              child: const Text('Excluir'),
            ),
          ],
        ),
      ],
    );
  }

  String _lotStatusLabel(LotRecord lot) {
    final status = lot.productionStatus.trim();
    return status.isEmpty ? 'N/D' : status;
  }

  String _lotDietLabel(LotRecord lot) {
    final diet = lot.diet.trim();
    return diet.isEmpty ? 'N/D' : diet;
  }

  String _binaryLabel(int value) {
    if (value == 1) return 'SIM';
    if (value == 2) return 'NAO';
    return 'N/D';
  }

  TableRow _gridRow(
    List<Widget> cells, {
    bool header = false,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return TableRow(
      decoration: BoxDecoration(
        color: header
            ? const Color(0xffd1cfd1)
            : selected
            ? const Color(0xffffe500)
            : Colors.white,
      ),
      children: cells
          .map(
            (cell) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: InkWell(
                onTap: header ? null : onTap,
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: header ? 22 : 20,
                    fontWeight: FontWeight.w400,
                  ),
                  child: cell,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _openLotForm([LotRecord? existing]) async {
    final lot = await Navigator.of(context).push<LotRecord>(
      MaterialPageRoute<LotRecord>(
        builder: (_) => LotFormPage(
          existing: existing,
          statusOptions: _statusOptions,
          dietOptions: _dietOptions,
          feedingLocations: _feedingLocations,
        ),
      ),
    );
    if (lot == null || !mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _repository.insertLot(lot);
      if (mounted) setState(() => _isLoading = false);
      await _loadLots();
    } on SoapException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<int, String> get _statusOptions => {
    for (final lot in _lots)
      if (lot.productionStatus.trim().isNotEmpty)
        lot.productionStatusCode: lot.productionStatus.trim(),
  };

  Map<int, String> get _dietOptions => {
    for (final lot in _lots)
      if (lot.diet.trim().isNotEmpty) lot.dietCode: lot.diet.trim(),
  };

  Future<void> _confirmDelete(LotRecord lot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lote?'),
        content: Text('O lote "${lot.name}" sera excluido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _repository.deleteLot(lot.code);
      if (mounted) setState(() => _isLoading = false);
      await _loadLots();
    } on SoapException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLots() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final lots = await _repository.fetchLots();
      if (mounted) setState(() => _lots = lots);
    } on SoapException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _errorMessage = 'Nao foi possivel consultar o Azure.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class LotFormPage extends StatefulWidget {
  const LotFormPage({
    this.existing,
    this.statusOptions = const {},
    this.dietOptions = const {},
    this.feedingLocations = const {},
    super.key,
  });

  final LotRecord? existing;
  final Map<int, String> statusOptions;
  final Map<int, String> dietOptions;
  final Map<int, String> feedingLocations;

  @override
  State<LotFormPage> createState() => _LotFormPageState();
}

class _LotFormPageState extends State<LotFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dryingController = TextEditingController(text: '0');
  final _preCalvingController = TextEditingController(text: '0');
  int _statusValue = 0;
  int _dietValue = 0;
  int _diagnosisValue = 0;
  int _feedingValue = 0;
  int _feedingLocationValue = 0;

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _dryingController,
      _preCalvingController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final lot = widget.existing;
    if (lot != null) {
      _nameController.text = lot.name;
      _statusValue = lot.productionStatusCode;
      _dietValue = lot.dietCode;
      _dryingController.text = '${lot.dryingDays}';
      _preCalvingController.text = '${lot.preCalvingDays}';
      _diagnosisValue = lot.pregnancyDiagnosis;
      _feedingValue = lot.milkFeeding;
      _feedingLocationValue = lot.feedingLocation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Incluir lote' : 'Alterar lote'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do lote',
                prefixIcon: Icon(Icons.grid_view_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Preenchimento obrigatório'
                  : null,
            ),
            const SizedBox(height: 16),
            selectField(
              label: 'Status de produção',
              value: _statusValue,
              options: widget.statusOptions,
              onChanged: (value) => setState(() => _statusValue = value!),
            ),
            const SizedBox(height: 12),
            selectField(
              label: 'Dieta',
              value: _dietValue,
              options: widget.dietOptions,
              onChanged: (value) => setState(() => _dietValue = value!),
            ),
            const SizedBox(height: 12),
            numberField(_dryingController, 'Dias de secagem'),
            const SizedBox(height: 12),
            numberField(_preCalvingController, 'Dias de pré-parto'),
            const SizedBox(height: 12),
            selectField(
              label: 'Diagnóstico gestacional',
              value: _diagnosisValue,
              options: const {1: 'SIM', 2: 'NÃO'},
              onChanged: (value) => setState(() => _diagnosisValue = value!),
            ),
            const SizedBox(height: 12),
            selectField(
              label: 'Aleitamento',
              value: _feedingValue,
              options: const {1: 'SIM', 2: 'NAO'},
              onChanged: (value) => setState(() => _feedingValue = value!),
            ),
            const SizedBox(height: 12),
            selectField(
              label: 'Local de aleitamento',
              value: _feedingLocationValue,
              options: widget.feedingLocations,
              onChanged: (value) =>
                  setState(() => _feedingLocationValue = value!),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar lote'),
            ),
          ],
        ),
      ),
    );
  }

  Widget numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => int.tryParse(value ?? '') == null
          ? 'Informe um numero inteiro'
          : null,
    );
  }

  Widget selectField({
    required String label,
    required int value,
    required Map<int, String> options,
    required ValueChanged<int?> onChanged,
  }) {
    final values = {...options};
    values.putIfAbsent(value, () => value == 0 ? 'N/D' : '$value');
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      hint: const Text('Selecione uma opcao'),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.arrow_drop_down_circle_outlined),
        border: const OutlineInputBorder(),
      ),
      items: values.entries
          .map(
            (entry) => DropdownMenuItem<int>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  void save() {
    if (!_formKey.currentState!.validate()) return;
    int number(TextEditingController controller) => int.parse(controller.text);
    Navigator.of(context).pop(
      LotRecord(
        code: widget.existing?.code ?? -1,
        name: _nameController.text.trim(),
        productionStatusCode: _statusValue,
        dietCode: _dietValue,
        dryingDays: number(_dryingController),
        preCalvingDays: number(_preCalvingController),
        pregnancyDiagnosis: _diagnosisValue,
        milkFeeding: _feedingValue,
        feedingLocation: _feedingLocationValue,
      ),
    );
  }
}

class AnimalsPage extends StatefulWidget {
  const AnimalsPage({super.key});

  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends State<AnimalsPage> {
  final searchController = TextEditingController();
  final List<AnimalRecord> animals0 = [];
  late final SoapClient soapClient;
  late final AnimalRepository repository;
  int selectedTab = 0;
  bool onlyActive = true;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    soapClient = SoapClient(suffix: ClientRoutingSession.suffix);
    repository = AnimalRepository(soapClient: soapClient);
    loadAnimals();
  }

  @override
  void dispose() {
    searchController.dispose();
    soapClient.close();
    super.dispose();
  }

  List<AnimalRecord> get _filteredAnimals {
    final query = searchController.text.trim().toLowerCase();
    return animals0.where((animal) {
      final matchesQuery =
          query.isEmpty || animal.tag.toLowerCase().contains(query);
      return matchesQuery && (!onlyActive || animal.active);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animais'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: loadAnimals,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Adicionar animal',
            onPressed: () async {
              final animal = await Navigator.of(context).push<AnimalRecord>(
                MaterialPageRoute<AnimalRecord>(
                  builder: (_) => const AnimalFormPage(),
                ),
              );
              if (animal != null && mounted) {
                setState(() => animals0.add(animal));
              }
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Pesquisar por brinco',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Filtros',
                  onPressed: () => showMessage('Filtros avancados em breve.'),
                  icon: const Icon(Icons.tune),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Ativos'),
                  selected: onlyActive,
                  onSelected: (selected) {
                    setState(() => onlyActive = selected);
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  '${_filteredAnimals.length} registro(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Lista'),
                  icon: Icon(Icons.view_list),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Grade'),
                  icon: Icon(Icons.grid_view),
                ),
              ],
              selected: {selectedTab},
              onSelectionChanged: (selection) {
                setState(() => selectedTab = selection.first);
              },
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAnimals.isEmpty
                ? _AnimalsEmptyState(errorMessage: errorMessage)
                : selectedTab == 0
                ? _AnimalsList(animals: _filteredAnimals)
                : _AnimalsGrid(animals: _filteredAnimals),
          ),
        ],
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> loadAnimals() async {
    if (isLoading) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final animals = await repository.fetchAnimals();
      if (!mounted) return;
      setState(() {
        animals0
          ..clear()
          ..addAll(animals);
      });
    } on SoapException catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = 'Nao foi possivel consultar o Azure.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}

class _AnimalsList extends StatelessWidget {
  const _AnimalsList({required this.animals});

  final List<AnimalRecord> animals;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: animals.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final animal = animals[index];
        return Card(
          elevation: 0,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.pets_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              'Brinco ${animal.tag}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('${animal.breed}  |  ${animal.reproductiveStatus}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDetails(context, animal),
          ),
        );
      },
    );
  }

  void showDetails(BuildContext context, AnimalRecord animal) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Animal ${animal.tag}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('Raca: ${animal.breed}'),
            Text('Status reprodutivo: ${animal.reproductiveStatus}'),
            Text(
              'Status produtivo: ${animal.productionStatus.isEmpty ? 'Não informado' : animal.productionStatus}',
            ),
            Text('Lote: ${animal.lot.isEmpty ? 'Não informado' : animal.lot}'),
          ],
        ),
      ),
    );
  }
}

class _AnimalsGrid extends StatelessWidget {
  const _AnimalsGrid({required this.animals});

  final List<AnimalRecord> animals;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 160,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: animals.length,
      itemBuilder: (context, index) {
        final animal = animals[index];
        return Card(
          elevation: 0,
          child: InkWell(
            onTap: () => showDetails(context, animal),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.pets_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Text(
                    'Brinco ${animal.tag}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(animal.breed, overflow: TextOverflow.ellipsis),
                  Text(
                    animal.reproductiveStatus,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void showDetails(BuildContext context, AnimalRecord animal) {
    _AnimalsList(animals: [animal]).showDetails(context, animal);
  }
}

class AnimalFormPage extends StatefulWidget {
  const AnimalFormPage({super.key});

  @override
  State<AnimalFormPage> createState() => _AnimalFormPageState();
}

class _AnimalFormPageState extends State<AnimalFormPage> {
  final formKey = GlobalKey<FormState>();
  final tagController = TextEditingController();
  final electronicTagController = TextEditingController();
  final birthDateController = TextEditingController();
  final lactationsController = TextEditingController();
  final lastBirthController = TextEditingController();

  String? donor;
  String? lot;
  String? breed;
  String? reproductiveStatus;
  String? productionStatus;
  String? origin;
  String? betaCasein;

  @override
  void dispose() {
    tagController.dispose();
    electronicTagController.dispose();
    birthDateController.dispose();
    lactationsController.dispose();
    lastBirthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incluir animal'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Identificacao',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            requiredTextField(
              controller: tagController,
              label: 'Brinco',
              icon: Icons.sell_outlined,
            ),
            const SizedBox(height: 12),
            textField(
              controller: electronicTagController,
              label: 'Brinco eletronico',
              icon: Icons.nfc_outlined,
            ),
            const SizedBox(height: 20),
            Text(
              'Dados do animal',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            dropdown(
              label: 'Doadora',
              value: donor,
              values: const ['Sim', 'Não'],
              onChanged: (value) => setState(() => donor = value),
              required: true,
            ),
            const SizedBox(height: 12),
            dropdown(
              label: 'Lote',
              value: lot,
              values: const ['A definir', 'Lote 1', 'Lote 2'],
              onChanged: (value) => setState(() => lot = value),
            ),
            const SizedBox(height: 12),
            dateField(birthDateController, 'Data de nascimento'),
            const SizedBox(height: 12),
            dropdown(
              label: 'Raca',
              value: breed,
              values: const ['A definir', 'Holandesa', 'Jersey', 'Girolando'],
              onChanged: (value) => setState(() => breed = value),
              required: true,
            ),
            const SizedBox(height: 12),
            dropdown(
              label: 'Status reprodutivo',
              value: reproductiveStatus,
              values: const ['NÃO APTA', 'Vazia', 'Prenha', 'Inseminada'],
              onChanged: (value) => setState(() => reproductiveStatus = value),
              required: true,
            ),
            const SizedBox(height: 12),
            dropdown(
              label: 'Status produtivo',
              value: productionStatus,
              values: const ['Seca', 'Em leite', 'Novilha'],
              onChanged: (value) => setState(() => productionStatus = value),
            ),
            const SizedBox(height: 12),
            numberField(lactationsController, 'Número de lactações'),
            const SizedBox(height: 12),
            dateField(lastBirthController, 'Ultimo parto'),
            const SizedBox(height: 12),
            dropdown(
              label: 'Origem',
              value: origin,
              values: const ['Nascida na fazenda', 'Comprada', 'Transferida'],
              onChanged: (value) => setState(() => origin = value),
            ),
            const SizedBox(height: 12),
            dropdown(
              label: 'Beta-caseina',
              value: betaCasein,
              values: const ['Não informado', 'A1A1', 'A1A2', 'A2A2'],
              onChanged: (value) => setState(() => betaCasein = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar animal'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget requiredTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return textField(
      controller: controller,
      label: label,
      icon: icon,
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Preenchimento obrigatório'
          : null,
    );
  }

  Widget textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.numbers),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget dateField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
          initialDate: DateTime.now(),
        );
        if (date != null) {
          controller.text =
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
        }
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget dropdown({
    required String label,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
    bool required = false,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: const Text('Selecione uma opcao'),
      validator: required
          ? (current) => current == null ? 'Selecione uma opcao' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.arrow_drop_down_circle_outlined),
        border: const OutlineInputBorder(),
      ),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AnimalRecord(
        tag: tagController.text.trim(),
        electronicTag: electronicTagController.text.trim(),
        donor: donor!,
        lot: lot ?? '',
        birthDate: birthDateController.text,
        breed: breed!,
        reproductiveStatus: reproductiveStatus!,
        productionStatus: productionStatus ?? '',
        origin: origin ?? '',
        betaCasein: betaCasein ?? '',
      ),
    );
  }
}

class _AnimalsEmptyState extends StatelessWidget {
  const _AnimalsEmptyState({this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum animal carregado',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Os animais serão consultados quando a sincronização estiver conectada.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePermissionsPage extends StatefulWidget {
  const ProfilePermissionsPage({super.key});

  @override
  State<ProfilePermissionsPage> createState() => _ProfilePermissionsPageState();
}

class _ProfilePermissionsPageState extends State<ProfilePermissionsPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final TabController _tabController;
  late final SoapClient _permissionClient;
  late final PermissionRepository _permissionRepository;
  int _tab = 0;
  int? _selectedProfile;
  int? _selectedGroup;
  List<_PermissionProfile> _profiles = const [];
  List<PermissionDefinitionRecord> _catalog = const [];
  late final Map<String, bool> _permissions;
  bool _loadingPermissions = false;
  bool _loadingProfiles = true;
  bool _loadingCatalog = true;
  bool _loadingAccess = true;
  Map<int, bool> _loggedProfilePermissions = const {};

  List<_PermissionGroup> get _groups => [
    for (final group in _catalog.map((item) => item.group).toSet())
      _PermissionGroup(group, _groupIcon(group)),
  ];

  List<_PermissionRoutine> get _routines => [
    for (final key
        in _catalog.map((item) => '${item.group}|${item.routine}').toSet())
      _PermissionRoutine(
        key.split('|').first,
        key.split('|').last,
        _routineIcon(key.split('|').last),
      ),
  ];

  List<_PermissionDefinition> get _profilePermissions => _catalog
      .where((item) => item.routine.toUpperCase() == 'PERFIL')
      .map((item) => _PermissionDefinition(item.code, item.action))
      .toList(growable: false);

  IconData _groupIcon(String group) {
    switch (group.toUpperCase()) {
      case 'AJUSTES':
        return Icons.settings_outlined;
      case 'CADASTROS':
        return Icons.folder_outlined;
      case 'SERVICOS':
        return Icons.handyman_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  IconData _routineIcon(String routine) {
    switch (routine.toUpperCase()) {
      case 'PERFIL':
        return Icons.person_outline;
      case 'ANIMAIS':
        return Icons.pets_outlined;
      case 'LOTES':
        return Icons.grid_view_outlined;
      case 'DIETAS':
        return Icons.restaurant_outlined;
      case 'MEDICAMENTOS':
        return Icons.medication_outlined;
      case 'FORNECEDORES':
        return Icons.local_shipping_outlined;
      default:
        return Icons.list_alt_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    _permissionClient = SoapClient(suffix: ClientRoutingSession.suffix);
    _permissionRepository = PermissionRepository(soapClient: _permissionClient);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _permissions = {};
    _loadProfiles();
    _loadPermissionCatalog();
    _loadLoggedProfileAccess();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    _searchController.dispose();
    _permissionClient.close();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    if (_tab != _tabController.index && mounted) {
      setState(() => _tab = _tabController.index);
    }
  }

  String _permissionKey(String profile, int permissionCode) =>
      '$profile|$permissionCode';

  bool get _canManageProfiles =>
      !_loadingAccess && ClientRoutingSession.canGrantPermissions;

  bool _loggedPermissionAllowed(String action) {
    final permission = _catalog.cast<PermissionDefinitionRecord?>().firstWhere(
      (item) =>
          item!.routine.toUpperCase() == 'PERFIL' &&
          item.action.toUpperCase().startsWith(action.toUpperCase()),
      orElse: () => null,
    );
    return permission != null &&
        _loggedProfilePermissions[permission.code] == true;
  }

  bool get _canEditPermissions =>
      _canManageProfiles &&
      _selectedProfile != null &&
      _profiles[_selectedProfile!].code != 1;

  List<_PermissionProfile> get _filteredProfiles {
    final query = _searchController.text.trim().toLowerCase();
    return _profiles
        .where((profile) => profile.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _refreshProfilesAndPermissions,
            icon: const Icon(Icons.refresh),
          ),
          if (_tab == 0)
            IconButton(
              tooltip: 'Incluir perfil',
              onPressed: _loggedPermissionAllowed('INCLUIR')
                  ? _addProfile
                  : null,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: colors.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: colors.primary,
              unselectedLabelColor: colors.onSurfaceVariant,
              indicatorColor: colors.primary,
              tabs: const [
                Tab(text: 'Perfil'),
                Tab(text: 'Grupos'),
                Tab(text: 'Rotinas'),
              ],
              onTap: _selectTab,
            ),
          ),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 1:
        return _buildGroups();
      case 2:
        return _buildRoutines();
      default:
        return _buildProfiles();
    }
  }

  void _selectTab(int tab) {
    if (tab > 0 && _selectedProfile == null) {
      _showNavigationMessage('Selecione um perfil primeiro.');
      _tabController.index = 0;
      return;
    }
    if (tab > 1 && _selectedGroup == null) {
      _showNavigationMessage('Selecione um grupo primeiro.');
      _tabController.index = 1;
      return;
    }
    setState(() => _tab = tab);
  }

  void _showNavigationMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildProfiles() {
    if (_loadingProfiles) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Perfil',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _filteredProfiles.length,
            separatorBuilder: (_, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final profile = _filteredProfiles[index];
              final profileIndex = _profiles.indexOf(profile);
              return ListTile(
                title: Text(
                  profile.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                selected: profileIndex == _selectedProfile,
                selectedTileColor: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.35),
                trailing:
                    profile.code != 1 &&
                        (_loggedPermissionAllowed('ALTERAR') ||
                            _loggedPermissionAllowed('EXCLUIR'))
                    ? PopupMenuButton<String>(
                        tooltip: 'Acoes do perfil',
                        onOpened: _refreshLoggedProfileAccess,
                        onSelected: (action) {
                          if (action == 'edit') _editProfile(profile);
                          if (action == 'delete') _deleteProfile(profile);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem<String>(
                            value: 'edit',
                            enabled: _loggedPermissionAllowed('ALTERAR'),
                            child: const Text('Alterar perfil'),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            enabled: _loggedPermissionAllowed('EXCLUIR'),
                            child: const Text('Excluir perfil'),
                          ),
                        ],
                      )
                    : const Icon(Icons.lock_outline),
                onTap: () => _selectProfile(profileIndex),
              );
            },
          ),
        ),
        _recordCount(_filteredProfiles.length),
      ],
    );
  }

  Widget _buildGroups() {
    if (_loadingCatalog) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _groups.length,
            separatorBuilder: (_, index) => const Divider(height: 1),
            itemBuilder: (context, index) => ListTile(
              leading: Icon(_groups[index].icon),
              selected: index == _selectedGroup,
              title: Text(
                _groups[index].name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() {
                _selectedGroup = index;
                _tab = 2;
                _tabController.index = 2;
              }),
            ),
          ),
        ),
        _recordCount(_groups.length),
      ],
    );
  }

  Widget _buildRoutines() {
    final profile = _profiles[_selectedProfile!];
    final group = _groups[_selectedGroup!];
    final routines = _routines
        .where((routine) => routine.group == group.name)
        .toList(growable: false);
    if (_loadingPermissions) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Permissoes de ${profile.name}',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            group.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final routine in routines)
          ExpansionTile(
            leading: Icon(routine.icon),
            title: Text(
              routine.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            children: [
              for (final permission in _catalog.where(
                (item) =>
                    item.group == group.name && item.routine == routine.name,
              ))
                CheckboxListTile(
                  value:
                      _permissions[_permissionKey(
                        profile.name,
                        permission.code,
                      )],
                  title: Text(permission.action),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: _canEditPermissions
                      ? (value) => _updatePermission(
                          profile,
                          _PermissionDefinition(
                            permission.code,
                            permission.action,
                          ),
                          value ?? false,
                        )
                      : null,
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _selectProfile(int profileIndex) async {
    setState(() {
      _selectedProfile = profileIndex;
      _selectedGroup = null;
      _loadingPermissions = true;
      _tab = 1;
      _tabController.index = 1;
    });
    try {
      final loaded = await _permissionRepository.fetchProfilePermissions(
        _profiles[profileIndex].code,
      );
      if (!mounted) return;
      setState(() {
        for (final entry in loaded.entries) {
          _permissions[_permissionKey(
                _profiles[profileIndex].name,
                entry.key,
              )] =
              entry.value;
        }
        _loadingPermissions = false;
      });
    } on SoapException catch (error) {
      if (!mounted) return;
      setState(() => _loadingPermissions = false);
      _showNavigationMessage(error.message);
    }
  }

  Future<void> _loadProfiles() async {
    try {
      final loaded = await _permissionRepository.fetchProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = loaded
            .map(
              (profile) =>
                  _PermissionProfile(profile.code, profile.description),
            )
            .toList(growable: false);
        _loadingProfiles = false;
      });
    } on SoapException catch (error) {
      if (!mounted) return;
      setState(() => _loadingProfiles = false);
      _showNavigationMessage(error.message);
    }
  }

  Future<void> _loadPermissionCatalog() async {
    try {
      final loaded = await _permissionRepository.fetchPermissionCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = loaded;
        _loadingCatalog = false;
      });
    } on SoapException catch (error) {
      if (!mounted) return;
      setState(() => _loadingCatalog = false);
      _showNavigationMessage(error.message);
    }
  }

  Future<void> _loadLoggedProfileAccess() async {
    final loggedProfile = ClientRoutingSession.profileCode;
    if (loggedProfile <= 0) {
      if (mounted) setState(() => _loadingAccess = false);
      return;
    }
    try {
      final permissions = await _permissionRepository.fetchProfilePermissions(
        loggedProfile,
      );
      if (!mounted) return;
      setState(() {
        _loggedProfilePermissions = permissions;
        ClientRoutingSession.canGrantPermissions = permissions[101] ?? false;
        _loadingAccess = false;
      });
    } on SoapException catch (error) {
      if (!mounted) return;
      setState(() => _loadingAccess = false);
      _showNavigationMessage(error.message);
    }
  }

  Future<void> _refreshLoggedProfileAccess() async {
    final loggedProfile = ClientRoutingSession.profileCode;
    if (loggedProfile <= 0) return;
    try {
      final permissions = await _permissionRepository.fetchProfilePermissions(
        loggedProfile,
      );
      if (!mounted) return;
      setState(() {
        _loggedProfilePermissions = permissions;
        ClientRoutingSession.canGrantPermissions = permissions[101] ?? false;
      });
    } on SoapException catch (error) {
      if (mounted) _showNavigationMessage(error.message);
    }
  }

  Future<void> _refreshProfilesAndPermissions() async {
    final selectedCode = _selectedProfile == null
        ? null
        : _profiles[_selectedProfile!].code;
    setState(() {
      _loadingProfiles = true;
      _loadingCatalog = true;
      _loadingPermissions = selectedCode != null;
    });

    try {
      final loaded = await _permissionRepository.fetchProfiles();
      final catalog = await _permissionRepository.fetchPermissionCatalog();
      final profiles = loaded
          .map(
            (profile) => _PermissionProfile(profile.code, profile.description),
          )
          .toList(growable: false);
      final selectedIndex = selectedCode == null
          ? null
          : profiles.indexWhere((profile) => profile.code == selectedCode);
      Map<int, bool> permissions = const {};
      if (selectedIndex != null && selectedIndex >= 0) {
        permissions = await _permissionRepository.fetchProfilePermissions(
          profiles[selectedIndex].code,
        );
      }
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _catalog = catalog;
        _selectedProfile = selectedIndex != null && selectedIndex >= 0
            ? selectedIndex
            : null;
        _loadingProfiles = false;
        _loadingCatalog = false;
        _loadingPermissions = false;
        if (_selectedProfile != null) {
          for (final entry in permissions.entries) {
            _permissions[_permissionKey(
                  profiles[_selectedProfile!].name,
                  entry.key,
                )] =
                entry.value;
          }
        }
      });
    } on SoapException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingProfiles = false;
        _loadingCatalog = false;
        _loadingPermissions = false;
      });
      _showNavigationMessage(error.message);
    }
  }

  Future<void> _updatePermission(
    _PermissionProfile profile,
    _PermissionDefinition permission,
    bool allowed,
  ) async {
    final key = _permissionKey(profile.name, permission.code);
    final previous = _permissions[key] ?? false;
    setState(() => _permissions[key] = allowed);
    try {
      await _permissionRepository.updatePermission(
        profileCode: profile.code,
        permissionCode: permission.code,
        allowed: allowed,
      );
      if (!mounted) return;
      _showNavigationMessage('Permissão atualizada.');
    } on SoapException catch (error) {
      if (!mounted) return;
      setState(() => _permissions[key] = previous);
      _showNavigationMessage(error.message);
    }
  }

  Widget _recordCount(int count) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text('$count registro(s)'),
        ),
      ),
    );
  }

  Future<void> _addProfile() async {
    final description = await _profileDescriptionDialog(
      title: 'Incluir perfil',
    );
    if (description == null || !mounted) return;
    try {
      await _permissionRepository.saveProfile(description: description);
      if (!mounted) return;
      _showNavigationMessage('Perfil incluído.');
      await _refreshProfilesAndPermissions();
    } on SoapException catch (error) {
      if (mounted) _showNavigationMessage(error.message);
    }
  }

  Future<void> _editProfile(_PermissionProfile profile) async {
    if (profile.code == 1) return;
    final description = await _profileDescriptionDialog(
      title: 'Alterar perfil',
      initialValue: profile.name,
    );
    if (description == null || !mounted) return;
    try {
      await _permissionRepository.saveProfile(
        code: profile.code,
        description: description,
      );
      if (!mounted) return;
      _showNavigationMessage('Perfil alterado.');
      await _refreshProfilesAndPermissions();
    } on SoapException catch (error) {
      if (mounted) _showNavigationMessage(error.message);
    }
  }

  Future<void> _deleteProfile(_PermissionProfile profile) async {
    if (profile.code == 1) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir perfil?'),
        content: Text('O perfil "${profile.name}" será excluído.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _permissionRepository.deleteProfile(profile.code);
      if (!mounted) return;
      _showNavigationMessage('Perfil excluído.');
      await _refreshProfilesAndPermissions();
    } on SoapException catch (error) {
      if (mounted) _showNavigationMessage(error.message);
    }
  }

  Future<String?> _profileDescriptionDialog({
    required String title,
    String initialValue = '',
  }) async {
    var description = initialValue;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initialValue,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 50,
          decoration: const InputDecoration(labelText: 'Descrição'),
          onChanged: (value) => description = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, description.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    return result;
  }
}

class _PermissionProfile {
  const _PermissionProfile(this.code, this.name);

  final int code;
  final String name;
}

class _PermissionDefinition {
  const _PermissionDefinition(this.code, this.label);

  final int code;
  final String label;
}

class _PermissionGroup {
  const _PermissionGroup(this.name, this.icon);

  final String name;
  final IconData icon;
}

class _PermissionRoutine {
  const _PermissionRoutine(this.group, this.name, this.icon);

  final String group;
  final String name;
  final IconData icon;
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final company = ClientRoutingSession.company.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_done_outlined, color: colors.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Conectado ao CowSystem',
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            company.isEmpty ? 'Online' : company,
            style: TextStyle(color: colors.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: colors.primary),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 5.1 : 2.1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            _ActionTile(
              tileLabel: 'Controle leiteiro',
              icon: Icons.water_drop_outlined,
            ),
            _ActionTile(tileLabel: 'Tarefas', icon: Icons.checklist_outlined),
            _ActionTile(
              tileLabel: 'Diagnóstico gestacional',
              icon: Icons.monitor_heart_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _ModuleList extends StatelessWidget {
  const _ModuleList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ActionTile(
          tileLabel: 'Cadastros',
          subtitle: 'Animais, lotes, fornecedores e insumos',
          icon: Icons.folder_copy_outlined,
        ),
        SizedBox(height: 10),
        _ActionTile(
          tileLabel: 'Serviços',
          subtitle: 'Manejo, inseminação, pesagem e parto',
          icon: Icons.handyman_outlined,
        ),
        SizedBox(height: 10),
        _ActionTile(
          tileLabel: 'Relatorios',
          subtitle: 'Indicadores de leite, rebanho e estoque',
          icon: Icons.bar_chart_outlined,
        ),
        SizedBox(height: 10),
        _ActionTile(
          tileLabel: 'Ajustes',
          subtitle: 'Perfil, sincronização e configurações',
          icon: Icons.settings_outlined,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.tileLabel,
    required this.icon,
    this.subtitle,
  });

  final String tileLabel;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ModulePage(title: tileLabel),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tileLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
