# Checkpoint vivo — Context-aware Gameplay & Game Feel

**Atualizado:** 4 de novembro de 2026. Este checkpoint distingue implementação, medição e julgamento; não constitui aprovação artística nem validação em hardware do proprietário.

## PROJECT_STATE

- **FACT:** COME TO ME: NEON RUINS é um projeto Godot 4.7.2, com regras por turnos e grelha; a apresentação não é a autoridade das regras. A branch da sessão é `arena/0ff1c63e-ctm-come-to-me`, com PR aberto.
- **FACT:** a base disponível para esta revisão no checkout restaurado foi `f8b8ac7`. O objeto `580bd05`, reportado numa sessão anterior, não estava disponível nesse object store; consultar `git log` e o estado do worktree para o HEAD e as alterações atuais.
- **FACT:** câmaras ambientais e especiais, correntes, gelo, condução, caixas, movimento visual segmentado, contacto, hitstop visual, feedback por material, árvore e persistência coexistem no estado atual. O guia e os relatórios históricos descrevem a intenção e versões anteriores, não substituem a inspeção das fontes.

## PROJECT_DIRECTION

Evolução integrada e cumulativa: compreender e combinar o que era útil nas versões anterior e recente, sem restaurar nem preservar cegamente. Peso não é lentidão. A bola deve manter squash/stretch e rotação superficial sem fazer girar artificialmente a iluminação; caixas devem transmitir força; ameaças devem ter presença, colisão legível e consequências. Impactos, luz, partículas, som e câmara têm de apoiar o mesmo acontecimento, não criar sinais desconexos.

A primeira prioridade é complementar os raios existentes com iluminação local coerente, sincronizada com a descarga e com os condutores realmente ativos; o restante trabalho de game feel permanece parte da visão global.

## LAST_CHECKPOINT

- **FACT — histórico:** `RELATORIO_COMBATE_GAME_FEEL_2026-11-04.md` documenta a versão anterior, incluindo 90 verificações lógicas e 91 gráficas. É histórico, não prova a versão desta sessão.
- **FACT — revisão de contexto:** a leitura do worktree e dos logs revelou que a revisão anterior deste checkpoint ainda dizia que as mudanças eram apenas planeadas; esta versão corrige essa desatualização.

## CURRENT_TASK

O proprietário autorizou reconciliar os históricos e mecânicas do PR #10, testar, publicar a branch sem force push e tentar o merge. A integração local preserva o game feel do HEAD e incorpora seletivamente história, gelo frágil, congelamento ambiental, módulos de Sokoban e ferramentas de desenvolvimento da base. **FACT:** a árvore foi testada como descrito em `RELATORIO_INTEGRACAO_PR10_2026-11-04.md`; estado de Git, CI e merge deve ser confirmado no remoto. A entrega atualizada tem de preceder a confirmação final e o merge, conforme `AGENTS.md`.

## ACTIVE_DESIGN_RULES

- A lógica, input, colisão, custos, turnos e ordem dos eventos continuam imediatos; hitstop é **visual**, limitado e nunca pausa global.
- Não expor trajetórias ou próximas células dos inimigos. Não usar setas para substituir contacto físico, hitstop ou a expressão das correntes. Pistas essenciais de perigo continuam acessíveis.
- Conservar ou integrar sons, câmara, partículas e movimento úteis, em vez de os eliminar para simplificar uma solução. Não julgar uma mecânica concluída apenas porque um teste passa.
- A luz elétrica é local, acompanha a geometria e a fase dos raios visíveis, e extingue-se com o circuito; não ilumina o HUD. O áudio respeita mute e pausa e é limitado em frequência.
- Respeitar o guia `GAME_FEEL_GAMEPLAY_GUIDE.md`; manter checkpoints vivos com FACT, MEASURED, OBSERVED, INFERRED, HYPOTHESIS, UNKNOWN e NOT TESTED quando apropriado. Qualidade percebida pertence ao jogador.

## EXISTING_IMPLEMENTATIONS

