# Come To Me: Neon Ruins

Ação tática 2D por turnos, feita em Godot 4.7.2. Um homem atravessa ruínas para encontrar Lia, a sua amada. Cada movimento avança os perseguidores; as salas, rotas alternativas, interruptores e tipos de inimigo mudam a decisão de cada andar.

## Jogar

- Abra `project.godot` no Godot 4.7.2 e pressione **F6/F5**.
- A janela abre maximizada e ajusta o mapa e a interface ao espaço disponível no ecrã.
- Mova com **WASD** ou as **setas**.
- Recolha escudos ciano: cada escudo protege de um ataque ou permite um salto de duas casas com **Espaço**.
- A partir do terceiro andar, procura cargas de demolição. **B** destrói uma parede adjacente e gasta um turno; os limites exteriores do mundo são indestrutíveis.
- Em alguns andares, explore salas diferentes para encontrar os interruptores que abrem o portal. Não há setas que revelem o próximo passo dos inimigos.
- Recolha moedas, evite armadilhas e alcance o portal roxo.
- Conclua cinco andares para encontrar Lia. **Enter** avança ao próximo andar; **R** reinicia.
- Se fores capturado, o personagem infla, pisca e rebenta; uma poça vermelha ocupa cerca de três a quatro casas, o som sobe até ao estalo e a imagem escurece antes do ecrã de derrota.
- Depois do terceiro andar, o quarto muda para uma secção lateral: corre com **←/→** ou **A/D**, salta com **Espaço/↑**, agacha com **↓/S**, evita sentinelas e feixes e encontra três fragmentos para abrir o portal.

## Validar

No PowerShell, na pasta do projeto:

```powershell
& 'C:\Users\edmun\OneDrive\Documentos\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/self_test.gd
```

O autoteste imprime `SELFTEST_PASS` quando WFC, limites, salas, perseguidores, movimento, salto, demolição, interruptores, portal, música adaptativa, interlúdio lateral, progressão, resgate e a sequência completa de captura passam.

## Referências analisadas

- `Neon Ruins.html` e `Neon Ruins (1).html` são cópias idênticas do jogo de grade por turnos.
- `Neon Ruins (Copy).html` mantém o jogo, mas altera o título do documento.
- `where.html` mantém o mesmo jogo com pequenas alterações no texto e na trilha gerada; não é um jogo separado.
- O projeto `jogo-2d-codex-create-2d-bounce-puzzle-game` é outro protótipo, de bola vermelha, obstáculos e interruptores. Foi mantido como referência secundária.
- `bounce_tales_future_240x320_164800.jar` e `godofwar32_cckmqw3u.jar` são referências J2ME com perspectiva lateral. Foram identificados pelo manifesto como Bounce Tales 2 e God of War: Betrayal; os seus recursos e bytecode são propriedade dos respetivos titulares e servem apenas para análise de alto nível, sem copiar código nem arte.

## Direção de jogo

A maioria dos andares continua estratégica e vista de cima. O quarto andar já é um interlúdio lateral jogável, com aceleração, salto, agachamento, fragmentos, feixes, espinhos, sentinelas e câmara horizontal. A captura tem uma sequência própria de inflação, clarão, partículas, poça e escurecimento; a música tem uma composição sintetizada de cerca de 39 segundos e uma camada de tensão sincronizada com a proximidade de inimigos.

O título de trabalho combina o apelo emocional de **Come To Me** com o cenário de **Neon Ruins**. O nome ainda pode mudar junto com a história.
