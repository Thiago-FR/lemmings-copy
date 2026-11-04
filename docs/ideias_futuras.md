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

## 10. Sugestões para encorpar o jogo (3 de novembro de 2026)

Pedido do usuário: mais ideias de gameplay para o jogo ficar mais encorpado,
incluindo a pergunta "a maioria dos jogos tem XP; como encaixaria aqui?".
Nada decidido. Cada ideia segue as regras que o usuário já deu: animação em
vez de texto, nada de personagem recolorido, fases que desafiam.

### 10.1 XP: onde encaixa e onde não encaixa

O jogo já tem **três moedas de progresso**: moedas na run (loja), cofre entre
runs (libera personagens) e pontuação (ranking). Um XP que só "sobe nível e
dá mais força" repetiria o cofre e deixaria as fases fáceis, o que estraga o
quebra-cabeça. As três formas de XP que acrescentam algo novo:

**A. Veteranos dentro da run (recomendada para o roguelike)**
- Cada boneco ganha XP por fase em que sobrevive e por ferramenta que usa.
  Com XP suficiente sobe de patente: uma insígnia sobre a cabeça, de bronze,
  prata e ouro, que sobe com um brilho, sem texto.
- Cada patente dá um bônus pequeno, sorteado entre 2 opções (como as
  cartas): aguenta mais queda, cava mais rápido, uma carga grátis por fase...
- **Por que encaixa:** os bonecos já são as vidas da run, e o veterano vira
  alguém que você quer proteger (como em XCOM). Perder um ouro dói mais que
  perder um novato. Dá peso a cada clique sem deixar a fase mais fácil para
  todos.
- Combina com a Pena da fênix (traz o veterano de volta com a patente) e com
  o Sacrificar (sacrificar um veterano vale mais moedas?).

**B. Maestria de personagem (entre runs)**
- XP por personagem, ganho jogando runs com ele. Cada nível libera
  **variedade**, não força: uma segunda habilidade para escolher no começo
  da run, uma relíquia inicial, um acessório no sprite (desenhado, não
  recolor), uma carta exclusiva que passa a aparecer.
- Resolve "por que jogar de novo com o Mago" depois de ter liberado todos.

**C. Nível de conta (Explorador), alimentado por tudo**
- Ganha XP com salvos, fases vencidas, estrelas, descobertas do compêndio.
- Cada nível abre algo do jogo: um ambiente novo na run, um modificador de
  dificuldade (Ascensão, ideia 3), um tipo de carta novo no sorteio.
- Risco: competir com o cofre. Se entrar, o cofre continua comprando
  personagens e o nível só abre conteúdo.

Sugestão de ordem: A primeiro (mexe só no roguelike e usa o que existe),
depois B. C só se faltar motivo para jogar a campanha e o roguelike juntos.

### 10.2 Campanha: motivo para jogar de novo

- **3 estrelas por fase**: vencer; salvar todos; sobrar ferramenta ou tempo.
  As estrelas aparecem na tela de Fases, e o total abre algo (a última
  paisagem, um personagem para o roguelike, fases bônus).
- **Desafios por fase** depois de vencer: "sem a Ponte", "só 3 cliques",
  "contra o relógio". Um ícone por desafio na tela da fase.
- **Fases bônus feitas à mão**: as 15 antigas (commit `a8d72f4`) eram
  quebra-cabeças pensados. Podem voltar como uma trilha extra de "Desafios",
  liberada pelas estrelas, já que a campanha nova é gerada.

### 10.3 Cada ambiente com uma mecânica própria

Hoje os 10 ambientes mudam o visual e a forma do relevo, mas o boneco se
comporta igual em todos. Uma regra por ambiente dá identidade e quebra-
cabeças novos:

