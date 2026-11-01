# Game Design — Lemmings-copy

Convenções de código e arquitetura de pastas estão em [CLAUDE.md](../CLAUDE.md).
Este documento cobre mecânicas, fases, dificuldade e roadmap — muda com mais
frequência que as convenções, por isso fica separado.

## 5. O Jogo: Lemmings — Visão Geral das Mecânicas

### 5.1 Conceito central

Lemmings caem de um ponto de entrada (spawn) e andam automaticamente em uma
direção, sem controle direto do jogador. O jogador não controla o personagem
diretamente — ele atribui habilidades a lemmings individuais clicando neles,
para guiá-los com segurança até a saída (exit), evitando obstáculos, quedas
fatais e armadilhas.

### 5.2 Loop de jogo (game loop)

- Lemmings nascem periodicamente em um `SpawnPoint`, a uma taxa (`spawn_rate`) definida por nível.
- Cada lemming anda automaticamente para frente até bater em uma parede (inverte direção) ou cair em um buraco/precipício.
- O jogador seleciona uma habilidade no `SkillPanel` e clica em um lemming para atribuí-la.
- O objetivo do nível é levar uma porcentagem mínima de lemmings (`required_percentage`) até a saída (`ExitPoint`) antes do tempo acabar ou de todos os lemmings nascidos serem perdidos.

### 5.3 Estado e movimento do Lemming (máquina de estados)

Sugestão de `enum LemmingState`:

- `FALLING` — caindo (se altura de queda > `MAX_SAFE_FALL_HEIGHT`, morre ao aterrissar, exceto se tiver a skill Floater/Bomber ativa).
- `WALKING` — andando para frente na direção atual.
- `DIGGING` — cavando verticalmente para baixo.
- `BUILDING` — construindo uma ponte de blocos na direção do movimento.
- `BLOCKING` — parado, funcionando como obstáculo que faz outros lemmings virarem.
- `BASHING` — escavando horizontalmente através de terreno.
- `MINING` — escavando na diagonal (para baixo e na direção do movimento).
- `CLIMBING` — escalando uma parede vertical (requer skill Climber).
- `FLOATING` — descendo com um "paraquedas" (requer skill Floater), sem sofrer dano de queda.
- `EXPLODING` — contagem regressiva de autodestruição (skill Bomber), destrói terreno ao redor.
- `DEAD` — removido do jogo (queda fatal, afogamento, explosão sem propósito, etc.).
- `EXITED` — chegou à saída com sucesso.

### 5.4 Habilidades clássicas (skills)

| Skill    | Efeito |
|----------|--------|
| Climber  | Passa a escalar paredes verticais em vez de virar ao encontrá-las. |
| Floater  | Ganha um "guarda-chuva", sobrevive a qualquer queda. |
| Blocker  | Para no lugar e vira barreira; outros lemmings que o encontram invertem a direção. |
| Builder  | Constrói uma escada/ponte de blocos na direção do movimento (número limitado de degraus). |
| Basher   | Escava horizontalmente através de terreno destrutível. |
| Miner    | No original, escava na diagonal. Aqui é a Picareta: a Pá na horizontal (túnel reto de um bloco de altura). |
| Digger   | Escava um túnel verticalmente para baixo. |
| Bomber   | Detona o lemming após uma contagem (5s), destruindo o terreno ao redor num raio. Também serve como forma de eliminar lemmings excedentes. |

Cada skill deve ser implementada como um script próprio herdando de
`skill_base.gd`, seguindo o padrão Strategy: o `LemmingController` delega a
lógica de comportamento à skill ativa, sem precisar de `if`/`elif` gigantes.

### 5.5 Terreno destrutível

O terreno pode ser representado como:

- Uma imagem bitmap (heightmap ou máscara de colisão) que é editada em tempo
  de execução conforme os lemmings cavam — abordagem clássica, fiel ao original.
- Alternativa mais simples para o Godot: usar um `TileMap` com tiles
  destrutíveis (célula a célula), mais fácil de implementar mas com
  granularidade menor.

**Recomendação para o MVP**: começar com `TileMap` (mais rápido de
implementar e debugar no Godot), e migrar para bitmap/`Image` collision mask
depois, se quiser fidelidade total ao visual orgânico do Lemmings original.

