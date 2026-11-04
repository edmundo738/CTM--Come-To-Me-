# Movement & Game Feel — auditoria e proposta localizada

**Data:** 3 de novembro de 2026<br>
**Branch analisada:** `arena/0ff1c63e-ctm-come-to-me` · **HEAD:** `b1c33998b9778aa6246a7bdc15f0ea94ee39d978`<br>
**Decisão de direção fornecida pelo proprietário:** Expressive + Hybrid<br>
**Estado:** proposta para revisão. Nenhuma alteração de código, implementação de movimento ou aprovação de Game Feel nesta etapa.

Este relatório segue o formato do [guia permanente de Game Feel & Gameplay](GAME_FEEL_GAMEPLAY_GUIDE.md). A crítica do proprietário — o movimento e outras ações são tediosos e carecem de personalidade — é o ponto de partida; não é anulada porque a mecânica passa testes.

## PROJECT_STATE

O projeto é Godot 4.7.2, com movimento em grelha e turnos. A referência acima contém `game.gd`, sistema de ambientes, HUD, barramento tático, áudio, comando e cinco suites de teste. As alterações locais desta e da auditoria anterior são documentação, evidências e instruções em `AGENTS.md`; nenhum ficheiro de lógica foi modificado nesta etapa.

A branch `visual-overhaul-v2` inspecionada anteriormente tem outras regras e um `_begin_player_move(next, path)` diferente, além de falhas de parsing no HUD da referência `cb67e75`. Não confundir esse estado com o código da branch atual nem copiar a implementação sem integração revista. O PR #10 já estava aberto e tinha conflitos na inspeção anterior; aqui não foi alterado, fundido ou fechado.

## CURRENT_TASK

Auditar **andar**, identificar o que já existe e o que não comunica suficientemente, e propor uma primeira melhoria com animação expressiva sobre regras discretas. A proposta **não** autoriza implementação e não inclui ataque, IA inimiga, destruição, redesign do HUD, troca global de arte, novas partículas ou mudança do sistema de turnos.

O objetivo é fazer a esfera parecer viva, com intenção e resposta, mesmo num espaço sem combate, mantendo a posição relevante e as consequências claras. Não se propõe acrescentar setas, painéis de turno, linhas piscantes ou avisos como substitutos de uma comunicação melhor.

## EXISTING_IMPLEMENTATION

