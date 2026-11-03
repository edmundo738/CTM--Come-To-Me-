# Neon Ruins — Master Design

**Estado:** direção viva do projeto; distingue o que está implementado do que continua planeado.

## Identidade

*Come To Me: Neon Ruins* é uma aventura tática 2D por turnos sobre uma bola vermelha que atravessa ruínas para encontrar Lia, outra bola com identidade visual própria. A câmara de cima, a leitura de casas e a decisão de quando avançar são o centro do jogo. O mundo pode parecer profundo através de luz, sombras, camadas e movimento, sem esconder regras de colisão.

## Ciclo principal

1. Ler a sala, os perseguidores, os perigos e as rotas visíveis.
2. Escolher um movimento, salto, espera, Blink ou demolição.
3. Resolver recolhas e perigos da rota; avançar inimigos uma vez por ação válida.
4. Ativar interruptores, abrir o portal e decidir se vale a pena explorar por moedas, escudos ou poderes.
5. Concluir o andar, receber estrelas e recompensa, e continuar a campanha.

As animações e o som apresentam resultados que a lógica já decidiu. Uma animação não atrasa nem altera uma regra do turno.

## Mundo e geração

- O gerador tiled **Wave Function Collapse** determina adjacências; um grafo de salas ligado forma espaços táticos, rotas secundárias e áreas de exploração.
- A mesma seed deve reproduzir o mapa. Correções de geração e colocação de objetos não podem criar um andar sem caminho ao portal.
- Os primeiros andares ensinam o movimento e a leitura dos inimigos antes de introduzir os chefes e perigos mais complexos.
- Biomas mudam a leitura visual e, quando indicado, a regra do piso. Um perigo novo precisa de sinal visual claro e de uma resposta possível.

## Interações ambientais implementadas

- **Jardim de Vidro:** setas marcam as correntes. Ao terminar uma ação numa célula corrente, a bola pode ser levada uma casa se o destino estiver livre. Uma caixa de madeira empurrada para a água flutua e percorre uma célula por turno, sem atravessar atores ou sair da água.
- **Catedral de Gelo:** o movimento sobre uma faixa de gelo desliza na direção escolhida até ao primeiro piso seguro ou a um obstáculo. Algumas placas frágeis ganham fissuras e deixam de deslizar após três passagens.
- **Água elétrica:** surge em andares posteriores do Jardim apenas numa célula marcada para a qual a geração encontra uma rota alternativa. O contacto usa a resolução de dano já existente e consome no máximo um recurso por ação.
- **Congelar Tempo:** mantém a regra existente de imobilizar inimigos e também suspende correntes e água elétrica durante o tempo restante. Armadilhas continuam ativas.
- **Caixas:** são objetos opcionais, sólidos para o jogador e os inimigos. A posição inicial preserva uma rota para o portal; caixa não pode ocupar portal nem interruptor. Ainda não são objetivos de Sokoban.

O estado ambiental é calculado durante o turno. Os indicadores de corrente, carga elétrica, gelo rachado e caixa flutuante são visuais; não são usados para decidir movimento ou dano.

## Combate, progressão e economia

- Escudos absorvem um impacto ou podem ser gastos num salto de duas casas; o contra-ataque dos chefes mantém a sua regra própria.
- Cada inimigo deve ter comportamento previsível, uma ameaça comunicada e oportunidade justa de resposta. Chefes não precisam de ser derrotados para escapar pelo portal.
- Moedas são a moeda atual do jogo, estrelas avaliam o desempenho por andar e os desafios concedem uma recompensa única. Uma loja, cosméticos e uma árvore de habilidades ainda precisam de sistemas de inventário e saves completos.
- Corações adicionais são uma habilidade de sobrevivência, não vidas gratuitas. Não adicionar pickups ou ícones de coração isolados: ligar o sistema a desbloqueio/ativação de habilidades, persistência por campanha e regras de contacto antes de expô-lo no HUD.
- A campanha atual tem checkpoint e diário de andares. Vários saves independentes e preservação completa de recursos ao revisitar um andar permanecem trabalho futuro.

## Game feel, imagem e som

- Responder a cada ação com uma assinatura curta e correspondente: moeda, escudo, caixa, gelo, corrente, dano, chefe, portal.
- Partículas, luzes, tremor e flash devem indicar uma consequência; limitar duração e quantidade para manter a grelha legível.
- Preservar a bola vermelha do jogador e o acabamento sombreado compartilhado com a bola de Lia, mudando a paleta e expressão da Lia. Inimigos devem ser lidos pela silhueta e comportamento antes de receber decoração.
- A trilha mantém tema e camada de ameaça sincronizados. Efeitos locais são curtos; não substituir música composta por loops ambientais repetitivos.
- Alvo técnico: Godot 4.7.2, renderizador Compatibility, máquinas modestas. Medir antes de adicionar shaders, partículas persistentes ou áudio espacial.

## Próximas fatias

1. Inspecionar visualmente as novas superfícies e ajustar contraste, movimento das caixas e feedback em janela real.
2. Criar uma sala de caixas com objetivos somente depois de validar soluções por busca de estados e garantir reset sem bloqueio.
3. Desenhar estados de ataque/recuperação distintos para chefes e testar combate por turno.
4. Fazer progressão de habilidades, corações e inventário por campanhas com migração e testes de saves.
5. Evoluir loja, cosméticos, variação de salas, níveis laterais especiais, VFX e trilha com testes de uso, não apenas conteúdo em lista.

## Verificação

Mudanças de gameplay precisam de autoteste determinístico sobre turno, colisão, geração, checkpoint e combinação de estados. Aprovação visual, escuta de áudio, equilíbrio e desempenho em hardware são verificações distintas; um teste headless não as prova.
