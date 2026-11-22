# Checkpoint vivo — Context-aware Gameplay & Game Feel

**Atualizado:** 5 de novembro de 2026. Este checkpoint distingue implementação, medição e julgamento; não constitui aprovação artística nem validação em hardware do proprietário.

## PROJECT_STATE

- **FACT — auditoria atual, 5 de novembro de 2026:** branch local `visual-overhaul-v2`, HEAD `34290e62fc72c45722a2ad5dbb91b4fc04e1111b`, 20 ficheiros rastreados alterados e 93 novos/não rastreados antes desta atualização documental. Não houve commit nem push. Ver [auditoria do estado atual](AUDITORIA_ESTADO_ATUAL_2026-11-05.md).
- **TESTED — auditoria atual:** importação oficial Godot 4.7.2, 15 suites lógicas e quatro sweeps passaram; suites gráficas, hardware real, escuta e playtest humano não foram repetidos. A auditoria detalha marcadores, avisos e limites.
- **FACT:** COME TO ME: NEON RUINS é um projeto Godot 4.7.2, com regras por turnos e grelha; a apresentação não é a autoridade das regras. A varredura de puzzles partiu do commit `bd2f931`, já com o PR #10 fundido; confirmar sempre a branch e o estado atuais com Git e GitHub.
- **FACT — histórico:** uma revisão anterior partiu de `f8b8ac7`, e o objeto `580bd05` não estava disponível no checkout dessa sessão. Esses factos não descrevem, por si só, o estado atual.
- **FACT:** câmaras ambientais e especiais, correntes, gelo, condução, caixas, movimento visual segmentado, contacto, hitstop visual, feedback por material, árvore e persistência coexistem no estado atual. O guia e os relatórios históricos descrevem a intenção e versões anteriores, não substituem a inspeção das fontes.

## PROJECT_DIRECTION

Evolução integrada e cumulativa: compreender e combinar o que era útil nas versões anterior e recente, sem restaurar nem preservar cegamente. Peso não é lentidão. A bola deve manter squash/stretch e rotação superficial sem fazer girar artificialmente a iluminação; caixas devem transmitir força; ameaças devem ter presença, colisão legível e consequências. Impactos, luz, partículas, som e câmara têm de apoiar o mesmo acontecimento, não criar sinais desconexos.

A primeira prioridade é complementar os raios existentes com iluminação local coerente, sincronizada com a descarga e com os condutores realmente ativos; o restante trabalho de game feel permanece parte da visão global.

## LAST_CHECKPOINT

- **FACT — histórico:** `RELATORIO_COMBATE_GAME_FEEL_2026-11-04.md` documenta a versão anterior, incluindo 90 verificações lógicas e 91 gráficas. É histórico, não prova a versão desta sessão.
- **FACT — revisão de contexto:** a leitura do worktree e dos logs revelou que a revisão anterior deste checkpoint ainda dizia que as mudanças eram apenas planeadas; esta versão corrige essa desatualização.

## CURRENT_TASK — Oficina independente (12 de novembro de 2026)

**IMPLEMENTADO:** a antiga janela Tkinter deixou de ser o launcher. `Abrir_Oficina_CTM.cmd` inicia `tools/oficina_web.py`, que serve uma aplicação visual local no navegador usando apenas Python padrão, sem depender do editor Godot nem de recursos externos. A interface mantém o tabuleiro no centro, paleta por famílias, inspetor contextual, seletor de fases 001–200, importação de blueprint/JSON, desenho de paredes, marcadores, colocação e arrasto de inimigos/recolhas/mecanismos, ligações, desfazer/refazer, zoom, redimensionamento, validação, guardar e desligar uma fase com cópia recuperável.

**INTEGRAÇÃO PRESERVADA:** o formato `ctmmap` e `components/external_map_loader.gd` continuam iguais. `game.gd` já consulta mapas externos antes do catálogo Godot; a Oficina não duplicou regras de campanha no navegador. O servidor escuta apenas em `127.0.0.1`, escolhe porta local e recusa pedidos de escrita com origem externa. A gravação mantém `.bak` e desligar cria `.disabled` sem apagar o mapa.

**REFERÊNCIAS DE AUTORIA:** Tiled orientou a área de mapa dominante, pintura e categorias; LDtk orientou peças colocáveis com inspeção contextual; o editor TileMap do Godot confirma o padrão de pintura por grelha. A documentação e os URLs consultados estão em `docs/OFICINA_INDEPENDENTE.md`. Isto é inspiração para fluxo, não importação de formatos ou cópia de jogos.

