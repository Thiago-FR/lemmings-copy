# Estado Atual — 2 de novembro de 2026

Registro de onde o projeto está, o que foi decidido e por quê. Convenções de
código em [CLAUDE.md](../CLAUDE.md), mecânicas em [game_design.md](game_design.md),
geração de imagens em [art_pipeline.md](art_pipeline.md), ideias ainda não
decididas em [ideias_futuras.md](ideias_futuras.md).

O projeto estava parado desde 1º de agosto de 2026 porque as habilidades não
funcionavam de forma confiável. Esta sessão achou a causa e fechou a primeira.

## O que está pronto

| Item | Estado |
|---|---|
| Pá (`SkillDigger`) | ✅ fechado, com teste automático |
| Escada vertical (`SkillLadderVertical`) | ✅ fechado, com teste automático |
| Escada diagonal (`SkillBuilder`) | ✅ refeita, com teste automático |
| Ponte (`SkillBridge`) | ✅ nova, com teste automático |
| Geometria corpo × grade | ✅ regra definida e verificada em tempo de execução |
| Morte visível | ✅ animação de esmagamento na queda + fade vermelho de 0,35s |
| Instruções da fase | ✅ num botão "i" do HUD, aparecem ao passar o mouse (`InfoButton`) |
| Interface em português | ✅ inclusive nomes das fases e das habilidades |
| Animação de escavar (frente) | ✅ com pá, mais lenta (20 px/s) |
| Habilidades, entrada e saída desacopladas | ✅ ver "Arquitetura" abaixo |
| Garras, Bloco, Dinamite, TNT, Britadeira, Picareta, Paraquedas | ✅ cada uma com fase e testes (ver abaixo) |
| Terra e concreto | ✅ dois materiais de terreno (ver "Terreno: terra e concreto") |
| Pedrinhas e explosão | ✅ desenhadas em código (`DebrisBurst`, `ExplosionEffect`) |
| Botões Pausar/Continuar, Reiniciar, Menu | ✅ em toda fase (`GameControlsController`, no HUD) |
| Menu com rolagem | ✅ Tutorial, Modo livre e uma fase por ferramenta |
| Modo livre (editor) | ✅ pintar cenário e testar (ver "Modo livre") |
| Animação de paraquedas | ✅ `float`, no estado FLOATING |
| Som e música | ✅ gerados em código (`tools/build_audio.py`), botão Som / tecla M |

## A causa raiz (o que travava tudo)

O corpo do mago tem **26×30** e a grade de terreno tinha **16×16**. Como as
habilidades removem blocos inteiros, o buraco só cabia o personagem quando
ele por acaso estava entre duas colunas. Daí o comportamento intermitente.

Corrigir isso expôs mais dois problemas em sequência:

1. **Corpo com a largura exata do bloco entala.** Tentei 16×32 numa grade de
   16 e o lemming parou de cair mesmo com gravidade total — sem folga, a
   física não consegue separar o corpo das duas paredes. O corpo precisa ser
   **menor** que a abertura, não igual.
2. **Encolher o personagem destrói a arte.** Gerei um boneco de 12×28 para
   caber na grade de 16 e ficou ilegível. A ordem certa é a inversa: **o
   personagem define a grade**. Com 26 de largura, o bloco passou para 32.

A regra final está na seção 9 de [game_design.md](game_design.md) e é
verificada por `LemmingController._assert_body_fits_carved_openings()` no
nascimento de cada lemming.

## Arquitetura (como as peças conversam)

Cada peça é independente e só fala por sinais ou parâmetros. O
`LevelManager` é o único lugar que liga uma coisa à outra.

| Peça | O que recebe | O que emite |
|---|---|---|
| Habilidade (`SkillBase` e filhas) | o lemming em que foi aplicada; ajustes como `@export` (velocidade, passos, pavio) | nada — devolve `true`/`false` em `physics_process` |
| Lemming (`LemmingController`) | `terrain` (antes de entrar na árvore, ou pelo grupo `terrain`) e habilidades via `assign_skill()` | `clicked`, `died(cause)`, `exited` |
| Entrada (`SpawnPoint`) | `start(intervalo, total)`; cena a criar, nó pai e texto como `@export` | `lemming_spawned`, `all_lemmings_spawned` |
| Saída (`ExitPoint`) | camadas detectadas e texto como `@export` | `lemming_exited` |
| `SkillManager` | moldes de habilidade (`register_skill()` troca um molde) | `skill_selected`, `skill_count_changed`, `skill_assigned` |

- Nenhuma habilidade lê `Constants` nem procura nó na árvore. O tamanho do
  passo vem de `terrain.get_cell_size()`.
- O nome que o jogador lê fica na própria habilidade (`display_name`).
- Para ajustar uma habilidade numa fase ou num teste, crie uma cópia com
  outros valores e registre: `var d := SkillDigger.new(); d.dig_speed = 10;
  SkillManager.register_skill(d)`.
- **O terreno tem estágios de escavação.** Cada bloco de 32 px passa por 4
  estágios de 8 px (tiles 0 a 3 do atlas, cada um com a colisão do que
  sobrou). O Escavador tira um estágio por vez com `dig_stage_in_rect()`, e
  `is_solid_at()`/`get_solid_cells_in_rect()` só contam a parte que ainda
  existe. Antes ele apagava o bloco inteiro e demorava 1,6 s para descer, e
  quem passava caía no buraco antes dele. `test_skill_digger` agora mede o
  vão aberto sob os pés durante a escavação (máximo: um estágio).
- A morte tem causa (`FALL`, `VOID`, `EXPLOSION`, `OTHER`). Cada causa pode
  ter uma animação em `DEATH_ANIMATIONS`; hoje só a queda tem.

## Armadilhas que custaram tempo (não repetir)

- **Teste que não compila fica rodando para sempre.** Com erro de sintaxe
  num script de teste o Godot não sai sozinho. E `| head` na saída do Godot
  também trava (o processo fica bloqueado escrevendo). Rodar os testes com
  `timeout 240 <godot> ...` e mandar a saída para um arquivo.
- **Parâmetro tipado com boneco morto.** Passar um boneco já liberado a um
  parâmetro `LemmingController` é erro de script que aborta a função **sem
  falhar o teste**: um boneco que morreu passava. Os auxiliares de teste
  recebem `Variant` e checam `is_instance_valid` primeiro.

- **Buracos de tamanhos diferentes.** Escavar "as colunas que o corpo
  encosta" abre um buraco de uma coluna quando o lemming está alinhado e de
  duas quando está entre colunas. As habilidades de escavar precisam
  **centralizar o corpo na coluna antes do primeiro corte**
  (`TerrainDestructible.column_centre_x`).
- **Lemming flutuando no fundo do poço.** O `_process_walking` checava
  parede antes de chão. No fundo de um poço tem parede dos dois lados, então
  ele se virava para sempre e nunca percebia que não tinha chão. **Chão
  primeiro, parede depois.**
- **Morte invisível vira "bug de atravessar o chão".** O `die()` removia o
  nó no mesmo quadro do impacto, então o lemming sumia exatamente ao encostar
  no chão. Foi reportado como atravessar o chão e não era.
- **A tela de fim de fase chama `get_tree().paused = true`.** Qualquer teste
  ou diagnóstico precisa de `process_mode = PROCESS_MODE_ALWAYS`, senão o
  run parece travar no instante em que a fase termina.
- **Autoloads não carregam com `--script`.** Testes que instanciam o lemming
  precisam rodar como **cena** (`godot --headless res://tests/x.tscn`),
  porque `LemmingController` usa o autoload `SkillManager`.
- **A caixa de colisão tem deslocamento de (1,2)** em relação à origem do nó.
  Perguntas sobre grade e posição devem usar `get_body_rect()`, nunca
  `global_position` direto.
