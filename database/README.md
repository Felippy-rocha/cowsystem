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

## Aplicacao

As migracoes podem ser aplicadas por uma ferramenta de deploy ou pelo `sqlcmd`
usando credenciais fornecidas pelo ambiente. Nao coloque senhas, tokens ou
strings de conexao neste repositorio.

Antes de aplicar uma migracao em producao:

1. Fazer backup ou confirmar o ponto de restauracao do banco.
2. Executar a migracao em homologacao.
3. Conferir o resultado e registrar a versao aplicada.
4. Aplicar a mesma migracao em producao.