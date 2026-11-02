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

| Modo    | Como funcionaria                                                                                                     |
| ------- | -------------------------------------------------------------------------------------------------------------------- |
| Fácil   | O boneco fica com a ferramenta e pode ser reativado com um clique.                                                   |
| Difícil | Sem esse sistema: a ferramenta só age quando é entregue, e cada uso gasta uma do painel (como no Lemmings original). |

Relaciona com a ideia 1: carregar a ferramenta visível no sprite resolveria
o "não dá para saber que ele está com a escada".

Confirmado pelo usuário em 1º de novembro de 2026: é isso que ele quer
dizer com "clicar e voltar a habilitar" (clicar de novo no boneco reusa a
ferramenta que ele carrega). **Não aplicar ainda**: depende de como o jogo
vai ficar se virar roguelike (ideia 3).

## 3. Modo roguelike: proposta

Proposta discutida em 1º de novembro de 2026. Nada decidido em definitivo;
marcar aqui o que entra e o que sai.

### Organização: o jogo atual é o núcleo, cada modo é uma pasta

Ideia do usuário: tudo o que foi feito até agora (bonecos, ferramentas,
terreno, fases, editor, áudio) é o **esqueleto/núcleo**. Cada modo de jogo
fica numa pasta própria que só **usa** o núcleo, com um botão no menu para
jogá-lo. Outra ideia de modo no futuro = outra pasta, mesmo núcleo.

- `res://modes/roguelike/` autocontida: `scenes/`, `scripts/`,
  `resources/`, `tests/` dentro. Tudo de um modo junto; apagar a pasta
  remove o modo.
- **Regra de ouro: o núcleo nunca conhece os modos.** Um modo pode chamar
  `LevelManager`, `SkillManager`, `TerrainDestructible`, as ferramentas
  etc.; o núcleo não importa nada de `modes/`. Se um modo precisar de algo
  novo do núcleo, o núcleo ganha um gancho genérico (sinal, parâmetro), não
  um `if roguelike`.
- O menu lista os modos; o modo é só uma cena que o botão abre (como o
  editor).
- Os testes do núcleo continuam valendo para todos os modos; cada modo tem
  os seus em `modes/<modo>/tests/`.

### O ciclo de uma run

- Você guia **uma tropa** por uma sequência de fases geradas na hora; os
  bonecos **salvos numa fase são os que entram na próxima**. Perder boneco
  é perder vida. A run acaba quando a tropa zera ou no fim.
- Por exemplo 10 a 15 fases em 3 "andares" (terra, minas, fortaleza de
  concreto), com um desafio maior no fim de cada andar.
- Começa com ~20 bonecos e um kit pequeno de ferramentas.
- começa com apenas 1 boneco, vai liberando o boneco conforme passa de fase.
- cada boneco tem suas habilidades especiais.

### Escolhas entre as fases

- Mapa de caminhos: **fase normal**, **elite** (mais difícil, recompensa
  melhor), **loja** (paga com bonecos salvos ou moedas), **evento**
  (escolha curta: "arrisque 3 bonecos por 2 TNT"), **descanso** (recupera
  bonecos ou cargas).
- Fim de fase: **escolher 1 de 3 recompensas**: cargas ("+3 Pá"),
  ferramenta nova para o kit, ou melhoria (relíquia): Pá mais rápida, Ponte
  de 16 peças, Bloco de concreto, paraquedas automático no primeiro boneco,
  Dinamite com pavio de 2s... Melhorias que combinam criam "builds"
  (escavador, construtor, explosivos).

### Barra de itens no roguelike

Pedido do usuário: a barra de ferramentas (já com ícones e número de
cargas, ver `estado_atual.md`) começa vazia e **vai ganhando slots conforme
você pega itens**, com um **limite de slots** (decidir quantos, e o que
acontece ao pegar um item com a barra cheia: trocar, descartar, recusar).

### Fases procedurais

- Montadas a partir de **pedaços prontos** feitos no editor (um buraco, uma
  parede, uma sala embaixo, um platô) que o gerador encaixa; mais
  controlável que ruído puro. Precisa de salvar/carregar no editor.
- O gerador garante que **dá para resolver com o kit atual**; pode até
  conferir sozinho jogando a fase, como os testes automáticos já fazem.