- **`local_to_map()` arredonda perto da borda da célula.** Com margem de
  0,001 px, um retângulo terminando em y=192 caía na linha 6 em vez da 5, e
  o escavador abria duas linhas de uma vez (o lemming caía 96 px e morria).
  A margem em `TerrainDestructible._cells_overlapping` agora é 0,1 px.
- **Em testes com mais de um cenário, passe o `terrain` ao lemming.** O
  terreno do cenário anterior continua no grupo `terrain` até o
  `queue_free()` rodar, e a busca pelo grupo pega o terreno já apagado.
- **Posicione o lemming antes de inseri-lo na cena.** Ele começa a contar
  distância de queda de onde nasce; inserir na origem e mover depois conta
  como uma queda enorme e mata na aterrissagem.

## Como rodar

| | |
|---|---|
| Jogar | clique duplo em `play.bat` |
| Rodar os testes | clique duplo em `run_tests.bat` |
| Um teste só | `godot --headless res://tests/test_skill_digger.tscn` |
| Teste da morte por queda | `godot --headless res://tests/test_fall_death.tscn` |
| Teste da escada vertical | `godot --headless res://tests/test_tool_ladder_vertical.tscn` |
| Jogar a fase da escada vertical sozinho | `godot --headless res://tests/test_level_ladder_vertical.tscn` |
| Teste da escada diagonal | `godot --headless res://tests/test_tool_ladder_diagonal.tscn` |
| Jogar a fase da escada diagonal sozinho | `godot --headless res://tests/test_level_ladder_diagonal.tscn` |
| Teste da ponte | `godot --headless res://tests/test_tool_bridge.tscn` |
| Jogar a fase da ponte sozinho | `godot --headless res://tests/test_level_bridge.tscn` |
| Diagnóstico de queda | `godot --headless res://tests/diagnose_falling_through.tscn` |
| Regerar a arte do terreno | `python tools/build_terrain_art.py`, depois `godot --headless --path . --import` |
| Regerar o terreno (TileSet) | `godot --headless --script res://tools/build_terrain_tileset.gd` |
| Imagem de amostra do terreno | `godot --path . --resolution 800x450 --script res://tools/capture_terrain_preview.gd -- saida.png` (sem `--headless`) |
| Regerar as fases | `godot --headless --script res://tools/build_test_levels.gd` (regera todas; descarte com `git checkout` as que não mudaram de propósito, porque o Godot reescreve os ids internos) |
| Regerar a animação de escavar | `python tools/build_dig_frames.py` |
| Regerar a animação de morte | `python tools/build_death_frames.py` |

O Godot está em `C:\Users\Thiago\Desktop\CriarJogos\Godot_v4.6-stable_win64.exe`
e não está no PATH; os `.bat` já apontam para ele.

## Ferramentas em vez de habilidades

Decidido em 1º de novembro de 2026: o jogador **entrega uma ferramenta** ao
boneco, e o botão mostra o nome da ferramenta, não de uma profissão. O código
continua chamando de `skill` (`SkillBase`, `SkillManager`); só o
`display_name` muda:

| id | Botão |
|---|---|
| `digger` | Pá |
| `builder` | Escada diagonal |
| `ladder_vertical` | Escada vertical |
| `bridge` | Ponte |
| `floater` | Paraquedas |
| `climber` | Garras |
| `block` | Bloco |
| `dynamite` | Dinamite |
| `tnt` | TNT |
| `basher` | Britadeira |
| `miner` | Picareta |

**Uma ferramenta por vez, cada uma com sua fase exclusiva no menu**, onde
ela é a única disponível e o único jeito de chegar à saída. A fase é criada
em `tools/build_test_levels.gd` e tem um teste que a joga do começo ao fim
(`tests/test_level_<ferramenta>`).

As antigas fases 4 ("Escalador + Escada diagonal") e 5 ("Livre") foram
removidas: o modo livre virou o editor.

| Ferramenta | Fase exclusiva | Teste da ferramenta | Teste da fase |
|---|---|---|---|
| Pá | "A pá" (fase 2) | `test_skill_digger` | — |
| Escada diagonal | "Escada diagonal" (fase 3) | `test_tool_ladder_diagonal` | `test_level_ladder_diagonal` |
| Escada vertical | "Escada vertical" (fase 6) | `test_tool_ladder_vertical` | `test_level_ladder_vertical` |
| Ponte | "Ponte" (fase 7) | `test_tool_bridge` | `test_level_bridge` |
| Paraquedas | "Paraquedas" (fase 8) | `test_tool_floater` | `test_level_floater` |
| Garras | "Garras" (fase 9) | `test_tool_climber` | `test_level_climber` |
| Bloco | "Bloco" (fase 10) | `test_tool_block` | `test_level_block` |
| Dinamite | "Dinamite" (fase 11) | `test_tool_dynamite` | `test_level_dynamite` |
| TNT | "TNT" (fase 14) | `test_tool_tnt` | `test_level_tnt` |
| Britadeira | "Britadeira" (fase 12) | `test_tool_basher` | `test_level_basher` |
| Picareta | "Picareta" (fase 13) | `test_tool_miner` | `test_level_miner` |

Os testes novos usam bases comuns: `tests/tool_scenario_test.gd` (monta
terreno, cria bonecos, roda cenários) e `tests/level_playthrough_test.gd`
(carrega a fase pelo `GameManager` e entrega a ferramenta pelo
`SkillManager`, como um clique).

### Paraquedas, Garras, Britadeira e Picareta

- **Garras (climber)** já funcionava; só ganhou teste e fase.
- **Paraquedas** (antes "Paraquedista"): dado a um boneco **já caindo**,
  era aceito e gastava a carga, mas o boneco continuava caindo e morria.
  Agora abre na hora.
- **Britadeira (basher)**: começava na hora e, sem parede encostada, parava no
  primeiro golpe; como o boneco vira no instante em que toca a parede,
  nunca dava para usar. Agora funciona como a Escada vertical: o boneco
  **guarda a ferramenta** e cava na próxima parede em que encostar. O túnel
  tem **um bloco de altura** (`tunnel_height_tiles` = 1): com dois, quebrava
  também o bloco acima do boneco, o que o usuário achou estranho.
- **Picareta (miner)**: era uma escavação na diagonal (a do Lemmings
  original). O usuário decidiu que a Picareta é **a Pá na horizontal**: o
  boneco guarda a ferramenta, e na próxima parede cava um túnel reto de um
  bloco de altura, **um estágio de 8px por vez**, andando para dentro de
  cada fatia a 20 px/s (mesmo ritmo da Pá). Para quando fura para o vazio.
  Teste: `test_tool_miner` mede o maior movimento por quadro.
- **Estágios de lado** (`TerrainDestructible.dig_side_stage_at`): os mesmos
  tiles de estágio da Pá, desenhados **transpostos** (perde a parte da
  esquerda) ou **transpostos e espelhados** (perde a direita). O Godot
  transforma a colisão junto, então não houve tile novo. Todas as consultas
  (`is_solid_at`, `get_solid_cells_in_rect`, `solid_top_y_at`) passam por
  `_solid_rect_of(cell)`, que lê o lado pelo transform da célula. Uma célula
  cavada por um lado e depois por outro some de uma vez.
- A Britadeira ainda avança um bloco inteiro por golpe e não tem animação
  própria (anotado em `ideias_futuras.md`).

### Tela cheia, câmera e escala

- O jogo abre em **tela cheia**; **F11** ou a opção "Tela cheia" das
  Configurações troca para uma janela de 1280x720 (escolha salva em
  `user://settings.cfg`, seção `display`). O mundo é desenhado no
  **tamanho real**: num monitor Full HD o boneco tem 26x30 e a tela mostra
  ~60x34 blocos (escolha do usuário: "nada de zoom"). Antes uma imagem
  fixa de 800x450 era esticada, e em tela cheia parecia zoom.
