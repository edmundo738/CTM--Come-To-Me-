# Come To Me: Neon Ruins

Jogo tático 2D por turnos feito em Godot 4.7.2. A protagonista é uma bola vermelha que atravessa ruínas para encontrar Lia. Cada ação válida faz avançar o turno; salas, rotas alternativas, objetivos e inimigos exigem decisões diferentes em cada andar.

## Jogar

- Abra `project.godot` no Godot 4.7.2 e pressione **F6/F5**. O menu permite continuar, iniciar uma campanha ou consultar o diário de andares.
- Mova com **WASD** ou as **setas**. Tocar numa parede dá feedback, mas não gasta turno. **X** espera um turno sem mudar de direção; também há um botão no ecrã e o botão superior esquerdo do comando.
- Recolha escudos ciano: cada carga absorve um impacto ou permite saltar duas casas com **Espaço**. Uma ação só pode gastar um escudo, mesmo que várias ameaças atinjam o jogador no mesmo turno.
- Recolha cargas de demolição e use **B** para abrir uma parede adjacente ou atingir um inimigo à frente; a ação gasta um turno e uma carga. A fronteira do mundo não pode ser destruída.
- Ative os interruptores necessários para abrir o portal. Recolha moedas, evite armadilhas e encontre o caminho até ele.
- O desafio opcional aparece no cabeçalho: não saltar, não sofrer danos, escapar dentro do limite de ações ou recolher todas as moedas. O limite tem em conta uma rota real pelos interruptores e pelo portal, incluindo a ordem das runas nos puzzles. Concluir o desafio rende **5 moedas**, incluídas uma única vez na recompensa apresentada no resultado.
- **Enter** continua depois de concluir um andar; **R** repete o andar com a mesma seed e os recursos do início desse andar; **N** começa uma campanha nova; **L** abre o diário; **Esc** pausa; **M** alterna a música. O menu de pausa também permite repetir o andar.
- Se for capturado, o jogo apresenta a sequência de inflação e explosão antes do ecrã de derrota. Continuar restaura o início do andar perdido sem apagar os andares já desbloqueados nem as estrelas anteriores.

## Comandos e vibração

O jogo reconhece comandos suportados pelo Godot/SDL, incluindo muitos modelos **Xbox**, **PlayStation/PS3** e gamepads genéricos. Liga o comando antes ou durante o jogo: o nome aparece no menu, e desligar ou trocar de comando não exige reiniciar. O último comando utilizado controla o jogo e recebe a vibração; não é necessário que seja o dispositivo número zero. Na pausa ou no menu inicial, abre **COMANDOS / VIBRAÇÃO** para ver os dispositivos, escolher qual configurar, ligar/desligar a vibração, ajustar a **intensidade de 0% a 200%** e testar o comando selecionado. Na barra de intensidade, usa esquerda/direita quando estiver focada, ou clica/toca e arrasta. O valor e o interruptor são independentes e ficam guardados. Novos perfis usam automaticamente 200%; perfis antigos que estavam no máximo também passam para 200%, enquanto valores reduzidos e a opção desligada são preservados.

| Ação | Xbox / padrão | PlayStation / PS3 |
| --- | --- | --- |
| Mover e navegar nos menus | Direcional ou analógico esquerdo | Direcional ou analógico esquerdo |
| Confirmar / saltar | A | Cruz |
| Voltar / pausar | B ou Start | Círculo ou Start |
| Demolir | X | Quadrado |
| Esperar | LB | L1 |
| Blink | RB | R1 |
| Menu do desenvolvedor | Y ou Back | Triângulo ou Select |

Os rótulos são indicativos: adaptadores, Steam Input e drivers podem apresentar outro nome ou outro mapeamento. Os botões físicos de confirmação podem variar por região. Os menus, diário de andares, resultados e consola de desenvolvimento também podem ser navegados por comando; teclado, rato e toque continuam disponíveis.

Se um comando genérico não responder corretamente, abre **COMANDOS / VIBRAÇÃO → CONFIGURAR BOTÕES E EIXOS** com um comando funcional, teclado, rato ou toque, escolhe o dispositivo e segue o assistente. Move o analógico/direcional e pressiona os botões pedidos, soltando entre passos; direções, confirmar e voltar são obrigatórios, enquanto as outras ações podem ser ignoradas. Nos passos opcionais, pressiona e solta o botão já escolhido para **voltar** para ignorar; mantém-no premido para cancelar. Antes de configurar esse botão, manter um botão ou eixo premido por dois segundos também cancela. **S** ignora um passo opcional e **Esc** cancela no teclado. O assistente rejeita controlos duplicados e só substitui o mapeamento anterior ao terminar. Cada ação configurada utiliza o botão ou sentido de eixo escolhido no assistente, em vez dos controlos padrão dessa ação.

