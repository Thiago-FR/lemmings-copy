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
| Instruções da fase na tela | ✅ |
| Interface em português | ✅ inclusive nomes das fases e das habilidades |
| Animação de escavar (frente) | ✅ com pá, mais lenta (20 px/s) |
| Habilidades, entrada e saída desacopladas | ✅ ver "Arquitetura" abaixo |
| Demais ferramentas | ⬜ pendentes (escada horizontal, ...) |

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
boneco, e o botão mostra o nome da ferramenta, não de uma profissão. Pá em
vez de Escavador, Escada diagonal em vez de Construtor. O código continua
chamando de `skill` (`SkillBase`, `SkillManager`); só o `display_name` muda.

Ferramentas previstas: Pá, Escada vertical, Escada diagonal (o `SkillBuilder`
de hoje), Ponte e Escada horizontal.

**Uma ferramenta por vez, cada uma com sua fase exclusiva no menu**, onde
ela é a única disponível e o único jeito de chegar à saída. A fase é criada
em `tools/build_test_levels.gd` e tem um teste que a joga do começo ao fim
(`tests/test_level_<ferramenta>`). A fase "Livre" não recebe ferramenta nova.

| Ferramenta | Fase exclusiva | Teste da ferramenta | Teste da fase |
|---|---|---|---|
| Pá | "A pá" (fase 2) | `test_skill_digger` | — |
| Escada diagonal | "Escada diagonal" (fase 3) | `test_tool_ladder_diagonal` | `test_level_ladder_diagonal` |
| Escada vertical | "Escada vertical" (fase 6) | `test_tool_ladder_vertical` | `test_level_ladder_vertical` |
| Ponte | "Ponte" (fase 7) | `test_tool_bridge` | `test_level_bridge` |

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
  (`TerrainDestructible.place_brick`), com colisão, contada por todas as
  consultas e removida pelas mesmas funções que destroem terreno.
- Os outros bonecos sobem a escada andando, como qualquer degrau baixo, sem
  quicar (o teste mede o sprite do segundo boneco: nunca desce e nunca sobe
  mais de 2px num quadro).
- Altura e largura do degrau são parâmetros: `step_height_fraction_of_tile`
  (0,25 = 8px; 0,125 = 4px) e `step_width_fraction_of_tile` (1,0 = um
  bloco).
- Quem chega numa escada **ainda sendo montada** pode sair pela ponta
  inacabada e cair, como no Lemmings original. Quem chegou na plataforma
  antes da escada fica **preso embaixo dela** até o tempo da fase acabar.
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
- Se aparece uma parede antes da beira, **o boneco recusa a ponte** e a
  carga não é gasta (não há o que atravessar).
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
- Obstáculo na altura da cabeça agora conta como parede. Antes um boneco
  andando por baixo da escada diagonal empurrava os tijolos para sempre.

## Próximo passo

A definir com o usuário. Pendências conhecidas: animação de colocar escada
(as duas escadas usam animações provisórias) e as ideias em
[ideias_futuras.md](ideias_futuras.md).

## Pendências de arte

- A pá é desenhada por código na mesma grade de ~7 px da arte do mago
  (`tools/wizard_art.py`). Na escala do jogo as mãos ficam com ~1 px.
- A animação de escavar está pronta, mas o **tronco ficou mais liso e escuro**
  que as demais, porque tirar a mochila deixou uma área vazia. Dá para
  acrescentar uma dobra de manto usando o sombreado do quadro de andar.
- Falta decidir se a vista **de costas que já existe** (quadros de escalada)
  serve para a escada vertical ou se é preciso uma animação nova.