### 5.6 Condições de vitória/derrota

- **Vitória**: porcentagem de lemmings salvos ≥ `required_percentage` do
  nível quando o tempo acaba ou todos os lemmings nascidos já saíram/morreram.
- **Derrota**: porcentagem de lemmings salvos < `required_percentage` ao
  final do tempo do nível.

## 6. Fases (Níveis)

Sugestão de estrutura de progressão, inspirada no jogo original:

1. **Fase tutorial** — só andar e cair; sem obstáculos, ensina o objetivo básico (chegar à saída).
2. **Fases introdutórias de skills** — cada fase nova introduz UMA skill isoladamente (ex: fase 2 introduz só o Digger, fase 3 só o Builder), para o jogador aprender uma mecânica de cada vez.
3. **Fases de combinação** — exigem combinar 2-3 skills para resolver o puzzle.
4. **Fases de pressão de tempo** — tempo curto e spawn rate alto, forçando decisões rápidas.
5. **Fases complexas (endgame)** — múltiplos caminhos, armadilhas, exigem planejamento e uso preciso de todas as skills.

Cada nível deve ser definido como um `Resource` customizado (`LevelData`), contendo:

```gdscript
class_name LevelData
extends Resource

@export var level_name: String
@export var spawn_rate: float          # segundos entre spawns
@export var total_lemmings: int        # total que vai nascer no nível
@export var required_percentage: float # % mínima para vencer (0.0 a 1.0)
@export var time_limit_seconds: int
@export var available_skills: Array[String]  # quais skills o jogador tem disponíveis
@export var skill_counts: Dictionary    # quantidade de cada skill (ex: {"digger": 5})
@export var scene_path: String          # cena do terreno/nível
```

Isso permite criar novos níveis sem editar código, apenas criando novos
arquivos `.tres` no editor Godot.

## 7. Níveis de Dificuldade

Seguindo a nomenclatura clássica do Lemmings, 4 categorias de dificuldade,
cada uma com um conjunto de fases:

| Dificuldade            | Características |
|--------------------------|------------------|
| Fun (Fácil)             | Poucos obstáculos, skills ilimitadas ou quase, tempo generoso, `required_percentage` baixo (~50%). |
| Tricky (Médio)          | Introduz combinações de skills, número limitado de cada skill, tempo moderado. |
| Taxing (Difícil)        | Layouts mais complexos, spawn rate mais alto, `required_percentage` mais exigente (~80-90%). |
| Mayhem (Muito Difícil)  | Skills muito limitadas, timing apertado, terreno hostil, `required_percentage` de 100% em alguns casos. |

Cada dificuldade pode ser uma subpasta dentro de `resources/levels/` (ex:
`resources/levels/fun/`, `resources/levels/tricky/`), carregada dinamicamente
pelo `LevelLoader` a partir de um menu de seleção.

## 8. Ordem de Implementação Sugerida (Roadmap do MVP)

1. Criar o projeto Godot + estrutura de pastas. ✅
2. Configurar autoloads (`GameManager`, `AudioManager`, `LevelLoader`).
3. Implementar o Lemming com estados `FALLING` e `WALKING` apenas (sem skills ainda), incluindo detecção de colisão com parede/chão e queda fatal.
4. Implementar o `SpawnPoint` e `ExitPoint`, com contagem de lemmings salvos/perdidos.
5. Implementar o HUD básico (contador de lemmings, tempo restante, porcentagem necessária).
6. Implementar o sistema de seleção de skill (`SkillPanel`) + clique no lemming para atribuir.
7. Implementar as skills uma a uma, começando pelas mais simples: Blocker → Digger → Builder → Basher → Miner → Climber → Floater → Bomber.
8. Implementar terreno destrutível via `TileMap`.
9. Criar 3-4 níveis de teste (tutorial + uma fase por skill nova) usando `LevelData`.
10. Polir: sons, animações de transição de estado, tela de vitória/derrota.

## 9. Geometria do Corpo e da Grade (invariante)

Esta seção existe porque o descumprimento dela foi o que travou o projeto na
primeira tentativa.