- Em telas densas (4K, celular) tudo é ampliado por um fator **inteiro**
  (2x, 3x), nunca fracionário, para a arte em pixel continuar nítida:
  `DisplayScaler` (autoload) põe o `content_scale_size` da janela em
  tamanho / fator, com stretch `canvas_items` e aspect `expand`.
- `LevelCamera`: fase menor que a tela fica centralizada; maior, rola com
  setas/WASD, arrastando com o botão do meio (ou um dedo no celular) e
  encostando o mouse na borda. Não passa dos limites, mais a margem das
  barras de cima e de baixo. O `LevelManager` cria a câmera e o fundo
  (`LevelBackdrop`) se não houver uma câmera; o editor tem a sua, que
  continua valendo durante o teste.
- Limites da fase: o terreno, a entrada e a saída, cortados um pouco acima
  da entrada/saída mais alta (as fases antigas têm paredes de borda até a
  linha -20 só para ninguém escalar para fora).
- **A tela fica sempre cheia** (pedido do usuário, opções 1+2+3):
  1. **Tamanho padrão de fase: no mínimo 80 x 45 blocos** (maior que uma
     tela Full HD, então sempre há o que rolar). As fases de teste antigas
     (800x450) continuam pequenas, mas a moldura e o fundo preenchem o resto.
  2. **Moldura de rocha** (`LevelBackdrop`): fora dos limites da fase,
     rocha maciça desenhada com a textura de terra do atlas, mais escura,
     com uma linha escura marcando a borda. Só visual.
  3. **Fundo com profundidade** (`LevelBackground`, um CanvasLayer atrás de
     tudo): degradê e duas camadas de silhuetas que rolam mais devagar que
     a fase (parallax). Desenhado em código.
- **Ambiente** (`LevelEnvironment`): define o fundo e a cor da moldura de
  uma vez, para não misturar (o usuário: "não vai ter caverna com fundo de
  céu azul"). Hoje há SURFACE (céu ao entardecer, morros) e CAVE (sem céu,
  rocha escura, estalactites). Cada fase escolhe em
  `LevelData.environment_kind`; o gerador procedural deve escolher o ambiente
  junto com os tiles. Quando existirem tiles por ambiente, entram aqui.
- Para ver o resultado de verdade: `tools/capture_screens.tscn` salva
  capturas de uma fase e do editor (abre uma janela; ver o cabeçalho do
  script).

### Barras com ícones

- A barra de ferramentas da fase virou **slots com ícone** e o número de
  cargas no canto; o nome aparece ao passar o mouse. Painel de madeira
  centralizado embaixo, da largura dos ícones, rolando se não couber.
- O editor usa os mesmos ícones e painéis: ferramentas de pintar e
  controles em cima, contadores com o ícone de cada ferramenta embaixo.
- Tudo de visual passa por `UiStyle` (painel 9-slice, slots nos estados
  normal/hover/selecionado/desabilitado, ícone por id). Arte gerada por
  `tools/build_ui_art.py` em `assets/sprites/ui/`.

### Editor maior

- A área de desenho tem **120 x 60 blocos**, com câmera própria (começa no
  canto de baixo à esquerda), fundo e grade. As barras são opacas e a
  câmera pode rolar o desenho para fora de baixo delas.

### Sair do jogo

- Botão "Sair do jogo" no fim do menu principal (salva as configurações
  e fecha). Não aparece no celular nem na web.

### Configurações

- Tela **Configurações** (`SettingsMenu`), aberta pelo menu principal ou
  pelo botão Config das fases (pausa a fase). Seções: **Tela** (tela cheia
  ou janela) e **Áudio** (volume geral, música, efeitos e "sem som"). Esc
  ou Voltar fecha.
- O `AudioManager` cria os barramentos Music e Effects (que vão para o
  Master) e salva os volumes em `user://settings.cfg`. Volumes padrão mais
  baixos (geral 80%, música 50%, efeitos 80%): o usuário achou alto.
- Teste: `test_settings`.

### Som e música

- Tudo gerado em código, de graça e sem serviço: `tools/build_audio.py`
  (numpy) sintetiza efeitos no estilo sfxr (onda quadrada, triângulo,
  ruído, glissando, envelope, filtro) e duas músicas chiptune em loop
  (`menu_theme` no menu e no editor, `level_theme` nas fases). As músicas
  usam tons com só os harmônicos que cabem em 44,1 kHz, sem chimbal de
  ruído, com eco leve e filtro: a primeira versão (onda quadrada crua a
  22 kHz) tinha chiado. Saem em
  `assets/audio/sfx/` e `assets/audio/music/`; mudou o som, rode o script.
- O código toca pelo nome: `AudioManager.play_sound(&"dig_earth")`,
  `AudioManager.play_music_track(&"level_theme")`. O volume de cada som fica
  em `AudioManager.SOUND_VOLUMES_DB` (os bipes de onda quadrada soam bem
  mais alto que os de ruído no mesmo pico). Som que não existe não toca
  nada.
- Momentos com som: cavar (Pá), golpe de Picareta, Britadeira, pôr bloco,
  tijolo (escada diagonal, ponte), segmento de escada, pavio, explosão,
  paraquedas abrindo, boneco saindo da entrada, salvo, morte por queda,
  escolher ferramenta, dar ferramenta, fase ganha e perdida.
- Tecla **M** em qualquer tela (ou "Sem som" nas Configurações) liga e
  desliga tudo. A música continua com o jogo pausado; os efeitos pausam.
- Teste: `test_audio` acha no código todo som e música tocados e confere
  que o arquivo existe e carrega.

### Bloco (substituiu o Escudo)

- O boneco coloca **um bloco de terra logo na frente dele**, na altura do
  corpo, e por isso ele mesmo dá meia-volta; quem chegar depois vira no
  mesmo bloco. Nada no ar, sem escolher lugar: o jeito mais simples, pedido
  do usuário.
- É terreno comum: qualquer ferramenta de cavar ou explosivo o tira.
- Se o espaço da frente já está ocupado (terreno, escada, tijolo), a
  ferramenta é recusada e não gasta. Se a frente do corpo já entrou na
  célula seguinte, o bloco vai uma adiante, para nunca cair em cima do
  boneco.
- O Escudo antigo (o boneco parado para sempre, `SkillBlocker`, a área
  `BlockerZone` e o estado `BLOCKING`) foi apagado: dois deles prendiam
  todos os bonecos entre si (print `prints/bug2.png`).

### Escada diagonal e Ponte terminam encostadas na parede

- A raiz dos bugs 5 e 7: a escada parava quando o próximo degrau **inteiro**
  não cabia, deixando um vão de até 31px antes da parede. Agora o último
  degrau é **cortado** no tamanho do espaço que sobrou e encosta na parede
  (`TerrainDestructible.fit_brick`, mínimo 2px). A continuação de uma
  escada também corta, então preenche o vão de uma escada antiga.
- A Ponte faz o mesmo no outro lado do buraco (antes sobrava até uma peça
  de vão quando o buraco não tinha tamanho exato de bloco).
- Testes: `test_ladder_diagonal_meets_wall` (escada de longe e continuação
  do caso do bug7) e `test_bridge_meets_far_side` (buraco de 6,5 blocos);
  os dois conferidos falhando sem a correção. Lição: os testes antigos
  passavam porque conferiam a regra que eu tinha definido, não o que o
  usuário esperava; a medida de "chegou na parede" tem que olhar só os
  degraus antes da parede.

### Escada diagonal: continuar uma escada