| Classificação | Sistema e estado atual |
|---|---|
| PRESERVAR / COMPLEMENTAR | `environment_vfx.gd` conserva os canais ramificados existentes; acrescenta até dois pequenos motes determinísticos nos picos da mesma descarga. A fonte de condução continua a ser `environment_system.gd`. |
| CRIAR / INTEGRAR | `electric_presentation.gd` usa um pool de quatro `PointLight2D`, escolhidos perto do jogador, com posição e energia derivadas dos arcos, sem consumir RNG de jogo. A luz aplica-se à camada de mundo; o ícone da fonte permanece e o arco é desenhado por cima. A seleção mantém apenas as quatro candidatas mais próximas antes de calcular a geometria das luzes; todos os arcos continuam desenhados. |
| CRIAR / INTEGRAR | `audio_feedback.gd` sintetiza um estalo espacial; o listener acompanha a bola, há cooldown global de 0,85 s, limiar de arco visível e respeito por mute/pausa. O código e um WAV foram produzidos; qualidade audível e mistura não foram avaliadas. |
| CORRIGIR / APERFEIÇOAR | A textura da bola já não roda juntamente com o reflexo incorporado; deformação mantém-se e uma marca superficial discreta acompanha o movimento. O teste gráfico cobre repouso e uma pose intermédia de movimento nos eixos horizontal e vertical, com controlo negativo. |
| APERFEIÇOAR | Contacto de escudo usa superfícies curvas em vez de V/seta; empurrões usam contacto e fragmentos de material. Os novos sons de material/escudo podem combinar o corpo sonoro anterior em camada 10 dB mais baixa, sem duplicar o evento lógico ou háptico. |
| APERFEIÇOAR | O tremor volta a estar ligado ao contacto em bloqueios, empurrões e impactos, com magnitude contextual. Um impacto pequeno posterior não herda a força de um tremor pesado já terminado. Eventos distantes e fora de ecrã não causam flash/tremor global. |
| CORRIGIR / PRESERVAR | Uma separação **apenas de desenho** impede que a bola esconda o inimigo durante um contacto de escudo com recuo disponível; cobre inimigos comuns, Guardião e cavalo. Os centros lógicos, destino, dano e turno não mudam. Sem espaço legal, a sobreposição lógica anterior é mantida, sem inventar passagem por paredes. |
| APERFEIÇOAR | As derrotas mantêm identidade por papel e usam fragmentos distintos de placas, aros, estilhaços e motes; paredes mantêm distinção entre pedra, vidro, metal, gelo e energia. |
| INVESTIGAR | Placas opcionais de escudo e demais mecânicas precisam de avaliação pelo propósito e pelas decisões oferecidas; não alterar as suas regras precipitadamente. |

## LATEST_CHANGES

- **FACT — integração:** a introdução de Lia no andar 5 é opcionalmente guardada por campanha, bloqueia movimentos e pode ser avançada; o resgate do andar 100 é contabilizado uma única vez. O sandbox de F1 isola gravações e restaura a campanha; um recorde legítimo pendente é guardado ou a entrada é recusada.
- **FACT — ambiente:** Congelar Tempo suspende corrente para a bola e madeira, protege a bola de eletricidade e não desativa armadilhas nem o circuito. Gelo frágil parte na terceira ação sobre a casa, com estado em `environment.cells`.
- **FACT — Sokoban:** os módulos da base usam o agendador, solver, caixas e placas já existentes. Desfazer é limitado a 128 snapshots e restaura estado, pickups, recursos, contadores e RNG; Blink, salto e demolição mantêm-se. O par de empurrões dos modelos não altera a pontuação e desafios anteriores.
- **FACT:** implementação e integração de luz, partículas e áudio elétrico; listener posicionado no jogador; limpeza dos recursos nas transições; desenho do arco por cima do marcador da fonte.
- **FACT:** correção do reflexo da bola, marcas de contacto sem setas, partículas e camadas de som, resposta de câmara, preservação das silhuetas de criaturas durante escudo e testes dedicados.
- **FACT:** adicionados `tests/electric_presentation_test.gd`, `tests/electric_render_test.gd`, ampliações de combate/ambiente, integração no runner e workflow, e `tools/game_feel_timeline.gd` para sequências reproduzíveis.
- **FACT:** a seleção elétrica foi otimizada com índice de caixas e top-4 determinístico; um teste a compara com a seleção por ordenação completa em circuitos densos, posições/vistas variadas, caixa móvel e caixas sobrepostas.
- **FACT:** criadas sete sequências silenciosas capturadas pelo renderer, com passos simulados de 40 ms, e WAVs sintetizados/combinações offline explicitamente identificados. `tools/export_game_feel_audio.gd` e `tools/benchmark_electric.gd` reproduzem as amostras e a medição de CPU, não uma gravação ou teste de FPS.