**TESTED:** `python -m unittest tests.test_oficina_web tests.test_oficina_ctm -v` — 10 passaram; `node --check tools/oficina_web/app.js`; `python -m py_compile tools/oficina_web.py tools/oficina_ctm.py`; Godot 4.7.2 `external_map_loader_test.gd` — 12; `external_map_runtime_test.gd` — 4. No browser, fase 001 abriu com blueprint e 24 peças; fase 007 recebeu uma sentinela e `Desfazer` removeu-a sem gravar no mapa. A inspeção visual a 1366×768 confirmou grelha central e painéis visíveis; texto pequeno ainda merece avaliação do proprietário.

**OBSERVED / NOT ACCEPTANCE:** o novo fluxo é mais espaçoso e funcional que o Tkinter anterior, mas não é aprovação estética do proprietário nem prova de facilidade para principiantes. A navegação no navegador de teste começou a falhar depois da verificação de desfazer; não foi possível completar o retorno visual à fase 001 nessa sessão. Nenhuma alteração de mapa de teste foi guardada na campanha.

**LIMITES:** sem edição de arte/tiles, WFC, água/gelo, armadilhas, camadas de profundidade, regras avançadas ou preview dentro do jogo. Requer Python 3 e navegador. A etapa seguinte deve responder ao uso do proprietário antes de ampliar a Oficina para WFC/ambientes; não presumir que esta revisão resolveu os problemas de UX.
## NEXT_ACTION

1. Proprietário abrir `Abrir_Oficina_CTM.cmd` e usar o mapa sem o guardar, avaliando se a seleção, peças e mover/colocar estão óbvios.
2. Corrigir fricção visual ou operacional indicada no uso real.
3. Só depois construir pré-visualização da fase no jogo e migrar camadas visuais/WFC/ambiente sem quebrar formato de mapa nem saves.
## CHECKPOINT_ARQUITETURA — 5 de novembro de 2026

- **FACT:** o proprietário confirmou que a meta é reformular a arquitetura inteira para autoria no Godot. A execução é faseada para preservar e verificar o jogo; a meta não é limitada à primeira câmara ou a uma fatia de demo. `AGENTS.md`, README e `PLANO_ARQUITETURA_EDITAVEL_GODOT.md` agora dizem isto.
- **IMPLEMENTED:** adicionadas definições `BiomeDefinition`, `BossDefinition`, `EnemyDefinition`, `PowerupDefinition` e `GameContentCatalog` em `content/`, com `.tres` individuais. O jogo ativo usa o catálogo para nomes/tamanhos/crescimento de biomas, escolha/vida/regra/textura/cor/escala/perfil de chefes, perfil de movimento/escala/duração/halo dos inimigos comuns e cor/duração/lista de poderes. Os perfis vêm dos Resources sem acrescentar campos aos dicionários de estado inimigo; assim, não se alterou o formato serializado nem as impressões digitais da geração.
- **PRESERVED:** 5 tamanhos/nome de biomas, crescimento por ciclo, seis chefes a cada cinco andares, HP, arte, cores, poderes/durações e ordem cíclica permanecem equivalentes aos valores anteriores. A simulação de grelha continua a autoridade; nada aqui torna a arte uma regra.
- **TESTED — Godot oficial 4.7.2 headless:** import/editor sem erros; `CONTENT_CATALOG_PASS` (13), `COMPONENT_ARCHITECTURE_PASS`, `SELFTEST_PASS`, `SPECIAL_CONTENT_TEST_PASS` (12.242), `ENVIRONMENT_TEST_PASS`, `CAMPAIGN_STORAGE_TEST_PASS` (191), `PERFORMANCE_REGRESSION_PASS` e `SWEEP_PASS` (5.889 ações). A primeira execução expôs referências de testes às constantes removidas e um campo adicional que mudava hashes; atualizei os testes e removi esse campo do estado, depois repeti self-test, regressão e sweep sem erros.
- **OBSERVED — Inspector nesta fatia:** não confirmado nesta sessão para os Resources de conteúdo. O import e os testes carregam/validam os `.tres`, e o Inspector de mecanismos/blueprint já foi observado anteriormente; a inspeção visual destes novos arrays/recursos continua pendente.
- **NOT TESTED:** playtest humano, áudio, GPU/hardware, renderer gráfico e impacto de alterar valores no Inspector e jogar. Esta migração ainda não moveu os desenhos de personagens/inimigos, cenas de atores, WFC assembler, HUD/menus, parâmetros de economia/habilidades nem o restante jogo para cenas/Resources.
- **CURRENT LIMIT:** a meta integral continua em curso. A tabela de cobertura e critérios está em `PLANO_ARQUITETURA_EDITAVEL_GODOT.md`; passos de edição que já funcionam estão em `COMO_EDITAR_CONTEUDO_NO_GODOT.md`.
