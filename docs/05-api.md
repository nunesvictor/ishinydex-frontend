# API

O contrato completo, mantido junto com o backend, fica em
[`ishinydex-backend/docs/plans/frontend-api.md`](../../ishinydex-backend/docs/plans/frontend-api.md).
Com o backend rodando, a documentação interativa (Swagger) fica em
<http://localhost:8008/api/docs/> e o schema OpenAPI em `/api/schema/`.

## Endpoints consumidos pelo app

| Método | Rota | Onde é usado |
| --- | --- | --- |
| POST | `/api/auth/token/` | `HttpAuthRepository.login` |
| GET | `/api/personal-dexes/?page=&page_size=100` | `fetchDexes` (percorre todas as páginas) |
| GET | `/api/personal-dexes/{id}/` | `fetchDex` |
| GET | `/api/personal-dexes/{id}/boxes/` | `fetchBoxes` (lista simples, sem paginação) |
| GET | `/api/personal-dexes/{id}/generations/` | `fetchGenerations` (progresso por geração, com a primeira box de cada uma) |
| GET | `/api/personal-dexes/{id}/hunts/?reasons=&accepted_balls=&generation=&type=&category=&search=&include_locked=&page=&page_size=20` | `fetchHunts` (caçadas do shiny dex; `reasons` vai sempre, o resto só quando usado; ver `HuntQuery.toQueryParameters`) |
| GET | `/api/personal-dexes/preview/?force_new_box=` | `previewNewDex` (simula o dex padrão: formas, boxes, onde começa, boxes novas a criar, se há espaço) |
| POST | `/api/personal-dexes/` | `createDex` (`{name, is_shiny_dex, force_new_box}`; conjunto padrão nas primeiras boxes livres) |
| PATCH | `/api/personal-dexes/{id}/` | `updateDex` (`{name, is_shiny_dex}`; `force_new_box` não muda) |
| DELETE | `/api/personal-dexes/{id}/` | `deleteDex` (libera os slots; os espécimes continuam, disponíveis) |
| GET | `/api/slots/?personal_dex=&box=` | `fetchSlots` (os slots **do dex** na box, sem paginação; os livres ficam de fora — ver abaixo) |
| POST | `/api/slots/{id}/deposit/` | `deposit` (`{"specimen_id": n}`) |
| POST | `/api/slots/{id}/withdraw/` | `withdraw` (retirar do slot sem apagar o espécime) |
| GET | `/api/slots/?personal_dex=&form=1,2&page_size=100` | `fetchSlotsByForms` (onde as formas da linha evolutiva estão no dex) |
| POST | `/api/personal-dexes/{id}/link-specimens/` | `linkSpecimens` (`{"strict", "dry_run"}` → `{linked, missing, slots}`: depositar automaticamente e a prévia) |
| GET | `/api/specimens/?form_id=&available=true&page_size=100` | `fetchAvailable` |
| GET | `/api/specimens/?page=&page_size=20&search=&available=&is_shiny=&pokeball=&type=&ot=&generation=&origin_mark=&ordering=...` | `fetchSpecimens` (inventário; só os filtros usados vão na URL, listas separadas por vírgula; ver `SpecimenQuery.toQueryParameters`) |
| GET | `/api/forms/?search=&page_size=30` | `searchForms` (seletor de forma do cadastro avulso) |
| GET | `/api/slots/{id}/` | `fetchSlot` ("Ver no dex": descobre dex e box do slot) |
| GET | `/api/slots/?personal_dex=&search=&page_size=30` | `searchSlots` (busca no dex: nome da forma ou número, na ordem das boxes) |
| POST | `/api/specimens/` | `create` |
| GET | `/api/specimens/{id}/` | `fetchSpecimen` (formulário de edição) |
| PATCH | `/api/specimens/{id}/` | `update` (todos os campos menos `form`, que é imutável; vazios vão como `null`) |
| DELETE | `/api/specimens/{id}/` | `release` (libertar: apaga o specimen, mesmo depositado; o slot fica faltante) |
| GET | `/api/specimens/ids/?<filtros>` | `fetchSpecimenIds` ("selecionar todos os resultados"; sem paginação) |
| PATCH | `/api/specimens/bulk/` | `bulkUpdate` (`{"ids": [...], "changes": {...}}` → `{"updated": n}`; conflito de gênero → `GenderConflictFailure`) |
| POST | `/api/specimens/bulk-release/` | `bulkRelease` (`{"ids": [...]}` → `{"released": n}`; tudo ou nada) |
| GET | `/api/specimens/options/` | `fetchOptions` (idiomas, gêneros, naturezas, pokébolas, tipos, gerações e marcas de origem; pokébolas e tipos trazem `sprite_url`) |
| GET | `/api/forms/{id}/` | `fetchForm` (tipos, habilidades, status base e dados da espécie: linha evolutiva, outras formas, gênero, captura, ovos, altura, peso e estreia) |
| GET | `/api/trainers/?page_size=100` | `fetchTrainers` |
| POST | `/api/trainers/` | `createTrainer` (`{name, trainer_id, version?}`; nome + ID únicos) |
| GET | `/api/versions/` | `fetchVersions` (versões de jogo em ordem de lançamento, sem paginação) |
| GET | `/api/saves/` | `fetchSaves` (saves do usuário, sem paginação: `{id, label, trainer: Trainer}`) |
| POST | `/api/saves/` | `createSave` (`{trainer, label}`; só OT de jogo que recebe do HOME) |
| PATCH | `/api/saves/{id}/` | `updateSave` (só `label`) |
| DELETE | `/api/saves/{id}/` | `deleteSave` (com espécimes no save → 400) |
| GET | `/api/shiny-locks/` | `fetchShinyLocks` (ordem alfabética, sem paginação: `{id, caption, description, lock_type, active, forms: FormRef[]}`) |
| POST | `/api/shiny-locks/` | `createShinyLock` (`ShinyLockDraft.toJson()`: `forms` por id, ao menos uma; `caption` único) |
| PATCH | `/api/shiny-locks/{id}/` | `updateShinyLock` (mesmo corpo) |
| DELETE | `/api/shiny-locks/{id}/` | `deleteShinyLock` (as formas continuam) |
| POST | `/api/specimens/transfer/` | `transfer` (`{"ids": [...], "save": id \| null}` → `{"transferred": n}`; `null` = de volta ao HOME) |
| POST | `/api/specimens/{id}/evolve/` | `evolve` (`{"form": id}`: evoluiu fora do HOME; sai do slot) |

