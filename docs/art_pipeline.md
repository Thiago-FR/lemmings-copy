# Pipeline de Arte — Como geramos as imagens

Decidido em 1º de novembro de 2026. Convenções de código estão em
[CLAUDE.md](../CLAUDE.md); mecânicas em [game_design.md](game_design.md).

## Regra geral

**Nenhuma imagem é desenhada à mão.** Tudo é gerado — ou por código, ou por
IA rodando na máquina local. Nenhuma ferramenta paga, nenhuma chave de API,
nenhuma mensalidade.

A escolha entre os dois caminhos é pelo **tamanho** da imagem:

| Tamanho | Caminho | Por quê |
|---|---|---|
| Até ~32 px | Código (GDScript) | Modelo de IA não controla pixel individual nesse tamanho — gera borrado e perde o detalhe ao reduzir. |
| Acima de ~64 px | ComfyUI local | Tamanho suficiente para o modelo acertar forma, sombra e textura. |

## Caminho 1 — Geração por código (GDScript)

Para blocos de terreno e ícones simples.

- Os geradores ficam em `tools/`. O `build_terrain_tileset.gd` roda pelo
  próprio Godot e monta o TileSet (tiles e colisão); a arte do terreno é
  desenhada pelo `build_terrain_art.py` (ver "Terreno" abaixo).
- Exceção: as animações do mago montadas a partir da arte existente
  (`build_dig_frames.py`, `build_death_frames.py`, `build_float_frames.py`,
  `build_climb_frames.py`, `build_pickaxe_frames.py`, `build_jackhammer_frames.py`,
  com funções em comum
  em `wizard_art.py`) são em Python, porque é trabalho de máscara pixel a pixel.
  O que é desenhado novo (pá, poeira) usa a mesma grade de ~7 px da arte
  original, senão as bordas ficam finas demais perto do personagem.
- O paraquedas (`build_float_frames.py` → `float_0..3.png`, animação
  `float`, 6 fps) é o quadro de andar de lado, sem a mão da cintura e com
  os dois braços levantados segurando as cordas, pendurado sob uma cúpula
  listrada creme/vermelha de 30x9 células, com só quatro cordas (mais que
  isso vira borrão na escala do jogo). A cúpula balança uma célula para
  cada lado e inclina junto; o corpo balança como pêndulo (±5° em torno do
  centro da caixa de colisão), os pés chutam devagar — um desce enquanto o
  outro sobe — e a barra da túnica fica uma célula atrás do balanço. Esses
  quadros têm 250x404 em vez de 250x250: o `AnimatedSprite2D` centraliza
  cada quadro, então o espaço extra é acrescentado igual em cima e embaixo —
  o corpo fica exatamente na mesma posição dos quadros de andar (alinhado
  com a colisão 26x30) e a cúpula ocupa as linhas de cima. Mudar a altura
  de um lado só desalinha o corpo.
- A escalada com garras (`build_climb_frames.py` → `climb_side_0..3.png`,
  animação `climb`, 7 fps) é vista de lado, olhando para a parede à direita
  (o jogo espelha com `flip_h` quando anda para a esquerda). O corpo de
  andar inclina 6° para a parede e recua duas células; os braços são
  curtos, saem do ombro e as mãos, com garras pequenas, encostam na borda
  direita da caixa de colisão, onde fica a parede. Uma mão segura na altura
  da cabeça e a outra perto do peito, e elas trocam; quem carrega a subida
  é o corpo, que sobe uma célula entre uma
  pegada e outra, e os pés, que se revezam empurrando a parede. Mãos acima
  do capuz foram descartadas: o braço ficava com o dobro do comprimento que
  o corpo permite e o mago parecia um boneco de borracha. A vista de costas
  antiga (`climb_aligned_*`) continua no `SpriteFrames` como animação
  `ladder`, usada pela escada vertical.
