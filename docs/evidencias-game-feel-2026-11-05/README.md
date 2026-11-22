# Evidência da revisão de game feel — 5 de novembro de 2026

**Contém spoilers da Instalação Submersa.** As imagens são capturas técnicas, não uma avaliação por jogadores.

## Estados preparados

As imagens de placas/portão, água e recolhas vêm de uma fixture temporária em Godot Web 4.7.2, Chromium 106, WebGL2 e SwiftShader. A fixture usa o código real do projeto, mas coloca objetos em posições preparadas e avança os relógios de apresentação manualmente; **não são frames de um percurso jogado naturalmente**. Cada imagem foi obtida do viewport do Godot. Foram feitas 12 capturas em 1280 × 720 e repetidas em 800 × 540, sem erros de consola; aqui ficam as 12 primeiras e duas amostras da resolução menor.

- `placas-porta-fechada`, `intermedia` e `aberta`: mesmas placas de madeira/metal e portão antes, durante e após a mudança. Os encaixes e batentes permanecem visíveis; a abertura não fica tapada por um fundo escuro.
- `agua-antes`, `inicio`, `meio`, `drenada` e `desfazer`: a regra muda na ação, mas a superfície, válvula, cabos e terminais têm apresentação gradual e reversível. O perigo elétrico, se presente, continua a refletir o estado lógico imediatamente.
- `recolhas-antes`, `meio`, `fim` e `desfazer`: moedas, escudos, cargas e poderes são preparados lado a lado para mostrar a imagem que encolhe e o brilho que desvanece. O teste lógico separado exercita recolhas reais e desfazer.
- Os sufixos `1280` e `800` identificam a largura do viewport; a altura correspondente é 720 ou 540.

## Percurso automatizado

`instalacao-concluida-800.png` vem do **projeto normal**, não da fixture: foram enviadas 198 ações de teclado num navegador até ao ecrã “CÂMARA 5 CONCLUÍDA”, sem erros de consola. O percurso confirma este caso, não a recuperação de todas as configurações possíveis.

A suite headless da instalação, o teste de apresentação, as regressões e as suas limitações estão em `../CHECKPOINT_GAME_FEEL.md`. Estas imagens não demonstram qualidade de áudio, desempenho em GPU real, conforto, clareza ou satisfação de uma pessoa.