As definições são guardadas no perfil local. O mapeamento acompanha o identificador/nome do dispositivo e, quando o sistema o disponibiliza, o número de série; comandos idênticos sem número de série partilham o mesmo mapeamento. O botão de restauro remove apenas o mapeamento do comando selecionado. A vibração pode ser desligada globalmente e tem padrões diferentes para passos, colisões, saltos, danos, poderes e outros eventos; funciona mesmo com os efeitos sonoros silenciados. Ao usar teclado ou toque, os eventos do jogo não fazem vibrar um comando que ficou ligado. O teste da página de configuração envia um pulso ao dispositivo selecionado independentemente do último método de entrada.

### Feedback tático

O **Tactical Feedback Bus** encaminha eventos do turno para som, vibração e apresentação, sem esperar pelas animações nem alterar as regras. Há assinaturas diferentes para passos (com variações por bioma), parede bloqueada, moedas, escudo recolhido e impacto absorvido, contra-ataque ao chefe, demolição com ecos, poderes, portal e crescendo/explosão da captura. Um anel discreto aparece após a ação, a bola comprime-se ligeiramente ao aterrar e uma ameaça visível próxima pode originar até dois batimentos duplos com intervalos de silêncio, renovados após um turno ou mudança de distância; um inimigo que acaba de avançar para uma casa adjacente pode provocar um sinal breve de quase-acerto, com um sopro sonoro discreto. Os novos batimentos e a aura não provocam vibração contínua nem assinalam inimigos atrás de paredes; a camada musical de ameaça mantém o comportamento anterior.

Os padrões usam segmentos com prioridade: uma colisão importante não é substituída por um passo ou moeda. Alguns são modulados por envelopes de amplitude das bandas graves/agudas calculados a partir dos próprios efeitos sonoros, não por FFT em tempo real nem pelo volume da música; continuam a funcionar com efeitos sonoros silenciados. O novo máximo aplica **2× o ganho de software** do máximo anterior aos dois motores, antes do limite físico. Nos impactos importantes e no pulso de teste, as partes que atingem esse limite duram até 50% mais, mantendo as pausas; passos e batimentos continuam breves e distintos. Cada pedido ao sistema tem duração limitada, os segmentos de jogo são cancelados ao mudar para teclado/rato/toque, e todos são cancelados ao desligar a vibração, perder o foco ou desconectar o comando.

**Limitações de hardware:** reconhecer e fazer vibrar todos os dispositivos não é garantido. A API padrão do Godot expõe apenas o motor *weak* (alta frequência) e o *strong* (baixa frequência), nesta ordem; não são canais posicionais esquerda/direita. Cada motor aceita valores de 0 a 1: **200% é ganho de software, não 200% da capacidade física**. Assim, partes que já estavam a 100% não podem ter o dobro da amplitude e a sensação não será necessariamente duas vezes mais forte. A API `Input` não expõe separadamente os motores **Impulse Trigger** dos gatilhos Xbox: controlá-los exige um backend ou extensão nativa apropriada, que não está incluída. O comando tem de ser reconhecido pelo sistema operativo e a resposta depende do hardware, da ligação, dos drivers e da plataforma. Enviar um pulso ou o sistema anunciar suporte não confirma que um motor tenha vibrado. Comandos sem vibração continuam utilizáveis; alguns adaptadores podem precisar de drivers ou remapeamento. Para verificar a sensação, testa o comando físico em diferentes intensidades e por USB/Bluetooth conforme disponível.

## Poderes

Surge um power-up alcançável por andar; os quatro tipos repetem-se pela ordem abaixo. As durações contam **ações válidas**, incluindo a ação que recolhe o poder. Recolher novamente um efeito temporário renova a sua duração.

- **Velocidade** (`speed`): durante 6 ações, os inimigos só se movem em ações alternadas; a ação de recolha é a primeira em que ficam parados.
- **Íman** (`magnet`): durante 8 ações, recolhe moedas até dois passos de distância por caminhos livres, sem as atrair através de paredes.
- **Blink**: ganha uma carga. **Q**, o botão no ecrã ou o botão superior direito do comando teleporta até três casas na direção atual, para a casa de chão mais distante. Pode atravessar paredes interiores e ignora ameaças e itens pelo caminho, mas não atravessa a fronteira; só a casa de chegada é ativada. Um Blink bem-sucedido gasta uma carga e um turno; uma tentativa sem destino válido não gasta nenhum dos dois. Blink não conta como salto para o desafio de não saltar.
- **Congelar tempo** (`time_freeze`): imobiliza todos os inimigos durante 4 ações, incluindo a de recolha. O contacto direto ainda causa dano e **as armadilhas continuam a funcionar**.

O HUD indica as cargas de Blink e os turnos restantes dos efeitos. Velocidade e congelamento podem coexistir: o congelamento impede todos os movimentos, enquanto ambos os temporizadores continuam a contar.

## Puzzles, inimigos e armadilhas

Os andares com número `% 5 == 3` (3, 8, 13…) são pisos de puzzle sem inimigos nem armadilhas. Para abrir o portal, ative as três runas por ordem: **ciano → âmbar → violeta**. Também são identificadas por **um, dois e três pontos**, respetivamente, e a sequência aparece no ecrã. Uma runa fora da ordem reinicia a sequência. O gerador verifica a solução considerando a ordem e os possíveis reinícios, não apenas a conectividade do mapa.