- A picareta (`build_pickaxe_frames.py` → `pickaxe_0..3.png`, animação
  `pickaxe`, 5 fps) é a versão de lado da pá: mesmo corpo de andar sem a
  mão da cintura, com a ferramenta, o braço e as lascas desenhados na grade
  de ~7 px. A picareta sai de trás do capuz, passa por cima, crava na
  parede na altura do peito (a ponta passa um pouco da borda direita da
  colisão) e recua; o corpo balança em torno dos pés (para trás na
  preparação, para a frente no golpe) e lascas saem da parede no golpe e no
  recuo. Uma mão só no cabo: duas mãos de 2x2 viravam um palito cor de pele
  na escala do jogo.
- A britadeira (`build_jackhammer_frames.py` → `jackhammer_0..3.png`,
  animação `jackhammer`, 12 fps) usa o mesmo corpo de lado, recuado duas
  células, segurando na altura da cintura uma britadeira deitada: carcaça
  cinza de 6x4 células com aletas escuras (é o que diferencia de uma arma
  nessa escala), alça em D em cima com a pega amarela (preta sumia contra o
  rosto escuro do capuz), bico e broca clara. Não há balanço: corpo e
  ferramenta tremem uma célula entre os quadros (o tronco só desce, nunca
  sobe, para a túnica não descolar dos pés, que só tremem para os lados), a
  ponta da broca entra e sai uma célula em volta da borda direita da
  colisão e solta poeira da parede. Braço curto, do ombro até a pega.
- As funções em comum desses três (corpo sem a mão, separar os pés, braço
  com mão e garras, girar um ponto junto com o corpo) estão em
  `wizard_art.py`.
- GDScript e não Python de propósito: o projeto fica com uma ferramenta só,
  a mesma que já é necessária para rodar os testes.
- Vantagem: controle exato de cada pixel, resultado idêntico toda vez que
  roda, e o arquivo fonte é o script — dá para ajustar uma cor e regerar.

## Terreno (blocos, bordas, escada, tijolo)

Gerado por `tools/build_terrain_art.py` (Python + PIL, pixel a pixel, com
`random` de semente fixa: o resultado é sempre o mesmo) em
`assets/sprites/terrain/`. Um texel = um pixel da tela, que é também o
tamanho de uma "célula" da arte do mago na escala 0,15, então terreno e
personagem ficam na mesma grade. Mesma lógica de paleta do mago: contorno
quase preto em toda borda que dá para o ar, faixas de cor chapada, um pouco
de ruído. Terra em marrons mais escuros e menos saturados que o roxo do
manto, para o mago se destacar; concreto em cinzas frios; madeira (escada e
tijolo) mais clara e quente que a terra.

**Chão e parede são o mesmo bloco** (mesmo material, mesma colisão). A
diferença é só no desenho, decidida pelos vizinhos, para servir também a
mapas gerados por código:

| Situação do bloco | Desenho |
|---|---|
| ar em cima | **chão**: grama (terra) ou borda de laje (concreto) |
| ar do lado, coberto em cima | **parede**: contorno e faixa erodida com pedrinhas (terra), aresta clara/escura (concreto) |
| ar embaixo | **teto**: faixa escura com raízes penduradas (terra) |
| cercado | **interior**: só o tile |
| chão encontra parede no topo | **canto**: a grama dobra a quina |

Como funciona:

- Os tiles do TileSet (`terrain_atlas.png`, linha 0 terra, linha 1
  concreto, 4 estágios de escavação) mostram **só o interior**, sem borda.
  Coordenadas do atlas, colisão e todas as consultas continuam iguais.
- `TerrainEdgeOverlay` (`scripts/level/terrain_edge_overlay.gd`), filho do
  `TerrainDestructible`, desenha por cima as tiras de borda
  (`<material>_floor`, `_wall_left/right`, `_ceiling`, `_corner_left/right`).
  O terreno o avisa pelo gancho `_update_cells()` do `TileMapLayer`, que o
  Godot chama para **qualquer** mudança de célula (métodos do terreno,
  `set_cell` direto dos testes, `tile_map_data` copiado no editor).
- As bordas seguem o que **sobrou** do bloco (`get_cell_solid_rect`): bloco
  cavado por cima tem o chão na superfície cavada; cavado de lado, a parede
  no corte; vizinho cavado só cobre parte do lado, e o resto aparece como
  exposto.
