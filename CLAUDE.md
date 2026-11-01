# Lemmings-copy — Convenções do Projeto (Godot 4 / GDScript)

Clone funcional de Lemmings (1991, DMA Design) em Godot 4. Fase 1: reproduzir a
mecânica original o mais fielmente possível, sem preocupação com identidade
visual própria. Arte e tema evoluem depois que o core gameplay estiver
funcionando.

Todo o código (variáveis, funções, classes, nós, cenas, arquivos, comentários)
deve ser escrito em **inglês**.

## Convenções de Nomenclatura (GDScript Style Guide + Clean Code)

| Elemento                          | Convenção                                   | Exemplo                                      |
|------------------------------------|----------------------------------------------|-----------------------------------------------|
| Classes / `class_name`             | PascalCase                                    | `LemmingController`, `LevelManager`           |
| Nomes de arquivo de script         | snake_case                                    | `lemming_controller.gd`, `level_manager.gd`   |
| Nomes de cena (`.tscn`)            | snake_case                                    | `lemming.tscn`, `level_01.tscn`               |
| Funções / métodos                  | snake_case                                    | `func spawn_lemming()`, `func assign_skill()` |
| Variáveis / parâmetros             | snake_case                                    | `var fall_height`, `var spawn_rate`           |
| Constantes                         | UPPER_SNAKE_CASE                              | `const MAX_FALL_HEIGHT = 60`                  |
| Sinais (signals)                   | snake_case, tempo passado                     | `signal lemming_died`, `signal level_completed` |
| Enums                               | PascalCase (tipo) + UPPER_SNAKE_CASE (valores) | `enum SkillType { DIGGER, BUILDER, BLOCKER }` |
| Nós na árvore de cena              | PascalCase, descritivo                        | `AnimatedSprite2D`, `CollisionShape2D`, `SpawnPoint` |
| Autoloads / Singletons             | PascalCase                                    | `GameManager`, `AudioManager`, `SkillManager` |

## Princípios de Clean Code

- Funções pequenas, uma responsabilidade por função (evitar funções gigantes fazendo tudo).
- Nomes descritivos, sem abreviações obscuras (`spawn_interval`, não `sp_int`).
- Evitar números mágicos — usar `const` nomeadas (`const WALK_SPEED = 20.0`).
- Composição sobre herança profunda — preferir componentes (ex: `HealthComponent`, `MovementComponent`) quando fizer sentido.
- Separação de responsabilidades: lógica de jogo separada de UI e de input.
- Sinais em vez de referências diretas entre nós desacoplados (ex: `Lemming` emite `died`, `LevelManager` escuta — em vez de `Lemming` chamar `LevelManager` diretamente).
- Comentar o "porquê", não o "o quê" — o código já diz o que faz.
- Evitar duplicação (DRY) — extrair lógica repetida em funções utilitárias ou classes base.
- Fail fast / validar pré-condições no início das funções (`assert`, early return).

## Arquitetura de Pastas

```
res://
├── assets/
│   ├── sprites/
│   │   ├── characters/
│   │   ├── terrain/
│   │   ├── ui/
│   │   └── vfx/
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   └── fonts/
├── scenes/
│   ├── main/
│   ├── levels/
│   ├── characters/
│   ├── ui/
│   └── vfx/
├── scripts/
│   ├── autoload/
│   ├── characters/
│   ├── skills/
│   ├── level/
│   ├── ui/
│   └── utils/
├── resources/
│   └── levels/
└── tests/
```

- `assets/` guarda mídia bruta (arte, áudio, fontes) — nunca lógica.
- `scenes/` guarda composição visual (`.tscn`), organizada por domínio.
- `scripts/` espelha `scenes/`, isolando a lógica (facilita localizar o script de qualquer cena).
- `resources/` guarda dados configuráveis via `Resource` customizado (ex: dados de nível, estatísticas), permitindo criar/editar níveis sem tocar em código.
- `autoload/` centraliza managers globais (Singletons), acessíveis via Autoload do Godot.

Crie pastas/scripts conforme as features forem implementadas — não scaffold
arquivos vazios especulativamente.

## Sprites Placeholder

Os sprites atuais do personagem jogável (`sprite_wizard_0.png`,
`sprite_wizard_1.png`) ficam em
`res://assets/sprites/characters/wizard/` e servem apenas como placeholder —
serão substituídos pelos sprites reais do lemming futuramente. O
`AnimatedSprite2D` de `lemming.tscn` referencia um `SpriteFrames` chamado
`wizard_placeholder`, permitindo trocar os sprites sem alterar código.

## Documentação Relacionada

Mecânicas de jogo, fases e dificuldade ficam em `docs/game_design.md`
(mudam com mais frequência e não precisam ser recarregadas em toda sessão).
