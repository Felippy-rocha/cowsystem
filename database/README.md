# Banco de dados

Este diretorio guarda a referencia versionada do banco SQL Server usado pelo
Cowsystem.

## Baseline

`baseline/000_initial_schema.sql` e o export original recebido do Azure em
18/09/2026. O arquivo foi mantido sem reformatacao para permitir a conferencia
com o banco de origem.

## Novas alteracoes

Alteracoes futuras devem ser adicionadas como scripts independentes e
numerados, por exemplo:

```text
migrations/001_add_campo_exemplo.sql
migrations/002_create_procedure_exemplo.sql
```

Cada migracao deve ser revisada, testada em um banco de homologacao e aplicada
uma unica vez em cada ambiente. O aplicativo Flutter nao deve executar
`ALTER TABLE`, `CREATE PROCEDURE` ou outras alteracoes estruturais do banco.

## Primeira organizacao de permissoes

As migracoes de permissoes devem ser executadas nesta ordem:

1. `migrations/001_audit_permission_integrity.sql` - somente leitura; lista
	 nulos, duplicidades, valores invalidos e registros orfaos.
2. `migrations/002_add_permission_indexes.sql` - adiciona indices para perfis,
	 permissoes e vinculos perfil-permissao.
3. `migrations/003_add_permission_foreign_keys.sql` - adiciona os
	 relacionamentos e a validacao de `PERMITIDO` como 0 ou 1.
4. `migrations/004_fix_delete_profile_order.sql` - corrige a ordem de exclusao
	de perfis depois da criacao da foreign key.
5. `migrations/005_create_tipo_baia.sql` - cria `TB_TIPOBAIA` no Azure e inclui
	`AGRUPAMENTO` e `BEZERREIRO`.

Se a primeira migracao retornar registros problematicos, pare e corrija os
dados antes de executar as seguintes. A terceira migracao aborta sozinha caso
encontre dados incompatíveis.

Relacionamentos criados:

```text
TB_PERFILPERMISSOES_NEW.CODPERFIL
	-> TB_PERFIL.CODPERFIL

TB_PERFILPERMISSOES_NEW.CODPERMISSAO
	-> TB_PERMISSOES_NEW.CODPERMISSAO
```

## Aplicacao

As migracoes podem ser aplicadas por uma ferramenta de deploy ou pelo `sqlcmd`
usando credenciais fornecidas pelo ambiente. Nao coloque senhas, tokens ou
strings de conexao neste repositorio.

Antes de aplicar uma migracao em producao:

1. Fazer backup ou confirmar o ponto de restauracao do banco.
2. Executar a migracao em homologacao.
3. Conferir o resultado e registrar a versao aplicada.
4. Aplicar a mesma migracao em producao.

## Roteamento por dispositivo

O banco central pode autorizar cada dispositivo na tabela
`CLIENTES_COWSYSTEM`. O aplicativo consulta essa tabela pelo identificador do
dispositivo usando `ObterClientePorDispositivo`, recebe o `SUFIXO` autorizado
e usa esse valor nas consultas da base do cliente.

No Flutter, esse fluxo esta implementado em:

- `lib/data/client_routing.dart`
- `lib/data/client_routing_repository.dart`
- `lib/data/soap_client.dart`

O dispositivo nunca deve enviar livremente o sufixo da base. O servidor deve
validar o dispositivo e retornar o sufixo; se nao houver autorizacao, o app
deve bloquear o acesso. Antes de ativar a resolucao automatica em producao,
confirme no banco central os nomes exatos das colunas `DISPOSITIVO` e `SUFIXO`,
ou ajuste a consulta do repositorio.