- Se o primeiro degrau não cabe (o boneco está no meio de uma escada e o
  próximo degrau já existe, ou de frente para uma parede), o boneco
  **guarda a ferramenta** e começa assim que couber: dada a um boneco
  subindo uma escada pronta, ele continua do último degrau. Antes ela
  começava ali mesmo, achava o lugar ocupado, parava e gastava a carga.
- Em cima de um tijolo, o primeiro degrau novo vai **no fim desse tijolo,
  um degrau acima** (`_set_origin`). Começando na frente do corpo, ele
  empilhava o degrau novo em cima do último, no meio dele
  (`prints/bug6.png`).
- Teste: `test_ladder_diagonal_continue` (12 + 12 degraus, cada um um
  degrau acima do anterior e ao lado dele, sem sobrepor; conferido que
  falha sem a correção do bug6).

### Uma ferramenta por boneco

- **Mudou em 2 de novembro de 2026:** a ferramenta nova agora substitui a
  atual (ver "Ferramenta nova sempre substitui a atual"). O texto abaixo é
  a regra antiga.
- Regra do usuário: **um boneco só tem uma ferramenta por vez**. Enquanto
  carrega uma ferramenta ainda não usada (escadas, ponte, britadeira,
  picareta) ou está usando uma, ele recusa qualquer outra
  (`LemmingController.assign_skill`), sem gastar carga. Paraquedas e Garras
  são traços permanentes, não ferramentas seguradas, e não contam. Isso
  resolveu o boneco que carregava a Ponte, recebia a Pá e montava a ponte no
  ar ao furar o chão. Teste em `test_bridge_carried`.

### Tijolo como tábua

- Os tijolos (degraus, peças da ponte) são desenhados como `NinePatchRect`:
  as pontas da tábua ficam inteiras e só o meio encolhe ou estica, então o
  degrau cortado contra a parede parece uma tábua curta, não um pedaço
  espremido (`prints/bug8.png`).

### Pá em cima de tijolo

- A Pá cava tijolos (escada diagonal, ponte) de um golpe e continua na
  terra embaixo. Antes não achava terra, parava e gastava a carga.
  `TerrainDestructible.remove_bricks_in`. Teste: `test_shovel_on_bricks`.

### Gerador de fases procedurais (`scripts/procedural/`)

Núcleo, sem saber de modo nenhum (serve ao roguelike e, depois, a um botão
"Gerar fase" no editor).

- `MazeStageGenerator.generate(semente, dificuldade 0-4)` devolve um
  `MazeStageData`: células (vazio/terra/concreto), entrada, saída, "spots"
  de item (ferramenta com quantidade, ou bônus) e a **solução gravada**
  (onde dar cada ferramenta). `MazeStageData.paint_onto(terreno)` pinta num
  `TerrainDestructible`.
- Labirinto de 5 x 3 salas numa tela de 60x34; andares 11 linhas um do
  outro. Ligações: **porta** (livre), **parede** de terra (Picareta ou
  Britadeira) ou concreto (só Britadeira), **fosso** de um bloco (Ponte, ou
  cair nele e sair com Escada vertical de 1 peça), **remendo de terra no
  chão** sobre uma escadaria de degraus de 2 blocos (Pá, só desce) e
  **poço** encostado num separador que a Escada vertical sobe (12 peças,
  exatamente o limite; sobe para a sala na diagonal). Nenhuma sala tem
  beirada mortal: antes de abrir, toda ligação é parede.
- Entrada e saída em qualquer sala, até vizinhas, desde que haja
  ferramentas entre elas. Garras e Paraquedas não entram (um escalador sobe
  a parede da sala até o teto e cai).
- **Garantia:** `MazeSolver` (modelo de alcance: um boneco só, barra vazia,
  só os itens da fase) tem de chegar à saída; senão o gerador descarta e
  tenta de novo. No máximo 4 ferramentas diferentes por fase (a barra nunca
  descarta o que foi pego ali).
- `MazeLayout` também desenha fase à mão (`add_open`, `add_wall`,
  `add_trough`, `add_stairs`, `add_ladder`, `add_tool_spot`...) e
  `MazeStageGenerator.from_layout` confere e pinta. As 5 fases prontas do
  roguelike são feitas assim (`modes/roguelike/scripts/stages/handmade_stages.gd`).
- No roguelike, o modo desenvolvedor tem **Fases: Procedurais / Prontas**.
- Testes: `tests/test_maze_generator` (100 fases, medidas de cada ligação);
  `modes/roguelike/tests/test_procedural_stages` (modelo, 20 sementes x 5
  fases), `test_procedural_play_1..3` (um robô joga fases geradas seguindo a
  solução) e `test_stage_01..05` (as fases prontas).

### Modo roguelike (`modes/roguelike/`)

Primeira versão, feita por um agente; botão "Roguelike" no menu.

- Run de **5 fases-labirinto** de 60x34 blocos (uma tela Full HD), geradas
  pelo gerador procedural do núcleo a partir da semente da run (ou as 5
  fases prontas, ver "Gerador de fases procedurais"). Começa só com o
  **Mago**; quem é salvo segue para
  a próxima fase; a cada fase um personagem novo entra (Mineiro, Engenheiro,
  Batedor, Inventor). Sem sobreviventes: "Fim da run".
- **Personagens:** Mago (+1 carga por ferramenta pega), Mineiro (cava 2x
  mais rápido), Engenheiro (+4 peças em ponte e escadas), Batedor (aguenta
  queda de 160px), Inventor (uma vez por fase repete a última ferramenta
  sem gastar carga). Cada um tem **seus próprios sprites**, desenhados do
  zero em todas as animações (Mineiro baixo e largo de capacete com
  lanterna e barba; Engenheiro de boné, macacão e tábuas nas costas;
  Batedor alto de capuz verde e cachecol vermelho; Inventor pequeno de
  cabelo branco, óculos redondos e mochila com antena), gerados por
  `tools/build_character_variants.py` (desenhos em
  `tools/character_designs.py`) em `assets/sprites/characters/<id>/`
  com um SpriteFrames por personagem em `resources/sprite_frames/`. A
  tinta e a pedrinha sobre a cabeça saíram.
- **Itens na fase:** ferramentas (+cargas), Pena da fênix (resgata um
  perdido), Ampulheta (+60s), Bolsa (+1 carga em cada ferramenta).
- **Barra:** começa vazia, ganha um slot por ferramenta nova, **limite de 4**
  (6 com a relíquia Bolso extra). Cheia: sai o slot zerado ou o mais antigo.
- **Cartas** no fim da fase (1 de 3): cargas, ferramenta nova, recruta,
  relíquias (Lâminas afiadas, Ponte longa, Escada comprida, Pavio curto,
  Bolso extra, Paraquedas reserva), Pena da fênix.
- **Ganchos genéricos no núcleo** (sem `if roguelike`):
  `SkillManager.set_remaining_count`, sinal
  `LemmingController.skill_about_to_apply(skill)` (ajustar a ferramenta só
  daquele boneco) e `LemmingController.max_safe_fall_height` por boneco.
  As relíquias registram cópias ajustadas das ferramentas e devolvem as
  originais ao sair do modo.
- **Testes:** `modes/roguelike/tests/` (run, sessão, fluxo e uma partida
  completa por fase). Fora do `run_tests.bat`, que só roda `tests/`.
- **Moedas, loja e bônus pelos bonecos salvos** (pedido do usuário: a
  quantidade de bonecos tem que valer algo):
  - cada boneco salvo dá 3 moedas e pontos (10 x número da fase);
  - fase sem perder ninguém: escolha entre **4 cartas** em vez de 3;
  - depois da carta, a **Loja** (`RoguelikeShopScreen`): 4 ofertas com o
    preço de cada tipo (cargas 3, ferramenta nova 6, Pena da fênix 8,
    recruta 10, relíquia 12); compra quantas as moedas pagarem;
  - na vitória, a pontuação é multiplicada pelos sobreviventes.
  Teste: `test_coins_shop`.
