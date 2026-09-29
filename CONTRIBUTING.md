# Fluxo de trabalho

Toda mudança entra na `main` por pull request, a partir de uma issue.

1. **Issue.** Descreva o problema ou a funcionalidade (em pt-BR), com o
   comportamento esperado e o que fica fora do escopo. Se a mudança depende
   da API, abra a issue irmã em
   [ishinydex-backend](https://github.com/nunesvictor/ishinydex-backend)
   e vincule as duas.
2. **Branch.** Uma por issue, nomeada `<número>-<resumo>` (ex.:
   `2-editar-libertar-especime`), a partir da `main` atualizada.
3. **Pull request.** Preencha o template com `Closes #<número>`, para a issue
   fechar sozinha no merge. O CI ([ci.yml](.github/workflows/ci.yml)) roda em
   todo PR e precisa ficar verde. Quando o app depende de uma mudança no
   backend, o PR do backend é mergeado primeiro.
4. **Revisão e merge.** O dono do repositório revisa e faz **squash merge**,
   o único modo habilitado: vira um commit na `main` com o número do PR. A
   branch é apagada automaticamente.
5. **Deploy local.** Só depois do merge: `docker compose up -d --build`
   (ver [docs/06-deploy-local.md](docs/06-deploy-local.md)).

## Antes de abrir o PR

```sh
dart run build_runner build -d
dart format lib test tool integration_test test_driver
flutter analyze
flutter test --coverage && dart run tool/check_coverage.dart
```
