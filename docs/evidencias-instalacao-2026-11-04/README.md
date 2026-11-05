# Evidências — Instalação Submersa (4 de novembro de 2026)

**Contém spoilers do puzzle.** Estas são capturas automatizadas para inspeção, não uma sessão de jogador humano.

- `01-entrada-800.png` — entrada normal pela opção `I` do título, a 800 × 540.
- `02-painel-800.png` — painel após a primeira interação correta na sala C.
- `03-perigo-800.png` — água energizada antes de desligar a fonte.
- `04-dreno-fixture-1280.png` — verificação visual da última versão do dreno e dos três intertravamentos a 1280 × 720; esta cena colocou os estados diretamente através de um **fixture**, não através de um percurso jogado.
- `05-conclusao-800.png` — ecrã obtido no fim do percurso automatizado de 198 ações reais no jogo.
- `06-circuitos-fixture-1280.png` — verificação visual da ligação do painel e da escotilha na versão final; esta cena também colocou estados diretamente através de um **fixture**.

As imagens 01, 02, 03 e 05 são do PCK imediatamente anterior aos ajustes exclusivamente visuais que reposicionaram a válvula e separaram os fios do dreno, terminais, painel e escotilha. As imagens 04 e 06 usam a geometria visual final das respetivas ligações. O jogo atual e os seus testes encontram-se no projeto, não nestas imagens.

O percurso de 198 teclas foi executado em Godot Web 4.7.2 oficial, Chromium 106 sem shim, WebGL2/SwiftShader, sem erros de consola. Uma passagem anterior em Chromium 129 também chegou ao portal, mas precisou de um shim NSS exclusivamente no ambiente HTTP local. Os motores, shims, PCKs e scripts temporários usados nessas verificações não fazem parte do projeto.

Para repetir as verificações lógicas, usar Godot 4.7 instalado e executar `tools/test-godot.sh` ou a suite específica `godot --headless --path . --script res://tests/submerged_installation_test.gd`. Para testar graficamente, abrir o projeto Godot, iniciar a cena e escolher `I` no título; observar também o comportamento em ecrãs, comandos e áudio reais. Os resultados e as limitações estão em `../CHECKPOINT_GAME_FEEL.md`.