| Componente atual | **FACT** — referência e comportamento | Limite da evidência |
|---|---|---|
| Entrada por teclado | `game.gd:2925–2929, 3004–3017`: cada pressionamento aceite chama `try_move`; eventos de repetição `echo` são ignorados. | É uma regra de código; não medimos latência de teclado físico. |
| Comando, rato e toque | `controller_input.gd:14–15, 340–348, 416–442` emite a direção inicial e repete com atraso inicial de 320 ms e intervalo de 200 ms; `game.gd:592–618, 2805–2834` encaminha cliques, swipe e comando. | A suite de comando usa dispositivos simulados; não prova sensação em comando físico. Não mudar a repetição nesta unidade sem aprovação. |
| Célula, colisão e turno | `game.gd:1715–1742`: valida a direção e a casa/caixa, atualiza o jogador, emite `MOVE` e resolve o turno. Ação bloqueada não consome turno. | Ações válidas são resolvidas sem esperar o fim da animação; uma fila lógica nova não é pressuposto. |
| Entrada de movimento visual | `game.gd:1755–1759`: `_begin_player_move(next)` recolhe a posição visual corrente, altera `player_position`, define `player_to` e reinicia `player_anim`. | A função hoje participa tanto na atualização lógica como na apresentação. Alterá-la exige preservar esse contrato e todos os seus chamadores. |
| Trajetória | `game.gd:2688–2691, 2908–2911`: duração de 0,115 s por interpolação e curva `smoothstep`, não uma transição linear. | A conclusão ocorre no primeiro frame processado após o tempo; 115 ms não é uma medição de latência de input nem garantia de 60 FPS. |
| Corpo e repouso | `game.gd:4501–4525, 4548–4611`: textura esférica, rotação calculada, arco de até 4 unidades, compressão/extensão, aterragem de 0,12 s, bob vertical, olhos e reação de medo. Sombra e halo já existem. | Não foram encontrados piscar de olhos em idle, fases independentes de antecipação/recuperação nem overshoot posicional na função auditada. A qualidade percebida continua por validar. |
| Gelo e corrente | `game.gd:786–806, 1932–1936`: `_begin_player_move` é chamado outra vez para a casa forçada; perigos e recolhas podem ser resolvidos em ambas. | O percurso visual e o anel precisam acompanhar o resultado sem alterar esta ordem. |
| Anel de turno | `game.gd:1904–1907, 2858–2867`: `TURN_COMMITTED` define a célula do anel antes de deslocações ambientais; o desenho espera visualmente a chegada. | Na sonda de gelo ficou na casa de entrada, não na posição final. Não adicionar outro marcador para esconder o problema. |
| Áudio/háptica | `tactical_feedback.gd:6–9, 59–88`: `MOVE` encaminha `step` e padrão tátil; é emitido antes da resolução completa do turno. | Um evento emitido e um WAV gerado não validam som, sincronismo percebido ou vibração física. |
| Inimigos | `game.gd:1940–1970` recolhe posições e aplica-as no mesmo turno; `2688–2695` avança as interpolações em `_process`, sem esperar uma animação por inimigo. | A sugestão genérica de tornar inimigos simultâneos não demonstra um problema nesta branch e não justifica reescrever IA nesta tarefa. |
| Câmara e outras dependências | `game.gd:2301, 2317, 2756–2774, 3401, 4237–4467`: a posição visual é usada por efeitos de dano/captura, câmara, halo e alguns desenhos de inimigos. Salto usa `_begin_player_move`; Blink deliberadamente fixa logo a posição visual (`1817–1820`). | Uma mudança aparentemente local pode alterar enquadramento, local dos efeitos ou apresentação de salto/Blink, mesmo sem mudar a lógica. |

## OBSERVED_PROBLEM

1. **Trajetórias rápidas podem perder uma casa visualmente.** Em duas ações sintéticas para a direita no mesmo frame, o estado avançou duas casas e dois turnos, enquanto a apresentação foi reorientada diretamente da origem para o destino final, um segmento de 112 unidades concluído na mesma duração configurada de 115 ms. Não houve perda de turno na sonda; a experiência pode esconder a passagem pela casa intermédia.
2. **Uma curva rápida encurta o caminho apresentado.** Com a segunda ação 40 ms após a primeira, a apresentação começou no ponto visual intermédio e seguiu em diagonal para o destino final, em vez de passar pelo centro da primeira casa. Isso não prova passagem lógica por uma parede nem que toda curva seja desagradável; é uma diferença observável entre o percurso lógico e o visual a avaliar junto de obstáculos e perigos.
3. **A rotação não diferencia as quatro direções cardeais na fórmula atual.** Com um deslocamento de uma casa, a fórmula do desenho começa em `+3,294` radianos tanto à direita como à esquerda, em cima ou em baixo, e vai a zero. Os olhos são desenhados separadamente. Não é prova de que o efeito seja impercetível ou necessariamente desagradável, mas não implementa uma orientação de rolamento invertida entre esquerda e direita.
4. **A deformação é aplicada aos mesmos eixos de ecrã.** Durante o passo, `stretch.x` aumenta e `stretch.y` diminui pela mesma regra independentemente da direção. Não existe uma fase posicional de overshoot nem preparação independente no código examinado. **HYPOTHESIS:** isto pode contribuir para uma sensação genérica; necessita de comparação visual e avaliação humana.
5. **O feedback de gelo está deslocado.** No cenário da câmara 3, a posição final foi `(4,4)` mas o anel ficou no centro de `(3,4)`. A caixa/portal também podem atualizar antes de o jogador concluir a interpolação, como documentado na auditoria sensorial. São problemas de causalidade da apresentação, não prova de falha das regras.
6. **Uma ação bloqueada pode sobrepor a reação de aterragem ao passo ainda em curso.** Na sonda, um bloqueio não gastou turno, mas colocou `landing_feedback_time=0,10` com `player_anim≈0,348`. **HYPOTHESIS:** a sobreposição pode confundir peso/contacto; ainda não foi julgada numa sessão humana.
7. **Pausa tem comportamento específico, não um defeito automaticamente provado.** A animação continuou a processar sob o estado `paused` na sonda, enquanto uma nova ação não avançou o turno. Ao retomar, o estado visual podia já estar concluído. Qualquer proposta tem de escolher e testar uma política, sem introduzir animações presas ou ações atrasadas.