- **Cartas desenhadas** (`tools/build_card_art.py`, `assets/sprites/ui/cards/`):
  uma moldura por família (ferramenta: madeira e latão; recruta: tecido
  roxo; relíquia: pedra com filigrana dourada; resgate: fogo), que acende
  ao passar o mouse; retrato de cada personagem e ilustração de cada
  relíquia na janela da carta; título na faixa de cima e texto curto
  embaixo (o texto completo fica no tooltip). Mostradas em 2x
  (`RoguelikeCardScreen`; as áreas da arte estão em `art_pipeline.md`).
- **Sem dicas de como resolver a fase** (tela de apresentação e HUD): o
  usuário achou confuso; ensinar as ferramentas fica para um tutorial.
- **Modo desenvolvedor** (opção "Modo desenvolvedor" nas Configurações,
  salva em `GameManager.developer_mode`): botão "Dev" na apresentação da
  fase, com ir para qualquer fase, aplicar qualquer carta (todas, inclusive
  personagens ainda bloqueados), abrir a tela de recompensa e ver o estado
  da run (`RoguelikeDevScreen`). Teste: `test_dev_screen`.

### Roguelike: HUD com ícones, Sacrificar e Encerrar fase (2 de novembro de 2026)

Pedido do usuário depois de olhar as telas (prints `art2`, `art3`).

- **Barra de cima** (`RoguelikeRunHud`): fase e nome, depois ícone + número
  para tropa, na fase, salvos, perdidos, **relógio**, penas da fênix e
  **moeda**; cada um com tooltip. Ícones novos em `tools/build_ui_art.py`
  (`hud_*`, `sacrifice`, `give_up`, `settings`).
- **Botões** iguais aos do editor (ícones): Pausar/Continuar, Configurações,
  **Encerrar fase** (bandeira branca) e Menu.
- **Encerrar fase** pergunta antes (a fase fica pausada enquanto isso). Quem
  já saiu segue na run; quem está na fase é sacrificado; quem nem saiu da
  entrada é perdido. Núcleo: `LevelManager.end_now()` e `SpawnPoint.stop()`.
- **Sacrificar** (slot com ∞ depois das ferramentas): armado, o próximo
  boneco clicado é sacrificado. Sem limite. Escolher uma ferramenta desarma.
- **Bônus do sacrifício: 1 moeda** (`RoguelikeRunState.COINS_PER_SACRIFICED`).
  Análise: um motivo para encerrar uma espera sem saída em vez de esperar o
  relógio, e bem abaixo do que salvar dá (3 moedas + o boneco segue na run),
  então sacrificar nunca compensa mais do que salvar. Conta como perdido
  (tira o bônus de fase perfeita; a Pena da fênix pode trazê-lo de volta).
- **Animação do sacrifício** (núcleo, `DeathCause.SACRIFICE`): o boneco
  brilha, afina e sobe enquanto some em violeta; faíscas sobem e um anel de
  luz se abre no chão (`SacrificeEffect`); som `sacrifice` (brilho
  subindo, em `tools/build_audio.py`). O fim da fase espera a animação.
- Corrigido: o contador "Na fase" só mudava quando alguém morria ou saía (o
  `LevelManager` não avisava ao soltar um boneco).
- Teste: `modes/roguelike/tests/test_sacrifice`.

### Roguelike: escolha de personagem, cofre, fim de run e modo dev (2 de novembro de 2026)

- **Tela de escolha** (`RoguelikeCharacterSelectScreen`) abre a run e
  substitui a tela de apresentação da fase (print `art1`, que saiu do fluxo:
  agora é escolha -> fase -> cartas -> loja -> próxima fase). Mostra os 5
  personagens com retrato, nome e o que fazem; os bloqueados aparecem como
  **sombra preta**, com preço e botão Comprar.
- **Cofre** (`RoguelikeProfile`, `user://roguelike_profile.cfg`): as moedas
  que sobram no fim de cada run (vitória ou não) vão para ele; liberar
  personagem custa Mineiro 25, Engenheiro 35, Batedor 45, Inventor 60
  (`price` em `character_catalog.gd`).
- **Run de um personagem só**: a tropa e todo recruta são do escolhido
  (`RoguelikeRunState.character_id`); depois de cada uma das 4 primeiras
  fases entra mais um dele. O bônus do personagem vale só para o boneco que
  pega/usa (não multiplica pela tropa).
- **Fim de run** (`RoguelikeRunEndScreen`): título, retrato (apagado se
  perdeu), uma linha com ícone por resultado (fase alcançada, salvos,
  pontuação, moedas para o cofre).
- **Modo dev** refeito (`RoguelikeDevScreen`): estado da run à esquerda;
  seções com ícones à direita (personagem da run, que troca a tropa toda, sem
  misturar; +1/-1 boneco; fase e procedural/pronta; ferramentas; relíquias;
  pena, moedas, cofre). Botão Dev na tela de escolha e na loja.
- HUD: tirado o "Fase 1/5" (fica só o nome) e o "Ferramentas 1/4" da barra.
  **Sacrificar** saiu da barra de ferramentas (parecia habilidade do
  personagem) e foi para os botões de cima, com ícone de adaga.

### Ferramenta nova sempre substitui a atual (2 de novembro de 2026)

Bug relatado: um boneco com a Picareta indo para uma parede de **concreto**
(que ela não cava: ele vira e continua carregando para sempre) recusava a Pá
por causa da regra "uma ferramenta por boneco", e ficava preso.

- Agora a ferramenta mais nova vence (`LemmingController.assign_skill`):
  a carregada e não usada é largada e **a carga volta para a barra**
  (sinal `carried_tool_dropped` -> `SkillManager.refund_charge` -> no
  roguelike, `inventory.add_charges`); a que está em uso (cavando,
  construindo) para onde está. Não interrompe a contagem de explosivo nem a
  subida numa escada já montada.
- A **mesma** ferramenta de novo (segundo clique sem querer) é recusada e
  não gasta carga; só uma ferramenta diferente substitui.
- Bloco, Dinamite, TNT, Paraquedas e Garras não são ferramentas seguradas
  (`SkillBase.is_held_tool`) e convivem com a que o boneco carrega.
- **Balão sobre o boneco** com o ícone da ferramenta carregada e ainda não
  usada (`CarriedToolIndicator`, posto pelo `LevelManager`).
- Teste: `tests/test_tool_replace` (Pá no lugar da Picareta carregada,
  Britadeira interrompendo a Pá, Bloco sem largar a Picareta).
  `test_bridge_carried` não exige mais a recusa.

### Entrar no portal de saída (2 de novembro de 2026)

O boneco sumia ao encostar na borda da saída. Agora
(`LemmingController.enter_exit`) ele anda até o meio da porta, vira de costas
(quadro da animação `ladder`), encolhe e escurece entrando nela; só então
conta como salvo (`ExitPoint` emite `lemming_exited` quando ele termina).
Nesse trajeto nada mais acontece com ele: sem clique, sem ferramenta, sem
morte (nem pelo Encerrar fase).

### Cara das telas: tema do jogo, menu, configurações (2 de novembro de 2026)

Pedido do usuário: "dar cara a todas as UX de menus e botões" e usar pouco
texto (só quando necessário).

- **Tema do projeto** (`resources/ui/game_theme.tres`, em
  `project.godot` -> `gui/theme/custom`): botões de madeira (normal, mouse,
  apertado, desativado), botão **verde** para a ação principal de cada tela
  (`UiStyle.PRIMARY_BUTTON`), painel de madeira, caixa de marcar, barra
  deslizante com puxador de latão, campo de número e dica. Arte em
  `tools/build_ui_art.py` (`button*`, `check_*`, `slider_*`); o arquivo do
  tema sai de `UiStyle.build_theme()` pelo `tools/build_ui_theme.gd`
  (rodar de novo depois de mudar a arte ou o `UiStyle`). Tema na janela não
  serve: não chega às telas em `CanvasLayer`.
