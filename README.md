# Come To Me: Neon Ruins

Jogo tatico 2D por turnos feito em Godot 4.7.2. O protagonista e uma bola vermelha que atravessa ruinas para encontrar Lia. Cada movimento tambem avanca os perseguidores; salas, rotas alternativas, objetivos e inimigos exigem decisoes diferentes em cada andar.

## Jogar

- Abra `project.godot` no Godot 4.7.2 e pressione **F6/F5**.
- O menu permite continuar no andar guardado, iniciar uma campanha ou consultar o diario de andares.
- Move com **WASD** ou as **setas**. Cada passo faz os perseguidores avancarem.
- Recolhe escudos ciano: cada carga absorve um impacto ou permite saltar duas casas com **Espaco**.
- A partir do terceiro andar, procura cargas de demolicao. **B** abre uma parede adjacente e gasta um turno; a fronteira do mundo nao pode ser destruida.
- Em andares de busca, explora as salas para encontrar interruptores que abrem o portal. Os inimigos nao mostram linhas nem previsoes de movimento.
- Recolhe moedas, evita armadilhas e chega ao portal. Os cinco andares tem biomas, paletas e estruturas de salas diferentes.
- **Enter** continua depois de concluir um andar; **R** repete o andar atual; **N** comeca uma campanha nova; **L** abre o diario; **Esc** pausa; **M** alterna a musica.
- Se fores capturado, a bola infla e pisca antes de rebentar, com som, particulas, tremor, clarão e uma poça menor antes do ecrã de derrota. A continuacao volta ao inicio do andar perdido, sem apagar as estrelas e os andares ja desbloqueados.

## Progresso

O diario guarda ate cinco estrelas por andar e desbloqueia o proximo quando o portal e alcancado. A derrota guarda o andar atual e o progresso acumulado dos andares concluidos. O perfil local fica em `user://come_to_me_profile.cfg`.

## Geracao e biomas

O gerador usa o modelo tiled do Wave Function Collapse para respeitar adjacencias e depois monta uma rede conectada de salas, corredores largos e ligacoes alternativas. Cada andar usa um perfil de salas e uma paleta propria. O quarto andar continua a vista de cima e usa interruptores, armadilhas e perseguidores; nao ha uma fase lateral no meio da campanha.

## Validar

No PowerShell, na pasta do projeto:

```powershell
& 'C:\Users\edmun\OneDrive\Documentos\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/self_test.gd
```

O autoteste imprime `SELFTEST_PASS` quando WFC, cinco perfis de bioma, conectividade, perseguicao e visao dos inimigos, movimento, salto, demolicao, interruptores, portal, musica, resgate, estrelas, continuacao e sequencia de captura passam.

## Referencias analisadas

- `Neon Ruins.html` e `Neon Ruins (1).html` sao copias do prototipo tatico de grade por turnos.
- `Neon Ruins (Copy).html` mantem o jogo, com titulo diferente.
- `where.html` mantem o mesmo jogo com pequenas mudancas no texto e na trilha gerada.
- O projeto `jogo-2d-codex-create-2d-bounce-puzzle-game` e outro prototipo, de bola vermelha, obstaculos e interruptores.
- `bounce_tales_future_240x320_164800.jar` e `godofwar32_cckmqw3u.jar` foram analisados como referencias J2ME de alto nivel. A direcao atual usa a silhueta de bola do jogador, sem copiar arte ou codigo desses jogos.

O titulo combina o apelo emocional de **Come To Me** com o cenario de **Neon Ruins** e ainda pode mudar com a historia.