- **Grama só nasce em superfície que já estava aberta quando o terreno foi
  preenchido** (o primeiro `_update_cells`) ou em bloco colocado depois
  (`build_cell_at`: editor, ferramenta Bloco). Chão de túnel, fundo de poço
  e cratera ficam com terra crua cortada (`earth_floor_dug`).
- `earth_details.png`: pedras e raiz espalhadas em ~45% dos blocos inteiros,
  escolhidas pela coordenada da célula, para o tile de 32px não se repetir
  igualzinho num maciço de terra.
- `ladder.png`: trilhos e degraus de madeira, degraus a cada 8px (emenda sem
  costura). `brick.png`: tábua 32x8 com pregos, usada por
  `TerrainDestructible.place_brick` (ponte e escada diagonal) num
  `TextureRect` esticado ao tamanho do tijolo.
- O terreno usa filtro `NEAREST` (os filhos herdam): com o filtro linear
  padrão a arte borra quando a janela muda de tamanho.

Regerar: `python tools/build_terrain_art.py`, depois
`godot --headless --path . --import` e
`godot --headless --script res://tools/build_terrain_tileset.gd`. Para
conferir: `godot --path . --resolution 800x450 --script
res://tools/capture_terrain_preview.gd -- saida.png` (sem `--headless`:
precisa renderizar; abre uma janela por um instante) monta uma cena de
amostra com chão, parede, plataforma, poço, túnel, concreto, escada, ponte e
magos, e salva a imagem. A geometria das tiras (quantas linhas a grama sobe
acima da superfície, etc.) está nas constantes do topo do `.py` e do
`TerrainEdgeOverlay`, que precisam bater.

## Interface (ícones, painel, slots)

Gerado por `tools/build_ui_art.py` (Python + PIL, mesma regra do terreno:
pixel a pixel, semente fixa, paleta do terreno e do mago) em
`assets/sprites/ui/`. Cada forma é desenhada em cores chapadas e ganha
automaticamente um contorno de 1 px quase preto, o que mantém tudo legível
em 32 px sobre fundo claro e escuro. Usar filtro `NEAREST` (escala 2x/3x
sem borrar).

| Arquivo | Tamanho | Uso |
|---|---|---|
| `icons/<id da ferramenta>.png` | 32x32 | digger, builder, ladder_vertical, bridge, floater, climber, block, dynamite, tnt, basher, miner |
| `icons/editor_<nome>.png` | 32x32 | earth, concrete, ladder, brick, eraser, entrance, exit, play, pause, restart, menu, counts |
| `icons/sound_on.png`, `sound_off.png` | 32x32 | botão de som |
| `panel.png` | 24x24 | fundo/moldura da barra (`StyleBoxTexture`), **margens 9-slice = 8** nos quatro lados |
| `slot.png`, `slot_hover.png`, `slot_selected.png`, `slot_disabled.png` | 40x40 | fundo do item, **margens 9-slice = 4** nos quatro lados |

- As bordas do painel e dos slots são uniformes ao longo do comprimento, para
  esticar sem borrar; os únicos detalhes (rebites) ficam nos cantos, que o
  9-slice nunca estica. O centro é cor chapada (pode esticar ou repetir).
- Um ícone de 32 dentro de um slot de 40 deixa 4 px de folga, exatamente a
  margem do slot.
- Para distinguir à primeira vista: escada diagonal = degraus de tábua
  subindo com estacas; escada vertical = trilhos e degraus; ponte = tábuas
  retas entre dois barrancos com grama. Pá = lâmina larga; picareta = cabeça
  fina em meia-lua; britadeira = em pé, com pegas amarelas (como na animação).
- `editor_ladder` é o mesmo desenho de `ladder_vertical`.

Regerar: `python tools/build_ui_art.py [preview.png]` (com o caminho, salva
também uma folha de conferência em 1x e 3x, fundo claro e escuro, com a barra
montada em 9-slice), depois `godot --headless --path . --import`.

## Cartas (recompensas do modo roguelike)

Gerado por `tools/build_card_art.py` (Python + PIL, mesmas regras e mesma
paleta de `build_ui_art.py`, cujas funções ele importa) em
`assets/sprites/ui/cards/`. Usar filtro `NEAREST`; foi conferido em 1x e 2x.

