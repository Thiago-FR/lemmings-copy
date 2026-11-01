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

- Os geradores ficam em `tools/` e rodam pelo próprio Godot, sem nenhuma
  dependência externa — hoje é o `build_terrain_tileset.gd`.
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
