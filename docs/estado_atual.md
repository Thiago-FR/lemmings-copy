# Estado Atual — 1º de novembro de 2026

Registro de onde o projeto está, o que foi decidido e por quê. Convenções de
código em [CLAUDE.md](../CLAUDE.md), mecânicas em [game_design.md](game_design.md),
geração de imagens em [art_pipeline.md](art_pipeline.md).

O projeto estava parado desde 1º de agosto de 2026 porque as habilidades não
funcionavam de forma confiável. Esta sessão achou a causa e fechou a primeira.

## O que está pronto

| Item | Estado |
|---|---|
| Escavador vertical (`SkillDigger`) | ✅ fechado, com teste automático |
| Geometria corpo × grade | ✅ regra definida e verificada em tempo de execução |
| Morte visível | ✅ fade vermelho de 0,35s |
| Instruções da fase na tela | ✅ |
| Interface em português | ✅ |
| Animação de escavar (frente) | ✅ gerada a partir da arte existente |
| Demais 7 habilidades | ⬜ pendentes |

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
- **Posicione o lemming antes de inseri-lo na cena.** Ele começa a contar
  distância de queda de onde nasce; inserir na origem e mover depois conta
  como uma queda enorme e mata na aterrissagem.

## Como rodar

| | |
|---|---|
| Jogar | clique duplo em `play.bat` |
| Rodar os testes | clique duplo em `run_tests.bat` |
| Um teste só | `godot --headless res://tests/test_skill_digger.tscn` |
| Diagnóstico de queda | `godot --headless res://tests/diagnose_falling_through.tscn` |
| Regerar o terreno | `godot --headless --script res://tools/build_terrain_tileset.gd` |
| Regerar as fases | `godot --headless --script res://tools/build_test_levels.gd` |
| Regerar a animação de escavar | `python tools/build_dig_frames.py` |

O Godot está em `C:\Users\Thiago\Desktop\CriarJogos\Godot_v4.6-stable_win64.exe`
e não está no PATH; os `.bat` já apontam para ele.

## Próximo passo

Escavador horizontal (`SkillBasher`), seguindo o protocolo da seção 10 de
[game_design.md](game_design.md): corrigir, escrever
`tests/test_skill_basher`, cobrir os dois alinhamentos de grade, verificar
que o lemming **chega** do outro lado e não só que se moveu, e só então
passar para o Construtor.

Ao chegar no Construtor, lembrar que as fases 3 e 4 foram montadas assumindo
degrau de 8px e hoje o degrau é de 32px — a geometria delas precisa ser
refeita em `tools/build_test_levels.gd`.

## Pendências de arte

- A animação de escavar está pronta, mas o **tronco ficou mais liso e escuro**
  que as demais, porque tirar a mochila deixou uma área vazia. Dá para
  acrescentar uma dobra de manto usando o sombreado do quadro de andar.
- Falta decidir se a vista **de costas que já existe** (quadros de escalada)
  serve para a escada vertical ou se é preciso uma animação nova.