- Dificuldade sobe por andar (mais concreto, buracos maiores, menos tempo).
- **Modificadores** vistos antes de entrar: chão frágil, tempo curto,
  bonecos mais rápidos, escuridão.
- Chão, parede e interior com arte diferente (pela vizinhança), para o
  terreno gerado ser legível de relance.

### Visão do usuário para as fases (2 de novembro de 2026)

- **Do tamanho da tela inteira**, sem precisar rolar a câmera (o usuário
  não tem certeza de que mover a tela com o mouse é uma boa experiência).
  Em Full HD isso são 60 x 34 blocos.
- **Não lineares, como um labirinto**, no estilo de Ori e Silksong (e não
  "andar para a direita" como Mario): vários caminhos e andares, a saída
  pode estar em qualquer lugar, becos sem saída, atalhos que uma
  ferramenta abre.
- Para gerar isso, uma ideia: dividir a tela numa grade de salas (por
  exemplo 5 x 3 salas de 12 x 11 blocos), gerar um caminho entre a sala da
  entrada e a da saída (como um labirinto), e preencher cada sala com um
  pedaço pronto que liga as portas certas; ferramentas abrem as passagens
  entre salas (cavar para baixo, ponte, escada). O gerador confere que dá
  para chegar à saída com o kit da run.

### Para que serve a quantidade de bonecos

Hoje os bonecos são as **vidas** da run: quem é salvo segue, e sem
nenhum a run acaba. O usuário perguntou qual o motivo de ter essa
quantidade e quer **algum bônus pela quantidade**. Ideias:

- Recompensa pelo número de salvos na fase: salvou todos, escolhe entre
  4 cartas em vez de 3 (ou uma carta rara).
- Moedas por boneco salvo, para uma loja entre as fases.
- Pontuação final da run multiplicada pelos sobreviventes.
- Mais bonecos permitem arriscar: um boneco pode "se sacrificar" com uma
  ferramenta (bomba) para abrir caminho aos outros.

### Progressão entre runs

- Desbloquear **variedade**, não força: ferramentas novas no conjunto que
  pode aparecer, personagens iniciais com kits diferentes (Mineiro começa
  com Picareta; Engenheiro com pontes maiores).
- Níveis de dificuldade da run (estilo "Ascensão"), cada um uma regra a
  mais; substitui a dúvida de modo fácil/difícil da ideia 2.

### Ligação com a ideia 2

"Um boneco, uma ferramenta, reusar com clique" encaixa: ferramentas viram
**equipamento** de bonecos específicos, que você protege; perder o boneco é
perder a ferramenta.
no caso do rougue reusar pode ser habilidade de algum boneco especifico

### Cuidados

- Fases curtas (1 a 3 minutos) para uma run de 30 a 40.
- Frustração de perder a run num clique errado: desfazer limitado, ou
  recuperar alguns bonecos por fase. reuperar pode ser algum item que recupera.

### Primeiro passo sugerido

Protótipo mínimo, sem arte nova: run de **5 fases** montadas de 4 a 6
pedaços feitos no editor, **tropa que passa de fase em fase**, e **escolher
1 de 3 recompensas** no fim de cada fase. Serve para sentir se a graça
aparece antes de investir em loja, eventos e progressão.

## 4. Bomba, terrenos e pedrinhas: feito

Dinamite e TNT, piso quebrando, explosão, terra e concreto e as pedrinhas
foram feitos em 1º de novembro de 2026 (ver `estado_atual.md`). Ainda em
aberto: existir um terreno que **nada** quebra.

## 7. Escudo: resolvido com o Bloco

O Escudo (boneco parado para sempre) prendia todo mundo. Foi trocado pela
ferramenta **Bloco**: o boneco põe um bloco de terra na frente e vira (ver
`estado_atual.md`). Em aberto para o futuro: bloco de concreto, escolher o
lugar, usar no ar.

## 8. Animações que faltam (lista)

- Montar a Escada diagonal, a Escada vertical e a Ponte (hoje usam
  animações provisórias).

## 9. Roguelike: cartas que caem durante a fase

Anotada em 2 de novembro de 2026, para analisar. Inspiração: em Megabonk as
cartas/melhorias aparecem durante a partida, não só no fim. Aqui seria uma
carta (ou um baú) solta no mapa, que o boneco pega no caminho e abre a escolha
na hora. Em aberto: pausa o jogo ao escolher? Substitui ou soma com a carta
do fim da fase?
