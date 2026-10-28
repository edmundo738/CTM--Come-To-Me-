# Come To Me: Neon Ruins

Protótipo 2D tático por turnos feito em Godot 4.7.2. Um homem atravessa ruínas para encontrar Lia, sua amada. Cada movimento avança os perseguidores; as setas vermelhas mostram para onde eles vão antes de o jogador escolher o próximo passo.

## Jogar

- Abra `project.godot` no Godot 4.7.2 e pressione **F6/F5**.
- Mova com **WASD** ou as **setas**.
- Recolha escudos ciano: cada escudo protege de um ataque ou permite um salto de duas casas com **Espaço**.
- Recolha moedas, evite as paredes e alcance o portal roxo.
- Conclua cinco andares para encontrar Lia. **Enter** avança ao próximo andar; **R** reinicia.

## Validar

No PowerShell, na pasta do projeto:

```powershell
& 'C:\Users\edmun\OneDrive\Documentos\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/self_test.gd
```

O autoteste imprime `SELFTEST_PASS` quando geração de salas, caminho ao portal, intenções dos inimigos, movimento, salto, progressão e final de resgate passam.

## Referências analisadas

- `Neon Ruins.html` e `Neon Ruins (1).html` são cópias idênticas do jogo de grade por turnos.
- `Neon Ruins (Copy).html` mantém o jogo, mas altera o título do documento.
- `where.html` mantém o mesmo jogo com pequenas alterações no texto e na trilha gerada; não é um jogo separado.
- O projeto `jogo-2d-codex-create-2d-bounce-puzzle-game` é outro protótipo, de bola vermelha, obstáculos e interruptores. Foi mantido como referência secundária.

O título de trabalho combina o apelo emocional de **Come To Me** com o cenário de **Neon Ruins**. O nome ainda pode mudar junto com a história.
