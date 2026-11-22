# Auditoria do estado atual do projeto — 5 de novembro de 2026

Esta auditoria é a fotografia de base antes da migração arquitetónica descrita no fim deste documento. O texto original regista o estado observado nessa revisão; a atualização posterior corrige o que mudou depois.

## Estado do checkout

- Branch local: `visual-overhaul-v2`; HEAD: `34290e62fc72c45722a2ad5dbb91b4fc04e1111b`. A branch não tem upstream configurado. `origin/master` está em `400c853`; não consultei o remoto nesta revisão.
- A árvore já estava muito modificada: 20 ficheiros rastreados alterados e 93 novos/não rastreados. O diff rastreado mostrava 4.118 linhas adicionadas e 1.389 removidas; esse número não inclui os ficheiros novos. Não fiz commit, push, limpeza ou reset.
- `git diff --check` aponta seis linhas com espaços finais em `game.gd`; são problemas de formatação, não erros de execução.

## O que o projeto é agora

É um jogo tático 2D em Godot 4.7.2, GDScript, grelha e turnos. A lógica decide imediatamente posição, colisão, custos e consequências; movimento, luz, áudio e efeitos apresentam o resultado. O jogo já não é JavaScript.

O WFC tiled e o grafo de salas geram a maioria dos andares; a seed da campanha permite reproduzir o andar. Existem cinco biomas, caminhos alternativos, inimigos, armadilhas, moedas, portal, escudos, Blink, congelamento e demolição. Uma agenda determinística introduz sete famílias especiais: runas em sequência, Sokoban, oficina de portão, circuito, interruptores, híbrido e zona tranquila. Os andares especiais de caixas são pequenas salas desenhadas à mão/refletidas por seed, verificadas por um solver limitado; o WFC não é usado para inventar livremente cada tabuleiro Sokoban.

O jogador e Lia são esferas desenhadas com uma linguagem comum; Lia usa paleta rosa/violeta. A aparição com Capturador e jaula no andar 5, os seis chefes de xadrez, o Guardião, a árvore de 36 habilidades, corações, três campanhas, diário de andares, câmaras ambientais e a Instalação Submersa estão presentes no código/documentação. A campanha pode continuar além de 200; o resgate está associado ao andar 100.

## Diferença entre a intenção e a implementação

O proprietário especificou um andar diferenciado a cada seis, com Sokoban, outros modos e híbridos. A implementação atual agenda especiais em intervalos pseudoaleatórios de 3–9 andares, preservando andares de chefe, Guardião e o marco opcional de corrente. Assim, a variedade existe, mas o ritmo não cumpre literalmente a cadência de seis. Alterar isso requer escolher como tratar esses marcos.

O Sokoban atual aceita até duas caixas e combina placas, materiais e circuito em alguns tipos de sala; o solver cobre as regras modeladas, não inimigos, correntes, armadilhas, diversão ou todas as combinações futuras. Uma busca interrompida ou mapa rejeitado cai para WFC. Os testes provam casos codificados, não qualidade estratégica. A queixa anterior de corredores continua a merecer revisão de mapas exemplares: os testes exigem quartos e um mínimo de espaço transitável, mas não medem decisões interessantes nem espaço de manobra por sala.

## Arquitetura e conteúdo

O projeto usa GDScript e tem módulos separados para WFC, regras ambientais, agenda e puzzles especiais, armazenamento, habilidades, feedback, movimento visual e renderização do terreno. Porém, `game.gd` ainda tem 7.144 linhas e 248 funções; `hud.gd` tem 1.270 linhas. `main.tscn` contém apenas o nó raiz; cenário, atores, HUD e muitos elementos são compostos/desenhados por código. A colisão principal é lógica de grelha, não uma cena editável de TileMap/CharacterBody2D. Isto funciona para a regra atual, mas ainda não entrega a edição visual por nodes que o proprietário pretendia. Uma refatoração de cenas seria estrutural e deve ser planeada antes de começar.

Há SVGs dos seis chefes e da história, uma imagem de fundo e duas faixas WAV (tema e camada de ameaça); muitos elementos do tabuleiro, esferas, inimigos, menus e VFX são desenhados em GDScript. Existem sons de ação sintetizados. Não há 25 bolas/personagens jogáveis, loja ou cosméticos jogáveis; esses itens encontrados em notas antigas são propostas, não sistemas atuais. A música e o mix ainda não foram aprovados por escuta humana.

## Validação feita nesta auditoria

Godot oficial `4.7.2.stable.official.ed1daf0bf`: importação headless sem erros de script; 15 suites lógicas passaram: self-test, ambiente, instalação submersa, apresentação e geometria de mecanismos, apresentação elétrica, conteúdos especiais, integração, comandos, feedback tático, regressão de performance, movimento expressivo, combate, árvore de habilidades e armazenamento de campanhas. As mensagens da integração/armazenamento são avisos esperados de falha de gravação, perfil futuro e migração em conflito; as suites passaram.

Também passaram as varreduras 1–10 com 2 seeds/bots (2.752 ações), 25–35 com 1 seed/bot (1.286 ações), e geração dos andares 100 e 200. O maior tempo observado nesta execução foi 1.607 ms no andar 28; não é benchmark de FPS nem medida em hardware-alvo. Os testes gráficos não foram repetidos nesta auditoria; há capturas e resultados históricos do renderer Web/SwiftShader em `docs/evidencias-*`. Nada aqui valida beleza, clareza, diversão, áudio audível, comando físico ou equilíbrio.