- **Menu principal**: céu e montanhas das fases ao fundo, título grande,
  modos em botões grandes com ícone (Roguelike em verde), fases de
  ferramenta como grade de ícones (nome na dica), Configurações e Sair como
  ícones no canto.
- **Configurações**: seções com ícone (Tela, Áudio, Desenvolvedor) e linha,
  Voltar em verde.
- **Escolha de personagem**: Jogar em verde e Comprar só com moeda + preço,
  do mesmo tamanho; Menu e Dev como ícones (ícone novo `dev`).
- **Modo dev**: campo Quantidade + Adicionar/Remover para bonecos, cargas de
  cada ferramenta, penas, moedas e cofre; relíquia que já tem sai ao clicar.
- **Compêndio** (`RoguelikeCompendiumScreen`, botão no modo dev): abas
  Personagens, Ferramentas, Itens da fase, Cartas, Relíquias, cada entrada
  com figura, nome e descrição. Pronto para o jogador: com uma função de
  "descoberto", o que ainda não foi descoberto aparece em sombra preta com
  "???" (ideia do usuário: ir liberando conforme pega e usa). Ainda falta
  guardar o que foi descoberto e o botão para o jogador.

### Itens valem 1 e saída sem entrar do alto (2 de novembro de 2026)

- **Cada item de ferramenta dá 1 carga** (o usuário achou 3 fácil demais;
  mais por item vem das cartas). O gerador agora espalha as cargas de uma
  pilha em itens separados na sala (`MazeStageGenerator._place_markers`:
  primeiro um lugar para cada pilha, depois as cargas extras onde couber;
  sem chão, empilha). Cada item lembra de que pilha veio (`spot_index`),
  que é o que a solução gravada usa. Item bônus de ferramenta: 1.
  **O Mago ainda dá +1 em cada item que pega** (a decidir).
- **Saída**: um boneco andando num bloco ao lado da saída, na altura da
  porta, entrava lá de cima. Agora só entra com os pés no chão da saída
  (`ExitPoint._stands_on_exit_floor`); antes disso cai na frente dela.
  Teste: `tests/test_exit_point`.

### Dinamite e TNT

Substituíram a Bomba antiga (`SkillBomber`, apagada). Decisões do usuário:

- O boneco **coloca a carga no chão e segue andando**; ele não explode
  junto. A carga (`ExplosiveCharge`) mostra o pavio queimando e os segundos
  que faltam (3s).
- **Dinamite** (`SkillDynamite`) pega um quadrado 3x3 de blocos em volta da
  carga; **TNT** (`SkillTnt`) um 5x5 sem os cantos. A regra é uma só:
  offset (dx, dy) com dx² + dy² <= r² + 1, r = 1 ou 2.
- A explosão **quebra o piso** e quebra **concreto** também. Mata todo
  boneco cujo corpo encosta num bloco da explosão.
- Base comum: `SkillExplosive`. Explosão desenhada em código
  (`ExplosionEffect`): clarão, anel de fumaça e pedaços voando.
- **Cuidado ao desenhar fases:** quebrar o piso deixa uma cratera com
  paredes de 32px, que ninguém sobe, e queda acima de 80px mata. Por isso as
  fases 11 e 14 põem a saída numa sala de um bloco de altura logo embaixo
  de um chão de um bloco: a explosão abre o chão e eles caem 64px.
- Os bonecos que vêm atrás chegam na carga justo quando ela explode (andam
  150px em 3s). Nas fases, saída a cada 3s: morre só um.

### Terreno: terra e concreto

- Duas linhas de blocos no atlas: linha 0 terra, linha 1 concreto, com a
  arte de `tools/build_terrain_art.py` montada por
  `tools/build_terrain_tileset.gd`.
- **Chão, parede e teto têm desenhos diferentes** (grama, barranco, raízes;
  laje no concreto), decididos pelos vizinhos por `TerrainEdgeOverlay`. É só
  desenho: o bloco é o mesmo, com a mesma colisão. Detalhes em
  [art_pipeline.md](art_pipeline.md), seção "Terreno".
  `TerrainDestructible.TerrainMaterial` (EARTH, CONCRETE), `is_concrete_at`,
  `material_at`, e `build_cell_at(posição, material)`.
- **Pá e Picareta só cavam terra**; param no concreto (a Picareta dá
  meia-volta numa parede de concreto e continua com a ferramenta).
  **Britadeira quebra os dois.** As explosões também. Teste: `test_concrete`.
- No editor: ferramentas **Terra** e **Concreto**.
- A fase da Britadeira (12) tem a parede de concreto.

### Picareta e Britadeira: a mesma escavação

- Base comum `SkillSideDigger`: guarda a ferramenta até a próxima parede, e
  ali cava um túnel de um bloco de altura, **8px por vez**, andando para
  dentro de cada fatia. Picareta a 20 px/s, só terra; Britadeira a 24 px/s,
  terra e concreto. Antes a Britadeira tirava um bloco inteiro a cada 0,15s
  e pulava um bloco por vez (parecia teletransporte).
- Pedrinhas (`DebrisBurst`) saem a cada fatia, e na Pá a cada estágio:
  marrons na terra, cinza no concreto.

### Garras (escalar)

- No topo da parede o boneco agora **sobe até os pés passarem da borda e dá
  um passo de 6px andando** para cima dela. Antes parava quando o meio do
  corpo passava da borda e era jogado um bloco inteiro para o lado num
  quadro, caindo com as pernas dentro do bloco: parecia teletransporte.
- A sonda dos pés usa meio pixel, não `GROUND_PROBE_EPSILON` (2px): com 2px
  o passo começava com os pés ainda abaixo da borda, o corpo empurrava a
  quina, escorregava e caía até morrer. `test_tool_climber` pega isso (foi
  conferido trocando de volta).
- O passo é o mesmo do topo da escada vertical
  (`_start_ledge_step` / `_continue_ledge_step`, `LEDGE_STEP_FOOTING`).

### Animações por estado

| Estado | Animação |
|---|---|
| CLIMBING (Garras) | `climb`: vista de lado, garras na parede |
| LADDER_PLACING / LADDER_CLIMBING | `ladder`: a vista de costas que antes se chamava `climb` |
| FLOATING (Paraquedas) | `float`: paraquedas balançando, braços nas cordas, pés chutando |
| MINING (Picareta) | `pickaxe`: golpe de picareta para a frente |
| BASHING (Britadeira) | `jackhammer`: britadeira tremendo, com poeira |
| DIGGING (Pá) | `dig` |

### Escada vertical

- **Não destrói terreno.** Sobe pelo espaço vazio, encostada numa parede,
  até o topo ficar no nível de cima da parede; o boneco sai para cima dela.
- **O boneco guarda a escada** quando recebe a ferramenta e a usa sozinho na
  próxima parede em que encostar (`LemmingController.pending_wall_tool`,
  ganchos `can_start_at_wall`/`start_at_wall` em `SkillBase`). Motivo: o
  boneco vira no instante em que toca a parede, então não há momento para o
  jogador clicar nele parado ali. Parede alta demais (`max_pieces`, 12) ou
  coluna bloqueada acima: ele vira normalmente e guarda a escada para a
  próxima. Quem já carrega uma escada recusa outra.
- **Coloca um segmento e sobe nele, coloca o próximo e sobe**, no mesmo
  ritmo da Pá descendo. Nunca fica mais de um segmento acima do boneco.
