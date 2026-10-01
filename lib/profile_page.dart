import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/permission_repository.dart';
import 'data/soap_client.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canManageProfiles = ClientRoutingSession.canGrantPermissions;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do usuario'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: colors.primaryContainer,
            child: Icon(Icons.person_outline, size: 38, color: colors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            ClientRoutingSession.username.isEmpty
                ? 'Usuario nao identificado'
                : ClientRoutingSession.username,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            child: Column(
              children: [
                _ProfileInfoTile(
                  icon: Icons.business_outlined,
                  label: 'Empresa',
                  value: ClientRoutingSession.company,
                ),
                const Divider(height: 1),
                _ProfileInfoTile(
                  icon: Icons.badge_outlined,
                  label: 'Perfil de acesso',
                  value: ClientRoutingSession.profileDescription,
                ),
                const Divider(height: 1),
                _ProfileInfoTile(
                  icon: Icons.devices_outlined,
                  label: 'Dispositivo',
                  value: ClientRoutingSession.deviceId,
                ),
                if (ClientRoutingSession.appVersion.isNotEmpty) ...[
                  const Divider(height: 1),
                  _ProfileInfoTile(
                    icon: Icons.info_outline,
                    label: 'Versao do aplicativo',
                    value: ClientRoutingSession.appVersion,
                  ),
                ],
              ],
            ),
          ),
          if (canManageProfiles) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _ProfileAccessPage(),
                ),
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Gerenciar perfis e permissoes'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value.isEmpty ? 'Nao informado' : value),
    );
  }
}

class _ProfileAccessPage extends StatefulWidget {
  const _ProfileAccessPage();

  @override
  State<_ProfileAccessPage> createState() => _ProfileAccessPageState();
}

class _ProfileAccessPageState extends State<_ProfileAccessPage> {
  late final SoapClient _client;
  late final PermissionRepository _repository;
  List<PermissionProfileRecord> _profiles = const [];
  List<PermissionDefinitionRecord> _catalog = const [];
  Map<int, bool> _permissions = const {};
  int? _selectedProfileCode;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = PermissionRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load({int? preferredCode}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profiles = await _repository.fetchProfiles();
      final catalog = await _repository.fetchPermissionCatalog();
      final requestedCode =
          preferredCode ??
          _selectedProfileCode ??
          ClientRoutingSession.profileCode;
      final selectedCode =
          profiles.any((profile) => profile.code == requestedCode)
          ? requestedCode
          : profiles.isEmpty
          ? null
          : profiles.first.code;
      final permissions = selectedCode == null
          ? const <int, bool>{}
          : await _repository.fetchProfilePermissions(selectedCode);
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _catalog = catalog;
        _selectedProfileCode = selectedCode;
        _permissions = permissions;
        _loading = false;
      });
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Nao foi possivel carregar os perfis no Azure.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectProfile(int? code) async {
    if (code == null) return;
    setState(() {
      _selectedProfileCode = code;
      _loading = true;
      _error = null;
    });
    try {
      final permissions = await _repository.fetchProfilePermissions(code);
      if (!mounted) return;
      setState(() {
        _permissions = permissions;
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

  Future<void> _createProfile() async {
    final description = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Novo perfil'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Descricao'),
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
    if (description == null || description.isEmpty || !mounted) return;
    try {
      await _repository.saveProfile(description: description);
      await _load();
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _deleteProfile() async {
    final code = _selectedProfileCode;
    if (code == null) return;
    final profile = _profiles.firstWhere((item) => item.code == code);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir perfil?'),
        content: Text('O perfil "${profile.description}" sera excluido.'),
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
      await _repository.deleteProfile(code);
      await _load(preferredCode: ClientRoutingSession.profileCode);
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _setPermission(int code, bool allowed) async {
    final profileCode = _selectedProfileCode;
    if (profileCode == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.updatePermission(
        profileCode: profileCode,
        permissionCode: code,
        allowed: allowed,
      );
      if (mounted) {
        setState(() => _permissions = {..._permissions, code: allowed});
      }
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfis e permissoes'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Criar perfil',
            onPressed: _createProfile,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Excluir perfil selecionado',
            onPressed: _selectedProfileCode == null ? null : _deleteProfile,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : _profiles.isEmpty
          ? const Center(child: Text('Nenhum perfil cadastrado.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(_selectedProfileCode),
                    initialValue: _selectedProfileCode,
                    decoration: const InputDecoration(
                      labelText: 'Perfil',
                      border: OutlineInputBorder(),
                    ),
                    items: _profiles
                        .map(
                          (profile) => DropdownMenuItem(
                            value: profile.code,
                            child: Text(profile.description),
                          ),
                        )
                        .toList(),
                    onChanged: _selectProfile,
                  ),
                ),
                Expanded(
                  child: _catalog.isEmpty
                      ? const Center(
                          child: Text('Nenhuma permissao cadastrada.'),
                        )
                      : ListView(
                          children: [
                            for (final group in _groups)
                              ExpansionTile(
                                key: PageStorageKey(group),
                                title: Text(group),
                                children: [
                                  for (final permission in _catalog.where(
                                    (item) => item.group == group,
                                  ))
                                    SwitchListTile(
                                      title: Text(permission.routine),
                                      subtitle: Text(permission.action),
                                      value:
                                          _permissions[permission.code] ??
                                          false,
                                      onChanged: _saving
                                          ? null
                                          : (value) => _setPermission(
                                              permission.code,
                                              value,
                                            ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  List<String> get _groups =>
      _catalog.map((item) => item.group).toSet().toList()..sort();
}