| Arquivo | Tamanho | Uso |
|---|---|---|
| `card_tool.png`, `card_tool_hover.png` | 120x168 | cargas e ferramenta nova (madeira e latão) |
| `card_recruit.png`, `card_recruit_hover.png` | 120x168 | recrutar personagem (tecido roxo, costura dourada) |
| `card_relic.png`, `card_relic_hover.png` | 120x168 | relíquias (pedra escura, filigrana dourada) |
| `card_rescue.png`, `card_rescue_hover.png` | 120x168 | Pena da fênix (vermelho e laranja, chamas) |
| `relic_<id>.png` | 64x64 | `sharp_blades`, `long_bridge`, `long_ladders`, `short_fuse`, `extra_pocket`, `spare_parachute` (ids de `relics.gd`) |
| `character_<id>.png` | 64x64 | `wizard`, `miner`, `engineer`, `scout`, `tinkerer` (ids e cores de `character_catalog.gd`) |
| `rescue_phoenix.png` | 64x64 | Pena da fênix |

Cartas de ferramenta não têm ilustração: usam o ícone 32x32 da ferramenta
(`icons/<id>.png`) ampliado 2x, que preenche a janela exatamente.

Retângulos dentro da carta (x, y, largura, altura, em pixels da carta em 1x;
em 2x, multiplicar tudo por 2). São iguais em todas as famílias e nas
variantes hover. A moldura de cada área fica **fora** do retângulo, então o
interior inteiro é livre:

| Área | Retângulo | Conteúdo |
|---|---|---|
| Faixa do título | `(12, 11, 96, 15)` | cor chapada escura, para texto creme centralizado |
| Janela da arte | `(28, 34, 64, 64)` | fundo radial escuro; a ilustração 64x64 (ou o ícone 32x32 em 2x) vai em `(28, 34)` |
| Painel de texto | `(12, 108, 96, 50)` | cor chapada escura, 2 a 3 linhas de texto creme |

- Hover/selecionada: mesma carta com a borda externa, os frisos da faixa, da
  janela e do painel trocados por dourado brilhante. Mesmo tamanho, basta
  trocar a textura.
- Os enfeites de canto passam por cima das molduras, mas nunca entram na faixa
  do título nem no painel de texto (o gerador recorta).
- Ilustrações têm fundo transparente e contorno de 1 px, como os ícones; o
  fundo vem da janela da carta.
- Retratos: o Mago é o encapuzado (olhos amarelos, mochila, alça no peito)
  em 3/4 para a direita, com o cajado de orbe. Os outros quatro são bustos
  dos próprios sprites, desenhados em `tools/character_portraits.py` (ver
  "Personagens" abaixo).

Regerar: `python tools/build_card_art.py [preview.png]` (com o caminho, salva
uma folha de conferência com todas as cartas, normal e hover, com ilustração
e texto de exemplo, e todas as ilustrações, em 1x e 2x), depois
`godot --headless --path . --import`.

## Personagens (desenhados do zero)

Gerado por `tools/build_character_variants.py` (Python + PIL, sem
aleatoriedade), com os desenhos em `tools/character_designs.py`. O Mago fica
como está; os outros quatro de `character_catalog.gd` (`miner`, `engineer`,
`scout`, `tinkerer`) têm corpo próprio — a primeira versão, que só trocava a
cor do manto do mago e punha um acessório, foi descartada pelo usuário
("eu quero literalmente outro tipo de sprite").

O que é compartilhado com o mago é só o **contrato dos quadros**, para o
código do jogo não mudar: o script lê o `SpriteFrames` `wizard_placeholder`
de `scenes/characters/lemming.tscn` (animações, fps, loop, duração e ordem),
escreve cada quadro com o mesmo nome e o mesmo tamanho do quadro do mago
(250x250; `float_*` 250x404, com o espaço extra igual em cima e embaixo) em
`assets/sprites/characters/<id>/`, e `resources/sprite_frames/<id>.tres`
(e `wizard.tres`, apontando para os quadros originais) com exatamente as
mesmas animações. Animação nova no `lemming.tscn` sem desenho no script
para a execução com erro, dizendo o que falta.