## KNOWN_PROBLEMS

- **OBSERVED:** antes da correção, a captura de contacto de escudo mostrava a bola quase a ocultar por completo o Hunter; depois, a bola e a criatura aparecem lado a lado. O Guardião também ficou visível. Isto demonstra os cenários capturados, não todas as situações de combate.
- **FACT:** quando o jogador e inimigo ficam completamente cercados, a regra anterior pode manter os dois na mesma célula, com proteção contra dano repetido. A nova apresentação não inventa um recuo através de parede; a sobreposição nesse caso continua possível e exige avaliação de design.
- **MEASURED / HYPOTHESIS:** a otimização reduziu o custo de seleção num microbenchmark sintético, mas ainda se percorrem condutores e o pior cenário medido continua relevante. O custo de desenhar todos os arcos, FPS e impacto no hardware do proprietário são desconhecidos.
- **UNKNOWN:** qualidade e audibilidade da mistura, sensação de peso/responsividade, conforto dos flashes/tremores, justiça em jogo real e clareza das animações para o proprietário.
- **NOT TESTED:** Windows, comando/vibração físicos, GPU real, performance/FPS no dispositivo alvo, experiência de jogadores, exportação nativa e CI das alterações locais.

## FAILED_EXPERIMENTS

- **FACT:** a compilação Godot custom com `disable_3d=yes` para editor foi recusada; a compilação seguinte concluiu. Ela não tem fontconfig nem servidores de física reais.
- **FACT:** a importação pelo editor custom terminou com exit 0 e sem erros de parsing dos scripts, mas emitiu dez erros de fontconfig e avisos de física Dummy. Não chamar a importação limpa nem a execução do runner oficial de ponta a ponta um PASS.
- **FACT:** no primeiro staging Web faltavam SVGs originais e o diretório `.godot`, causando falha do self-test; corrigidos os ficheiros temporários, o self-test passou. Houve também um erro real de inferência em GDScript, corrigido antes dos testes finais.
- **FACT:** o primeiro ensaio de luz mediu uma cena antes de a câmara/chunks estabilizarem; descartado e repetido com aquecimento. Um teste inicial usava a variável errada da rotação; corrigido para `player_roll_angle` antes do resultado final.
- **FACT:** WebGL/SwiftShader e áudio Dummy não demonstram áudio audível nem performance em GPU real. Links internos `sandbox:` não satisfazem a necessidade do proprietário de um link HTTPS clicável.

## LATEST_EVIDENCE