As implementações ficam em
[http_personal_dex_repository.dart](../lib/features/personal_dex/data/http_personal_dex_repository.dart),
[http_specimen_repository.dart](../lib/features/specimens/data/http_specimen_repository.dart) e
[auth_repository.dart](../lib/features/auth/data/auth_repository.dart).

### Marca de origem

`Specimen.originVersion` (jogo de origem) e `Specimen.originMark` (`paldea`,
`galar`, `go`...; `null` = sem marca) vêm prontos do backend, que os deriva
do OT: o app só escolhe o OT, como sempre. A tabela jogo → marca e a
prioridade do GO ficam em `home/origin_marks.py` no backend (espelhadas no
`FakeBackend`); o app só traduz o slug em nome e ícone (`OriginMark`). O
filtro `origin_mark` aceita vários slugs, `go` e `none`, e a lista vem de
`/specimens/options/`.

### Slots livres

As boxes são as mesmas do Pokémon HOME para todos os dexes. Os slots que
sobram no fim da última box de cada geração (dexes com `force_new_box`) ficam
no banco com `form` e `personal_dex` nulos, então o filtro `personal_dex=`
não os devolve e uma box pode vir com menos de 30 slots. O `BoxGrid` desenha
essas posições como `EmptySlotTile`, e o `FakeBackend` segue a mesma regra.

## Erros

O backend usa o formato padrão do Django REST Framework, com mensagens em
pt-BR. [`mapDioException`](../lib/core/network/app_failure.dart) converte:

| Resposta | `AppFailure` | O app faz |
| --- | --- | --- |
| Sem resposta (rede/CORS/timeout) | `NetworkFailure` | Mostra erro com "Tentar novamente" |
| 401 | `UnauthorizedFailure` | O interceptor faz logout e volta ao login |
| 404 | `NotFoundFailure` | Mostra erro |
| 400 `{campo: [msgs]}` | `ValidationFailure` | `errorFor('campo')` mostra a mensagem no campo do formulário |
| 400 `{"detail": msg}` | `ValidationFailure` | Mostra `detail` |
| 5xx | `ServerFailure` | Mostra erro |

## Integrando um endpoint novo

1. Confira o shape no Swagger (`/api/docs/`) ou pegue uma resposta real:
   ```bash
   TOKEN=$(curl -s -X POST http://localhost:8008/api/auth/token/ \
     -H 'Content-Type: application/json' \
     -d '{"username":"...","password":"..."}' | jq -r .token)
   curl -s -H "Authorization: Token $TOKEN" http://localhost:8008/api/forms/1/ | jq
   ```
2. Cole a resposta em [test/fixtures/api_fixtures.dart](../test/fixtures/api_fixtures.dart)
   e escreva o teste do `fromJson` antes do resto. Assim você sabe que o
   modelo bate com o backend.
3. Siga a receita de [01-arquitetura.md](01-arquitetura.md#como-adicionar-uma-feature-receita).
4. Replique a regra de negócio no [`FakeBackend`](../lib/fake/fake_backend.dart)
   para que a demo e os testes se comportem como a API real.
