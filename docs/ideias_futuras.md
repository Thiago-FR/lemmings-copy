# Ideias Futuras — para analisar depois

Anotado em 1º de novembro de 2026. **Nada aqui é para implementar agora.**
São ideias para discutir e decidir mais tarde. O que está pronto fica em
[estado_atual.md](estado_atual.md).

## 1. Escada vertical: só começar ao achar uma parede ficou estranho

Hoje o boneco guarda a escada quando recebe a ferramenta e só monta ao
encostar numa parede (ver "Escada vertical" em `estado_atual.md`). Isso foi
feito porque o boneco vira no instante em que toca a parede, então não há
momento para clicar nele parado ali.

Na prática, ficou estranho: o jogador dá a ferramenta e nada acontece até o
boneco chegar numa parede. Melhorar no futuro. Pontos para pensar:

- Começar a montar na hora do clique, mesmo longe da parede?
- Algum sinal visual de que ele está carregando a escada (ver ideia 2)?
- O que a escada faz no meio do chão, sem parede para encostar?

## 2. Um boneco, uma ferramenta, visível no sprite

- Cada boneco pode carregar **apenas uma ferramenta**.
- A ferramenta aparece no sprite: com a pá, ele anda com a pá nas costas;
  com a escada, anda com a escada.
- Ele usa a ferramenta assim que a recebe, como é hoje.
- Clicando nele de novo, **reativa a ferramenta que já carrega**, sem gastar
  outra do painel.

Dúvida em aberto: **isso vira parte de um modo de jogo?**

| Modo | Como funcionaria |
|---|---|
| Fácil | O boneco fica com a ferramenta e pode ser reativado com um clique. |
| Difícil | Sem esse sistema: a ferramenta só age quando é entregue, e cada uso gasta uma do painel (como no Lemmings original). |

Relaciona com a ideia 1: carregar a ferramenta visível no sprite resolveria
o "não dá para saber que ele está com a escada".

## 3. Virar um roguelike (algo na linha de Megabonk)

Ideia inicial, sem formato definido. Só para explorar depois. Perguntas para
quando for discutir:

- O que é uma "run"? Uma sequência de fases geradas aleatoriamente?
- O que o jogador escolhe entre as fases (ferramentas novas, melhorias,
  mais bonecos)?
- O que se perde ao falhar, e o que fica de uma run para a outra?
- Como isso convive com as fases fixas de teste por ferramenta?
