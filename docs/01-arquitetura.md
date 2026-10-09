# Arquitetura

> **Desatualizado em parte:** desde a v2.0.0 o app não tem servidor (sem
> login, sem API; os dados ficam no aparelho, com sync opcional pelo
> Dropbox). Trechos sobre login, token, API, Docker e nginx descrevem o
> modelo antigo. A revisão está em
> [ishinydex#49](https://github.com/nunesvictor/ishinydex/issues/49).

## Visão geral

O código é organizado **por feature** (auth, personal_dex, specimens,
settings). Dentro de cada feature, ele se divide em **camadas**:

```
┌──────────────────────────────────────────────────────────────┐
│ presentation/   Telas e widgets (ConsumerWidget)             │
│                 leem providers com ref.watch                 │
├──────────────────────────────────────────────────────────────┤
│ *_providers.dart  Providers Riverpod: cache, estado, ações   │
├──────────────────────────────────────────────────────────────┤
│ domain/         Modelos (freezed) + interfaces de repositório │
│                 (sem Flutter, sem HTTP)                        │
├──────────────────────────────────────────────────────────────┤
│ data/           Implementações HTTP dos repositórios (Dio)    │
│ fake/           Implementação em memória (FakeBackend)        │
└──────────────────────────────────────────────────────────────┘
```

**Regra de dependência:** as camadas de cima conhecem as de baixo, nunca o
contrário. Uma tela nunca chama o Dio diretamente: ela pede dados a um provider,
que usa um **repositório**, que é uma interface. Por isso é possível:

- rodar o app inteiro sem backend (`USE_FAKE_API=true`);
- testar telas sem rede, trocando o repositório por um fake ou mock.

## Mapa das pastas

| Caminho | Responsabilidade |
| --- | --- |
| [lib/main.dart](../lib/main.dart) | Cria o `ProviderScope` e sobe o app |
| [lib/app.dart](../lib/app.dart) | `MaterialApp.router`: tema claro/escuro, idioma pt-BR, rotas |
| [lib/core/config/env.dart](../lib/core/config/env.dart) | Lê `API_BASE_URL` (absoluta ou relativa, ex.: `/api`) e `USE_FAKE_API` do `--dart-define` |
| [lib/core/network/](../lib/core/network/) | `createDio` + `AuthInterceptor`, `AppFailure` (erros do DRF → mensagens), `Paginated<T>` |
| [lib/core/router/app_router.dart](../lib/core/router/app_router.dart) | Rotas e redirecionamento de login |
| [lib/core/responsive/](../lib/core/responsive/) | `WindowSize` (breakpoints) e `AdaptiveShell` (NavigationBar/Rail) |
| [lib/core/theme/app_theme.dart](../lib/core/theme/app_theme.dart) | Tema Material 3 |
| [lib/core/widgets/](../lib/core/widgets/) | `PokemonSprite` (imagem com fallback), `ProgressBadge`, views de loading/erro/vazio, diálogo de confirmação, `OriginMarkChip`/`OriginMarkIcon` (marca de origem), `ShinyIcon`/`AlphaIcon`/`GoIcon` (ícones do HOME com emoji de reserva), `SearchField` (busca em pílula), `MenuChip` (chip de filtro com menu) |
| [lib/core/utils/origin_mark.dart](../lib/core/utils/origin_mark.dart) | `OriginMark`: slug da API → nome e ícone da marca de origem (a regra fica no backend) |
| [assets/](../assets/) | Arquivos empacotados no app (`pubspec.yaml` → `flutter: assets:`); hoje, os ícones das marcas de origem (fonte em `assets/README.md`) |
| [lib/features/auth/](../lib/features/auth/) | Login por token, armazenamento seguro do token, `AuthController` |
| [lib/features/personal_dex/](../lib/features/personal_dex/) | Dexes, boxes, slots; depositar, editar e libertar (`SlotActions`) |
| [lib/features/specimens/](../lib/features/specimens/) | Inventário (aba Espécimes), seletor de specimens para depósito, formulário de cadastro/edição (`ChoiceSelect`: select digitável com sprites), cadastro de treinador |
| [lib/features/settings/](../lib/features/settings/) | Servidor atual e logout |
| [lib/features/catalog/](../lib/features/catalog/) | Pacote do catálogo (`catalog.json`, gerado pelo backend): `Catalog` monta `FormRef`, `FormDetail`, opções e versões a partir dele, com as regras da API, e diz em que pokédex de cada jogo do HOME uma espécie está e em que versões dá para caçá-la (`pokedexesOf`, `huntableVersions`: exclusivos de versão e formas lançadas depois do jogo ficam de fora); carregado na inicialização com `CATALOG_URL` (`catalogOverrides`) |
| [lib/features/local/](../lib/features/local/) | Modo local (`LOCAL_DATA`): o arquivo de dados (`LocalStore`, com `updatedAt` por registro e marcas de exclusão, nascidos por comparação a cada gravação), o armazenamento (`shared_preferences`) e o `SaveScheduler`. O backend é o `FakeBackend.local`, com as mesmas regras da API |
| [lib/features/shiny_locks/](../lib/features/shiny_locks/) | Cadastro de shiny locks (Ajustes → Shiny locks): lista, criar, editar e apagar (`ShinyLockActions`) |
| [lib/fake/fake_backend.dart](../lib/fake/fake_backend.dart) | Backend em memória que segue as mesmas regras da API real |

## O caminho de um dado: da API até a tela

Exemplo: abrir um dex e ver a primeira box.

```
DexDetailPage.build
  └─ ref.watch(boxesProvider(dexId))                 ← personal_dex_providers.dart
       └─ ref.watch(personalDexRepositoryProvider)   ← escolhe HTTP ou fake pelo Env
            └─ HttpPersonalDexRepository.fetchBoxes  ← data/http_personal_dex_repository.dart
                 └─ dio.get('personal-dexes/1/boxes/')
                      └─ AuthInterceptor adiciona "Authorization: Token ..."
                 └─ BoxSummary.fromJson(...)         ← domain/models.dart (freezed)
  └─ boxes.when(data: ..., loading: ..., error: ...)
       └─ BoxView → ref.watch(slotsProvider((dexId, boxId))) → BoxGrid → SlotTile
```

1. A tela **observa** um provider. Na primeira vez, o provider está carregando
   e a tela mostra `LoadingView`.
2. O provider chama o repositório, que faz a requisição e converte o JSON em
   modelos.
3. Quando o `Future` completa, o provider emite `AsyncData` e a tela é
   reconstruída com os dados.
4. Se der erro, o repositório lança uma `AppFailure`
   ([app_failure.dart](../lib/core/network/app_failure.dart)). O provider
   emite `AsyncError`, a tela mostra `ErrorView` com a mensagem e um botão
   que chama `ref.invalidate(...)`.

## O fluxo de depósito

```
SlotTile (toque) ─► DexDetailPage guarda _selectedSlotId
                    └─ SlotDetailPanel ("Depositar")
                         └─ showDepositFlow()                 ← specimens/presentation/deposit_flow.dart
                              ├─ compacto: bottom sheet / demais: Dialog
                              └─ DepositPicker
                                   ├─ ref.watch(availableSpecimensProvider(formId))
                                   │    → GET /specimens/?form_id=&available=true
                                   ├─ sortForDeposit(): shiny primeiro em dex shiny
                                   ├─ shininess diferente do dex? → confirmação
                                   ├─ "Cadastrar novo" → SpecimenFormPage → POST /specimens/
                                   └─ SlotActions.deposit()   ← personal_dex_providers.dart
                                        → POST /slots/{id}/deposit/
                                        → invalida slots, boxes, dex e lista
                                        → telas atualizam sozinhas
```

Regras de negócio que vêm do backend e que o app trata:

- **Forma diferente** ou **specimen já depositado em outro slot**: a API
  responde 400 com `{"specimen_id": [...]}`. O `DepositPicker` mostra a
  mensagem e recarrega a lista.
- **Slot sem forma**: 400 com `{"non_field_errors": [...]}`. O app nem oferece
  o botão, porque slots livres não são clicáveis.
- **Slot registrado** não oferece depósito: as ações são as do próximo
  tópico.
- **Token inválido/expirado**: 401 faz o `AuthInterceptor` chamar
  `AuthController.expire()`, e o router leva de volta ao login.

## Painel do slot e detalhe do espécime

O painel do slot
([slot_detail_panel.dart](../lib/features/personal_dex/presentation/widgets/slot_detail_panel.dart))
e o detalhe do espécime no inventário
([specimen_detail.dart](../lib/features/specimens/presentation/specimen_detail.dart))
seguem o mesmo padrão, para as ações não empilharem botões:

- **Barra fixa no rodapé** (`DetailActionBar`, em
  [action_sheet.dart](../lib/core/widgets/action_sheet.dart)): só a ação
  principal (Depositar num slot faltante; Editar espécime num registrado) e
  **⋯ Mais ações**. O conteúdo rola por cima dela.
- **Mais ações** abre uma folha de ações (`showActionSheet`, padrão do iOS):
  Ver no dex (inventário), Enviar para jogo ou Trazer de volta ao HOME
  (`locationAction`), Retirar do slot e, separada e em vermelho, Libertar.
  Ações novas entram ali sem a tela crescer.
- **Corpo comum** (`DetailBody`, em
  [detail_body.dart](../lib/features/personal_dex/presentation/widgets/detail_body.dart)):
  sprite, nome, as linhas da forma e as abas. O que muda entre o slot e o
  espécime vem por parâmetro: a posição na caixa (só no slot), os chips de
  situação (Registrado/Faltante × Depositado/Disponível), os campos (OT,
  idioma, captura e observação, só no inventário) e a navegação da aba
  Espécie. As ações ficam com cada tela.
- **Abas** (`FormInfoTabs`): o resumo ("Espécime"; "Forma" num slot
  faltante ou na ficha) e **Espécie**. A altura fica a da aba aberta, e não a
  soma de tudo.
  - **Resumo:** tipos e habilidades (a do espécime destacada), os chips, o
    cartão **Status base** (`StatsCard`) e os campos. Em telas largas (a
    partir de 640 px), o cartão vai para a direita dos campos. Como na tela
    de resumo dos jogos, o hexágono (`BaseStatsChart`) fica junto dos dados:
    desenhado com `CustomPainter` (HP no topo e, no sentido horário, Ataque,
    Defesa, Velocidade, Def. Esp. e Atq. Esp.), com escala fixa até 200, o
    total e o EV. A natureza do espécime pinta os stats que muda e aparece
    embaixo do hexágono (o chip solto saiu); sem status, ela continua à
    vista.
  - **Espécie** (`SpeciesInfo`): linha evolutiva e outras formas (Mega,
    Gigantamax, regionais) com sprite, e uma grade com gênero, taxa de
    captura, ciclos de ovo, estreia, altura e peso. No dex, tocar numa forma
    leva ao slot dela (`formSlotsProvider` →
    `GET /slots/?personal_dex=&form=`), e a que não está no dex fica
    esmaecida. No inventário não há dex nem slot: tocar abre a **ficha da
    forma** (`showFormSheet`, em
    [form_sheet.dart](../lib/features/personal_dex/presentation/widgets/form_sheet.dart)),
    um bottom sheet só de leitura com as mesmas abas; tocar em outra forma
    troca a ficha, sem empilhar sheets, e a aba aberta continua.
  - Os dados vêm do detalhe da forma (`formDetailProvider` →
    `GET /forms/{id}/`), com carregamento e erro contidos na aba.

Na tela larga do inventário, o botão flutuante "Novo espécime" fica embaixo
da lista (à esquerda), para não cobrir a barra do detalhe.

## Editar, libertar e retirar

- **Editar espécime:** abre o `SpecimenFormPage` com `specimenId`. Ele
  carrega o specimen (`specimenProvider` → `GET /specimens/{id}/`), preenche
  o formulário com `SpecimenDraft.fromSpecimen` e salva com
  `PATCH /specimens/{id}/` (`toUpdateJson`: sem `form`, que o backend não
  deixa mudar). Depois, `SlotActions.specimenEdited` invalida o specimen e o
  slot. O formulário abre no navigator raiz, para cobrir a `NavigationBar`.
- **Libertar:** botão com a cor de erro e ícone de alerta, mais um diálogo
  destrutivo ("não pode ser desfeita"). `SlotActions.release` chama
  `DELETE /specimens/{id}/`: o cadastro é apagado e o slot fica faltante.

- **Retirar do slot:** tira o espécime do slot sem apagá-lo
  (`SlotActions.withdraw` → `POST /slots/{id}/withdraw/`): ele volta ao
  inventário como disponível, e o slot fica faltante. Como nada é apagado,
  não há confirmação; a mensagem tem **Desfazer**, que deposita de novo no
  mesmo slot.

## Depositar automaticamente

Menu ⋮ do dex → **Depositar automaticamente**
([auto_deposit_sheet.dart](../lib/features/personal_dex/presentation/widgets/auto_deposit_sheet.dart)):
espécimes do inventário que estão sem slot vão para os slots vazios do dex
(`POST /personal-dexes/{id}/link-specimens/`, a mesma regra do comando
`link_specimens` do backend). A folha mostra antes a prévia
(`linkPreviewProvider`, com `dry_run`): quantos e onde, com o selo "Não
shiny" nas exceções de um shiny dex, e a opção **Só espécimes shiny**
(`strict`). "Depositar N" confirma e recarrega boxes, contagens e caçadas
(`SlotActions.linkSpecimens`).

## Data de captura

- **Formato:** os Ajustes guardam o formato da data de captura
  ([`settings_providers.dart`](../lib/features/settings/settings_providers.dart),
  com `shared_preferences`). As opções são **Pokémon HOME** (`mm/dd/aaaa`,
  padrão) e **a do idioma do app** (pt-BR: `dd/mm/aaaa`).
- **PC** (`isDesktopPlatform`): o formulário usa o
  [`CaptureDateField`](../lib/features/specimens/presentation/widgets/capture_date_field.dart),
  digitável, com leitura estrita pelo `CaptureDatePattern`.
  - Erros "Data inválida (formato)" e "Data no futuro"; enquanto houver erro,
    não dá para salvar.
  - O botão de calendário também preenche o campo.
- **Celular:** tocar abre o calendário, e a data aparece no formato escolhido.
- **Onde vale:** só no formulário. O detalhe e o seletor de depósito
  continuam em `dd/mm/aaaa`.

## Autenticação

- [`AuthController`](../lib/features/auth/auth_providers.dart) é um
  `AsyncNotifier<String?>`: o valor é o token, ou `null` se deslogado.
- O token é salvo por um `TokenStorage`
  ([token_storage.dart](../lib/features/auth/data/token_storage.dart)),
  escolhido por `createTokenStorage`:
  - **web**: `PrefsTokenStorage` (`localStorage`). O `flutter_secure_storage`
    da web depende de WebCrypto, que não existe em HTTP fora de `localhost`, e
    o app é acessado pelo IP da rede (guia de deploy local, removido na v2.0.0);
  - **iOS**: `SecureTokenStorage` (Keychain).
- O `dioProvider` lê o token do `AuthController` a cada requisição.

## Escolha do PersonalDex

Um usuário pode ter vários dexes.

- **Criar pelo app:** "Novo PersonalDex" na lista abre o
  [`NewDexPage`](../lib/features/personal_dex/presentation/new_dex_page.dart).
  - **Padrão:** o mesmo conjunto de formas do comando `create_personal_dex`,
    com as regras explicadas na tela. Tem as opções "Dex shiny" e "Nova box a
    cada geração".
  - **Resumo antes de criar:** `GET /personal-dexes/preview/` diz quantas formas,
    quantas boxes, a partir de qual box e quantas boxes novas seriam criadas
    no fim (`boxesToCreate`; `firstBox` nulo = dex todo em boxes novas). Sem
    espaço nem criando boxes (limite de 300 do HOME, `homeMaxBoxes`), o botão
    fica desabilitado.
  - **Criação:** `POST /personal-dexes/` instala o esquema na primeira sequência
    de boxes livres (ou completa a do fim com boxes novas), e o app abre o dex
    novo.
  - **Personalizado:** aparece como "em breve". Chama `openCustomDexFlow`, que
    hoje só avisa e é o ponto a substituir quando esse fluxo for definido.

- **Editar e apagar:** o menu "⋮" da barra do dex (`DexMenu`) tem "Editar dex"
  (nome e "Dex shiny"; "nova box a cada geração" não muda, o esquema já está
  nas boxes) e "Apagar dex", com confirmação. Apagar libera os slots, mantém
  os espécimes no inventário (disponíveis) e volta para a lista. Fica num
  menu porque a barra já está cheia no celular. O `DexActions` invalida o que
  mostra o dex (e, ao apagar, o inventário); o "último dex" salvo não precisa
  ser limpo: `resolveHomeDexId` ignora um dex que não existe mais.

- **Último dex lembrado:** ao abrir um dex, a `DexDetailPage` grava o id num
  `LastDexStorage`
  ([last_dex_storage.dart](../lib/features/personal_dex/data/last_dex_storage.dart)),
  via `shared_preferences`. Não é dado sensível, então web e iOS usam o
  mesmo storage.
- **Abertura do app:** ao sair do login/splash, o `redirect` do router chama
  `homeLocation` → `resolveHomeDexId`: abre o último dex, se ele ainda
  existir; senão abre o único dex, se só houver um; senão mostra a lista.
  Se a API falhar, também cai na lista, que mostra o erro com "Tentar
  novamente".
- **Troca rápida:** o título do AppBar do dex é um
  [`DexSwitcher`](../lib/features/personal_dex/presentation/widgets/dex_switcher.dart)
  (`MenuAnchor`) com os outros dexes e o progresso de cada um, além de "Ver
  todos", que volta para a lista.
- A `DexListPage` continua sendo o lugar central dos dexes; é lá que vai
  entrar a criação de PersonalDex pelo app.

## Busca no dex

A busca (`GET /slots/?personal_dex=&search=`, com debounce) não fica num
diálogo: o Safari do iOS só abre o teclado com um toque no próprio campo (ver
`02-conceitos-flutter.md`). Como a tela inicial do iPhone, ela é uma pílula
"Buscar"
([`SlotSearchPill`](../lib/features/personal_dex/presentation/widgets/slot_search.dart))
16 px abaixo da grade da box, em todos os tamanhos de tela (nas telas maiores,
centralizada na coluna da grade). O conjunto grade + pílula fica centralizado
no espaço livre. A posição vem do tamanho da grade (`boxGridSize`, o mesmo
cálculo do `BoxGrid`): a área das boxes marca o lugar, e a página o mede
depois do layout.

A pílula é o próprio campo. Ao ganhar o foco, ela anima até o topo com um
`AnimatedPositioned` e vira a barra de busca (no celular, na largura da tela;
nas telas maiores, até 560 px, centralizada), a AppBar recolhe e os resultados
(`SlotSearchResults`) abrem por trás. O campo nunca é recriado, só muda de
lugar, então o foco e o teclado continuam durante a animação. Ativa, a busca
mostra "Cancelar", que leva a pílula de volta. O "x" do campo (como no
inventário) apaga o texto e mantém o foco, para buscar outra coisa.

Os resultados vêm por relevância (nome exato, depois os que começam com o
texto, depois os que só o contêm: "mew" mostra Mew antes de Mewtwo), e o
primeiro vem destacado. **Enter** (ou "Buscar" no teclado do celular) abre o
destacado, como um toque. Ele usa o texto do campo na hora, sem esperar o
debounce: se a lista ainda não chegou, a página marca "abrir quando chegar"
(`onReady` de `SlotSearchResults`, chamado depois do quadro, porque abrir muda
a tela). No PC, **↑/↓** movem o destaque (um `CallbackShortcuts` em volta do
campo pega as setas antes dos atalhos do texto, então o foco fica no campo),
o mouse também destaca, **Esc** cancela e uma linha embaixo da lista mostra os
atalhos. No celular, o destacado leva a etiqueta "Buscar abre".

Escolher um resultado fecha a busca, leva à box do slot e o seleciona; no
compacto, também abre o bottom sheet. O `PageView` ignora o `onPageChanged` da
página atual, para o pulo programático não limpar a seleção.

## AppBar do dex

Só o essencial, para o nome do dex caber no celular: o título
([`DexSwitcher`](../lib/features/personal_dex/presentation/widgets/dex_switcher.dart))
com o progresso do dex embaixo ("20 de 30 registrados · 66%"), o ícone de
Caçadas (só em shiny dex), "Destacar faltantes" e o menu ⋮
([`DexMenu`](../lib/features/personal_dex/presentation/widgets/dex_menu.dart)):
Progresso por geração, Editar dex e Apagar dex. "Destacar faltantes" é um
filtro da visualização e ganha fundo quando está ativo.

## Progresso por geração

"Progresso por geração", no menu ⋮ do dex, abre o
[`GenerationProgressView`](../lib/features/personal_dex/presentation/widgets/generation_progress.dart)
(`GET /personal-dexes/{id}/generations/`): uma linha por geração com
registrados/total e "Faltam N". Tocar numa geração leva à primeira box dela. O
`generationsProvider` é invalidado junto com as outras contagens em
`SlotActions`.

## Caçadas (shiny dex)

Num shiny dex, o ícone de alvo no AppBar abre a
[`HuntsPage`](../lib/features/personal_dex/presentation/hunts_page.dart)
(rota `/dexes/{id}/hunts`, `GET /personal-dexes/{id}/hunts/`): o que ainda
falta caçar, na ordem das boxes. Dois grupos de filtros no
[`HuntQuery`](../lib/features/personal_dex/domain/models.dart):

- **Motivos** (somados com OU), sempre à vista em chips: sem shiny (vazio ou
  espécime não shiny), shiny do GO e pokébola fora das escolhidas. O último
  motivo marcado não pode sair, porque sem motivo a lista fica vazia.
- **Escopo** (combinado com E), na folha "Filtros": categoria (lendário,
  mítico, Ultra Beast, bebê, comum), geração, tipo (qualquer um) e "incluir
  shiny impossível".

Cada item segue o estilo do inventário: o título é o mesmo
`SpecimenHeadline` (pokébola, nome/apelido, ♂️/♀️, ✨, alfa, 📱) com o
espécime que está no slot, ou só o nome da forma se o slot está vazio; o
sprite é o shiny da forma (o que se procura). O subtítulo, numa linha só,
traz "#0402 · HOME 12 · L1 C3 · motivo" (a espécie entra antes do nº quando
o título mostra um apelido). "Do GO" não aparece no texto porque o 📱 do
título já diz isso. Para isso o resumo do espécime no slot
(`SpecimenSummary`) traz `gender` e `is_from_go`.

Por que dentro de `personal_dex` e não numa feature própria: a lista é uma
visão do dex, e o `SlotActions` (depositar, editar, libertar) precisa
invalidar o `huntPageProvider`. Numa feature separada, uma importaria a outra.

Tocar num item **empilha** (`context.push`) a página do dex já na box e no
slot, com o painel aberto (no compacto, o bottom sheet abre sozinho quando a
URL traz `?slot=`). Com `push`, e não `go`, o voltar retorna à lista com os
filtros como estavam. Na API, cada item é um slot "achatado" com `reasons` e
`shiny_lock` ao lado, por isso o `Hunt.parse` é escrito à mão.

## Saves: Pokémon fora do HOME

O HOME transfere Pokémon para os jogos e de volta. Para não esquecer um
Pokémon num save, o espécime tem uma **localização**: `location` (um
`Save`, ou `null` = no HOME) e `locationSince`.

- **Save** ([`Save`](../lib/features/specimens/domain/models.dart)) é um
  treinador original (nome, TID e versão) marcado como "meu", em
  **Ajustes → Meus saves**
  ([saves_page.dart](../lib/features/specimens/presentation/saves_page.dart)).
  Só OTs de jogos que **recebem** do HOME servem (`Save.transferVersions`).
  O OT continua sendo "de onde o Pokémon veio"; o save é "onde ele está".
- **Fora do HOME, o espécime continua no slot**, que fica reservado para a
  volta (a API recusa depositar outro ali). Ele continua contando no
  progresso; as contagens trazem `away`, mostrado como "· 2 fora" na box,
  na lista de dexes e nas gerações.
- **Na box**, o slot fica esmaecido com o selo do jogo no canto superior
  direito (`OriginMark.fromVersion`: a marca de origem do jogo do save).
- **Ações** ([location_flow.dart](../lib/features/specimens/presentation/location_flow.dart)),
  reaproveitadas no painel do slot, no detalhe do espécime, na seleção do
  inventário (menu "Ações da seleção") e na tela "Fora do HOME":
  - *Enviar para jogo…*: escolhe o save numa folha. Sem saves, explica e
    oferece abrir Meus saves.
  - *Trazer de volta*: pergunta "Voltou igual / Evoluiu…". Se evoluiu,
    escolhe a forma nova; `POST /specimens/{id}/evolve/` troca a forma e
    tira o espécime do slot antigo (que volta a faltar). A evolução vem
    **antes** da transferência: se a forma não servir, nada muda.
  - Todas terminam com `specimensChanged()`, que recarrega slots,
    contagens, inventário e a lista "Fora do HOME".
- **Fora do HOME**
  ([away_page.dart](../lib/features/specimens/presentation/away_page.dart),
  rota `/specimens/away`, atalho na barra do inventário): espécimes
  agrupados por save, o que saiu há mais tempo primeiro, com "Saiu há N
  dias". São poucos, então vêm todos numa página só e o agrupamento é feito
  no app (`AwayPage.group`).
- **Filtro** "Onde está" na folha do inventário: no HOME, fora ou um save
  (`location` da API).

## Shiny locks

Formas sem shiny (`unobtainable`) ou com shiny só por distribuição
(`distro-only`) são cadastradas à mão, em **Ajustes → Shiny locks**, na
feature [`shiny_locks`](../lib/features/shiny_locks/):

- **Lista** ([shiny_locks_page.dart](../lib/features/shiny_locks/presentation/shiny_locks_page.dart)):
  ordem alfabética, filtro por tipo com a contagem, ícone do tipo (cadeado ou
  presente), as primeiras formas e o total. Inativos ficam esmaecidos, com o
  selo "Inativo".
- **Cadastro** ([shiny_lock_form_page.dart](../lib/features/shiny_locks/presentation/shiny_lock_form_page.dart)):
  a mesma tela cria e edita (tela cheia, no Navigator raiz). Nome,
  descrição, tipo (`SegmentedButton`), ativo e formas, adicionadas pelo
  seletor de forma do cadastro de espécime. Os erros da API (nome repetido,
  sem formas) aparecem nos campos, e mexer num campo tira o erro dele.
- **Depois de salvar ou apagar**, `ShinyLockActions` invalida a lista, as
  caçadas (o aviso e o "incluir shiny impossível") e o `formDetailProvider`
  (o aviso no painel do slot e no cadastro de espécime). Na API, só os locks
  **ativos** valem; no `FakeBackend`, os avisos das formas também vêm dos
  locks cadastrados (o seed tem um de exemplo, no Pikachu).

O enum do tipo é o `ShinyLockType`, o mesmo das caçadas (`Hunt.shinyLock`).

## Inventário (aba Espécimes)

A terceira aba lista **todos** os espécimes, depositados ou não:

- **Cabeçalho compacto** (`SpecimenHeadline`, como no Pokémon HOME):
  pokébola, nome/apelido e selos (♂️/♀️, ✨, ícone de alfa do HOME, 📱)
  numa linha.
  É o título de cada item da lista (o subtítulo é "Espécie · #0402", com o
  nº da dex nacional) e o nome nos detalhes do espécime e do slot, no lugar
  dos chips de Shiny, Alfa e pokébola. Recebe valores soltos porque o slot
  só tem o resumo do espécime; a pokébola acompanha o tamanho da fonte.
- **Filtros rápidos** na barra: busca por apelido, forma ou nº da dex
  nacional (com um "x" que limpa o campo e busca na hora; o
  `TextEditingController` fica no `State` da página, que também controla o
  debounce), Todos/Disponíveis/Depositados, Shiny, Alfa e GO.
- **Filtros avançados** na folha "Filtros": ordem, pokébola (e "sem"), OT
  (e "sem"), natureza, idioma, tipo (até 2, exige os dois), categoria
  (lendário, mítico, Ultra Beast, bebê, comum; qualquer uma, como nas
  caçadas: o enum `SpeciesCategory` é o mesmo), geração, gênero, habilidade e
  intervalo de captura. Tudo vai num `SpecimenQuery`
  (`toQueryParameters()`) para `GET /specimens/`. Paginação por página e
  decisões de layout em [02-conceitos-flutter.md](02-conceitos-flutter.md), 5.5.
- **Detalhe** ([`SpecimenDetailView`](../lib/features/specimens/presentation/specimen_detail.dart)):
  tela própria no compacto (`/specimens/:id`) e painel ao lado da lista nos
  demais. Ações:
  - Editar (o `SpecimenFormPage` de sempre);
  - Libertar (`SlotActions.releaseSpecimen`);
  - Ver no dex: `GET /slots/{id}/` descobre dex e box, e o app navega para
    `/dexes/:id?box=&slot=`.
- **Novo espécime:** o seletor de forma (`GET /forms/?search=`) e o
  formulário com `depositAfterSave: false` (botão "Salvar").
- **Edição em lote** ([bulk_edit_sheet.dart](../lib/features/specimens/presentation/widgets/bulk_edit_sheet.dart)):
  - toque longo entra no modo de seleção (AppBar contextual; tocar marca e
    desmarca);
  - a seleção **sobrevive** à busca e aos filtros: o lote pode juntar
    resultados de várias buscas. A AppBar mostra "N selecionados" e, se
    houver, "M fora da lista" (`specimenIdsProvider` com os ids da consulta
    atual);
  - o chip "Só selecionados" troca a lista por `SpecimenQuery(ids: ...)`
    (filtro `id` da API), para revisar e desmarcar antes do lote; mudar a
    busca ou um filtro volta para a lista normal;
  - "Selecionar todos os resultados" busca os ids do filtro
    (`GET /specimens/ids/`), inclusive páginas não carregadas, e **soma** à
    seleção;
  - a folha começa com tudo em "Manter" (`SpecimenChanges` de `FieldEdit`);
    confirmação com resumo e aviso de que não dá para desfazer;
  - `PATCH /specimens/bulk/` é tudo ou nada; gênero impossível para algum
    espécime → `GenderConflictFailure` com a lista, e o diálogo oferece
    "Desmarcar estes".
- **Libertar em lote** (mesma seleção, botão "Libertar em lote"): antes de
  confirmar, pergunta à API quantos dos marcados estão depositados
  (`GET /specimens/ids/?id=...&available=false`), porque parte deles pode
  estar em páginas não carregadas; a confirmação avisa que esses slots
  ficarão faltantes. `POST /specimens/bulk-release/` é tudo ou nada; depois,
  `specimensChanged()` recarrega inventário, contagens e caçadas, e o
  detalhe aberto ao lado fecha se era de um libertado.
- **Caches entre abas:** o `StatefulShellRoute` mantém as abas vivas, então
  depositar no dex precisa atualizar o inventário e vice-versa. Por isso:
  - `SlotActions` invalida `specimenPageProvider` junto com as contagens;
  - `SlotActions.specimensChanged()` invalida as famílias do dex (`dexProvider`,
    `boxesProvider`, `slotsProvider`) e o detalhe (`specimenProvider`) quando
    algo muda pelo inventário.

## Como adicionar uma feature (receita)

Exemplo: uma tela que lista **todos os specimens**.

1. **Modelo** (se precisar de um novo): em `features/<feature>/domain/models.dart`,
   crie a classe `@freezed` com `fromJson` e rode
   `dart run build_runner build`.
2. **Repositório**: adicione o método na interface
   (`specimens/domain/specimen_repository.dart`) e implemente em:
   - `HttpSpecimenRepository` (chamada Dio dentro de `guardRequest`);
   - `FakeBackend` (mesma regra, em memória).

   O compilador acusa as implementações que faltam.
3. **Provider**: em `specimens/specimen_providers.dart`, crie um
   `FutureProvider.autoDispose` que chama o método.
4. **Tela**: crie um `ConsumerWidget` em `presentation/`, use
   `ref.watch(...).when(...)` com `LoadingView`/`ErrorView`/`EmptyView`.
5. **Rota**: registre em `app_router.dart`. Para virar uma aba, adicione um
   `StatefulShellBranch` e um item em `shellDestinations`
   ([adaptive_shell.dart](../lib/core/responsive/adaptive_shell.dart)).
6. **Testes**: teste do repositório HTTP com `http_mock_adapter`, teste do
   `FakeBackend` e teste de widget da tela em tamanho compacto e expandido.
   Rode `flutter test --coverage && dart run tool/check_coverage.dart`.
   Veja [03-testes.md](03-testes.md).

## Decisões e por quês

| Decisão | Motivo |
| --- | --- |
| Modelos freezed servem de domínio e de DTO | App pessoal e pequeno: uma camada de DTO separada só duplicaria código. Se a API divergir do domínio, dá para separar depois. |
| Providers escritos à mão (sem `riverpod_generator`) | Menos código gerado e mais explícito para quem está aprendendo. |
| `Image.network` em vez de pacote de cache | O navegador já faz cache HTTP. `webHtmlElementStrategy.fallback` usa `<img>` se o CORS falhar. |
| Retry automático do Riverpod desligado | Erros de validação não devem ser repetidos; as telas têm "Tentar novamente". |
| Arquivos gerados fora do git | Diffs limpos. O CI e o README mandam rodar o `build_runner`. |
| Nomes de tipos (e, no futuro, golpes) em inglês | Seguem os dados da API (`language: en`). A interface continua em pt-BR; só esses nomes de jogo ficam como no original. |
