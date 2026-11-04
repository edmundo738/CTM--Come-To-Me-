# Auditoria do repositório e diferenças — 4 de novembro de 2026

## Âmbito e referências

Foram lidos os scripts de jogo, interface, geração, ambiente, áudio/feedback, comandos, saves, testes, documentação e protótipos HTML, além do histórico e das branches no GitHub. A referência comum era `f8b8ac7`; a branch desta tarefa tinha `b1c3399` no remoto antes desta atualização, e `visual-overhaul-v2` estava em **`cb67e75e13c2307addc5fa240cf89d6bb2bc4794`**. O `master` consultado estava em `400c853`. Os resultados sobre outra branch são uma fotografia dessa revisão, não uma afirmação sobre alterações futuras.

Classificação: **código** significa que foi inspecionado; **medido** significa que uma execução foi observada; **proposta** é trabalho não entregue; **não testado** não é aprovação. Este relatório complementa, não substitui, a [auditoria histórica](auditoria-e-plano.md), o [guia de game feel](GAME_FEEL_GAMEPLAY_GUIDE.md) e o [relatório Expressive V1](RELATORIO_EXPRESSIVE_MOVEMENT_V1.md).

## O que existe nesta entrega

| Área | Estado real |
|---|---|
| Núcleo | Jogo Godot 4.7.2 por turnos e grelha, gerador WFC, cinco biomas, moedas, desafios, interruptores, runas ordenadas, seis inimigos comuns, Guardião e seis chefes de xadrez. O portal não exige derrotar os chefes. |
| Poderes | Velocidade, íman, Blink e congelamento têm durações/cargas e passam entre pisos; saltar gasta escudo, demolição gasta carga. |
| Ambiente | Madeira e metal empurráveis, corrente, condução elétrica, gelo marcado, placas/portões, quatro câmaras de prática e desafio opcional da campanha. Deslocamento adicional da corrente e do gelo é de no máximo **uma casa por ação** nesta branch. |
| Expressive V1 | Os efeitos visuais apresentam movimentos já resolvidos, com continuidade limitada e respostas por material. A lógica não espera pela animação. Os trajetos/casas futuras dos inimigos não são desenhados; a ameaça é comunicada na própria entidade. |
| Nova progressão | 36 nós funcionais em seis ramos, pontos separados de moedas, dependências, desbloqueio e ativação distintos, corações extras e recuperação. As regras, valores provisórios e abertura dos menus estão em [Árvore e campanhas](ARVORE_E_CAMPANHAS.md). |
| Saves | Três campanhas independentes, checkpoints de início de piso, revisita preservando recursos, migração de perfil antigo, confirmação de substituição e backups restauráveis. Cosméticos jogáveis e uma loja **não** existem. |
| Testes e ferramentas | Suites de gameplay, ambiente, comandos, feedback, geração, movimento expressivo, árvore, armazenamento e duas suites gráficas; launchers do projeto-fonte para Windows e Linux. Não há export nativo Windows incluído. |

## Diferenças que não devem ser perdidas

A branch `visual-overhaul-v2` **não é equivalente** a esta entrega. O seu código em `cb67e75` contém trabalho separado:

1. **Capturador Divino, jaula e Lia:** ativos SVG e código para uma aparição cinematográfica no piso 5, com possibilidade de saltar a sequência. Esses elementos narrativos não foram trazidos para esta branch. Não os eliminar ao reconciliar versões.
2. **Sokoban em curso:** `sokoban_generator.gd` contém dois módulos de caixas/alvos, espelhamento por seed e integração com portal/undo em `game.gd`. Essa implementação não está nesta branch; as nossas câmaras com placas são outro sistema, não equivalem a ela. O README/`PROJECT_STATE.md` dessa revisão ainda diz que Sokoban não existe, embora o código já o esteja a desenvolver. Não chamar o trabalho de pronto ou validado só pela presença dos ficheiros.
3. **Ambiente com regras diferentes:** a outra branch contém gelo frágil com fissuras e deslizamento até à primeira casa segura, e congelamento que suspende corrente e água elétrica. A nossa usa até uma casa adicional de gelo/corrente, caixas de madeira/metal, condução, placas e câmaras, com integração própria. Estas diferenças alteram regras, geração e testes; escolher e combinar deliberadamente antes de fundir. A nossa versão **não** inclui fissuras nem a suspensão ambiental por congelamento.
4. **Esta branch** acrescenta a integração ambiental e suas câmaras, Expressive V1, regras de não mostrar movimento futuro, a árvore, os três slots, migração e testes associados. Trazê-la para a outra sem reconciliação também poderia apagar ou alterar trabalho narrativo/ambiental.