Além dos perseguidores anteriores, a **patrulha** anda em linha e roda no sentido horário ao encontrar um obstáculo. O **espelho** responde na direção oposta à do movimento, salto ou Blink do jogador, respeitando paredes e casas ocupadas; ao esperar ou demolir fica imóvel.

As armadilhas de ritmo são recorrentes e têm um ciclo de três ações. Os três indicadores mostram as fases; o círculo branco assinala a **próxima** ação. A primeira fase, vermelha e com triângulo aceso, causa dano; as outras duas são seguras. Bater numa parede não avança o ciclo. As armadilhas normais de ativação única continuam a existir. Os poderes, o Blink, os erros de sequência e as armadilhas de ritmo têm efeitos sonoros próprios.

## Chefes de xadrez e mini-chefe

A cada cinco andares surge uma peça diferente, com silhueta e vida próprias: **Peão** (andar 5, 2 vidas), **Torre** (10, 3), **Cavalo** (15, 4), **Bispo** (20, 5), **Rainha** (25, 6) e **Rei** (30, 7); depois o ciclo repete-se. Não são variações do Guardião e não têm letras sobre as personagens. A barra mostra a vida e o movimento. As peças de linha movem-se até três casas; o cavalo salta em L e as diagonais não atravessam cantos bloqueados. Se uma peça ficar presa pela geometria do mapa, pode usar um passo ortogonal para contornar o obstáculo.

O **Guardião original** permanece como mini-chefe nos andares 4, 9, 14… e não usa a barra nem a identidade dos chefes de xadrez. Ambos os tipos resistem a mais de uma demolição: cada carga retira apenas uma vida, e um escudo que absorva o contacto também causa uma vida de dano e afasta o inimigo. Derrotá-los é opcional: o portal continua a ser uma rota de fuga quando o objetivo estiver cumprido.

## Progresso e compatibilidade

O diário guarda até cinco estrelas por andar e desbloqueia o próximo quando o portal é alcançado. O checkpoint guarda a seed, moedas, escudos, cargas de demolição, direção, histórico, efeitos temporários (incluindo a fase da velocidade) e cargas de Blink do início do andar. **R**, derrota e continuação restauram esses valores; ao concluir um andar, os efeitos restantes seguem para o checkpoint do andar seguinte. Perfis antigos continuam a carregar, com os poderes novos inicialmente a zero. O perfil local fica em `user://come_to_me_profile.cfg`.

O gerador WFC foi otimizado para mapas maiores. Uma mesma seed continua reproduzível nesta versão, inclusive ao repetir ou continuar, mas **o layout e os itens gerados por uma seed antiga podem ser diferentes** após a atualização; o progresso e os recursos do perfil não são apagados.

## Geração e biomas

O gerador usa o modelo tiled do Wave Function Collapse para respeitar adjacências e depois monta uma rede conectada de salas, corredores largos e ligações alternativas. Há cinco perfis de bioma e de salas que se repetem ao longo da campanha. O quarto andar mantém a vista de cima, com interruptores, armadilhas, perseguidores e o Guardião mini-chefe.

## Validar

Depois de importar o projeto uma vez no editor, execute a partir da pasta do projeto:

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/self_test.gd
godot --headless --path . --script res://tests/controller_test.gd
godot --headless --path . --script res://tests/tactical_feedback_test.gd
godot --headless --path . --script res://tests/sweep.gd -- floors=1-40 seeds=3 bots=1
```

No PowerShell, substitua `godot` pelo caminho do executável de consola do Godot 4.7.2. O primeiro teste imprime `SELFTEST_PASS` e verifica WFC, desafios, checkpoints, bosses separados, poderes, puzzles, patrulha, espelho, armadilhas, captura e áudio. O teste de comandos imprime `CONTROLLER_TEST_PASS` e simula vários IDs, ligação/desligação, menus, sticks, remapeamento, perfil e pedidos de vibração; não substitui um teste com hardware físico. `TACTICAL_FEEDBACK_TEST_PASS` verifica eventos reais dos turnos, análise das bandas de áudio, sequências, prioridade, ganho 2× e saturação, pulsos de perigo e cancelamento seguro com um backend simulado. A varredura imprime `SWEEP_PASS` se os mapas, itens, ordem de puzzle, reprodutibilidade e bots passarem; um bot é invulnerável para verificar que consegue concluir cada objetivo. Use, por exemplo, `floors=100-100 seeds=3 bots=1` para testar um andar específico. Os tempos mostrados são medições locais, não limites de desempenho. Os testes também correm no GitHub Actions com o Godot oficial 4.7.2.

## Referências analisadas

- `Neon Ruins.html` e `Neon Ruins (1).html` são cópias do protótipo tático de grade por turnos.
- `Neon Ruins (Copy).html` mantém o jogo, com título diferente.
- `where.html` mantém o mesmo jogo com pequenas mudanças no texto e na trilha gerada.
- A direção atual usa a silhueta de bola do jogador, sem copiar arte ou código dos jogos de referência.
