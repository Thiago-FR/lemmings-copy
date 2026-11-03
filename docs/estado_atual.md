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
| Campanha "Fases" | ✅ 5 fases que ensinam e 10 quebra-cabeças (labirinto, rotas, espera, relógio, duas entradas...), seleção, progresso, Parabéns e créditos; robô de teste em cada uma e solução ingênua que perde em 7 (ver "Campanha (Fases)") |
| Cenários novos | ✅ deserto, caverna de cristal, campo de neve, vulcão: fundo, blocos, entrada e saída de cada um |

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

- **Nunca trocar o tipo de cursor com o botão do mouse apertado.** Mudar
  `mouse_default_cursor_shape` (ou `Input.set_default_cursor_shape`) entre
  apertar e soltar faz o Godot mandar um movimento de mouse "sem botão", e o
  botão cancela o clique: **nenhum botão do menu funcionava com o mouse de
  verdade** (não dava para começar uma run). Os testes sem janela passavam,
  porque o Godot só faz isso quando o ponteiro do sistema está mesmo sobre o
  botão, e sem janela não há ponteiro. Para a mão fechar, troca-se só a
  **imagem** do cursor da mão (`Input.set_custom_mouse_cursor`). O teste
  `tests/window_test_real_clicks.tscn` (com janela; põe o ponteiro sobre cada
  botão) pega isso: menu, Roguelike, Jogar e Pausar.

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
| Rodar os testes (rápido) | clique duplo em `run_tests.bat`: tudo menos as partidas inteiras (robô jogando a fase toda); no fim abre uma janela e mexe o mouse por uns segundos, não mexa nele enquanto isso |
| Rodar todos os testes | `run_tests.bat completo` (inclui as 38 partidas inteiras, uns 25 min): antes de um commit grande ou depois de mexer no gerador ou numa fase |
| Quando escrever testes | só quando a coisa estiver do jeito que o usuário quer (ferramentas: sim). Enquanto fases e gerador estão sendo refeitos, testar jogando, sem escrever nem ajustar testes deles |
| Teste de cliques de verdade | `godot --path . res://tests/window_test_real_clicks.tscn` (**sem** `--headless`; os `window_test_*` precisam de janela) |
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
| Regerar as fases da campanha | `godot --headless --path . --script res://tools/build_campaign_levels.gd [-- <pasta>]` (com a pasta, salva também o mapa de cada fase em texto) |
| Jogar uma fase da campanha sozinho | `godot --headless --path . res://tests/test_campaign_07.tscn` (01 a 15) |
| Capturas da campanha | `godot --path . --windowed res://tools/capture_campaign.tscn -- <pasta> [números das fases]` (sem `--headless`) |
| Regerar os cenários (blocos, entrada, saída) | `python tools/build_terrain_themes.py [amostra.png]`, depois `godot --headless --path . --import` |

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
  rocha escura, estalactites), e agora DESERT, CRYSTAL_CAVE, SNOWFIELD e
  VOLCANO. Cada fase escolhe em
  `LevelData.environment_kind`; o gerador procedural deve escolher o ambiente
  junto com os tiles. Desde a campanha há mais quatro (deserto, caverna de
  cristal, neve, vulcão), cada um com os próprios blocos, entrada e saída
  (ver "Cenários novos").
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
- **Personagens:** Mago (Teleporte), Mineiro (cava 2x mais rápido;
  Quebra-concreto), Engenheiro (+4 peças em ponte e escadas; Plataforma),
  Batedor (aguenta queda de 160px; Salto), Inventor (Repetir a última
  ferramenta sem gastar carga). As habilidades estão em "Roguelike:
  habilidade de cada personagem". Cada um tem **seus próprios sprites**, desenhados do
  zero em todas as animações (Mineiro baixo e largo de capacete com
  lanterna e barba; Engenheiro de boné, macacão e tábuas nas costas;
  Batedor alto de capuz verde e cachecol vermelho; Inventor pequeno de
  cabelo branco, óculos redondos e mochila com antena), gerados por
  `tools/build_character_variants.py` (desenhos em
  `tools/character_designs.py`) em `assets/sprites/characters/<id>/`
  com um SpriteFrames por personagem em `resources/sprite_frames/`. A
  tinta e a pedrinha sobre a cabeça saíram.
- **Itens na fase:** ferramentas (+cargas), Pena da fênix (resgata um
  perdido), Ampulheta (+60s), Bolsa (+1 carga em cada ferramenta), moedas
  e Recarga (+1 carga da habilidade).
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

### Ranking, tempo apertado no roguelike, mão do cursor (2 de novembro de 2026)

- **Ranking** (`RoguelikeProfile.ranking`, salvo no perfil): as 10 melhores
  runs, cada uma com pontuação, personagem, fase alcançada, vitória e data.
  Tela `RoguelikeRankingScreen` (troféu na escolha de personagem e no fim de
  run): medalhas de cor para os 3 primeiros, a run que acabou de entrar
  desliza e brilha; o fim de run mostra a posição conquistada.
- **Tempo vale pontos**: cada segundo que sobra na fase dá
  `SCORE_PER_SECOND_LEFT` x número da fase (`RoguelikeRunState.time_bonus`,
  com algum salvo); aparece na fileira de ícones das cartas.
- **Relógio apertado**: o robô vence as fases geradas em 35 a 90 s e o
  limite ia de 190 a 350 s (3,5 a 7x). Agora `TIME_FACTOR` é 1,0 a 0,75 e o
  piso 90 s (cerca de 2 a 4x o robô). Os testes de partida falham se o robô
  não terminar com pelo menos 25% do tempo sobrando
  (`MIN_TIME_SPARE_SHARE`), então a fase nunca fica impossível.
- **Mão do cursor redesenhada** (luva com sombra, dedão e punho dourado) e
  **mão fechada** (`cursor_grab`): fecha ao apertar o botão sobre algo
  clicável e abre ao soltar; fica fechada ao arrastar a tela (`CURSOR_DRAG`).
  A primeira versão trocava o tipo de cursor no clique e cancelava todo
  clique real em botão; corrigido trocando só a imagem (ver "Armadilhas").
