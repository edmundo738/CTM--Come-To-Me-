# Game Feel integrado — implementação, evidência e limites

**Data:** 4 de novembro de 2026

**Estado:** alterações locais integradas para avaliação; não é aprovação artística, teste de áudio real nem exportação final. O checkpoint vivo é `CHECKPOINT_GAME_FEEL.md`.

## 1. Como esta revisão tratou as versões

O código anterior disponível e o trabalho recente foram confrontados com o guia de gameplay e com o projeto atual. O trabalho integra e aperfeiçoa; não restaura cegamente um estado anterior nem considera uma funcionalidade ausente sem inspeção.

| Decisão | Implementação e consequência |
|---|---|
| **PRESERVAR** | Os raios ramificados recentes, o marcador de fonte, regras de condução, colisões, turnos, sons e respostas úteis continuam a existir. As regras por grelha continuam a ser a autoridade. |
| **CORRIGIR** | A textura iluminada da bola deixa de girar com o deslocamento; mantém deformação e uma marca superficial móvel. Um ajuste exclusivamente visual separa bola e criatura num contacto de escudo quando existe recuo legal, sem alterar posições lógicas ou inventar passagem por paredes. |
| **APERFEIÇOAR** | Contactos de empurrão, bloqueio, demolição e ataque têm resposta local por material; câmara e hitstop são proporcionais e a resolução lógica não espera pela animação. Fragmentos distinguem parede, vidro, metal, gelo e papéis de criaturas. |
| **COMPLEMENTAR** | Os raios existentes recebem luz local quente, pequenas partículas no mesmo pulso e um estalo espacial discreto, limitado e dependente de uma descarga forte. O som original pode continuar como camada mais baixa sob os novos sons de contacto. |
| **SUBSTITUIR seletivamente** | No contacto de escudo, o antigo V/seta de feedback dá lugar a superfícies curvas; não se substituem colisões ou pistas essenciais de perigo por um indicador direcional. As correntes continuam sem setas artificiais. |
| **CRIAR / INTEGRAR** | `electric_presentation.gd` liga arcos, luz e áudio à mesma condução existente; testes específicos, um microbenchmark e ferramentas de evidência permitem verificar a integração sem consumir RNG de jogo. |

Não se altera o propósito de placas opcionais apenas para lhes acrescentar efeitos: ainda é necessária uma avaliação de design das decisões e recompensas que oferecem.

## 2. Eletricidade, bola e contacto

**FACT:** `environment.powered` decide que água e metal conduzem. A geometria e a opacidade dos arcos são calculadas por `environment_vfx.gd`; a luz acompanha essa geometria e essa fase, apaga quando a condução termina e afeta o mundo, não o HUD. Até quatro luzes são atribuídas aos condutores visíveis mais próximos do jogador. A geometria das luzes é calculada apenas para os quatro selecionados; os arcos de todos os condutores continuam a ser desenhados.

**FACT:** os pequenos motes são determinísticos e aparecem em descargas fortes; o estalo é espacial, usa o listener junto da bola, respeita mute e pausa e tem intervalo global de pelo menos 0,85 s. Por causa do limite de frequência, **não** é um som para cada descarga. As camadas de som preservadas não criam um segundo evento lógico nem uma segunda resposta háptica.

**MEASURED:** no mesmo cenário gráfico, ao ligar/desligar apenas as luzes, as diferenças de luminância média normalizada foram **0,02685** na amostra da bola, **0,04858** no piso, **0,03499** numa criatura e **0,17279** na caixa metálica; as amostras distante e do HUD foram **0,0**. São regiões de teste, não uma medida geral de visibilidade ou de conforto.

**MEASURED:** durante a mesma pose intermédia de movimento, alterar o ângulo acumulado de 0° para 90° manteve a diferença da região do reflexo em **0,0** para movimento horizontal e vertical; a marca superficial alterou, respetivamente, **53** e **46** pixels na área da bola. Um controlo negativo, que fez deliberadamente a textura iluminada rodar apenas no staging, foi rejeitado pelo teste nos dois eixos; a versão correta foi restaurada e repetida. Isto não demonstra todas as poses, velocidades ou condições de luz.

**OBSERVED:** nas capturas de contacto, a bola e um Hunter aparecem lado a lado; uma captura de controlo sem inimigo mostra a contribuição da criatura. O Guardião também está visível no contacto capturado. Nas sequências são visíveis deslocamento da bola, caixas de madeira/metal, recuo de escudo, fragmentos e descargas. **INFERRED:** a separação visual corrige a ocultação observada nestes casos; não prova todos os encontros.

**Limite conhecido:** se jogador e inimigo ficarem completamente cercados, a regra existente pode mantê-los na mesma célula. A apresentação não inventa uma saída através de parede; a sobreposição e a sua justiça ainda precisam de avaliação em jogo.

## 3. Avaliação das cinco dimensões

| Dimensão | Evidência disponível | O que não se pode concluir |
|---|---|---|
| **PESO** | Há compressão, inclinação, contacto, deslocação das caixas e tempos de movimento explícitos; as sequências mostram esses estados. A lógica continua imediata. | **UNKNOWN:** se o peso é convincente e responsivo para uma pessoa; peso não deve ser confundido com lentidão. |
| **LEGIBILIDADE** | Arcos iluminam regiões próximas, HUD não foi afetado na amostra, marcador de fonte permanece, a criatura é visível nos contactos capturados e não se desenham trajetórias futuras. | **UNKNOWN:** leitura em todos os cenários, fundos, tamanhos de ecrã ou por pessoas com necessidades visuais diferentes. |
| **IMPACTO** | Contactos desencadeiam partículas, som/câmara e hitstop visual; testes verificam ordem, limites e consequências sem paragem global. Fragmentos variam por material/entidade. | **UNKNOWN:** se a intensidade, o contraste e o tremor são agradáveis e proporcionais durante jogo real. |
| **SATISFAÇÃO** | Há ferramentas para inspecionar movimento, contacto e consequências em conjunto. | **NOT TESTED:** sensação de satisfação, prazer auditivo ou preferência estética de jogadores; não há pontuação honesta sem jogar e ouvir. |
| **INTEGRAÇÃO** | Testes cobrem condução, mute, pausa, limite de luzes, turnos, RNG, colisões, derrota e transições. Sons antigos são preservados como camada quando aplicável. | **UNKNOWN:** mistura com música, conforto, vibração real, comportamento em todas as combinações e performance no dispositivo alvo. |

