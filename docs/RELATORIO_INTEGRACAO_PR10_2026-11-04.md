# Integração do PR #10 — reconciliação, testes e limites

**Data:** 4 de novembro de 2026

**Âmbito:** integrar as alterações locais de game feel com a branch base `visual-overhaul-v2`, sem apagar o histórico remoto da branch do PR. O proprietário autorizou a reconciliação, testes, push normal e tentativa de merge. O estado do GitHub e dos checks deve ser consultado no momento do merge.

## Históricos e decisões

- A linha de trabalho integra o commit local `5c8f3c2` e o antigo HEAD remoto `514f017` através de `b4ec62e`. A base inspecionada para a resolução era `cb67e75e13c2307addc5fa240cf89d6bb2bc4794`. A integração não requer force push.
- Foram combinados os eventos e sons ambientais e preservados os efeitos de material, luz, contacto e movimento mais recentes. As regras de turno continuam imediatas; a apresentação não passa a decidir colisões.
- A base tinha um estado independente de caixas e uma geração de Sokoban concorrente. Os modelos foram convertidos para o mesmo `EnvironmentSystem`, placas, agenda e solver da versão local. Continuam a existir salto, Blink, demolição e puzzles anteriores; não existe uma segunda autoridade de caixas. Os valores `push_par` dos modelos não substituem as regras de estrelas/desafios anteriores.
- A documentação `PROJECT_STATE.md` regista um checkpoint anterior da base; o README e `CHECKPOINT_GAME_FEEL.md` descrevem a integração atual.

## Funcionalidades integradas

1. **História:** a primeira visita ao andar 5 apresenta o Capturador e Lia, uma esfera da mesma linguagem visual do jogador, com paleta própria. É possível avançar e não se processam ações de jogo durante a cena. A flag é opcional e independente por campanha. O andar 5 não soma um resgate; o 100 soma uma vez, mesmo em revisita.
2. **Sandbox dev:** operações de desenvolvimento isolam gravações, exibem um aviso persistente e restauram a campanha ao sair. Um recorde legítimo pendente é guardado antes da entrada; se o save falhar, a entrada é recusada. A arena limpa objetivos e contadores herdados. Continuar regressa ao checkpoint guardado, não ao mapa experimental.
3. **Freeze e gelo:** congelar suspende a corrente do jogador e da madeira, incluindo a ação de recolha, e protege o jogador da eletricidade; armadilhas e circuito continuam ativos. Gelo frágil explicitamente marcado parte à terceira ação sobre a célula, sem abrir um buraco; depois não desliza nem abranda inimigos. A colocação opcional mantém conectividade e determinismo.
4. **Desfazer:** `Z`, botão no HUD e cancel do comando quando há botão de pausa separado revertem uma ação em Sokoban. São guardados no máximo 128 snapshots: tabuleiro, ambiente, caixas, recursos, pickups, contadores, portal e RNG. O histórico é descartado ao sair ou concluir o andar.

## Verificação desta integração

- **Lógica:** 12 suites nativas individuais PASS no Godot custom 4.7.2. Destaques: integração **74** verificações; conteúdos especiais **12.242**; movimento **200**; combate **122**; árvore **379**; campanhas **191**; elétrica **36**. Também passaram ambiente, comandos, feedback, self-test e regressão de performance. As impressões digitais originais de performance foram preservadas e a verificação de determinismo da base adaptada ao estado ambiental unificado.
- **Geração:** `SWEEP_PASS` para andares 1–10 com duas seeds e bots, 25–35 com uma seed e bots, e andares 100 e 200 sem bots.
- **Gráficos:** Godot Web 4.7.2 em Chromium/WebGL2/SwiftShader: integração **14** verificações (cena, avançar, desfazer e aviso dev em 1280×720 e 800×540), ambiente **5**, eletricidade **13**, combate **94**, intenções **26** e árvore **66**, todos PASS. A captura da cena a 1280×720 alterou **80.887 pixels** face à cena de controlo.
- **Staging Web:** para executar no browser, os SVGs foram rasterizados e os recursos de imagem/áudio carregados diretamente apenas numa cópia temporária; as fontes de jogo usadas são as da árvore integrada. Não é uma exportação oficial do jogo.
- **Limites:** o binário nativo custom usa física e áudio Dummy. A importação terminou com código 0, mas emitiu **dez erros de fontconfig**; portanto não se apresenta o runner estrito de importação como PASS. Os testes Web emitiram avisos de áudio e não são audição. Não foram testados Windows, comando/vibração físicos, GPU alvo, desempenho/FPS, mistura audível ou experiência humana. O CI deve ser verificado no commit realmente publicado.

As capturas e logs específicos desta integração acompanham o ZIP de entrega. Os GIFs e amostras de áudio do trabalho anterior continuam identificados como sequências simuladas silenciosas e áudio sintetizado offline, não como gravações de jogadores.