## EVIDENCE

### Posição, tempo e direção — sonda controlada

**MEASURED:** teste em cópia descartável do commit, com `game.set_process(false)`, chamadas de ação e passos de tempo simulados. O jogador começou em `(5,5)`, centro `(308,308)`, e andou à direita para `(6,5)`, centro `(364,308)`:

| Tempo simulado | Posição lógica | Centro visual | Observação |
|---:|---|---|---|
| 0 ms | `(6,5)` | `(308,308)` | Turno já resolvido; visual ainda na origem. |
| 16,67 ms | `(6,5)` | `(311,188; 308)` | Avançou cerca de 3,19 unidades de 56. |
| 33,33 ms | `(6,5)` | `(319,387; 308)` | Curva não linear. |
| 57,5 ms | `(6,5)` | `(336; 308)` | Meio do segmento. |
| 115 ms | `(6,5)` | `(364; 308)` | Centro no destino; aterragem inicia. |

A mesma sonda exercitou as quatro direções, duas ações no mesmo frame, curva, inversão, bloqueio durante o passo, gelo, pausa, reset e `echo` do teclado. O marcador `MOVEMENT_PROBE_PASS` significa que as **expectativas de caracterização** foram reproduzidas; algumas expectativas descrevem limitações, portanto **não significa aprovação de Game Feel**. [Log integral](evidencias-movimento-2026-11-03/sonda-movimento.log).

Os valores de rotação no log são cálculo reproduzido da fórmula de `_draw_player()`, não medição independente de ângulo em pixels. As duas ações no mesmo frame são teste de stress sintético, não demonstração de frequência humana ou de latência física.

### Evidência visual

- [Passo atual — GIF reconstruído](evidencias-movimento-2026-11-03/movimento-atual-controlado.gif).
- [Viragem atual — GIF reconstruído](evidencias-movimento-2026-11-03/viragem-atual-controlada.gif).
- [Captura integral antes](evidencias-movimento-2026-11-03/passo-antes.png) e [captura aos 100 ms simulados](evidencias-movimento-2026-11-03/passo-04.png).
- [Janela 800×540 antes do passo](evidencias-movimento-2026-11-03/minimo-antes.png) e [aos 100 ms simulados](evidencias-movimento-2026-11-03/minimo-passo-100ms.png).
- [Log da captura, posições e avisos](evidencias-movimento-2026-11-03/captura-visual.log).
- [Evidência anterior do anel no gelo](evidencias-sensoriais-2026-11-03/05b-gelo-anel.png) e [empurrão/portal](evidencias-sensoriais-2026-11-03/animacao-empurrao-controlada.gif).

**OBSERVED:** a esfera e o cenário são desenhados na execução automatizada, com Godot 4.7.2 e X11/llvmpipe a 1366×768 e 800×540. Os GIFs ampliam um recorte da captura integral a 1366×768. O primeiro usa imagens em instantes de 0 a 150 ms simulados, espaçadas de 25 ms, mostradas a 60 ms por quadro, com pausas; a viragem usa uma primeira ação, outra aos 40 ms e amostras de 30 ms exibidas com pausas. São **reconstruções desaceleradas**, não gravações em tempo real, input real, medição de FPS ou avaliação subjetiva.

**UNKNOWN:** se a versão atual é satisfatória para jogadores; latência real da combinação teclado/comando/ecrã; resultado audível; vibração física; conforto e performance na UHD 620. As imagens de referência fornecidas pelo proprietário não foram inspecionadas aqui e não são assets do projeto.

## PROPOSED_SOLUTION

A implementação abaixo só começa **após aprovação desta proposta**. O objetivo é uma primeira amostra do movimento, não alterar a campanha inteira.

### A. Preservar a decisão imediata

