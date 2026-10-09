# Assets

Fora de `game_icons/`, `icons/` e `origin_marks/` para não entrar no bundle (o `pubspec.yaml` declara as pastas inteiras).

## Marcas de origem (`origin_marks/`)

Ícones das marcas de origem no padrão do Pokémon HOME (64×64, glifo branco com fundo transparente), baixados da [Bulbagarden Archives](https://archives.bulbagarden.net/) (artigo [Origin mark](https://bulbapedia.bulbagarden.net/wiki/Origin_mark)). As marcas são propriedade da Nintendo/Creatures/GAME FREAK/The Pokémon Company; aqui servem só para identificar a origem dos espécimes neste app pessoal.

| Arquivo | Original |
| --- | --- |
| `game_boy.png` | `GB_icon_HOME.png` |
| `gba.png` | `GBA_icon_HOME.png` (FireRed e LeafGreen do Switch; o original é cinza, convertido para RGBA) |
| `kalos.png` | `Blue_pentagon_HOME.png` |
| `alola.png` | `Black_clover_HOME.png` |
| `lets_go.png` | `Let's_Go_icon_HOME.png` |
| `galar.png` | `Galar_symbol_HOME.png` |
| `bdsp.png` | `BDSP_icon_HOME.png` |
| `hisui.png` | `Arceus_mark_HOME.png` |
| `paldea.png` | `Paldea_icon_HOME.png` |
| `lumiose.png` | `Z-A_icon_HOME.png` |
| `go.png` | `GO_icon_HOME.png` |

O app pinta o branco com a cor do tema (`OriginMarkIcon`, em `lib/core/widgets/origin_mark_chip.dart`).

O `champions.png` (o Pokémon que visita o Pokémon Champions, #174) não é marca de origem nem existe nas Archives: é a marca "Has visited Pokémon Champions" do HOME, redesenhada em SVG a partir de uma captura (`champions_mark.svg`, fora do bundle) e exportada no mesmo padrão (64×64, glifo branco).

## Ícones de jogo (`game_icons/`)

Ícones dos jogos no Pokémon HOME (128×128, coloridos), baixados da Bulbagarden Archives, categoria [Pokémon HOME game icons](https://archives.bulbagarden.net/wiki/Category:Pok%C3%A9mon_HOME_game_icons). Só os jogos ligados ao HOME (os que viram save e o FireRed/LeafGreen do Switch, que só envia), com o nome da versão no catálogo. Mesma ressalva de propriedade das marcas de origem.

| Arquivo | Original |
| --- | --- |
| `champions.png` | `HOME_Champions_icon.png` (o Pokémon Champions, que não é save: só o detalhe e as ações da visita) |
| `firered.png` | `HOME_FireRed_icon.png` |
| `leafgreen.png` | `HOME_LeafGreen_icon.png` |
| `lets-go-pikachu.png` | `HOME_Let's_Go_Pikachu_icon.png` |
| `lets-go-eevee.png` | `HOME_Let's_Go_Eevee_icon.png` |
| `sword.png` | `HOME_Sword_icon.png` |
| `shield.png` | `HOME_Shield_icon.png` |
| `brilliant-diamond.png` | `HOME_Brilliant_Diamond_icon.png` |
| `shining-pearl.png` | `HOME_Shining_Pearl_icon.png` |
| `legends-arceus.png` | `HOME_Legends_Arceus_icon.png` |
| `scarlet.png` | `HOME_Scarlet_icon.png` |
| `violet.png` | `HOME_Violet_icon.png` |
| `legends-za.png` | `HOME_Legends_Z-A_icon.png` |

Usados por `GameIcon` (`lib/core/widgets/game_icon.dart`), que mostra a sigla do jogo se o asset faltar.

## Ícone de alfa (`icons/alpha.png`)

Selo de alfa do Pokémon HOME/Legends: Arceus (58×61, colorido), baixado da Bulbagarden Archives como `Alpha_icon.png` ("Icon used in summary screen of Alpha Pokémon"; artigo [Alpha Pokémon](https://bulbapedia.bulbagarden.net/wiki/Alpha_Pok%C3%A9mon)). Não confundir com `Alpha_Mark.png`, a marca "Former Alpha" de Scarlet/Violet. Mesma ressalva de propriedade das marcas de origem.

Usado por `AlphaIcon` (`lib/core/widgets/mark_icons.dart`), que volta ao emoji 💢 se o asset falhar.

## Ícone de shiny (`icons/shiny.png`)

As duas estrelas laranja que marcam um shiny no Pokémon HOME (44×44, colorido), baixadas da Bulbagarden Archives como [`ShinyHOMEStar.png`](https://archives.bulbagarden.net/wiki/File:ShinyHOMEStar.png) ("Image of the star indicating a Shiny Pokémon from the mobile version of Pokémon HOME"; artigo [Shiny Pokémon](https://bulbapedia.bulbagarden.net/wiki/Shiny_Pok%C3%A9mon)). Mesma ressalva de propriedade das marcas de origem.

Usado por `ShinyIcon` (`lib/core/widgets/mark_icons.dart`), que volta ao emoji ✨ se o asset falhar. O "veio do GO" usa a marca de origem `go.png` pelo `GoIcon`, com o 📱 de reserva.