Os desenhos são ASCII, um caractere por célula da grade de 7 px (~1 px na
tela), uma letra por cor. Cada personagem tem três vistas da parte de cima
do corpo (cabeça e tronco): de lado olhando para a direita (o jogo espelha),
de frente (pá) e de costas (escada vertical). Pernas, botas e braços são
gerados a partir dos quadris e ombros de cada vista, e cada parte ganha
contorno de uma célula antes de empilhar, por isso braço e perna se
destacam do tronco. Peças que mexem sozinhas ou ficam atrás (cachecol,
tábuas, antena) são camadas à parte.

| Personagem | Silhueta | Cores |
|---|---|---|
| Mineiro (`miner`) | baixo e largo, pernas curtas e grossas, capacete de aba larga com lanterna na frente, barba grande cobrindo o peito, suspensórios, botas pesadas | capacete laranja, camisa ferrugem, barba e calça marrons |
| Engenheiro (`engineer`) | médio, boné de aba longa com óculos de solda levantados, macacão com bolso, cinto de ferramentas, **feixe de três tábuas amarrado nas costas** passando da cabeça (é com elas que a ponte e a escada dele ficam maiores) | boné e macacão azuis, camisa amarela, tábuas de madeira clara |
| Batedor (`scout`) | o mais alto e magro, capuz verde de ponta caída para trás com o rosto à mostra, cachecol vermelho com as pontas voando para trás (mudam a cada quadro), capa curta, pernas longas com botas de cano alto; anda inclinado para a frente | verdes, cachecol vermelho, couro marrom |
| Inventor (`tinkerer`) | pequeno de cabeça grande, cabelo branco espetado, óculos redondos enormes de lente ciano, mochila de couro com engrenagem de latão e **antena com bulbo vermelho** subindo atrás | casaco ciano, latão, cabelo branco |

Poses, todas com os pés na mesma linha do chão e o corpo centrado na caixa
de colisão de 26x30:

- `walk_aligned_*`: passo de quatro tempos (contato, passagem com o corpo
  uma célula acima e o pé que vem levantado, contato do outro lado,
  passagem), o braço da frente balançando contra as pernas.
- `dig_aligned_*` (de frente): o corpo agacha 0/1/3/2 células com os pés
  plantados e os joelhos abrindo — as mesmas proporções em que o mago
  achata —, e os dois braços vão às mãos no cabo.
- `climb_aligned_*` (de costas, escada vertical): as mãos se revezam
  pegando o degrau acima da cabeça, com o pé do outro lado levantado.
- `climb_side_*`, `pickaxe_*`, `jackhammer_*`, `float_*`: mesma inclinação,
  recuo, tremida e balanço do mago. A inclinação é feita deslocando linhas
  inteiras de células (não girando a imagem), para as bordas continuarem
  nítidas. Na escalada o corpo chega mais perto da parede que o do mago
  (até 3 células), para os braços ficarem curtos.
- `death_fall_*`: o quadro em pé achatado e alargado como o do mago, com a
  mesma poeira (funções de `build_death_frames.py`).
- **Ferramentas** (pá, picareta, britadeira, garras, paraquedas e cordas),
  poeira e lascas saem das mesmas funções e das mesmas poses por quadro dos
  `build_*_frames.py` do mago, então ficam exatamente no mesmo lugar e no
  mesmo tempo; só o braço que segura parte do ombro de cada personagem.

A linha de baixo das botas fica em y=237 nos quadros de 250 (a do mago é
235): as ferramentas do mago são desenhadas na grade de 7 px começando em
0, e o corpo novo usa a mesma grade para casar com elas — 2 px na arte,
0,3 px na tela.

Retratos das cartas (`character_<id>.png`, 64x64): desenhados em
`tools/character_portraits.py`, que o `build_card_art.py` usa para os
quatro (o do Mago continua lá). Busto de 3/4 para a direita com as mesmas
cores do sprite; a silhueta sozinha identifica o personagem, porque a tela
de escolha mostra os bloqueados como sombra preta.