| Ambiente | Mecânica |
|---|---|
| Prado | (ensina, sem regra nova) |
| Floresta | troncos caídos que rolam ou pontes de cipó que caem depois de N bonecos |
| Deserto | areia movediça (afunda devagar; a Ponte passa por cima); areia que escorre num buraco cavado |
| Mina | trilhos com vagonete (leva os bonecos), lamparinas: túnel escuro sem elas |
| Caverna de Cristal | cristais que refletem a explosão (alcance maior) ou que só a Britadeira quebra |
| Geleira | gelo escorregadio: o boneco não para de deslizar até bater; gelo derrete com explosão e vira água |
| Vulcão | lava que sobe aos poucos (o relógio fica visível no mapa); rocha que esfria e vira chão |
| Cidade | portas e elevadores com botão de pressão (um boneco parado com o Bloco segura a porta) |
| Outro Planeta | gravidade baixa: quedas mais longas são seguras, pulo maior; plantas que lançam o boneco |
| Espaço | escotilhas de vácuo que puxam; esteiras; teleportes entre conveses |

Começar por uma ou duas (Geleira e Vulcão são as mais fáceis de ler) e
ensinar cada uma na 1ª fase da paisagem. O gerador e o verificador precisam
conhecer a regra.

### 10.4 Terreno e objetos novos (servem a qualquer ambiente)

- **Aço** (nada quebra): ideia 4, já pedida. Obriga a dar a volta.
- **Chão frágil**: quebra depois que N bonecos passam.
- **Água**: afoga quem cai; a Ponte passa por cima; o Paraquedas não salva.
- **Trampolim, esteira, teleporte de par**: peças do editor que o gerador
  também usa.
- **Alavanca e porta**: um boneco liga, outro passa. É quebra-cabeça de
  ordem, como a antiga fase "A Espera".
- **Armadilhas** (esmagador, fogo intermitente): ritmo, esperar a hora
  certa com Bloco.

### 10.5 Roguelike: mais escolhas na run

- **Mapa de caminhos** (já na ideia 3): fase normal, elite (meta maior,
  carta rara), evento, descanso, loja. Hoje a run é uma fila fixa de 30.
- **Chefe de paisagem**: a 3ª fase de cada ambiente com uma regra extra
  visível antes (lava subindo, tempo pela metade, só 2 tipos de ferramenta).
- **Eventos** curtos com escolha por ícones: "arrisque 2 bonecos por uma
  relíquia", "troque a Pá por 2 Pontes".
- **Sinergias de relíquias**: duas relíquias juntas liberam um efeito
  (Lâminas afiadas + Garimpeiro = cavar solta o dobro de item).
- **Semente do dia**: todos jogam a mesma run, com ranking próprio.
- **Run mais curta**: 30 fases é muito para uma run (a ideia 3 sugeria
  30-40 minutos). Exemplo: 10 a 12 fases, uma ou duas por paisagem, com as
  paisagens sorteadas.

### 10.6 Conforto do jogador

- **Minimapa** nas fases grandes (a última é 3,6x uma tela): mostra os
  bonecos, a saída e os itens.
- **Voltar no tempo** limitado (3 vezes por fase): menos frustração com
  clique errado, sem tirar o desafio.
- **Realce do boneco sob o cursor** e de quem tem ferramenta guardada (o
  balão já existe; falta destacar quando há muitos juntos).
- **Repetição da vitória** (replay) para ver a solução de novo.

### 10.7 Conquistas e estatísticas

- Conquistas com ícone (sem texto longo): "salvou 1000", "venceu sem perder
  ninguém", "usou todas as ferramentas numa fase". Ficam no compêndio.
- Estatísticas: bonecos salvos, perdidos por causa, ferramenta mais usada.

### Recomendação de ordem

1. Mecânica por ambiente (10.3), começando por Geleira e Vulcão: é o que
   mais muda o jogo e dá vida ao gerador que já existe.
2. Estrelas e desafios na campanha (10.2).
3. Veteranos no roguelike (10.1 A) e run mais curta (10.5).
4. Minimapa e voltar no tempo (10.6).

### O que o usuário achou (3 de novembro de 2026)

- **Adorou:** mecânica por ambiente (10.3), em especial a **gravidade baixa
  no Espaço**; as ideias da campanha (10.2); terreno e objetos novos (10.4).
- **A pensar:** minimapa; quantidade de fases da run (talvez 2 por
  paisagem em vez de 3).
