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

Para o personagem (12×28), ícones pequenos e blocos de terreno sólidos.

- Os geradores ficam em `tools/` e rodam pelo próprio Godot, sem nenhuma
  dependência externa: `build_terrain_tileset.gd` (bloco de terreno) e
  `build_lemming_placeholder.gd` (quadros do personagem).
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

Arte entra **depois** do gameplay, nunca antes. Enquanto as habilidades
estão sendo validadas, o lemming é um retângulo sólido do tamanho exato da
caixa de colisão — ver a seção de validação em [game_design.md](game_design.md).
Sprite que não bate com a colisão foi justamente o que impediu de enxergar
os bugs na primeira tentativa do projeto.
