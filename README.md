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
godot --headless --path . --script res://tests/sweep.gd -- floors=1-40 seeds=3 bots=1
```

No PowerShell, substitua `godot` pelo caminho do executável de consola do Godot 4.7.2. O primeiro teste imprime `SELFTEST_PASS` e verifica WFC, desafios, checkpoints, bosses separados, poderes, puzzles, patrulha, espelho, armadilhas, captura e áudio. A varredura imprime `SWEEP_PASS` se os mapas, itens, ordem de puzzle, reprodutibilidade e bots passarem; um bot é invulnerável para verificar que consegue concluir cada objetivo. Use, por exemplo, `floors=100-100 seeds=3 bots=1` para testar um andar específico. Os tempos mostrados são medições locais, não limites de desempenho. Os testes também correm no GitHub Actions com o Godot oficial 4.7.2.

## Referências analisadas

- `Neon Ruins.html` e `Neon Ruins (1).html` são cópias do protótipo tático de grade por turnos.
- `Neon Ruins (Copy).html` mantém o jogo, com título diferente.
- `where.html` mantém o mesmo jogo com pequenas mudanças no texto e na trilha gerada.
- A direção atual usa a silhueta de bola do jogador, sem copiar arte ou código dos jogos de referência.