1. Manter `try_move` e a ordem real de validação, colisão, custo, eventos e `_take_turn`. Não criar uma fila de **comandos lógicos** enquanto a regra atual aceita ações imediatamente.
2. Continuar a usar `_begin_player_move` como ponto de entrada compatível e registar apenas o necessário para descrever o caminho visual decidido, incluindo entrada e destino de gelo/corrente. Um dado de apresentação nunca volta a executar uma ação, colisão ou recompensa.
3. Preservar contagem e ordem de `MOVE`, `BLOCKED` e `TURN_COMMITTED`, assim como os sinais sonoros e hápticos existentes. Não atrasar o barramento tático até à aterragem nem disparar um segundo som de passo.

### B. Expressividade da esfera

1. Fazer a resposta corporal começar no primeiro frame disponível. Experimentar uma **antecipação curta que não atrase a regra**, seguida de uma curva de deslocação ajustada para leitura e resposta; testar ease-out ou outra curva, em vez de presumir que uma fórmula é bonita por definição.
2. Separar temporalmente contacto, deslocação e recuperação. Orientar squash/stretch e inclinação pela direção, preservar volume aparente, manter rosto legível e fazer o rolamento respeitar a direção. A esfera não tem pés: não criar um novo corpo ou rig para imitar a referência.
3. Testar uma pequena ultrapassagem **apenas visual** onde não prejudique a leitura de obstáculos; limitar ou omitir junto a paredes, em perigo, Blink, captura e outras transições que o exijam. Não mudar hitbox ou casa.
4. Aproveitar o idle atual; só acrescentar um piscar ou alteração de olhar se melhorar a personagem e não criar processamento ou repetição desnecessários. Não usar a RNG partilhada de gameplay para animação cosmética.
5. Não adicionar tremor de câmara, partículas, marcadores ou flashes ao andar. Preservar a câmara e o som existentes nesta primeira amostra; rever depois com audição real.

**Ponto de partida experimental, não aprovação de valores:** manter os 115 ms existentes como referência inicial e comparar uma preparação de até um frame a 60 Hz, uma chegada curta e uma recuperação discreta. Ajustar ou eliminar estas fases se degradarem a resposta. A duração final depende de observação e teste.

### C. Política explícita para sequência, curva e gelo

- **Lógica:** cada comando aceite resolve imediatamente na ordem atual. A apresentação nunca guarda uma ação para a executar depois.
- **Apresentação:** recomeçar a partir da pose visível, preservar os segmentos cardeais/percursos que a regra realmente percorreu e dar continuidade à orientação. A passagem pelo gelo contém a casa de entrada e a casa final, mas continua a ser uma única ação lógica quando a regra atual assim determina.
- **Coalescência controlada:** passos consecutivos colineares podem partilhar uma transição visual, desde que não apaguem uma consequência crítica. Curvas e contacto relevantes não devem ser transformados numa linha que sugira passagem por obstáculos. A fila, se existir, é **somente visual**, curta, limitada e cancelável; não reproduz áudio nem lógica antiga.
- **Eventos críticos e interrupções:** captura, dano, portal, Blink, reset e mudança de sala têm prioridade sobre animações antigas. A apresentação deve convergir rapidamente ao estado efetivo sem reproduzir passos atrasados ou insinuar posições impossíveis. O anel de turno existente, se mantido, deve corresponder ao significado/local final da ação; não alterar silenciosamente a ordem dos eventos lógicos. Avaliar posteriormente se o anel é necessário, em vez de o eliminar sem teste de leitura.
- **Limite honesto:** se uma sequência não limitada de ações for resolvida antes de qualquer frame, é impossível mostrar todas as etapas em tempo real, com atraso zero e sem qualquer salto. Propõe-se limitar o atraso visual, comprimir segmentos seguros e, em stress extremo, priorizar o estado final sobre uma fila interminável. O comportamento exato no excesso — incluindo eventual salto visual excepcional — precisa de teste e aprovação; não prometer simultaneamente garantias impossíveis nem atrasar os turnos para as fingir.
- **Pausa:** como hoje o visual continua sob o menu de pausa, preservar inicialmente esse comportamento e garantir que não surgem ações atrasadas ao retomar. Se se quiser congelar a apresentação, propor essa mudança separadamente.