## 4. Testes e evidência reproduzível

- **MEASURED — lógica nativa:** 11 suites passaram individualmente no Godot 4.7.2 custom headless. Incluem elétrica **37** verificações (com exportação de WAV), movimento **200**, combate **122**, conteúdos especiais **12.232**, árvore **379** e campanhas **191**. As restantes cobrem self-test, ambiente, comandos simulados, feedback tático e regressão lógica de performance. Física e áudio do motor estavam em Dummy.
- **MEASURED — sweeps:** pisos 1–10 com duas seeds/bots e 25–35 com uma seed/bots: **4.038 ações** no total; pisos 100 e 200 também passaram geração sem bots. Não são playtests humanos nem cobrem todas as seeds.
- **MEASURED — renderer:** Godot Web 4.7.2 em Chromium, WebGL2/SwiftShader: ambiente **5**, elétrica **13**, combate **94**, intenções de inimigos **26** e árvore **66** verificações, todas PASS; a lógica elétrica no Web passou **36** sem exportação de áudio. O staging converteu SVGs para PNG e carregou imagens/WAV diretamente; não é um PCK ou exportação nativa final. Áudio Dummy.
- **MEASURED — sequências:** `GAME_FEEL_TIMELINE_PASS` **12**; **107 frames** em sete cenários, com passos simulados de 40 ms. Os GIFs são silenciosos, recortados e não são gravações de uma pessoa a jogar.
- **MEASURED — comparação visual:** seis capturas elétricas antes/depois da otimização tiveram a região central de 320 × 160 pixels idêntica. Os fundos fora dessa região variaram entre execuções; não se afirma identidade da imagem inteira.
- **FACT — áudio para inspeção:** o pacote inclui WAVs isolados gerados pelo sintetizador do jogo e algumas misturas offline aproximadas, identificados como tal. Não são gravações do mixer, música ou áudio espacial em jogo; **não foram ouvidos**.
- **MEASURED — pacote de ensaio:** a integridade e a extração do ZIP foram verificadas; os 168 ficheiros de projeto coincidiam com o worktree. O launcher Linux arrancou em modo headless e a suite elétrica no projeto extraído passou **36** verificações. A importação desse ensaio repetiu os dez erros de fontconfig conhecidos; isto não valida execução gráfica nem Windows.

O ZIP inclui `Evidencias/Capturas`, `Frames`, `Sequencias`, `Audio`, `Logs` e uma cópia explicada do harness usado. Os testes e ferramentas também estão em `Projeto/tests/` e `Projeto/tools/`.

### Microbenchmark de CPU elétrica

Foi medido apenas `update_presentation` num motor custom headless, após 20 chamadas de aquecimento, com **200 chamadas temporizadas** por cenário sintético e a mesma área de teste alargada. A tabela apresenta média e percentil 95 em microssegundos; não inclui renderização, GPU, FPS ou o tempo total do jogo. O estado anterior foi medido numa cópia temporária que diferia na implementação da seleção elétrica.

| Condutores / caixas metálicas | Média antes → depois | P95 antes → depois |
|---|---:|---:|
| 1 / 0 | 42,5 → 51,9 µs | 57 → 70 µs |
| 14 / 0 | 441,2 → 285,3 µs | 498 → 322 µs |
| 180 / 0 | 6.834,2 → 2.855,7 µs | 8.193 → 3.103 µs |
| 400 / 40 | 19.991,4 → 6.399,3 µs | 22.691 → 6.791 µs |

**INFERRED:** a seleção limitada reduz o custo deste componente nos circuitos sintéticos maiores, com pequena sobrecarga para uma única célula. **UNKNOWN:** o impacto em FPS, renderização de todos os arcos ou hardware do jogador; mesmo o cenário de 400 condutores continua a ter custo relevante. A ferramenta `tools/benchmark_electric.gd` é diagnóstica e não impõe um limiar universal.

## 5. Limites e próximos testes humanos

- A importação pelo editor custom terminou com código 0 e sem erros de parsing, mas produziu **dez erros de fontconfig**, avisos de física Dummy e outros avisos do ambiente. O runner oficial completo, que rejeita erros de importação, **não foi declarado PASS** neste ambiente.
- O áudio Dummy e os WAVs produzidos não validam audição, volume, panorâmica, mistura com música ou sincronização percebida. O renderer Web/SwiftShader não valida GPU real, FPS ou exportação final. Windows, comando e vibração físicos não foram testados; a CI não foi executada para estas alterações locais.
- Para avaliação interativa: abrir as câmaras experimentais; ligar/desligar condução com metal; observar bola e criaturas junto aos arcos; comparar caixa de madeira e metal; testar contacto com escudo, ataques e demolição em vários ângulos; repetir com música/efeitos ligados e desligados, pausa e transições. Ouvir com volume confortável e verificar flashes/tremor no dispositivo alvo.
- O projeto e as evidências foram entregues antes do commit; posteriormente o proprietário autorizou um commit local. Não foi solicitado push nem alteração ou merge do PR.