- Depois do último segmento, termina de subir com o comportamento comum a
  todo boneco (`LemmingController._try_grab_ladder`): quem anda ou cai e
  passa pelo centro de uma escada agarra e sobe.
- No topo, sai para o lado que tem chão (para a frente, senão para trás).
  Se nenhum lado tem chão (escada ainda sendo montada), **espera no último
  degrau** em vez de cair, e continua quando a escada cresce.
- A animação de montar ainda é a de costas (que mostra a mochila).
  Falta uma animação própria de tirar a escada da mochila.
- Fase exclusiva: "Escada vertical" (fase 6): chão e uma plataforma alta
  com a saída em cima.

### Escada diagonal

- Começa **na hora do clique**, na direção em que o boneco olha.
- Degraus de **8px de altura por 32px de largura** (¼ de bloco de altura,
  um bloco de largura): 12 degraus sobem 96px em 384px. A cada tijolo o
  boneco coloca e **anda subindo** até ele (no máximo ~1px por quadro,
  verificado no teste), depois coloca o próximo.
- Para em `max_pieces` degraus, ou antes se o próximo tijolo entraria numa
  parede ou se não houver espaço para a cabeça.
- Os tijolos não ficam na grade de 32px: são uma camada do terreno
  (`TerrainDestructible.place_brick`), contada por todas as consultas e
  removida pelas mesmas funções que destroem terreno.
- **Os tijolos só colidem por cima** (`one_way_collision`), como plataforma:
  quem anda por baixo da escada atravessa os tijolos na altura da cabeça em
  vez de tomá-los por parede e voltar. A checagem de "cabeça bloqueada" do
  andar (`_is_head_blocked_ahead`) também ignora tijolos. Teste:
  `test_brick_underpass`.
- Os outros bonecos sobem a escada andando, como qualquer degrau baixo, sem
  quicar (o teste mede o sprite do segundo boneco: nunca desce e nunca sobe
  mais de 2px num quadro).
- Altura e largura do degrau são parâmetros: `step_height_fraction_of_tile`
  (0,25 = 8px; 0,125 = 4px) e `step_width_fraction_of_tile` (1,0 = um
  bloco).
- Quem chega numa escada **ainda sendo montada** pode sair pela ponta
  inacabada e cair, como no Lemmings original.
- Fase exclusiva: "Escada diagonal" (fase 3): chão e uma plataforma de 3
  blocos (96px = 12 degraus) começando a 12 blocos da parede da esquerda.
- Ainda usa a animação de andar. Falta uma animação de subir/montar escada.

### Ponte

- Começa **na hora do clique**, na direção em que o boneco olha.
- Peças de **32px de largura por 8px de altura** (um bloco de largura, ¼ de
  bloco de altura, a mesma espessura do degrau da escada diagonal). Em vez
  de subir, cada peça fica **pendurada logo abaixo da linha dos pés**, com o
  topo rente ao chão: o boneco e quem vem depois andam reto por cima.
- O boneco coloca uma peça, **anda até a ponta dela** (no máximo ~1px por
  quadro, verificado no teste) e coloca a próxima.
- **A ponte começa onde o chão acaba.** Quem recebe a ponte andando no chão
  antes do buraco primeiro anda até a beira (ainda controlado pela
  ferramenta) e começa ali; quem já está com a ponta do corpo além da beira
  começa a ponte na beira, atrás dele. Motivo: começar na ponta do corpo
  faria a primeira peça entrar no chão onde ele pisa (e a ponte pararia na
  hora), e uma ponte começada alguns pixels depois da beira terminaria
  alguns pixels antes do outro lado, deixando um vão mais largo que o corpo,
  onde ele cai.
- Sem buraco à frente antes de uma parede, **o boneco guarda a ponte** e a
  monta assim que um buraco aparece à frente dele, virando nas paredes se
  preciso, como as ferramentas que esperam uma parede. A carga é gasta no
  clique. Antes ele recusava, e depois de uma ponte cobrir o buraco nenhum
  outro boneco aceitava ponte (parecia que o clique não fazia nada).
  Gancho: `SkillBase.can_start_while_walking` / `start_while_walking`,
  checado a cada quadro de andar. Teste: `test_bridge_carried`.
- Para em `max_pieces` peças, ou antes se o lugar da próxima peça não está
  vazio: o outro lado do buraco, uma parede, um tijolo ou uma escada. Depois
  devolve o controle e o boneco segue andando.
- Buraco mais largo que a ponte: o boneco fica na ponta da última peça,
  segue andando, cai e morre (o teste verifica isso). Como no Lemmings
  original, quem chega numa ponte **ainda sendo montada** pode sair pela
  ponta inacabada e cair.
- Buraco que não é múltiplo de 32px: a última peça não cabe (entraria no
  outro lado) e sobra um vão menor que 32px. Até 26px (a largura do corpo)
  o boneco passa andando; entre 26 e 32px ele cai. As fases devem usar
  buracos de blocos inteiros.
- Usa os mesmos tijolos da escada diagonal (`TerrainDestructible.place_brick`).
- Fase exclusiva: "Ponte" (fase 7): chão, um buraco de 6 blocos sem fundo
  (cair nele é morte) e o chão continua do outro lado com a saída. Dar a
  ponte ao **primeiro** boneco salva todos (verificado no teste da fase); os
  seguintes podem alcançar a ponta da ponte enquanto ela ainda está sendo
  montada e cair.
- Ainda usa a animação de andar. Falta uma animação de montar a ponte.

### Limite de peças

As duas escadas e a ponte usam `max_pieces` (padrão 12), no topo do arquivo
de cada ferramenta (`skill_ladder_vertical.gd`, `skill_builder.gd`,
`skill_bridge.gd`) e visível no Inspector. Para uma fase usar outro valor sem mudar o padrão:
`var escada := SkillBuilder.new(); escada.max_pieces = 20;
SkillManager.register_skill(escada)`.

### Mudanças no andar de todo boneco (por causa da escada diagonal)

- A subida de degrau agora mede a altura pixel a pixel. Antes arredondava
  para o próximo múltiplo de 8 e jogava o boneco 16px num degrau de 8.
  O limite do que é parede não mudou (30px ou mais).
- Ao subir um degrau, o corpo sobe exatamente a altura do degrau **e avança
  ~2,5px** (`STEP_UP_FORWARD_NUDGE`), ficando em cima dele. Antes ficava um
  quadro no ar ao lado do degrau, isso contava como queda, e quem cai perde
  o movimento para a frente: travava na quina do degrau.
- O corpo sobe num quadro, mas o **sprite desliza** até ele
  (`_smooth_sprite_after_lift`). Sem isso o boneco parecia quicar a cada
  degrau.
- Terreno na altura da cabeça conta como parede; tijolos não (eles só
  colidem por cima, ver "Escada diagonal").
- **Degrau do outro lado de um vão: depende da largura do vão**
  (`_gap_before_obstacle`):
  - menor que 12px (`Constants.MAX_STEP_OVER_GAP`): **fresta**, ele passa por
    cima e sobe (`prints/bug5.png`);
  - de 12px até o corpo (26px): **parede**, ele dá meia-volta e não
    atravessa (`prints/bug7.png`; o usuário não quer boneco atravessando
    vão);
  - do tamanho do corpo ou maior: **buraco**, ele segue andando e cai nele
    (`prints/bug4.png`).
  Teste: `test_step_over_gap` (6px sobe, 22px volta, 32px cai).

### Topo da escada vertical

Ao chegar no topo, o boneco **dá um passo andando** (~9px, na velocidade de
andar) até pisar no chão ao lado e segue andando. Antes ele era movido um
bloco inteiro num quadro, o que parecia sumir da escada e aparecer no bloco
seguinte. `test_tool_ladder_vertical` mede o maior movimento por quadro.

