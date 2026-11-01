# Estado Atual — 1º de novembro de 2026

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
| Garras, Escudo, Dinamite, TNT, Britadeira, Picareta, Paraquedas | ✅ cada uma com fase e testes (ver abaixo) |
| Terra e concreto | ✅ dois materiais de terreno (ver "Terreno: terra e concreto") |
| Pedrinhas e explosão | ✅ desenhadas em código (`DebrisBurst`, `ExplosionEffect`) |
| Botões Pausar/Continuar, Reiniciar, Menu | ✅ em toda fase (`GameControlsController`, no HUD) |
| Menu com rolagem | ✅ Tutorial, Modo livre e uma fase por ferramenta |
| Modo livre (editor) | ✅ pintar cenário e testar (ver "Modo livre") |
| Animação de paraquedas | ✅ `float`, no estado FLOATING |

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
| Regerar o terreno | `godot --headless --script res://tools/build_terrain_tileset.gd` |
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
| `blocker` | Escudo |
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
| Escudo | "Escudo" (fase 10) | `test_tool_blocker` | `test_level_blocker` |
| Dinamite | "Dinamite" (fase 11) | `test_tool_dynamite` | `test_level_dynamite` |
| TNT | "TNT" (fase 14) | `test_tool_tnt` | `test_level_tnt` |
| Britadeira | "Britadeira" (fase 12) | `test_tool_basher` | `test_level_basher` |
| Picareta | "Picareta" (fase 13) | `test_tool_miner` | `test_level_miner` |

Os testes novos usam bases comuns: `tests/tool_scenario_test.gd` (monta
terreno, cria bonecos, roda cenários) e `tests/level_playthrough_test.gd`
(carrega a fase pelo `GameManager` e entrega a ferramenta pelo
`SkillManager`, como um clique).

### Paraquedas, Garras, Escudo, Britadeira e Picareta

- **Garras (climber) e Escudo (blocker)** já funcionavam; só ganharam teste e fase.
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
- Fase do Escudo: quem recebe o Escudo nunca sai, então a fase só termina
  quando o tempo acaba (60 s nessa fase).
- A Britadeira ainda avança um bloco inteiro por golpe e não tem animação
  própria (anotado em `ideias_futuras.md`).

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

- Duas linhas de blocos no atlas: linha 0 terra, linha 1 concreto (cinza
  com pintinhas), geradas por `tools/build_terrain_tileset.gd`.
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

## Próximo passo

A definir com o usuário. Pendências conhecidas: animação de colocar escada
(as duas escadas usam animações provisórias); redefinir o Escudo; e as
ideias em
[ideias_futuras.md](ideias_futuras.md).

## Pendências de arte

- A pá é desenhada por código na mesma grade de ~7 px da arte do mago
  (`tools/wizard_art.py`). Na escala do jogo as mãos ficam com ~1 px.
- A animação de escavar está pronta, mas o **tronco ficou mais liso e escuro**
  que as demais, porque tirar a mochila deixou uma área vazia. Dá para
  acrescentar uma dobra de manto usando o sombreado do quadro de andar.
- Falta decidir se a vista **de costas que já existe** (quadros de escalada)
  serve para a escada vertical ou se é preciso uma animação nova.