- **Fase-chefe:** o jogo não tem confronto, então é preciso definir o que
  seria um "chefe" (propostas em 11.5).
- **XP com patentes:** a ideia é boa, mas com 30 fases seriam precisas
  muitas patentes. "Ficar mais forte" precisa ser analisado antes. O que o
  usuário quer de verdade: **habilidades e cartas que se ganham durante o
  jogo**, como em Megabonk, onde as cartas vão aparecendo na tela enquanto
  se joga (seção 11).

## 11. Cartas e habilidades durante a run (estilo Megabonk)

Sugestões de 3 de novembro de 2026, a partir do pedido do usuário. Nada
decidido.

### 11.1 O XP vira "subir de nível na run"

Em Megabonk (e Vampire Survivors) o XP não sobe patente: enche uma barra, e
cada vez que ela enche o jogo pausa e mostra **3 cartas para escolher**. Isso
resolve "precisaria de muitas patentes": o nível da run não tem teto, e
cada nível é uma escolha.

- **Barra de XP** no HUD do roguelike. Enche com:
  - **cristais de XP** espalhados no mapa, que o boneco pega andando (como
    os itens; alguns em lugares que pedem ferramenta para chegar);
  - blocos cavados (pouco), bonecos salvos (muito), itens pegos.
- **Encheu:** o jogo pausa e sobem 3 cartas com animação; escolhe 1, o jogo
  continua. A barra seguinte pede um pouco mais.
- **A carta do fim da fase continua** (ou vira um baú de raridade maior).
- Cada carta tem **raridade** pela cor da moldura: comum, rara, épica e
  lendária. As famílias de moldura que já existem continuam.
- O nível e as cartas valem **só na run**. Entre runs fica o cofre
  (personagens).

### 11.2 Cartas para a tropa toda (passivas)

Já existem: Passo acelerado, Ampulheta, Ganância, Bolso extra, Paraquedas
reserva, Coletor, Lâminas afiadas, Ponte longa, Escada comprida, Pavio
curto, Dom ampliado. Novas:

| Carta | Efeito por nível | Por que é interessante |
|---|---|---|
| **Pés de pena** | queda segura +1 bloco | arrisca atalhos por quedas |
| **Botas de mola** | sobem degrau de 1 bloco (hoje é parede) | muda a leitura de toda fase; lendária |
| **Ímã** | pegam itens a até 1-2 blocos | menos desvio para pegar item |
| **Capacete** | o 1º boneco atingido por explosão em cada fase sobrevive | permite explosão perto da tropa |
| **Segunda chance** | o 1º que morreria de queda só fica tonto | reduz frustração de um clique errado |
| **Faro de minério** | veios e itens escondidos brilham através da terra | combina com Itens ao cavar |
| **Fila organizada** | controlar o ritmo de saída da entrada (o "release rate" do Lemmings original) | dá tempo para preparar o caminho |
| **Mão rápida** | o jogo fica em câmera lenta enquanto uma ferramenta está escolhida | ajuda nas fases cheias |
| **Pioneiro** | o 1º boneco de cada fase anda +30% e pega itens em dobro | estratégia de batedor |
| **Turma unida** | +1 moeda por boneco salvo para cada 5 salvos juntos | recompensa salvar todos |

### 11.3 Cartas que mudam uma ferramenta

Uma carta de ferramenta só aparece se a ferramenta está na barra. No nível
III vira uma **evolução**, que muda como a ferramenta funciona:

| Ferramenta | Melhoria I-II | Evolução (III) |
|---|---|---|
| Pá | cava +25% mais rápido | **Pá larga**: buraco de 2 colunas, passam dois por vez |
| Picareta | +25% | **Picareta diagonal**: cava descendo na diagonal, como no Lemmings original |
| Britadeira | túnel mais longo por carga | **Perfuratriz**: atravessa aço |
| Ponte | +3 peças | **Ponte de pedra**: explosão não derruba |
| Escada diagonal | +2 degraus | **Escada dupla**: sobe e depois desce do outro lado |
| Escada vertical | +2 peças | **Elevador**: leva quem chega até o topo na hora |
| Bloco | — | **Bloco de concreto** (a Pá não tira) ou **Bloco temporário** (some em 10 s) |
| Dinamite / TNT | pavio -0,5 s | **Detonador**: explode quando o jogador clica na carga |
| Paraquedas | — | **Asa-delta**: plana para a frente, atravessa abismos |
| Garras | — | **Garras de teto**: anda pelo teto até a próxima parede |