## Botões da fase e menu

- Toda fase tem, no canto superior direito, **Pausar/Continuar** (tecla P),
  **Reiniciar** (R) e **Menu** (Esc), que funcionam mesmo pausado. Ficam no
  HUD (`scenes/ui/hud.tscn`, `GameControlsController`), então nenhuma fase
  precisa incluí-los. Reiniciar e Menu passam por
  `GameManager.restart_level()` / `go_to_main_menu()`, que despausam antes
  de trocar de cena (senão a cena nova começava congelada). Teste:
  `test_game_controls`.
- O menu (`MainMenuController`) rola e lista: Tutorial, Modo livre (editor)
  e a seção "Ferramentas", com uma fase por ferramenta
  (`TOOL_LEVEL_PATHS`).
- O painel de ferramentas embaixo (`SkillPanel`) rola na horizontal: no
  editor ele mostra todas as ferramentas e não cabia na tela.

## Modo livre (editor)

`scenes/editor/level_editor.tscn`, scripts em `scripts/editor/`.

- Barra de cima (rola na horizontal): **Terra**, **Concreto**, **Escada**,
  **Ponte** (tijolo 32x8, alinhado às colunas e a linhas de 8px),
  **Borracha**, **Entrada**, **Saída**; **Jogar**, **Pausar**, **Reiniciar**;
  **Quantidades** e **Menu**.
- Clique e arraste para pintar; botão direito sempre apaga.
- Contadores de 0 a 50: bonecos e cada ferramenta.
- **Jogar** monta uma fase separada a partir de **cópias** do desenho (um
  `LevelManager` normal, terreno copiado com tijolos, entrada, saída e o
  painel de ferramentas). **Reiniciar** descarta a cópia e devolve o
  desenho original, exatamente como foi pintado. Jogar depois de Pausar
  continua de onde parou.
- Precisa de uma entrada para jogar; a saída é opcional. Sem paredes
  automáticas nas bordas. Sem salvar/carregar (por enquanto).
- Teste: `test_level_editor` (não usa mouse de verdade).

## Situação do repositório (2 de novembro de 2026)

- No GitHub (`Thiago-FR/lemmings-copy`, branch `main`) está **tudo do
  núcleo**: ferramentas, tela cheia, câmera, configurações, editor, áudio,
  arte de terreno/UI/entrada/saída, documentação.
- **Ainda sem commit, esperando o usuário testar:** o modo roguelike
  (`modes/`), o gerador de labirinto (`scripts/procedural/`,
  `tests/test_maze_generator.*`), a arte só do roguelike (cartas em
  `assets/sprites/ui/cards/`, personagens em
  `assets/sprites/characters/{miner,engineer,scout,tinkerer}/` e
  `resources/sprite_frames/`). Os geradores dessa arte
  (`tools/build_card_art.py`, `tools/build_character_variants.py`) já
  entraram no commit do núcleo.
- Os testes do roguelike ficam em `modes/roguelike/tests/` e não são rodados
  pelo `run_tests.bat` (só `tests/`). Para rodar tudo:
  `for t in tests/test_*.tscn modes/roguelike/tests/test_*.tscn` com
  `timeout 400 <godot> --headless --path . res://$t`.

## O que falta fazer (pendências conhecidas)

Roguelike e procedural (o usuário vai testar bastante o procedural):
- **Testar e ajustar o gerador de labirinto**: as fases ficam "em caixas"
  (só tetos e materiais variam); fossos e escadas aparecem pouco nas rotas
  do solver; Garras, Paraquedas, Escada diagonal e explosivos ainda não são
  usados como obstáculos. 34 linhas de 32px dão 1088px, 8px a mais que Full
  HD (a câmera rola 8px).
- **Tempo da fase chutado**: `_time_limit` soma 40s + 22s por sala da rota +
  um extra por ferramenta, vezes uma folga (1,8x a 1,4x), entre 3 e 8 min.
  Os números nunca foram medidos e não contam a distância real nem o tempo
  de cavar para baixo, então uma rota com muita escavação pode ficar sem
  tempo. Corrigir cronometrando o robô dos testes em cada tipo de ligação.

Plano aprovado pelo usuário em 2 de novembro de 2026 (nesta ordem):
1. ~~HUD com ícones, botões do editor, Encerrar fase e Sacrificar~~: feito.
2. ~~Escolher o personagem no início da run, cofre, fim de run~~: feito.
3. **Habilidade especial por personagem**, num slot próprio com poucas
   cargas por fase, recarga que pode cair no mapa: Mago **Teleporte**
   (atravessa parede/chão de 1 bloco), Mineiro **Quebra-concreto** (1 bloco),
   Engenheiro **Plataforma** (tábua de 3 na hora), Batedor **Salto** (vão de
   3 ou degrau de 2), Inventor **Repetir** (a habilidade atual dele).
4. **Moedas e recargas espalhadas pelo mapa.**
5. Carta **"passo acelerado"** (bonecos andam mais rápido).
6. **Compêndio** no menu: cada ferramenta, item, carta, relíquia e
   personagem com o que faz.
7. **Arte**: os 4 personagens novos desenhados do zero (o usuário rejeitou o
   mago recolorido; o Mago não é humanoide, os outros podem ser) e a arte da
   loja.
8. Medir o tempo das fases (item acima).
- Botão **"Gerar fase" no editor** (o `MazeStageData.paint_onto` já existe).
- **Profundidade da Pá** ainda em aberto (um boneco cavou até o concreto e
  o usuário esperou 3 minutos; Encerrar fase resolve a espera, a carta de
  passo acelerado o ritmo).
- Bug relatado e **não reproduzido**: Picareta que quebrou um bloco e parou
  (`prints/bug9.png`). Pedido ao usuário para reproduzir com o modo dev.
- Câmera: talvez uma opção para desligar a rolagem pela borda do mouse (o
  usuário não tem certeza de que é boa experiência).
- Loja e telas entre fases ainda com visual simples (lista); cartas já têm
  arte.

Núcleo:
- **Salvar/carregar cenários no editor.**
- **Tutorial** (o usuário quer que o jogo ensine as ferramentas, sem texto
  explicando a fase).
- Animações que faltam: montar a escada vertical, a diagonal e a ponte
  (usam animações provisórias); pedrinhas da britadeira já existem.
- Fases de teste antigas são pequenas (800x450); o padrão novo é tela
  inteira.
- Ideias em [ideias_futuras.md](ideias_futuras.md) (roguelike completo,
  um boneco/uma ferramenta reutilizável, terreno que nada quebra).

## Pendências de arte

- **Terreno com arte de verdade** (feito): blocos de terra e concreto,
  bordas de chão/parede/teto/canto decididas pelos vizinhos, escada de
  madeira e tábua para ponte e escada diagonal. Limites conhecidos: o fundo
  continua a cor cinza padrão do Godot; uma escada que atravessa rocha
  mostra o fundo cinza atrás dela (não há "parede de fundo" de túnel); o
  tile interior ainda se repete a cada 32px (as pedras sorteadas por célula
  disfarçam); a grama segue a regra "aberto quando a fase começou", então um
  bloco soterrado que fica exposto depois aparece com terra crua.

- A pá é desenhada por código na mesma grade de ~7 px da arte do mago
  (`tools/wizard_art.py`). Na escala do jogo as mãos ficam com ~1 px.
- A animação de escavar está pronta, mas o **tronco ficou mais liso e escuro**
  que as demais, porque tirar a mochila deixou uma área vazia. Dá para
  acrescentar uma dobra de manto usando o sombreado do quadro de andar.
- Falta decidir se a vista **de costas que já existe** (quadros de escalada)
  serve para a escada vertical ou se é preciso uma animação nova.