Regerar: `python tools/build_character_variants.py [preview.png]` (com o
caminho, salva uma folha com um quadro de cada animação por personagem ao
lado do mago, ampliado e na escala do jogo em 1x e 3x),
`python tools/build_card_art.py` para os retratos, depois
`godot --headless --path . --import`. Mudou alguma pose de ferramenta do
mago? Rode os `build_*_frames.py` primeiro e este script depois — as poses
são lidas deles.

## Entrada e saída

Gerado por `tools/build_portal_art.py` (Python + PIL, mesmas regras e paleta
de `build_ui_art.py`, cujas funções ele importa) em `assets/sprites/level/`.
Cada peça (moldura, porta, corrente, bandeira) é desenhada numa camada
própria com contorno de 1 px antes de empilhar, para a porta que gira
manter a borda escura por cima da moldura. Fundo transparente, filtro
`NEAREST`, conferido em 1x e 3x ao lado do mago e de um bloco de terra.

| Arquivo | Tamanho | Quadros | fps | Uso |
|---|---|---|---|---|
| `entrance_open_0..4.png` | 48x46 | 5 | 10, sem repetir | alçapão abrindo: fechado → portas penduradas |
| `entrance_idle_0..3.png` | 48x46 | 4 | 6, em loop | aberto: brilho azul pulsando, facho de luz, faíscas caindo, portas balançando |
| `exit_idle_0..3.png` | 44x56 | 4 | 6, em loop | arco de pedra com luz verde tremulando e bandeira verde ondulando |

- **Entrada**: caixa de madeira afunilada pendurada por duas correntes numa
  argola, com alçapão de duas folhas embaixo. Por dentro é azul, como o
  ícone `editor_entrance`. O facho de luz semitransparente que sai por baixo
  quando abre é o que impede as portas abertas de parecerem pés de mesa.
  Tocar `entrance_open` uma vez quando o nível começa e depois
  `entrance_idle` em loop.
- **Saída**: a abertura do arco tem 22 px de largura (colunas 11..32) e vai
  da linha 20 à 51, com o miolo branco na altura do corpo do mago. Verde
  como o ícone `editor_exit` e o placeholder antigo; laranja foi descartado
  porque o arco virava forno.

Âncora (pixel da imagem que fica na origem do nó; com `centered = false`, o
`offset` é o negativo disso):

| Peça | Pixel âncora | `offset` | O que é |
|---|---|---|---|
| Entrada | (24, 32) | (-24, -32) | centro da borda de baixo da caixa, logo abaixo da boca (última linha da boca = 31). O mago nasce com o centro do corpo aí: a metade de cima aparece dentro da boca iluminada (desenhar a entrada atrás dos magos) e ele cai pelo vão entre as portas. |
| Saída | (22, 56) | (-22, -56) | centro da base, apoiado no chão (a linha 55 é o contorno da soleira). Se a origem do `ExitPoint` continuar no centro da colisão 32x48 (base em y = +24), o `offset` fica (-22, -32). |

Regerar: `python tools/build_portal_art.py [preview.png]` (com o caminho,
salva uma folha com todos os quadros em 1x e 3x, fundo escuro e claro, ao
lado de um quadro do mago e de um bloco de terra com grama), depois
`godot --headless --path . --import`.

## Cenários (blocos, entrada e saída de cada ambiente)

Gerado por `tools/build_terrain_themes.py` (Python + PIL), que importa
`build_terrain_art.py` e lê os quadros de `build_portal_art.py`: **a mesma
arte, recolorida**, com os mesmos nomes de arquivo, numa pasta por tema:

| Tema | Ambiente (`LevelEnvironment`) | Blocos | Concreto | Entrada / saída |
|---|---|---|---|---|
| `sand` | Deserto | arenito com mato seco em cima, fósseis enterrados | pedra talhada | madeira clara, luz dourada |
| `crystal` | Caverna de cristal | ardósia azul com tufos de cristal ciano, cristais enterrados | cristal lilás | azul-ardósia, luz ciano |
| `snow` | Campo de neve | rocha congelada azul com neve em cima | gelo | madeira gelada, luz azul-clara |
| `basalt` | Vulcão | basalto preto com brasas e crosta de lava em cima | obsidiana | madeira queimada, luz laranja |

