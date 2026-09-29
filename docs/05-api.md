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
| GET | `/api/slots/?personal_dex=&box=` | `fetchSlots` (os slots **do dex** na box, sem paginação; os livres ficam de fora — ver abaixo) |
| POST | `/api/slots/{id}/deposit/` | `deposit` (`{"specimen_id": n}`) |
| GET | `/api/specimens/?form_id=&available=true&page_size=100` | `fetchAvailable` |
| GET | `/api/specimens/?page=&page_size=20&search=&available=&is_shiny=` | `fetchSpecimens` (inventário; só os filtros usados vão na URL) |
| GET | `/api/forms/?search=&page_size=30` | `searchForms` (seletor de forma do cadastro avulso) |
| GET | `/api/slots/{id}/` | `fetchSlot` ("Ver no dex": descobre dex e box do slot) |
| POST | `/api/specimens/` | `create` |
| GET | `/api/specimens/{id}/` | `fetchSpecimen` (formulário de edição) |
| PATCH | `/api/specimens/{id}/` | `update` (todos os campos menos `form`, que é imutável; vazios vão como `null`) |
| DELETE | `/api/specimens/{id}/` | `release` (libertar: apaga o specimen, mesmo depositado; o slot fica faltante) |
| GET | `/api/specimens/options/` | `fetchOptions` (idiomas, gêneros, naturezas, pokébolas; cada pokébola traz `sprite_url`) |
| GET | `/api/forms/{id}/` | `fetchForm` (habilidades da forma) |
| GET | `/api/trainers/?page_size=100` | `fetchTrainers` |
| POST | `/api/trainers/` | `createTrainer` (`{name, trainer_id, version?}`; nome + ID únicos) |
| GET | `/api/versions/` | `fetchVersions` (versões de jogo em ordem de lançamento, sem paginação) |

As implementações ficam em
[http_personal_dex_repository.dart](../lib/features/personal_dex/data/http_personal_dex_repository.dart),
[http_specimen_repository.dart](../lib/features/specimens/data/http_specimen_repository.dart) e
[auth_repository.dart](../lib/features/auth/data/auth_repository.dart).

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