- **Arrastar a tela com o botão esquerdo** nas fases (`LevelCamera.left_drag`;
  só vira arrasto depois de 8 px, então clicar num boneco continua sendo
  clique; desligado no editor, onde o esquerdo pinta).
- Nuvens com base arredondada (as pontas quadradas apareciam, print `bug12`).

### Telas sem texto: modal, cartas, fim de run, editor, fênix (2 de novembro de 2026)

Pedido do usuário: melhorar **todas** as telas e janelas; animação em vez de
mensagem.

- **`ConfirmModal`** (`scripts/ui/confirm_modal.gd`): o "tem certeza?" do
  jogo (fundo escuro, painel de madeira que surge, ícone grande, pergunta
  curta, consequências como ícone + número, Voltar e a ação em verde).
  Encerrar fase usa ele (já salvos / sacrificados / ainda na entrada).
  Nenhuma tela usa mais `ConfirmationDialog`.
- **`RoguelikeStageSummary`**: o que a fase trouxe vira uma fileira de
  ícones na tela de cartas e no fim de run (salvos, perdidos, moedas, estrela
  da fase perfeita, retrato de quem voltou pela pena e de quem entrou, que
  surgem com animação). As frases saíram.
- **`RoguelikeReviveAnimation`**: a pena da fênix sobe girando, explode em
  fogo e o retrato do boneco renasce das chamas; toca ao escolher a carta da
  pena e no fim da fase quando uma pena guardada traz alguém. Clique pula.
  Teste: `modes/roguelike/tests/test_revive_animation`.
- **Editor**: sem linha de status. Jogando, os contadores aparecem como
  ícones; faltou a entrada ou os bonecos, o botão que resolve pisca em
  vermelho e treme (`EditorToolbar.flash`). Contadores só com ícone (nome
  na dica).

### Acelerar, cursor, ícones sobre o boneco, ponte e fundo animado (2 de novembro de 2026)

- **Acelerar** (botão com duas setas, tecla F, nas fases normais e no
  roguelike): `GameManager.set_fast_forward` põe tudo 3x mais rápido
  (`FAST_FORWARD_FACTOR`), relógio incluído, e sobe os passos de física na
  mesma proporção (180 por segundo), então cada passo continua 1/60 s e a
  fase acontece igual, só mais cedo. Volta ao normal ao trocar de cena, ao
  fim da fase e ao sair do HUD. Teste em `test_game_controls`.
- **Cursor do jogo** (`cursor_arrow`, `cursor_hand` em
  `tools/build_ui_art.py`), posto pelo `GameManager`: seta normal e mão
  sobre todo botão (qualquer tela, via `node_added`) e sobre os bonecos.
- **Tudo o que o boneco tem aparece em cima dele** (`CarriedToolIndicator`):
  a ferramenta carregada ou em uso (aro dourado enquanto usa; a Ponte e a
  Escada diagonal começam quase na hora e antes não apareciam) e, menores,
  Garras e Paraquedas.
- **Ponte com cara de ponte** (`BridgeRailing`, criado pela `SkillBridge`):
  poste em cada ponta e corda de corrimão com pendurais em cada tábua; segue
  a ponte enquanto é montada e o que sobra dela se tábuas forem destruídas.
  Núcleo: `TerrainDestructible.has_brick`.
- **Fundo animado** (`LevelBackground`, `LevelEnvironment`): halo do sol
  pulsando, nuvens passando (prado, neve) e pássaros batendo asa (prado,
  deserto, neve). O prado ganhou sol.

### Cartas com nível (2 de novembro de 2026)

Regras aprovadas pelo usuário.

- **Dois tipos de carta.** Imediatas (+cargas, ferramenta nova, recruta,
  pena da fênix) servem uma vez. **Permanentes** (as relíquias) têm nível
  **I a III** (`RoguelikeRelics.MAX_LEVEL`): pegar a mesma de novo sobe o
  nível; no III ela não é mais oferecida; na loja custa 12 + 6 por nível.
- **As permanentes** (efeito por nível em `relics.gd`):
  Lâminas afiadas (cavam +25%/nível), Ponte longa (+3 peças/nível), Escada
  comprida (+2 peças/nível na vertical), Pavio curto (-0,5 s/nível),
  Bolso extra (+1 espaço/nível; a barra vai até 7), Paraquedas reserva
  (1º / 2 primeiros / todos), **Coletor** (cada item de ferramenta dá
  +1/nível), **Ganância** (+1 moeda/nível por salvo e em cada moeda do mapa),
  **Passo acelerado** (andam +15%/nível) e **Ampulheta** (+20 s/nível em
  toda fase). As 4 últimas são novas, com ilustração em
  `tools/build_card_art.py`.
- **Moedas no mapa**: item novo `COINS` (2 moedas, +Ganância) entre os
  bônus da fase.
- **Barra lateral** (`RoguelikeRelicBar`): na esquerda da fase, uma ficha
  por carta permanente com o nível em romano; a dica diz o efeito.
- **Gancho no núcleo**: `LemmingController.walk_speed` (por boneco; antes
  era a constante `WALK_SPEED`), usado pelo Passo acelerado.
- **Mago sem o +1 por item** (decisão: os itens valem 1; quem dá mais por
  item agora é o Coletor). A identidade dele é o Teleporte (feito, ver
  "Roguelike: habilidade de cada personagem").
- Texto das cartas encurtado ("Nova, 2 cargas." em vez de "Nova na barra",
  que o usuário achou confuso); loja com moeda + preço.