### 11.4 Cartas de risco (com custo)

Escolhas com troca deixam a run com a cara do jogador:
- **Pacto**: +3 cargas de cada ferramenta, mas perde 2 bonecos.
- **Pressa**: andam +30% e ganham +50% de moedas, mas o relógio tem -20%.
- **Vidro**: queda segura cai pela metade, mas toda carta seguinte é rara
  ou melhor.
- **Avareza**: tudo da loja pela metade, mas sem carta no fim da fase.
- **Herói solitário**: a fase seguinte começa só com 1 boneco; se ele
  salvar, +1 relíquia.

### 11.5 Habilidade especial e personagens

- **Evolução da habilidade especial** (uma carta lendária por personagem):
  - Mago: Teleporte em grupo (todos a até 2 blocos vão juntos);
  - Mineiro: Quebra-concreto vira túnel de 3 blocos;
  - Engenheiro: Plataforma de 6 tábuas;
  - Batedor: Salto em cadeia (salta de novo ao cair);
  - Inventor: Repetir sem limite de uma ferramenta escolhida na fase.
- **Personagens novos** (para o cofre), cada um com passivo e habilidade:
  - **Alquimista**: transforma 1 bloco de concreto em terra, ou terra em
    concreto (cria um bloqueio);
  - **Guardião**: fica parado como o Bloqueador do Lemmings original, mas um
    clique o solta (resolve o problema do Escudo antigo);
  - **Astronauta**: mochila a jato, sobe 3 blocos uma vez por carga;
    sente-se em casa no Espaço;
  - **Domador**: solta uma toupeira que cava um túnel sozinha até a
    próxima parede.

### 11.6 "Chefe" sem confronto: o perigo da paisagem

O jogo não tem combate, então o chefe pode ser **uma ameaça da paisagem**
que obriga a pensar rápido, na 2ª ou 3ª fase de cada ambiente:

| Ambiente | Perigo | Como vencer |
|---|---|---|
| Floresta | incêndio que se espalha pelas árvores | cavar uma vala ou um túnel corta-fogo |
| Deserto | verme gigante que atravessa a fase em intervalos, comendo um túnel | ler o ritmo, esperar com Bloco, usar os túneis dele |
| Mina | **Golem**: anda como um boneco gigante e esmaga quem encontra | levá-lo a um buraco cavado ou à lava; caído, vira ponte |
| Caverna de Cristal | cristais crescem e fecham passagens | correr; explosão quebra o cristal novo |
| Geleira | avalanche varre da esquerda para a direita | abrigar a tropa num túnel antes |
| Vulcão | lava subindo | fuga para cima: escadas e construção |
| Cidade | prédio desmoronando, andar por andar | descer ou sair antes |
| Outro Planeta | tempestade que empurra os bonecos | Bloco e paredes como quebra-vento |
| Espaço | conveses despressurizando em sequência | fechar as escotilhas (porta com botão) atrás da tropa |

O Golem é o mais perto de um chefe de verdade: um inimigo que se vence com
as ferramentas, não com ataque.

### 11.7 Cartas que caem durante a fase (liga com a ideia 9)

Além da barra de XP, um **baú** no mapa (em lugar difícil) abre 3 cartas na
hora. Dá motivo para explorar a fase grande, e o gerador já sabe pôr itens
onde se chega com as ferramentas da fase.

### Recomendação

Começar pelo **11.1 (barra de XP e cartas durante a fase)** com umas 8
cartas novas de 11.2 e 11.4: é o que dá a sensação de Megabonk e reaproveita
a tela de cartas, as raridades e as relíquias que já existem. Depois, as
evoluções de ferramenta (11.3) e os perigos de paisagem (11.6) junto com as
mecânicas por ambiente (10.3).