## O que está desalinhado ou por decidir

1. Fixar a cadência de níveis especiais e a relação entre Sokoban, híbridos e marcos de chefe.
2. Rever mapas reais em jogo para identificar salas estreitas, caminhos sem propósito e interruptores que parecem apenas prolongar a rota; solver e conectividade não respondem a isso.
3. **Resolvido pelo proprietário:** arquitetura editável no Godot passa a ser a prioridade máxima. A direção e a primeira fatia proposta estão em [PLANO_ARQUITETURA_EDITAVEL_GODOT.md](PLANO_ARQUITETURA_EDITAVEL_GODOT.md); a tecnologia de cada peça ainda não foi aprovada.
4. Rever UI, personagens, inimigos e materiais com o proprietário; relatórios e testes técnicos não anulam as rejeições visuais já registadas no checkpoint.
5. Rever se repetir andares pode conceder moedas/pickups novamente e como isso afeta estrelas, habilidades e economia. A documentação marca esse equilíbrio como desconhecido.

## Contexto e próximo passo

O checkpoint vivo e várias páginas do ai-memory descreviam uma branch ou uma revisão anterior. O estado detalhado da arquitetura aprovada e implementada depois desta fotografia está abaixo e no [plano editável do Godot](PLANO_ARQUITETURA_EDITAVEL_GODOT.md).

## Atualização posterior — arquitetura editável, 5 de novembro de 2026

O proprietário aprovou a **reformulação integral da arquitetura para edição no Godot**, autorizou trabalho local e pediu que não se limitasse a demonstração ou uma única fatia. A meta é o jogo inteiro: níveis/WFC, biomas/terreno, atores, mecanismos, itens, combate/economia, interface, áudio/VFX, opções e persistência. O método continua faseado para não quebrar a versão funcional; não fazer commit/push sem pedido.

Desde a fotografia acima, foram adicionadas Scenes para componentes de mecanismos, um blueprint manual com ligações por ID, validação e Resources editáveis para peças WFC. Esta tarefa acrescentou Resources independentes para 5 biomas, 6 bosses, 6 inimigos comuns e 4 poderes, ligados ao fluxo ativo. `game.gd` continua monolítico e personagens, cenas de atores, HUD, menus, WFC assembler e várias famílias ainda não são integralmente editáveis; ver a matriz do plano e [guia de autoria](COMO_EDITAR_CONTEUDO_NO_GODOT.md).

Validação adicional no Godot oficial 4.7.2 headless: `CONTENT_CATALOG_PASS` (13), `COMPONENT_ARCHITECTURE_PASS`, `SELFTEST_PASS`, `SPECIAL_CONTENT_TEST_PASS` (12.242), `ENVIRONMENT_TEST_PASS`, `CAMPAIGN_STORAGE_TEST_PASS` (191), `PERFORMANCE_REGRESSION_PASS` e `SWEEP_PASS` (5.889 ações). A inspeção visual dos novos Resources no Inspector, playtest humano, áudio audível e GPU real continuam por fazer. Não houve commit ou push.

### Verificação posterior — ligação bioma/WFC, 5 de novembro de 2026

Cada `BiomeDefinition` agora referencia um `WfcTileSet`, e `game.gd` passa-o ao gerador para cada andar. Os cinco biomas usam o mesmo `wfc_default_tile_set.tres`; a mudança torna a escolha editável sem alterar a composição atual. A validação do catálogo rejeita conjuntos sem `build_tables()` ou com IDs/máscaras inválidos. Um teste com seed fixa compara o dicionário completo gerado pelo caminho antigo e pelo Resource ligado; os resultados são iguais.

No Godot oficial 4.7.2, importação e suites `CONTENT_CATALOG_PASS` (14), `SELFTEST_PASS`, `COMPONENT_ARCHITECTURE_PASS`, `PERFORMANCE_REGRESSION_PASS` e `CAMPAIGN_STORAGE_TEST_PASS` (191) passaram. Esta revisão não executou os sweeps, os testes gráficos, Inspector visual nem playtest humano. O WFC ainda não instancia a biblioteca funcional de peças dos blueprints; consultar o plano de arquitetura.

### Verificação posterior — perfis WFC editáveis por bioma, 5 de novembro de 2026

Os cinco perfis antes embutidos em `level_generator.gd` foram migrados para `WfcRoomProfile` Resources e ligados ao respetivo bioma. O gerador usa os Resources para quantidade/dimensão de salas, largura de ligações, chance de rotas extras e layout da arena; os valores originais foram preservados. `GameContentCatalog.validate()` valida TileSets e perfis antes de usar conteúdo. Seeds, algoritmo de turnos e dados persistidos não foram alterados por esta migração.

Godot oficial 4.7.2: importação, `CONTENT_CATALOG_PASS` (15), `SELFTEST_PASS`, `COMPONENT_ARCHITECTURE_PASS`, `PERFORMANCE_REGRESSION_PASS`, `CAMPAIGN_STORAGE_TEST_PASS` (191) e sweep 1–10 com duas seeds/bots passaram. Renderização, inspeção visual do Inspector, áudio e playtest humano não foram repetidos. A composição WFC ainda não instancia mecanismos ou cenas funcionais por célula.
