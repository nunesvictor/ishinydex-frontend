# Fluxo de trabalho

Toda mudança entra na `main` por pull request, a partir de uma issue.

1. **Issue.** Descreva o problema ou a funcionalidade (em pt-BR), com o
   comportamento esperado e o que fica fora do escopo. Se a mudança depende
   do catálogo (dados de referência), abra a issue irmã em
   [ishinydex-backend](https://github.com/nunesvictor/ishinydex-backend),
   que gera o catálogo, e vincule as duas.
2. **Branch.** Uma por issue, nomeada `<número>-<resumo>` (ex.:
   `2-editar-libertar-especime`), a partir da `main` atualizada.
3. **Pull request.** Preencha o template com `Closes #<número>`, para a issue
   fechar sozinha no merge. O CI ([ci.yml](.github/workflows/ci.yml)) roda em
   todo PR e precisa ficar verde. Quando o app depende de uma mudança no
   catálogo, o PR do backend é mergeado primeiro.
4. **Revisão e merge.** O dono do repositório revisa e faz **squash merge**,
   o único modo habilitado: vira um commit na `main` com o número do PR. A
   branch é apagada automaticamente.
5. **Publicação.** Só depois do merge, pelo repositório principal
   [ishinydex](https://github.com/nunesvictor/ishinydex): PR que atualiza
   o submodule para o commit da `main` e, depois, uma tag `v*`, que publica
   o app no GitHub Pages.

## Antes de abrir o PR

```sh
dart run build_runner build
dart format lib test tool integration_test test_driver
flutter analyze
flutter test --coverage && dart run tool/check_coverage.dart
```
