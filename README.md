# Come To Me: Neon Ruins

Jogo tático 2D por turnos feito em Godot 4.7.2. A protagonista é uma bola vermelha que atravessa ruínas para encontrar Lia. Cada ação válida faz também avançar os perseguidores; salas, rotas alternativas, objetivos e inimigos exigem decisões diferentes em cada andar.

## Jogar

- Abra `project.godot` no Godot 4.7.2 e pressione **F6/F5**. O menu permite continuar, iniciar uma campanha ou consultar o diário de andares.
- Mova com **WASD** ou as **setas**. Tocar numa parede dá feedback, mas não gasta turno. **X** espera um turno sem mudar de direção; também há um botão no ecrã e o botão superior esquerdo do comando.
- Recolha escudos ciano: cada carga absorve um impacto ou permite saltar duas casas com **Espaço**. Uma ação só pode gastar um escudo, mesmo que várias ameaças atinjam o jogador no mesmo turno.
- Recolha cargas de demolição e use **B** para abrir uma parede adjacente ou atingir um inimigo à frente; a ação gasta um turno e uma carga. A fronteira do mundo não pode ser destruída.
- Em andares de busca, ative todos os interruptores para abrir o portal. Recolha moedas, evite armadilhas e encontre o caminho até ele.
- O desafio opcional aparece no cabeçalho: não saltar, não sofrer danos, escapar dentro do limite de ações ou recolher todas as moedas. O limite tem em conta uma rota real pelos interruptores e pelo portal. Concluir o desafio rende **5 moedas**, incluídas uma única vez na recompensa apresentada no resultado.
- **Enter** continua depois de concluir um andar; **R** repete o andar com a mesma seed, moedas, escudos, cargas e histórico do início desse andar; **N** começa uma campanha nova; **L** abre o diário; **Esc** pausa; **M** alterna a música. O menu de pausa também permite repetir o andar.
- Se for capturado, o jogo apresenta a sequência de inflação e explosão antes do ecrã de derrota. Continuar restaura o início do andar perdido sem apagar os andares já desbloqueados nem as estrelas anteriores.

## Chefes de xadrez

A cada cinco andares surge um guardião inspirado numa peça: **Peão** (5), **Torre** (10), **Cavalo** (15), **Bispo** (20), **Rainha** (25) e **Rei** (30); depois o ciclo repete-se. A barra mostra a vida e uma descrição do movimento. As peças de linha movem-se até três casas; o cavalo salta em L e as diagonais não atravessam cantos bloqueados. Se uma peça ficar presa pela geometria do mapa, pode usar um passo ortogonal para contornar o obstáculo.

Cada chefe tem pelo menos duas vidas: uma carga de demolição retira apenas uma, e um escudo que absorva o contacto também causa uma vida de dano e afasta o guardião. Derrotar o chefe é opcional: o portal continua a ser uma rota de fuga quando o objetivo estiver cumprido.

## Progresso e compatibilidade

O diário guarda até cinco estrelas por andar e desbloqueia o próximo quando o portal é alcançado. O checkpoint guarda a seed, moedas, escudos, cargas de demolição, direção e histórico do início do andar; perfis antigos que não tinham inventário guardado continuam a carregar, com os novos valores inicialmente a zero. O perfil local fica em `user://come_to_me_profile.cfg`.

O gerador WFC foi otimizado para mapas maiores. Uma mesma seed continua reproduzível nesta versão, inclusive ao repetir ou continuar, mas **o layout gerado por uma seed antiga pode ser diferente** após a atualização; o progresso e os recursos do perfil não são apagados.

## Geração e biomas

O gerador usa o modelo tiled do Wave Function Collapse para respeitar adjacências e depois monta uma rede conectada de salas, corredores largos e ligações alternativas. Há cinco perfis de bioma e de salas que se repetem ao longo da campanha. O quarto andar mantém a vista de cima, com interruptores, armadilhas e perseguidores.

## Validar

Depois de importar o projeto uma vez no editor, execute a partir da pasta do projeto:

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/self_test.gd
godot --headless --path . --script res://tests/sweep.gd -- floors=1-30 seeds=3 bots=1
```

No PowerShell, substitua `godot` pelo caminho do executável de consola do Godot 4.7.2. O primeiro teste imprime `SELFTEST_PASS` e verifica, entre outros, WFC, desafios, recompensa, checkpoints, repetição, colisões, chefes e captura. A varredura imprime `SWEEP_PASS` se os mapas, os itens, a reprodutibilidade e os bots passarem; um dos bots é invulnerável para verificar que consegue realmente concluir o objetivo. Use, por exemplo, `floors=100-100 seeds=3 bots=1` para testar um andar específico. Os tempos mostrados são medições locais, não limites de desempenho. Os testes também correm no GitHub Actions com o Godot oficial 4.7.2.

## Referências analisadas

- `Neon Ruins.html` e `Neon Ruins (1).html` são cópias do protótipo tático de grade por turnos.
- `Neon Ruins (Copy).html` mantém o jogo, com título diferente.
- `where.html` mantém o mesmo jogo com pequenas mudanças no texto e na trilha gerada.
- A direção atual usa a silhueta de bola do jogador, sem copiar arte ou código dos jogos de referência.

As notas de desenvolvimento também propõem novos power-ups, andares de puzzle, novos inimigos e mais efeitos audiovisuais; essas ideias ainda não fazem parte desta versão.
