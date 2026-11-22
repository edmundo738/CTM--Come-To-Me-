# Como testar a Instalação Submersa

Este pacote contém o **projeto Godot**, não um jogo executável já instalado.

1. Extrai o ZIP e abre o ficheiro `project.godot` no editor Godot 4.7.
2. Deixa o editor importar os recursos e executa o projeto.
3. No título, escolhe **INSTALAÇÃO SUBMERSA** ou carrega em **I**. Também podes chegar a ela depois das quatro câmaras experimentais iniciadas com **C**.
4. Move-te com WASD ou setas. **Z** desfaz até 128 ações; **R** reinicia a câmara; **X** espera; **Esc** abre a pausa. Os botões e a configuração de comando também estão disponíveis.

A câmara é experimental, não dá recompensas e não altera o checkpoint da campanha. Se uma caixa ficar presa, usa desfazer ou reinicia. As pistas estão no cenário e no painel de objetivo; não é necessário ler as capturas para jogar.

## Observar o game feel

- As placas têm superfícies de madeira ou metal, guias, relevo e movimento, sem letras na superfície. Na câmara de duas placas, observa-as junto das caixas com topos quadrados.
- Observa os portões a abrir e fechar nas paredes verticais e horizontais. A pequena luz de estado indica se a passagem está logicamente aberta, mesmo enquanto as folhas terminam a animação.
- Na instalação, compara o encaixe metálico vazio com o gerador instalado: são objetos diferentes, vistos na mesma perspetiva do resto do cenário.
- Na instalação, quando encontrares a drenagem, a água vai desaparecendo gradualmente. **Z** também permite observar o regresso visual da água; o perigo real muda imediatamente com as regras.
- Noutras partes do jogo, recolhas deixam uma imagem breve que encolhe. Experimenta os sons dos mecanismos e a pausa no teu equipamento. **M** liga/desliga apenas a música; não existe ainda um botão de mute dos efeitos.

## Estado da verificação

A suite específica passou 1.020 verificações lógicas, incluindo uma rota por ações do jogo e comparação dos ficheiros descartáveis de perfil, slot e backup antes e depois. O teste de apresentação passou 70 verificações de continuidade, desfazer, pausa e separação das regras; o de geometria passou 64 verificações de orientação e superfícies. Um percurso automatizado de 198 ações terminou a câmara no navegador. As 15 suites e quatro varreduras passaram no motor headless custom com filtro para um erro conhecido de fontconfig; o teste de geometria foi ampliado e repetido isoladamente, e o runner estrito ainda deve ser repetido com Godot oficial nativo. Detalhes e limitações estão em `docs/CHECKPOINT_GAME_FEEL.md`; as capturas em `docs/evidencias-perspetiva-2026-11-05/` incluem estados preparados e podem conter spoilers.

Ainda é necessário testar com pessoas e em hardware, áudio e comandos reais. Estes testes não provam ausência universal de estados bloqueados nem garantem que o puzzle seja divertido ou claro para todos.