- Testes: `test_run_state` (níveis, oferta sem carta no topo, preço),
  `test_relic_effects` (efeitos numa fase de verdade e a barra lateral).

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
- **Barra das fases normais** (`HudController`, print `art6`): ícone +
  número para na fase, salvos, perdidos, total, relógio e meta (ícone de
  alvo `hud_goal`), com dica; Pausar/Continuar, Reiniciar, Configurações e
  Menu como ícones do editor (`GameControlsController`).
- **Escolha de personagem**: Jogar em verde e Comprar só com moeda + preço,
  do mesmo tamanho; Menu e Dev como ícones (ícone novo `dev`).
- **Modo dev**: campo Quantidade + Adicionar/Remover para bonecos, cargas de
  cada ferramenta, penas, moedas e cofre; relíquia que já tem sai ao clicar.
- **Compêndio** (`RoguelikeCompendiumScreen`, botão no modo dev): abas
  Personagens, Ferramentas, Itens da fase, Cartas, Relíquias, cada entrada
  com figura, nome e descrição. Pronto para o jogador: com uma função de
  "descoberto", o que ainda não foi descoberto aparece em sombra preta com
  "???" (ideia do usuário: ir liberando conforme pega e usa). O que foi
  descoberto e o botão do jogador vieram depois (ver "Roguelike: habilidade
  de cada personagem e compêndio do jogador").

### Roguelike: habilidade de cada personagem e compêndio do jogador (2 de novembro de 2026)

Itens 3 e 6 do plano aprovado.

- **Habilidade especial** num slot próprio no fim da barra de ferramentas
  (`RoguelikeToolBar`), separado das ferramentas por uma linha na cor do
  personagem, com ícone e o número de cargas. Clica no slot (arma; clicar
  de novo desarma), clica num boneco: ele usa. Armar solta a ferramenta
  escolhida e desarma o Sacrificar; escolher uma ferramenta ou armar o
  Sacrificar desarma a habilidade. **Recusada não gasta carga.** Código em
  `modes/roguelike/scripts/abilities/` (`RoguelikeAbility` e uma subclasse
  por habilidade, catálogo `RoguelikeAbilities`, cargas em
  `RoguelikeAbilitySlot`, efeito visual `RoguelikeAbilityEffect`).
  | Personagem | Habilidade | Cargas/fase | O que faz e quando recusa |
  |---|---|---|---|
  | Mago | Teleporte | 2 | atravessa uma parede de 1 bloco (na frente, até 1 bloco de distância, ou a que acabou de tocar atrás dele) ou, sem parede, o chão de 1 bloco embaixo. Recusa se for mais grosso, se o corpo não cabe do outro lado ou se o outro lado é fora da fase (a parede de fora). Brilho violeta nos dois lados |
  | Mineiro | Quebra-concreto | 2 | quebra 1 bloco de concreto na altura do corpo (na frente, até 1 bloco, ou o que acabou de tocar). Terra não (é da Picareta). Lascas cinza e poeira |
  | Engenheiro | Plataforma | 2 | 3 tábuas (tijolos da Ponte) na hora, a partir de onde o chão acaba (até 1 bloco à frente); a última é cortada se encostar no outro lado. Recusa sem beirada perto ou com parede antes |
  | Batedor | Salto | 3 | pula um vão de até 3 blocos para chão na mesma altura, ou sobe um degrau de até 2 blocos (de 30 px para cima; menos que isso ele sobe andando). Arco checado contra o terreno antes de pular (tenta arcos mais baixos sob teto baixo); recusa se bate em algo ou não cabe onde cai. Poeira na saída e na chegada |
  | Inventor | Repetir | 1 | dá de novo a última ferramenta que ele recebeu, sem gastar carga dela (o que antes era "clicar nele sem ferramenta, uma vez por fase"). Recusa se ele ainda não recebeu nenhuma ou não pode receber aquela agora |
- Os bônus passivos ficam: Mineiro cava 2x, Engenheiro +4 peças, Batedor
  queda 2x. O Mago não tem passivo. A descrição de cada personagem agora é
  "passivo + habilidade" (`RoguelikeCharacters.get_ability`).
- **Recargas:** item novo na fase `ABILITY_CHARGE` (+1 carga, cristal azul)
  entre os bônus (`stage_factory._bonus`, ~12%, tirado das moedas) e a
  relíquia **Dom ampliado** I-III (+1 carga por nível), com ícone e
  ilustração em `tools/build_ability_art.py` (script próprio, separado do
  `build_ui_art.py`; também faz o ícone do livro do compêndio).
- **Gancho no núcleo:** estado novo `LemmingStateMachine.State.PERFORMING`
  (no fim do enum): o boneco é movido por uma "skill" de fora do núcleo
  (o arco do Salto, `RoguelikeLeapMotion`) e não recebe ferramenta nem pode
  ser interrompido no ar. Nada mais no núcleo mudou.
- **Compêndio do jogador:** botão com ícone de livro na tela de escolha de
  personagem. O que foi descoberto fica no perfil
  (`RoguelikeProfile.discovered`, em `user://roguelike_profile.cfg`); o
  resto aparece em sombra preta com "???". Regras (`RoguelikeDiscovery`):
  personagem quando liberado (o Mago sempre); ferramenta quando pega,
  recebida por carta ou usada; item da fase quando pego; tipo de carta,
  relíquia e a ferramenta de uma carta quando **oferecidos** (o jogador leu
  a carta; na tela de recompensa ou na loja); habilidade quando usada uma
  vez. O compêndio do modo dev continua mostrando tudo.
- **Pouco texto** (pedido do usuário: "aviso não, animação"): o compêndio
  virou uma fileira de ícones de categoria (Personagens, Habilidades,
  Ferramentas, Itens da fase, Cartas, Relíquias), cada um com
  descobertos/total, e uma grade de fichas (figura + nome); o que cada uma
  faz fica na dica. Descoberta nova na fase: o livro do compêndio salta
  sobre o lugar (`RoguelikeIconPop`), sem frase. Pegar uma Recarga: o
  cristal salta e o slot da habilidade pulsa, sem texto flutuante. Na
  escolha de personagem cada carta mostra o ícone + nome da habilidade e
  só o passivo curto; a descrição inteira está na dica.
- Testes: `test_abilities` (15 cenários num terreno montado: cada
  habilidade funcionando e cada recusa sem gastar carga),
  `test_ability_session` (slot na barra, armar/desarmar, recarga, registro
  no perfil), `test_compendium` (perfil, entradas, sombra, botão).

### Itens valem 1 e saída sem entrar do alto (2 de novembro de 2026)

- **Cada item de ferramenta dá 1 carga** (o usuário achou 3 fácil demais;
  mais por item vem das cartas). O gerador agora espalha as cargas de uma
  pilha em itens separados na sala (`MazeStageGenerator._place_markers`:
  primeiro um lugar para cada pilha, depois as cargas extras onde couber;
  sem chão, empilha). Cada item lembra de que pilha veio (`spot_index`),
  que é o que a solução gravada usa. Item bônus de ferramenta: 1.
  O Mago deixou de dar +1 por item (ver "Cartas com nível").
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

## Campanha (Fases)

Botão **"Fases"** no menu principal (depois do Tutorial). Faz parte do
núcleo, não é um modo em `modes/`.

- **Modo dev, na tela de Fases:** cadeado (liberar todas as fases sem marcar
  estrela; clicar de novo tranca) e seta circular (zerar o progresso, com
  confirmação). Em 2 de novembro de 2026 as 15 apareciam vencidas porque um
  robô de teste antigo gravou no progresso de verdade; hoje os testes usam
  arquivos próprios (`Campaign.save_path`, `Campaign.level_data_pattern`).

- **15 fases feitas à mão**, 3 por cenário: Prado (1-3), Deserto (4-6),
  Caverna de cristal (7-9), Campo de neve (10-12), Vulcão (13-15).
- **Refeitas em 2 de novembro de 2026** (veredito do usuário: "todas
  parecem Mario", pontes sempre do tamanho exato, nada de criatividade, as
  contagens já entregam a solução). A 1 a 5 continuam ensinando; da 6 em
  diante cada fase é um quebra-cabeça com **uma ideia própria** ("aha"),
  diferente da anterior: labirinto, rota que cabe nas contagens, espera,
  rede de segurança, relógio, só pontes, duas entradas, veios de pedra.
  Ferramentas sobrando, ferramentas que não servem e buracos maiores que
  uma ponte são de propósito.

| # | Nome | Ferramentas | A ideia | Por que não é óbvio |
|---|---|---|---|---|
| 1 | Terra Fofa | Pá 3 | campo fechado por um morro; a saída num vão embaixo: cavar | (ensina) |
| 2 | Ribeirão Seco | Ponte 3 | dois leitos sem fundo | (ensina) |
| 3 | Muralha do Moinho | Escada vertical 3 | dois paredões de 6 blocos | (ensina) |
| 4 | Escadaria das Dunas | Escada diagonal 4 | dois terraços de 3 blocos | (ensina) |
| 5 | Garras ao Vento | Garras 8, Paraquedas 8 | planalto e cânion: cada boneco precisa dos dois | (ensina) |
| 6 | Labirinto das Dunas | Bloco 2 | labirinto de túneis de 1 bloco ligados por buracos (queda segura) e poços fundos; virar todos de volta **logo na entrada**, para o buraco atrás dela, e mais uma vez no fim | eles caem no primeiro túnel e correm para um poço; virar ali só leva ao próximo poço, e esse ramo pede 3 blocos |
| 7 | Câmaras de Cristal | Picareta 1, Pá 1, Ponte 1, Dinamite 1 | três salas em cima, um túnel embaixo; três rotas, só a que **desce logo** (Pá, Ponte no abismo, Picareta na última parede) cabe | a parede em que eles batem pede a Picareta, que faz falta depois; as paredes têm 2 blocos e a Dinamite não fura nenhuma; cavar na beira do abismo mata |
| 8 | A Espera | Bloco 2, Dinamite 2, Picareta 1, Pá 1 | meta de **100%**; o chão de cristal só abre com explosão, que mata quem passa; o primeiro segue, um Bloco atrás dele prende o resto, ele põe a carga, a Picareta fura o Bloco | sem prender, a explosão leva um (o robô ingênuo salva 93%); perto da entrada o chão tem 2 blocos e a carga só faz uma cratera-armadilha |
| 9 | Rede de Segurança | Garras 1, Paraquedas 1, Escada vertical 1, Picareta 1, Ponte 1, Bloco 1 | **a escada pega quem cai por ela**: um pioneiro sai pela pedra (Garras), desce o poço (Paraquedas) e põe a escada até o túnel baixo na parede; só então a Picareta abre a pedra e os outros pulam no poço | a ponte sobre o poço leva a uma parede alta demais; a escada dada cedo é usada na pedra |
| 10 | Contra o Relógio | Pá 2, Bloco 2, Ponte 1 | seis túneis em zigue-zague até a saída: seguro e lento demais (125 s); cavar **na curva**, onde eles viram, pula dois túneis | todo chão é fino e qualquer Pá é segura, mas cavada onde eles andam não economiza nada: eles caem andando para o lado longo |
| 11 | Só Pontes | Ponte 3 | saem andando para um buraco sob um penhasco; a saída é do outro lado de um vão de 18 (mais que uma ponte); a ponte até o penhasco **faz eles voltarem**; duas pontes seguidas no vão, a segunda dada a quem anda na primeira | quem faz a primeira ponte do vão cai da ponta (perde-se 1 ou 2) |
| 12 | Duas Bocas | Escada vertical 1, Picareta 1, Ponte 1, Garras 2, Bloco 1 | **duas entradas**, uma de cada lado de uma torre com a saída em cima, e uma escada só: a escada numa face, depois um túnel pela base traz o outro grupo até ela | com o túnel primeiro não sobra face para a escada; Garras 2 salvam só dois |
| 13 | Beiço de Lava | Ponte 1, Escada diagonal 1, Escada vertical 2 | um poço de lava sob um penhasco à frente; a saída atrás, numa plataforma 2 blocos mais alta cuja beira avança sobre o canal; a **escada diagonal sobe por cima do canal** até a beira | a ponte no canal passa por baixo da beira até a parede e a beira impede a escada vertical; a diagonal também vira o grupo no penhasco, e aí a ponte não resolve o canal |
| 14 | Veios de Obsidiana | Pá 8, Picareta 8, Bloco 4 | ferramentas de sobra; o problema é ler a rocha: Pá até um veio 2 blocos abaixo, Picareta de lado até o oco seguinte, de novo, até a saída | cavar direto no oco embaixo da cratera é queda mortal; o lado errado de cada poço dá em lava; cavar em cima de veio prende |
| 15 | Coroa de Fogo | Bloco 3, Ponte 2, Dinamite 1, Picareta 2, Pá 1 | final: **duas entradas** caem num túnel longo com lava nas duas pontas e a saída sob o chão de obsidiana do meio, meta 95%; prender cada grupo do seu lado, a carga pelo pioneiro sozinho no meio, Picaretas abrem os dois cercados | são 4 paredes e 3 Blocos: pontes até a rocha depois dos poços também viram o grupo; sem prender, a explosão leva dois (o robô ingênuo salva 90%) |

- **Duas entradas:** `SpawnPoint` ganhou `lemming_count` (quantos essa
  entrada solta; 0 = o total da fase) e `faces_left` (saem andando para a
  esquerda). No gerador, `"spawns": [{cell, count, left}]`; a soma tem que
  dar `lemmings` (o `test_campaign` confere).

- **Tamanho:** todas com 80 x 45 blocos (o padrão "no mínimo 80 x 45"),
  câmera rolando.
- **Como são feitas:** `tools/build_campaign_levels.gd` desenha cada fase
  numa grade (começa toda de terra; céu, salas, abismos e concreto são
  pintados por cima) e salva `scenes/levels/campaign/campaign_NN.tscn` e
  `resources/levels/campaign/campaign_NN_data.tres`. O cabeçalho do script
  lista as regras de geometria que todas seguem (queda de 2 blocos é
  segura, chão para cavar/explodir é 1 bloco sobre um vão de 1, etc.).
  Depois do desenho, uma decoração automática põe pedras (concreto) e uma
  faixa de rocha no fundo, e nas cavernas ocos fechados com cristais —
  **só em blocos a 3 ou mais de qualquer espaço aberto e nunca numa parede
  entre dois espaços abertos** (onde passa túnel ou poço), para não mudar
  nenhuma solução. A primeira versão pôs uma pedra no meio do monte da fase
  12 e a Picareta parou nela; o teste pegou.
- **Teste de cada fase:** `tests/test_campaign_NN.gd` (base
  `tests/campaign_playthrough_test.gd`, que estende
  `level_playthrough_test.gd`) joga a fase com uma solução escrita
  (`give_once` / `give_each` com condições de posição; `someone_ahead_of`
  para dar a ferramenta ao segundo enquanto o primeiro segue) e só passa se
  ganhar, isto é, salvar a meta no tempo. Cada morte sai no log com tempo
  e lugar. Os testes rodam **4x mais rápido**: `Engine.time_scale = 4` com
  a física a 240 ticks/s, então cada passo ainda é 1/60 s, a mesma
  simulação. Os 15 passam.
- **Solução ingênua que tem que perder:** `tests/test_campaign_NN_naive.gd`
  (fases 6, 7, 8, 10, 13, 14 e 15) joga o que parece certo e passa só se a
  fase for **perdida** (`_expects_win()` devolve `false`): virar a cada
  poço (6), a Picareta na primeira parede (7), a carga sem prender ninguém
  (8: 93%, meta 100%), cavar onde eles andam (10), diagonal no penhasco e
  ponte no canal (13), cavar direto no oco (14), a carga sem cercados (15:
  90%, meta 95%).
- **Tempo:** a fase 10 é a única apertada de propósito (o robô usa 105 de
  125 s). Nas outras o robô usa de um terço a metade do tempo.
- **Progresso:** `Campaign` (`scripts/level/campaign.gd`) em
  `user://campaign.cfg`, seção `cleared`, a melhor porcentagem de cada fase
  ganha. A primeira está sempre aberta; ganhar abre a seguinte. Os testes
  usam outro arquivo (`Campaign.save_path`).
- **Tela de seleção** (`CampaignSelectScreen`, `scenes/ui/campaign_select.tscn`):
  15 botões em 5 colunas, uma por cenário, com uma faixa nas cores do
  cenário em cima; estrela nas ganhas, verde na próxima, cadeado nas
  fechadas; nome no tooltip; o fundo vira o cenário da fase sob o mouse.
- **Fim de fase** (`LevelResultController`, todo montado em código; a cena
  `level_result_screen.tscn` é só o nó): painel de madeira que surge
  crescendo; na vitória uma estrela entra girando e fica pulsando, na
  derrota a caveira cai, quica e treme; ícone + número para salvos (conta
  de 0 até o valor) e meta, com dica; Jogar de novo e Fases/Menu como
  ícones, **Próxima** em verde. Na campanha registra a vitória; depois da
  fase 15 o botão verde vira **Parabéns** (estrela).
- **Parabéns e créditos** (`CampaignCompleteScreen`,
  `scenes/ui/campaign_complete.tscn`, `Campaign.COMPLETE_SCENE_PATH`):
  "Parabéns!" entra elástico e balança, fogos de artifício
  (`CPUParticles2D`), as 15 estrelas acendem uma a uma, magos marcham no
  chão; depois sobe o painel de créditos (três linhas com ícone: "Um jogo
  de Thiago", "Feito com Claude", "Arte e som gerados por código"). Fases
  (verde) e Menu. Aberta pela vitória na fase 15 e, com todas ganhas
  (`Campaign.is_complete()`), por um botão verde **Parabéns** que pulsa na
  tela de seleção.
- Teste do fluxo: `tests/test_campaign` (dados das 15 fases, entradas,
  progresso, tela de seleção, tela de fim de fase, Parabéns depois da
  última, botão Parabéns só com tudo ganho, créditos, botão no menu).
- Capturas: `tools/capture_campaign.tscn` salva também `result_lost.png`,
  `select_complete.png` e `complete.png`.
- Ainda não medido com gente jogando: a dificuldade foi pensada, e o robô
  prova só que cada fase tem solução.

### Cenários novos (`LevelEnvironment`)

- Tipos novos (`LevelEnvironment.Kind`, acrescentados no fim, o número das
  fases antigas não muda): `DESERT`, `CRYSTAL_CAVE`, `SNOWFIELD`, `VOLCANO`.
- O fundo (`LevelBackground`) agora escolhe a silhueta por `skyline`
  (morros, dunas, picos com neve/lava no topo, estalactites) e pode ter sol,
  pontos que piscam (cristais), coisas que caem ou sobem (neve, brasas) e
  cristais saindo do chão.
- `terrain_theme` liga o cenário a uma pasta de arte: o `LevelManager`
  passa o tema para o terreno (`TerrainDestructible.art_theme`, troca a
  textura do atlas numa cópia do TileSet e as tiras de borda), a entrada e a
  saída (`art_theme` em `SpawnPoint`/`ExitPoint`, via `PortalSprite`) e a
  moldura de rocha. Tiles e colisão iguais: só a textura muda. Ver
  `art_pipeline.md`, "Cenários".

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
  automáticas nas bordas.
- **Várias entradas:** com a ferramenta Entrada, clique move a entrada mais
  próxima, **Shift+clique** cria outra, clicar numa entrada vira o lado
  para onde os bonecos saem (a seta amarela mostra) e o botão direito numa
  entrada a remove (enquanto sobrar outra). Várias entradas dividem os
  bonecos.
- **Modo dev: abrir e salvar as 15 fases da campanha** (botões do pergaminho
  e do baú na barra de cima). Abrir traz terreno, tijolos, entradas (com o
  lado), saída, bonecos e ferramentas. Salvar escolhe qualquer uma das 15 e
  pede confirmação; **antes de substituir, a versão antiga vai para um
  backup** em `user://campaign_backups/campaign_NN_<data>/` (cena e dados).
  Uma fase com backups mostra um relógio no seletor; abrir pergunta qual
  versão (a atual ou um backup pela data); para recuperar, abra o backup e
  salve por cima (o que também guarda a versão de agora). O que o editor
  não edita (nome, dica, meta %, tempo, cenário, ritmo de saída) fica o da
  fase substituída. Código: `CampaignLevelStore`
  (`scripts/level/campaign_level_store.gd`) e `EditorLevelPicker`.
- Os tijolos de uma fase salva ficam em `TerrainDestructible.initial_bricks`
  (não fazem parte dos dados do tile map).
- Testes: `test_level_editor` e `test_editor_campaign_levels` (este trabalha
  em cópias da fase 12; nunca mexe nas fases de verdade).

## Gerador por ambientes do roguelike (2 de novembro de 2026, segunda passada)

O usuário achou óbvio o gerador antigo (grade de 15 salas, print `bug13`) e
pediu fases por **ambiente**, em **ordem fixa**, cerca de 3 por ambiente. Na
primeira passada reprovou tudo (prints em `prints/bugsambientes/`): copas
redondas "de tinta espirrada" e "babaloo", fresta entre tronco e copa, fases
retas, linha de concreto solta na mina, prédios baixos, fundo do espaço sem
graça. Gostou da pirâmide (`bom1`), da caverna de cristal e dos pinheiros,
palmeiras e cogumelos como **enfeite de fundo**. O roguelike tem uma fase
para cada fase de cada ambiente, hoje **30**
(`RoguelikeRunState.stage_count()` = `BiomeStageGenerator.stage_count()`).

**Cada ambiente é um arquivo** em `scripts/procedural/biomes/` (pedido do
usuário: incluir um tema novo sem mexer nos outros). O arquivo estende
`StageBiome` (`scripts/procedural/stage_biome.gd`), diz em `_init` o `id`, o
nome, os nomes das fases (quantas quiser), `shapes`, `routes`, `order` (a
posição na partida; os atuais vão de 10 a 100, deixando espaço entre eles),
`walled` e `inside_wall`, e monta a fase em `build(g)` com as ferramentas do
gerador (`g.make_relief`, `g.carve_caves`, `g.fill_cells`, `g.add_need`,
`g.spawn_cell`, `g.exit_cell`...). O gerador acha os arquivos sozinho
(`BiomeStageGenerator.biomes()`); a partida, o editor e as prints passam a
incluir o ambiente novo sem mais nada.

- `BiomeStageGenerator` (`scripts/procedural/biome_stage_generator.gd`, no
  núcleo, com as ferramentas comuns): 10 ambientes, 3 fases cada (Prado, Floresta, Deserto, Mina,
  Caverna de Cristal, Geleira, Vulcão, Cidade, Outro Planeta, Espaço). Cada
  fase tem:
  - **tamanho que cresce** com a fase (`stage_size`): a 1ª cabe numa tela
    (56x30 blocos); a última é `GROWTH_AT_LAST_STAGE` (3,6) vezes maior no
    lado comprido. **Formato** comprida (`WIDE`), alta (`TALL`) ou os dois
    (`BOTH`), escolhido por ambiente e fase (`StageBiome.shapes`);
  - um **caminho**: atravessar (`TRAVERSE`), **subir** até uma saída lá em
    cima (`ASCEND`) ou descer até o fundo (`DESCEND`) (`routes`);
  - **relevo** (`make_relief`): morros que se anda (1 bloco por coluna) e, de vez
    em quando, paredões de 2 a 5 blocos que pedem ferramenta; ravinas;
    **subsolo** de cavernas em quase todos os ambientes, com buracos da
    superfície até elas e a parede da caverna desenhada atrás do ar;
    bolsões de rocha (concreto) só dentro da terra, nunca linhas soltas;
  - peças do ambiente: **árvores de copa quadrada para subir** (Prado,
    Floresta; tronco encostado na copa, sem fresta; algumas com item em
    cima), pirâmide de degraus altos que cresce (saída no topo na 3ª do
    Deserto), galerias da mina, caverna de gelo no início da Geleira,
    cone do vulcão com a saída na borda da cratera, **arranha-céus com
    andaimes** (plataformas de madeira e algumas escadas já montadas; a
    saída no telhado mais alto) e metrô sob a rua, ilhas flutuantes,
    módulos de estação em várias alturas.
- **Copas para subir** desenhadas **chapadas como os pinheiros de fundo**:
  um verde só, algumas manchas um tom acima ou abaixo, e na borda com o ar
  contorno escuro, faixa clara em cima e sombra embaixo e à direita. O
  usuário reprovou o contraste da grade 8x8 de "pixels" (granulada demais).
  As células de folha e de caixote não recebem grama nem pedrinhas da terra
  (`TerrainDestructible.self_drawn_cells`, `TerrainSkin.SELF_DRAWN`). Os
  enfeites não nascem perto delas.
- **Saída das fases de descida** numa câmara no fundo, à direita
  (`_bottom_chamber`). As paredes de caverna e os troncos ficam numa camada
  própria atrás dos portais (z -2): antes cobriam o portal de saída, que é
  desenhado logo atrás do terreno (z -1), e a saída "sumia".
- **Árvores de subir removidas** (o usuário não gostou de nenhuma versão):
  Prado e Floresta só têm árvores de enfeite, em maior número. A pele
  `TerrainSkin.LEAVES` continua existindo, sem uso.
- (Removidas depois) **Copas com silhueta de árvore**: topo arredondado alargando até as
  linhas mais largas **embaixo**, iguais dos dois lados (larguras por linha,
  de cima: 1,2,2 ou 1,2,3,3 meias-larguras). O usuário reprovou as copas
  retangulares, as que encolhem na base e as com pontas cortadas ao acaso
  (ficavam tortas).
- **Nuvens com volume**: cada uma é desenhada em três camadas (sombra
  cinza-azulada um pouco abaixo, corpo branco, bolinhas de luz em cima à
  esquerda); antes eram chapadas e acinzentadas.
- **Fundo de caverna segue os blocos** (`TerrainSkin.inside_wall`, calculado
  do terreno, não pintado pelo gerador). Um ar ganha a parede quando tem
  **teto** e não há céu aberto a até 2 blocos (a boca da caverna mostra um
  pouco de céu). Teto é: muita rocha em cima (6 blocos ou mais, subsolo
  fundo, qualquer altura ou largura de galeria), ou rocha perto em cima (até
  8 blocos) com rocha dos dois lados na linha (até 10 blocos). Folhas
  (verdes e roxas) e escadas não são rocha. Assim o ar sob uma ilha
  flutuante ou sob uma copa fica sem fundo (print `bugsambientes/bug11`:
  colunas escuras sob as ilhas do planeta). Recalculado perto de cada
  mudança, então um túnel cavado também ganha parede.
- **Espaço é uma nave** (o usuário achou os módulos soltos bizarros): casco
  comprido com motores atrás e o nariz à direita, conveses a cada 6 blocos
  ligados por poços (alguns com escada, os outros para escalar ou
  construir), anteparas com porta em cada convés (algumas fechadas, para a
  britadeira), escotilhas no teto para andar por fora do casco, asteroides
  em volta. A saída fica na ponte (nariz) ou, na fase de subida, em cima do
  casco.
- **Salas da nave** (`RoomDecor`, `scripts/level/room_decor.gd`, móveis
  desenhados na parede do fundo, não sólidos): cada compartimento entre duas
  anteparas e dois conveses ganha um uso. Atrás, a **sala de máquinas**
  (reatores com núcleo pulsando, canos, faixas de alerta). No nariz, na
  altura da janela, a **ponte** (janela de estrelas, consoles piscando,
  cadeiras). No meio, sorteadas sem repetir lado a lado nem uma sobre a
  outra: **refeitório** (mesas, banquinhos, pratos, máquina de comida),
  **dormitório** (beliches, armários), **laboratório** (tanques com bolhas
  subindo, bancada com frascos, monitor), **estufa** (prateleiras de plantas
  sob luz violeta), **porão de carga** (estantes, barris e **caixotes de
  verdade** no chão, 1 bloco, dá para subir ou cavar: `TerrainSkin.CRATE`) e
  **enfermaria** (cama, monitor cardíaco, armário com cruz). Lâmpadas no
  teto de todas. Cada sala tem **parede de fundo própria** (o cinza único da
  nave foi reprovado): placas de aço na de máquinas, painéis azul-marinho na
  ponte, madeira embaixo e creme em cima no refeitório, papel listrado azul
  no dormitório, azulejos claros no laboratório e verde-água na enfermaria,
  vidraças com trepadeiras na estufa, chapa ondulada no porão.
  `MazeStageData.rooms` leva as salas para a fase.
- (Substituído pela nave) **Módulos do espaço** viraram salas (8 blocos de altura, portinhola de 3
  em cada lado, parede interna atrás), em fileiras que não se sobrepõem e
  com alturas variando.
- **Árvores de enfeite** (pinheiro, pinheiro com neve, palmeira, cogumelo;
  `TreeArt` + `BackgroundDecor`): atrás do terreno, não são sólidas, sem
  item. Carvalho e cerejeira redondos foram removidos.
- **Borda inquebrável** (`TerrainDestructible.unbreakable_cells`): duas
  colunas de rocha escura com parafusos de cada lado e a rocha da primeira e
  da última linha; a ferramenta que tenta quebrar dá uma explosãozinha
  (sinal `unbreakable_hit`, efeito em `LevelManager`). O espaço não tem
  borda nem moldura (`has_frame = false`) e ganhou nebulosa e um planeta com
  anel (`nebula_colours`, `ringed_planet`).
- **Visual:** temas de terreno `city`, `alien` e `station`; ambientes
  `FOREST`, `CITY`, `ALIEN_PLANET` e `SPACE` (no fim do enum, porque as fases
  guardam o número); `TerrainSkin` desenha parede de prédio, casco de
  estação, borda, folhas quadradas e, atrás do ar subterrâneo, parede de
  caverna ou de gelo (segue `TerrainDestructible.cells_changed`).
- **Ainda não confere se a fase dá para vencer** e não grava a solução: os
  testes de partida do roguelike (`run_tests.bat completo`) falham até isso
  existir. De propósito, enquanto o usuário aprova o visual.
- **Prints de todas as fases:** `prints/ambientes/`, gerados por
  `godot --path . --resolution 1920x1080 res://modes/roguelike/tools/capture_stages.tscn -- <pasta> [semente] [primeira] [última]`.
- **Itens ao cavar** (plano aprovado antes) **ainda não existem**.

## Editor: coleções de fases e gerador (2 de novembro de 2026)

- **Abrir** e **Salvar** (pergaminho e baú, para todos) pedem primeiro o
  **modelo** (`LevelCollection.all()`): **Modo livre** (desenhos do
  jogador em `user://free_levels/`, sempre), e no modo dev **Fases** (as 15
  da campanha, `CampaignLevelCollection`) e **Roguelike** (as 30 fases,
  `modes/roguelike/level_collection.gd`). Um modo novo aparece sozinho se
  tiver `res://modes/<modo>/level_collection.gd` estendendo
  `LevelCollection` (o núcleo não cita modo nenhum).
- Depois, o espaço numerado (o nome no tooltip; vazio fica apagado ao
  abrir) e, se houver backups, a versão. Salvar por cima pede confirmação e
  **guarda backup** (`user://level_backups/<modelo>/slot_NN/<data>/`; a
  campanha continua em `user://campaign_backups/`).
- **Roguelike:** uma fase que ninguém desenhou abre como o gerador a faz
  (semente 1); salvar a torna **fixa**
  (`modes/roguelike/resources/stages/stage_NN.tres`) e toda run passa a
  jogá-la ali (`RoguelikeStageFactory` pergunta `override_maze`). As
  ferramentas contadas no editor viram itens nos chãos mais perto da
  entrada. A fase desenhada perde as árvores e as paredes de prédio (o
  editor só guarda o terreno).
- **Gerar** (dado): escolhe o ambiente, o tamanho (1 tela, Comprido, Alto,
  Grande, Enorme) e a dificuldade; a fase gerada vira o desenho, que pode
  ser mudado e salvo. O tamanho do desenho agora acompanha a fase aberta ou
  gerada (`LevelEditorController.set_map_size`).
- Formato salvo: `LevelDrawing` (`scripts/level/collections/`), que também
  converte `MazeStageData` em desenho e de volta.
- **Arrumação pedida pelo usuário:** tudo o que se põe no desenho fica
  **embaixo** (terra, concreto, escada, ponte, borracha, entrada, saída e
  **Virar entrada**, que vira o lado de saída dos bonecos de uma entrada
  clicada), junto dos contadores; em cima ficam Jogar/Pausar/Reiniciar,
  Quantidades, **Novo** (limpa tudo, com confirmação), Abrir, Salvar, Gerar
  e Menu. Ao abrir, só aparecem os espaços com fase; um modelo sem nada
  salvo fica apagado.

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

**Aprovado em 2 de novembro de 2026, a implementar (roguelike, depois que o
agente das habilidades terminar):**
- **Itens ao cavar** (ideia do usuário, estilo Bomberman):
  - as ferramentas que a fase exige continuam visíveis e garantidas pelo
    gerador; o que sai dos blocos é sempre extra;
  - cavar não se paga sozinho: carga de ferramenta é rara e nunca da
    ferramenta que cavou;
  - meio-termo visível/escondido: **veios** com brilho de minério sempre
    soltam algo; terra comum solta em 4%, concreto (Britadeira) em 12%;
  - raridade do que sai: moeda 60%, carga de ferramenta da barra 22%,
    ampulheta 10%, bolsa 6%, pena da fênix 2%; a Ganância aumenta moedas e
    uma carta nova (Garimpeiro) aumenta a chance;
  - a tabela de raridade fica no compêndio do modo dev e **é editável pelo
    modo dev**;
  - itens bônus soltos só onde dá para chegar e voltar para a rota com as
    ferramentas da fase (conferido pelo solucionador): o usuário ficava
    preso indo atrás de item.
- **Pena da fênix com animação** quando traz alguém de volta (carta ou fim
  da fase): hoje a carta age em silêncio. **Animação, não mensagem.** A pena
  vale para qualquer fase: traz o último perdido, mesmo de uma fase
  anterior.


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
3. ~~Habilidade especial por personagem, num slot próprio com poucas
   cargas por fase, recarga que pode cair no mapa~~: feito (Teleporte,
   Quebra-concreto, Plataforma, Salto, Repetir; relíquia Dom ampliado).
   Falta o usuário jogar e dizer se as cargas (2/2/2/3/1) estão boas.
4. **Moedas e recargas espalhadas pelo mapa.** Moedas e a Recarga da
   habilidade já caem nos lugares de bônus; falta decidir se deve haver
   mais (hoje só nos lugares de bônus do gerador).
5. Carta **"passo acelerado"** (bonecos andam mais rápido).
6. ~~Compêndio para o jogador~~: feito (botão de livro na escolha de
   personagem, entradas liberadas ao descobrir).
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