### D. Critério de saída da primeira amostra

Só propor expansão depois de ver o passo isolado e sequências rápidas na sala de teste e no jogo, e depois de o proprietário/jogadores julgarem se a personalidade e a resposta melhoraram. Se não melhorar, ajustar ou reverter a amostra, não acrescentar efeitos para esconder a falha.

## ARCHITECTURAL_IMPACT

**Futuros candidatos, não ficheiros alterados agora:**

| Ficheiro/sistema | Impacto proposto | Risco a controlar |
|---|---|---|
| `game.gd:1755–1759` | Preservar `_begin_player_move`, capturar trajetórias e estado de apresentação. | É chamado por andar, deslocação forçada, salto e Blink; não trocar o contrato lógico. |
| `game.gd:2680–2695, 2908–2911, 4501–4611` | Ajustar relógio, interpolação, pose e rotação; reusar textura, olhos e sombra. | Finalização, interrupções, pausa e frame longo; não introduzir RNG ou custo desnecessário. |
| `game.gd:304–328, 698–758, 877–919` | Limpar eventuais estados visuais novos ao reiniciar/trocar de sala. | Sem salvar estado temporário como progresso ou interferir no checkpoint. |
| `game.gd:1904–1907, 2858–2867` | Ajustar apenas a representação do anel existente se continuar a ser usado. | Não mover a emissão do evento nem mudar ordem das consequências sem justificação e testes. |
| `tests/` | Adicionar testes focados na apresentação e em invariantes, após aprovação de implementação. | Não enfraquecer testes atuais para obter PASS; manter limites de captura padrão. |
| `controller_input.gd`, `tactical_feedback.gd`, `audio_feedback.gd`, inimigos e geração | Sem alteração prevista na primeira unidade. | Verificar integrações; uma dependência adicional só entra com justificação e, se estrutural, aprovação. |

## TEST_PLAN

### 1. Regras e entradas

- Executar as cinco suites existentes: `self_test`, `environment_test`, `controller_test`, `tactical_feedback_test` e `performance_regression_test`; manter perfis isolados e inspecionar erros além do código de saída.
- Reproduzir sequências fixas nas quatro direções: uma ação válida produz exatamente um turno e resultado original; bloqueio não gasta turno nem inventa deslocação; evitar repetição ou perda de eventos.
- Testar direita→direita, direita→baixo, direita→esquerda e inputs no mesmo frame, com tempos entre ações maiores/menores que a duração visual. Conferir estados e ordem dos eventos contra o baseline, inclusive inimigos, caixas, recolhas e perigos.
- Testar entrada e casa final de gelo/corrente, bloqueio da casa extra, anel, caixa/placa, dano com escudo, captura e contacto inimigo. Um turno não pode ser executado duas vezes.
- Testar pausa/retoma, reset enquanto a animação está em curso, mudança de sala, frame longo e perda de foco. Confirmar destino final limpo e ausência de ações atrasadas.
- Testar salto e Blink como regressões: ambos partilham a entrada de movimento, mas Blink não deve tornar-se deslizamento através de obstáculos. Preservar testes e custos existentes.
- Verificar teclado sem `echo`, comando simulado incluindo repetição, clique e swipe; confirmar que o som/vibração desligados não alteram regras. Testar o comando físico mais tarde.
- Comparar snapshots lógicos com as mesmas seeds e sequência em diferentes `delta`s. Não introduzir consumo novo de RNG para pose; a partilha preexistente entre RNG visual e criação de inimigos é um risco conhecido e não deve ser declarada resolvida por este teste.

### 2. Apresentação e pessoas