- Saem em `assets/sprites/terrain/themes/<tema>/` (`terrain_atlas.png` e
  as tiras de borda) e `assets/sprites/level/themes/<tema>/`
  (`entrance_open_*`, `entrance_idle_*`, `exit_idle_*`). Escada e tábua
  continuam de madeira em todos.
- **Blocos: cor por cor.** A paleta de `build_terrain_art.py` tem nome
  (`EARTH_BASE`, `GRASS`, `CONCRETE_SEAM`...) e cada tema dá uma cor nova a
  cada nome (a grama vira neve, mato seco, cristal ou brasa). `crystal` e
  `sand` desenham os próprios detalhes enterrados (`earth_details.png`).
- **Entrada e saída: por faixa de matiz** (a paleta delas está espalhada em
  dois scripts): madeira (laranja-marrom) ganha o matiz do tema, a luz azul
  e a verde viram a cor da luz do tema, pedra e ferro (pouca saturação)
  levam o tom de pedra do tema; contornos e o buraco escuro ficam.
- Nenhuma rocha de tema é roxa: o mago é roxo.
- O jogo só troca de pasta (`TerrainDestructible.art_directory_for`,
  `PortalSprite.make(..., tema)`); tema sem pasta usa a arte padrão.
- Os **fundos** desses ambientes não têm arquivo: são desenhados em código
  pelo `LevelBackground` (dunas e sol; picos com neve e flocos caindo; picos
  com lava, sol vermelho e brasas subindo; estalactites, pontos que piscam e
  cristais saindo do chão).

Regerar: `python tools/build_terrain_themes.py [amostra.png]` (com o
caminho, salva uma cena pequena de cada tema lado a lado em 3x), depois
`godot --headless --path . --import`. Mudou a arte padrão do terreno ou da
entrada/saída? Rode este script depois, os temas saem dela.

## Ícones da campanha

`tools/build_campaign_art.py` (mesmas regras e funções de
`build_ui_art.py`) desenha em `assets/sprites/ui/icons/`: `campaign` (mapa
com trilha e bandeira, botão "Fases" do menu), `lock` (cadeado, fase
fechada), `star` (estrela, fase ganha) e `next` (seta verde, próxima fase).
Regerar: `python tools/build_campaign_art.py [amostra.png]`, depois
`godot --headless --path . --import`.

## Caminho 2 — ComfyUI local

Para fundo de fase, textura de terreno e ícones do painel de habilidades.

- **Hardware desta máquina:** RTX 3060 com 12 GB de VRAM, 24 GB de RAM.
  Folgado para geração de imagem local.
- **Custo:** zero, para sempre. Roda na placa de vídeo, nada sai da máquina,
  sem limite diário.
- **Instalação:** ~10 a 15 GB de disco (o peso são os modelos).
- O ComfyUI tem servidor próprio que permite a IA comandar a geração
  diretamente, sem ninguém clicar na interface.

## Descartados, e por quê

| Ferramenta | Motivo |
|---|---|
| Aseprite | Pago (~US$ 20). |
| `pixelforge-mcp` / Gemini | A chave é gratuita, mas os modelos de **geração de imagem** do Google exigem cobrança ativada. Gratuito só na teoria. |
| LibreSprite + servidor | As funções de editar pixel (`get_pixel`/`set_pixel`) não estão implementadas — são esqueleto vazio. Não cria camada nem quadro novo. |
| Pixelorama | Bom, gratuito e aberto, mas é para desenhar à mão. Fora da regra geral. |

## Ordem de execução

Arte entra **depois** do gameplay, nunca antes. O personagem continua sendo
o mago de `assets/sprites/characters/wizard/`, que já existia e já tem o
tamanho certo em relação à colisão.

Uma lição da primeira tentativa: **o tamanho do personagem define a grade do
terreno, não o contrário.** Encolher o desenho para caber numa grade menor
destrói a legibilidade. Se a arte final mudar as proporções do personagem,
o tamanho do bloco tem que ser recalculado junto — ver seção 9 de
[game_design.md](game_design.md).