- **MEASURED — integração atual:** 12 suites nativas e quatro sweeps passaram, incluindo `MERGE_INTEGRATION_TEST_PASS` **74**, `SPECIAL_CONTENT_TEST_PASS` **12.242**, performance com snapshots originais e determinismo ambiental, campanhas **191** e combate **122**. O teste de comandos foi ajustado para sair do sandbox antes de fabricar progresso de campanha; passou após a correção.
- **MEASURED — renderer atual:** Web/Chromium/SwiftShader: cena de Lia, avançar, desfazer e indicador dev **14**, ambiente **5**, elétrica **13**, combate **94**, intenções **26**, árvore **66**; teste lógico de apresentação elétrica **36**, todos PASS. A cena alterou **80.887 pixels** face ao controlo na captura 1280×720. SVGs foram rasterizados e recursos carregados diretamente apenas no staging temporário, não no projeto.
- **FACT — limites atuais:** a importação do Godot custom terminou com código 0 mas dez erros de fontconfig; física e áudio nativos Dummy. A execução individual não é um PASS do runner estrito, que corretamente rejeita esses erros. Testes Web tiveram avisos de áudio. CI no commit integrado, audição, Windows, dispositivos físicos, GPU e teste humano são verificações distintas.
- **HISTÓRICO:** os resultados de game feel e pacote anteriores, registados abaixo, não substituem os testes do estado integrado.
- **MEASURED — lógica nativa:** após a otimização, 11 suites passaram individualmente no Godot 4.7.2 custom headless, incluindo `ELECTRIC_PRESENTATION_TEST_PASS` **37** verificações com exportação de WAV, `COMBAT_FEEL_TEST_PASS` **122**, `EXPRESSIVE_MOVEMENT_TEST_PASS` **200**, conteúdos especiais **12.232**, árvore **379** e campanhas **191**. Física e áudio do motor estavam em Dummy; estas regras não dependem da física do motor.
- **MEASURED — sweeps:** andares 1–10 com duas seeds e bots (**2.752 ações**), andares 25–35 com uma seed e bots (**1.286 ações**), mais 100 e 200 sem bots: todos `SWEEP_PASS` (**4.038 ações** no total).
- **MEASURED — renderer:** após a otimização, Godot Web 4.7.2, Chromium/WebGL2/SwiftShader: ambiente **5**, luz elétrica **13**, combate **94**, intenções **26**, árvore **66** verificações, todas PASS; lógica elétrica no Web **36**. O staging carregou as mesmas fontes de jogo e recursos, mas converteu os SVGs das peças para PNG e carregou imagens/WAV diretamente; não é um PCK final. Áudio Dummy.
- **MEASURED — luz:** comparação de regiões fixas com o mesmo arco ligado/desligado: diferença média de luminância normalizada de **0,02685** na bola, **0,04858** no piso, **0,03499** numa criatura e **0,17279** na caixa metálica; **0,0** nas amostras distantes e HUD. São medições localizadas, não provas de conforto ou desempenho.
- **MEASURED — movimento:** em poses intermédias horizontal e vertical, a região do reflexo não mudou entre roll 0° e 90°; a marca superficial alterou **53** e **46** pixels. A regressão deliberada de fazer rodar a textura falhou nos dois eixos; restaurou-se a versão correta e repetiram-se os testes.
- **MEASURED — CPU elétrica:** microbenchmark sintético headless, média antes/depois em 200 chamadas: 14 células **441,2 → 285,3 µs**; 180 células **6.834,2 → 2.855,7 µs**; 400 células/40 caixas **19.991,4 → 6.399,3 µs**. Uma célula passou de **42,5 → 51,9 µs**. Não mede renderização, GPU ou FPS. Seis capturas antes/depois tiveram a região central de 320 × 160 pixels idêntica.
- **MEASURED — sequências:** `GAME_FEEL_TIMELINE_PASS` **12** verificações; **107** frames reais em sete cenários, passo simulado de 40 ms. GIFs são silenciosos e têm retenção final de 480 ms; não são gravação de sessão humana.
- **MEASURED — pacote:** ZIP íntegro, com 168 ficheiros de projeto e 232 de evidências extraídos iguais aos respetivos originais; launcher Linux headless iniciou e teste elétrico extraído passou **36** verificações. A importação voltou a emitir dez erros de fontconfig; não valida Windows nem execução gráfica.
- **OBSERVED:** a luz quente é local nos frames de água e metal e o raio existente mantém-se; escudo, bola e inimigo são visíveis no contacto capturado. **INFERRED:** a separação corrige uma causa de ocultação visual, mas não prova todas as colisões.
- **UNKNOWN / NOT TESTED:** audição do jogo, avaliação humana de PESO, LEGIBILIDADE, IMPACTO, SATISFAÇÃO e INTEGRAÇÃO, e os limites de hardware/Windows/CI acima. O relatório detalhado é `RELATORIO_GAME_FEEL_INTEGRADO_2026-11-04.md`.

## NEXT_ACTION

1. Fornecer o ZIP atualizado da integração e pedir confirmação antes do merge; confirmar o estado real do PR e dos checks no GitHub.
2. Após autorização necessária e checks, tentar o merge do PR #10 sem force push e informar o resultado real.
3. Pedir avaliação interativa e auditiva: peso, contactos, flashes, mistura, desempenho e conforto em hardware real; investigar o contacto completamente cercado e o propósito das placas opcionais com essa avaliação.