- Capturar antes/depois na mesma cena, resolução, seed, ações e opções; identificar separadamente **gravação em tempo real** e reconstruções por frames. Incluir um passo, as quatro direções, canto, inversão, repetição, parede e gelo.
- Inspecionar continuidade do centro, trajetória, direção e salto de ângulo, eixo do corpo, contacto, convergência à célula final, anel e câmara. Testar 30, 60 e 144 Hz simulados e frames longos; simulação não é prova de FPS físico.
- Testar primeiro sem novos efeitos, depois com o som/vibração atuais ligados e desligados. O projeto ainda não dispõe de uma opção geral de movimento reduzido: não declarar esse caso aprovado; propor e testar a opção numa tarefa apropriada.
- Pedir ao proprietário e a jogadores que experimentem movimento livre de combate e depois um pequeno percurso, sem explicar o que deveriam sentir. Recolher comentários sobre satisfação, rapidez, clareza e esforço; não fabricar notas 0–5. Verificar que quem observa identifica o destino e a direção sem setas extras.
- Testar 1366×768 e 800×540, contraste e formas não dependentes só de cor, som ou movimento. A opção acessível pode necessitar de comunicação adicional; não remover ajuda existente por princípio.

### 3. Performance e regressão

- Mesmo cenário antes/depois, com hardware, OS, driver, resolução, VSync, duração, inputs e opções registados; medir mediana e p95 de frame time e eventuais picos. Repetir com movimento, vários inimigos e efeitos simultâneos.
- Em Windows 11 com i5-8250U / UHD 620 / 12 GB, verificar o objetivo de **60 FPS sempre que possível**. Uma referência aproximada de 60 FPS é 16,67 ms por frame, mas não classificar o resultado sem considerar VSync, distribuição e condições reais.
- Gravar consumo de CPU/GPU e comparar resultados; não chamar uma medição headless ou llvmpipe de teste na UHD 620.

## RESULTS

**Executado nesta etapa:** importação isolada, sonda de caracterização descrita acima e cinco suites da branch atual em perfis separados. Todas terminaram com código 0, sem `SCRIPT ERROR`/`ERROR:` nos logs, com os marcadores:

- `SELFTEST_PASS`
- `ENVIRONMENT_TEST_PASS`
- `CONTROLLER_TEST_PASS`
- `TACTICAL_FEEDBACK_TEST_PASS`
- `PERFORMANCE_REGRESSION_PASS`

Os testes verificam os cenários codificados. Não demonstram satisfação, áudio audível, resposta física do comando ou os futuros critérios de movimento. A sonda e os scripts de captura usados estão no pacote complementar de evidências, apenas para execução numa cópia descartável.

**Não executado:** implementação da proposta, testes de uma nova animação, comparação antes/depois, ensaio com jogadores, audição, vibração física e teste no PC de referência. Nada disso é apresentado como PASS.

## FAILED_EXPERIMENTS

Não houve experimento de implementação de movimento nesta etapa, logo não há uma versão de melhoria falhada ou aprovada. A captura de diagnóstico usou áudio `Dummy` e renderizador por software; o ambiente avisou que não era possível configurar VSync. Uma execução intermediária da captura registou quatro instâncias ObjectDB por libertar ao terminar; a captura final não repetiu esse aviso. A causa/relevância não foi apurada; não o apresentar como fuga confirmada na jogatina normal. O log final não continha erros de script.

## PERFORMANCE

**MEASURED — somente baseline em software:** Godot 4.7.2, X11/Xvfb, Mesa llvmpipe, janela **1366×768**, áudio `Dummy`, arena limpa com inimigos removidos, 20 frames de aquecimento e 80 frames medidos. Foram disparados 10 movimentos sintéticos válidos, um a cada oito frames; 10 turnos foram resolvidos. [Log](evidencias-movimento-2026-11-03/benchmark-1366-software.log).

| Medida | Resultado |
|---|---:|
| Frame mediano | 76,185 ms |
| Frame p95 | 84,462 ms |
| Mínimo / máximo da amostra | 73,615 / 87,734 ms |

Isto caracteriza apenas esta máquina virtual com rasterização por CPU e VSync não configurável. **Não é o FPS nem o desempenho esperado na Intel UHD 620**, e não serve para aprovar 60 FPS. A medição anterior a 1280×720 com percurso diferente está na auditoria sensorial e não é comparação direta.

## NEXT_ACTION

Solicitar aprovação do proprietário para esta primeira unidade. Se aprovada, implementar a menor amostra de movimento Expressive + Hybrid, testar e apresentar projeto atualizado e evidências de antes/depois. Não integrar outras branches nem fazer commit ou PR sem a autorização necessária.