### Estado verificável da outra branch

Uma cópia isolada de `cb67e75` foi importada com o **Godot oficial 4.7.2**. O log apresentou `Function "_draw_sokoban_guide()" not found` em `hud.gd:153` e `Cannot infer the type of "show_minimap"` em `hud.gd:290`. A importação terminou com código 0 **apesar dos erros**. O self-test da cópia reportou erros de compilação e excedeu um limite de 30 segundos. Isto não demonstra que todos os sistemas dessa branch estejam errados, mas impede afirmar que essa revisão arranca ou passa. A CI desta entrega verifica também o conteúdo dos logs, marcadores de sucesso e timeout, não apenas o código de saída.

O [PR #10](https://github.com/edmundo738/CTM--Come-To-Me-/pull/10) já estava aberto para `visual-overhaul-v2` e marcado como conflituoso na consulta. Não foi feito merge automático. Antes de qualquer integração: corrigir o parsing da outra branch; comparar explicitamente as regras ambientais e as alterações sobrepostas em `game.gd`/`hud.gd`; preservar os ativos da história e o Sokoban; depois executar ambas as famílias de testes, cenários de saves antigos e inspeção visual. Só então decidir a resolução do conflito com o proprietário.

## Protótipos HTML e documentação

- `Neon Ruins.html` e `Neon Ruins (1).html` são idênticos: SHA-256 `57af206dd768180a69a4ea86e59d8e402da8ca736c31ea1bf87892ef5701062a`.
- `Neon Ruins (Copy).html` difere no título; `where.html` acrescenta ajustes de toque, direção e interface. São protótipos da mesma ideia, não versões equivalentes do Godot nem substitutos para os sistemas de campanha.
- Documentos de design históricos descrevem propostas, algumas agora parcialmente implementadas. O estado corrente está no README e em [Árvore e campanhas](ARVORE_E_CAMPANHAS.md); transformação/disfarces, teletransportadores de mapa, loja e cosméticos continuam propostas.

## Verificação e limites

**Medido antes dos últimos ajustes de navegação por teclado:** Godot oficial 4.7.2 passou `SELFTEST_PASS`, `ENVIRONMENT_TEST_PASS`, `CONTROLLER_TEST_PASS`, `TACTICAL_FEEDBACK_TEST_PASS`, `PERFORMANCE_REGRESSION_PASS`, `EXPRESSIVE_MOVEMENT_TEST_PASS` (151 verificações), `SKILL_TREE_TEST_PASS` (379) e `CAMPAIGN_STORAGE_TEST_PASS` (186). A varredura passou nos pisos 1–10/duas seeds, 25–35/uma seed, 100 e 200; os bots são invulneráveis e não provam equilíbrio. A suite de armazenamento emite propositadamente dois avisos ao testar versões futuras e conflitos de migração.

Com Xvfb, X11 e OpenGL/llvmpipe, `ENEMY_INTENTION_RENDER_PASS` passou 26 verificações, e `SKILL_TREE_RENDER_PASS` passou 78 com gravação de capturas: tamanhos 800×540 e 1280×720, botões, modais e aviso de save. Estas execuções usaram dados preparados e áudio dummy; não são teste com jogadores. O workflow inclui também regressão para a navegação por teclado adicionada depois dessas medições.

**Em aberto:** equilíbrio dos 36 nós, revisitas que permitem recolher moedas/pickups novamente, qualidade visual avaliada pelo jogador, acessibilidade e desempenho em hardware de destino. O RNG partilhado preexistente entre alguns VFX/tremores e a IA não foi resolvido nesta tarefa; o RNG separado dos pickups de coração não corrige esse problema mais amplo. Windows, áudio audível e vibração física não foram testados. A escrita temporária verificada não garante proteção contra todas as falhas de energia ou de sistema de ficheiros.
