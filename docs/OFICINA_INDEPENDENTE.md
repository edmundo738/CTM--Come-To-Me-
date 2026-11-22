# Oficina CTM independente

## Para que serve

A Oficina é uma aplicação local para editar mapas da campanha sem abrir o Godot nem escrever código. O programa abre no navegador, mas os ficheiros e o servidor permanecem no computador. A campanha continua a consumir o formato JSON `ctmmap`; as regras de validação e gameplay não são copiadas para o navegador.

## Abrir e escolher uma fase

1. Inicia `Abrir_Oficina_CTM.cmd` na pasta do projeto. Mantém a janela de arranque aberta enquanto usas a Oficina; fechá-la encerra o serviço local.
2. A página abre no navegador predefinido. Escolhe qualquer fase de 001 a 200 no seletor superior.
3. Se a fase tiver um mapa da Oficina, esse mapa abre. Caso contrário, a Oficina importa o blueprint da fase quando existe; para fases sem blueprint, abre um mapa novo.
4. **Novo mapa** limpa a fase atual. **Importar blueprint** recupera a planta Godot conhecida para essa fase. **Abrir mapa** aceita um ficheiro JSON `ctmmap`.

## Montar e editar

- **Parede:** pinta uma ou várias casas. **Apagar** remove a peça ou parede da casa.
- **Início / Portal:** seleciona a ferramenta e clica na nova casa.
- **Ameaças / Recolhas / Mecanismos:** escolhe a família e uma peça; clica no tabuleiro para a colocar. O início e o portal não podem ser ocupados.
- **Mover:** com **Selecionar**, arrasta uma peça ou marcador para uma casa livre. A lista **Na fase** também permite centrar e selecionar uma peça.
- **Ligar peças:** clica no mecanismo de origem e depois no destino. As linhas mostram ligações de mecanismos; a intenção dos inimigos nunca é desenhada.
- O painel **Detalhes** edita nome, descrição, objetivo e o uso exclusivo das peças colocadas. Ao selecionar um mecanismo, também permite mudar o nome usado nas ligações.
- **Tamanho do mapa** altera largura e altura de 9 a 160 casas. Peças que fiquem fora da nova borda são removidas; marcadores são mantidos dentro do mapa.
- Roda do rato ajusta o zoom; botão do meio arrasta a vista; **Ajustar** volta ao tamanho ideal. `Ctrl+Z`, `Ctrl+Y` e `Ctrl+S` desfazem, refazem e guardam.

## Validar e guardar no jogo

**Validar** usa o validador existente do formato CTM, verificando borda, sobreposição, objetivo, caminho até ao portal, referências e compatibilidade dos canais de mecanismo. Isto prova consistência estrutural, não prova que uma fase seja divertida.

**Guardar no jogo** grava `levels/external_maps/floor_NNN.ctmmap.json`. Se o ficheiro já existir, a Oficina conserva a versão anterior como `.bak` (ou `.bak.N`). O carregador de campanha aplica paredes, início, portal, mecanismos, inimigos e recolhas à fase. Ativar **Usar só estas peças** impede spawns aleatórios adicionais. Fases sem ficheiro externo continuam a usar o conteúdo anterior. O salvamento cria um formato de mapa ativo; não altera os saves de progresso. O botão **⊘** desliga o mapa externo atual e conserva o ficheiro como `.disabled` recuperável.

## O que orientou esta revisão

- O [Tiled](https://doc.mapeditor.org/en/stable/manual/introduction/) dá prioridade ao tabuleiro e oferece ferramentas de pintura e camadas de objetos; as [camadas](https://doc.mapeditor.org/en/stable/manual/layers/) ajudam a organizar o conteúdo e os [templates](https://doc.mapeditor.org/en/stable/manual/using-templates/) tornam objetos reutilizáveis. Esta Oficina adota a área central dominante e a colocação rápida de peças; ainda não importa mapas Tiled nem oferece camadas visuais de arte.
- O [LDtk](https://ldtk.io/docs/general/editor-components/entities/) trata objetos colocáveis como entidades com campos e limites; aqui isso inspira a paleta por família e os detalhes contextuais. Edição de campos avançados ainda está por fazer.
- Em jogos com criação para jogadores, o **Super Mario Maker 2** combina paleta, colocação direta, estilos/temas e experimentação; o guia oficial destaca também peças favoritas fixadas e combinações entre interruptores e objetos. O **Portal 2 Puzzle Maker** parte de uma câmara pronta, oferece peças do jogo e torna ligações como botão → porta explícitas antes de testar a câmara. Estas duas referências reforçam uma regra para a Oficina: permitir construir e experimentar no próprio mapa, com ligações legíveis e uma rota curta até ao teste — atualmente ainda sem preview embutido.
- O [editor 2D do Godot](https://docs.godotengine.org/en/4.7/tutorials/2d/using_tilesets.html) usa pintura em grelha para criar layouts e oferece cenas como tiles. O Godot continua como runtime e ferramenta de edição profunda; a Oficina não depende dele para editar o JSON CTM.

Fontes dos jogos: [Nintendo — Course Maker](https://www.nintendo.com/store/products/super-mario-maker-2-switch/), [Nintendo — guia de construção](https://play.nintendo.com/news-tips/tips-tricks/super-mario-maker-2-tips-tricks/) e [Valve/Steam — Puzzle Maker do Portal 2](https://store.steampowered.com/oldnews/?appgroupname=Portal+2+-+Two+Pack&appids=620&enddate=1357027200&feed=steam_community_announcements).

Estas são referências para fluxos de autoria, não cópias dos jogos ou dos formatos dessas ferramentas.

## Limites atuais

A Oficina ainda não edita arte ou tilesets, WFC, água, gelo, armadilhas, biomas, regras avançadas de entidades, áudio/VFX nem pré-visualiza a fase dentro do jogo. Também não importa recursos Godot arbitrários. Para já, a fase pode ser validada e ligada à campanha; a avaliação visual e de gameplay continua a exigir abrir o jogo.

## Verificação técnica

```powershell
python -m unittest tests.test_oficina_web tests.test_oficina_ctm -v
& 'C:\Users\edmun\OneDrive\Documentos\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/external_map_loader_test.gd
```