As habilidades de escavar removem **tiles inteiros**, então toda abertura por
onde um lemming precisa passar é alinhada à grade e tem tamanho múltiplo do
tile. Daí o invariante: **o corpo tem que ser menor que essa abertura, com
folga dos dois lados.**

| | valor |
|---|---|
| Bloco de terreno | 32 × 32 |
| Folga mínima por lado | 2 px |
| Corpo máximo | 28 × 60 |
| Corpo atual (mago) | 26 × 30 |

A ordem de causa importa: **o personagem define a grade, não o contrário.**
O mago tem 26 de largura, então o bloco precisa ter no mínimo 30. Ficou 32.
Encolher o personagem para caber numa grade de 16 foi tentado e descartado —
o desenho fica ilegível nesse tamanho.

Dois erros separados vinham disso, e os dois produziam o mesmo sintoma
("cavou o buraco mas o lemming não passou"):

1. **Corpo mais largo que um bloco** (26 numa grade de 16) só cabia quando
   por acaso ficava entre duas colunas, e a escavação limpava as duas.
2. **Corpo com exatamente a largura do bloco** entala entre as duas paredes
   do poço e para de cair mesmo com gravidade total — não sobra espaço para
   a física separar o corpo das laterais.
3. **Escavar "as colunas que o corpo encosta"** fazia a mesma habilidade
   abrir um buraco de uma coluna quando o lemming estava alinhado e de duas
   quando estava entre colunas — buracos visivelmente diferentes para a
   mesma ação. As habilidades de escavar agora **centralizam o corpo na
   coluna antes do primeiro corte**, e o poço sai sempre com um bloco.

`LemmingController._assert_body_fits_carved_openings()` verifica isso no
nascimento de cada lemming, então quebrar a regra acusa na hora em vez de
virar uma habilidade com comportamento estranho várias etapas depois.

Consequência de aumentar o bloco: `MAX_SAFE_FALL_HEIGHT` subiu de 60 para 80,
porque um vão vertical precisa ter dois blocos (64px) para um corpo de 30 de
altura passar, e 60 mataria o lemming no menor vão legal do jogo.

## 10. Protocolo de Validação das Habilidades

Uma habilidade por vez. Só passa para a próxima quando a atual estiver
fechada por um teste automático que roda sem abrir a janela do jogo.

Para cada habilidade:

1. Corrigir a habilidade.
2. Escrever `tests/test_skill_<nome>.gd` + `.tscn`, cobrindo **no mínimo**
   dois casos de alinhamento: corpo dentro de uma coluna/linha da grade, e
   corpo entre duas. Era exatamente essa diferença que fazia o bug parecer
   intermitente.
3. O teste tem que verificar **chegada**, não só movimento — "desceu 64px"
   não prova nada se o lemming terminou flutuando. Verifique que ele
   aterrissou em chão sólido e voltou para `WALKING`.
4. Rodar: `godot --headless res://tests/test_skill_<nome>.tscn`
   (sai com código 0 se passou, 1 se falhou).
5. Só então passar para a próxima.

Ordem (geometria mais simples primeiro, que difere da ordem da seção 8):

| Ordem | Habilidade | Estado |
|---|---|---|
| 1 | Digger (vertical) — botão "Pá" | ✅ fechado |
| 1b | Escada vertical (nova) | ✅ fechado |
| 2 | Basher (horizontal) — botão "Britadeira" | ✅ fechado (fase 12) |
| 3 | Builder — botão "Escada diagonal" | ✅ refeita (degraus de 8px) |
| 4 | Miner — botão "Picareta", refeita como Pá na horizontal | ✅ fechado (fase 13) |
| 5 | Climber — botão "Garras" | ✅ fechado (fase 9) |
| 6 | Blocker — botão "Escudo" | ✅ fechado (fase 10) |
| 7 | Floater — botão "Paraquedas" | ✅ fechado (fase 8) |
| 8 | Bomber — virou Dinamite (fase 11) e TNT (fase 14): o boneco coloca a carga e se afasta | ✅ fechado |

**Builder (Escada diagonal):** voltou a ter degraus de 8px, agora como
tijolos fora da grade (ver `estado_atual.md`). A fase 3 foi refeita para
ele. A antiga fase 4 (Escalador + Escada diagonal) foi removida.
