# Combate, impactos e materiais — relatório de implementação

**Data:** 4 de novembro de 2026

**Estado:** alterações locais na branch de trabalho; ainda requerem avaliação humana de sensação, áudio e acessibilidade.

## O que mudou

- A resolução de movimento, colisão, danos, recursos e turnos continua imediata. O evento semântico é emitido uma vez no momento lógico; quando apropriado, apenas o som, a vibração e o desenho do contacto aguardam a chegada visual. A interface pode refletir a consequência lógica antes da conclusão da animação.
- Bloqueios, empurrões, escudo, perda de coração, eletricidade, ataques e demolição têm respostas específicas de direção, peso e material. A bola aproxima visualmente o corpo de uma caixa sem alterar os centros lógicos. Pedra, vidro, metal, gelo e energia usam fragmentos distintos. A casa já aberta não é coberta por uma parede sólida falsa.
- Inimigos mostram pose de ataque apenas para um movimento **já resolvido**. As apresentações de Hunter, Rusher, Sentinela, Wisp, Guardião e cavalo conservam diferenças; `next` e `path` não são desenhados. Na derrota, uma silhueta temporária não interativa preserva a identidade do ator até ao contacto e depois se dissipa. Não altera colisões, recompensas ou turnos.
- O **hitstop é somente visual**: não pausa a SceneTree, input, regras, temporizadores reais, áudio nem háptica. Contactos importantes usam durações entre 28 e 80 ms; o limite absoluto por sequência é 100 ms, com um intervalo de proteção. Empurrões de madeira e recolhas comuns não causam hitstop. A lista de efeitos e o atraso de contacto são limitados; perante excesso, a decoração pode ser descartada, mas um som/vibração associado a um evento já emitido é apresentado uma vez.
- Em pausa, reinício e mudança de andar, contactos pendentes não voltam a ser desenhados ou reproduzidos ao regressar; os respetivos sinais pendentes são entregues uma vez antes de limpar a apresentação. Um inimigo que chega a um jogador parado termina a aproximação antes do recuo visual de escudo ou coração. A posição e o dano continuam resolvidos imediatamente.
- O RNG de partículas e câmara foi separado do RNG das decisões. Isso evita que os novos efeitos alterem as decisões seguintes, mas **não garante uma sequência histórica bit a bit igual** à de versões que consumiam o mesmo RNG para efeitos e jogo.

A fila normal de movimento visual permanece limitada a três segmentos e cerca de 0,24 s. Um recuo de coração pode conservar a espera pelo contacto e mais um passo, até cerca de 0,44 s; uma nova sobrecarga pode antecipar ou substituir segmentos antigos. Não é uma fila de comandos nem bloqueia input. Em condições extremas pode haver salto visual transitório; a apresentação converge para o estado resolvido.

## Verificação executada

| Resultado | Teste e âmbito |
|---|---|
| PASS | `combat_feel_test.gd`: **90 verificações**, incluindo 100 contactos em sobrecarga, recuos consecutivos, ordem de eventos/sons, pausas, mudança de andar, captura, aproximação e recuperação. Compara ainda dez checkpoints lógicos e eventos de combate entre zero frames de apresentação e simulações a 30, 60 e 144 Hz. Não é comparação exaustiva com uma versão histórica. |
| PASS | `expressive_movement_test.gd`: **200 verificações** de movimento, materiais, caixas, inimigos, interrupções e RNG. |
| PASS | `special_content_test.gd`: **12.232 verificações** de agenda, câmaras, circuitos, ações e reset. |
| PASS | `self_test.gd`, `environment_test.gd`, `controller_test.gd`, `tactical_feedback_test.gd`, `performance_regression_test.gd`, `skill_tree_test.gd` (**379**) e `campaign_storage_test.gd` (**191**). O self-test foi atualizado para aguardar o contacto antes de verificar o arco do recuo; inicialmente ainda esperava o recuo visual antecipado. |
| PASS | Sweep dos andares **1–80**, duas seeds por andar e bots, **5.884 ações**; andares 100, 200 e 1000 com duas seeds cada, sem bots. |
| PASS | `combat_render_test.gd`: **91 verificações** e **51 capturas**, usando o PCK exportado com os recursos reais, Godot Web 4.7.2, Chromium, WebGL2/SwiftShader e áudio Dummy. Inclui antes/contacto/recuperação, materiais, caixas, quatro silhuetas derrotadas, seis ataques resolvidos, escudo, água eletrificada, coração e captura. |
| PASS | No mesmo renderer Web: `environment_render_test.gd` (**4**), `enemy_intention_render_test.gd` (**26**) e `skill_tree_render_test.gd` (**66**). O teste de intenção verifica oito famílias e que mudar `next`/`path` não altera os pixels. |
| PASS | O ZIP foi extraído e o launcher Linux foi exercitado em modo **headless** com o binário local; o teste de combate voltou a passar no projeto extraído. Isto não valida uma sessão gráfica de jogo nem o launcher Windows. |

Os testes headless foram executados individualmente com uma compilação local Godot 4.7.2 sem X11, fontconfig e servidores de física. Os testes não dependem da física do motor; o binário emitiu avisos de servidores Dummy. A importação e a exportação terminaram, sem erros de parsing de scripts, mas o editor emitiu **dez erros de fontconfig ausente**. Portanto, esta sessão não demonstra uma importação limpa nem executou o runner oficial completo de ponta a ponta com esse binário. O workflow foi preparado para usar Godot oficial e Xvfb, mas as alterações locais ainda não foram enviadas para CI.

O pacote de entrega inclui as capturas em `Evidencias/Combate/`, seis GIFs de aproximação em `Evidencias/Animacoes/` e os logs em `Evidencias/Logs/`. Os GIFs agrupam esses frames reais com pausas deliberadamente alongadas; não são gravações em tempo real nem aprovação estética. O runtime Web de teste foi apenas temporário e não acompanha o pacote.

## Limitações

- **Não testado:** áudio audível/mistura, vibração ou comando físicos, sessão de jogadores, conforto de flashes/tremor, Windows, exportação nativa e desempenho/FPS em hardware do proprietário. O driver Dummy confirma eventos simulados, não o som ou a vibração reais.
- O renderer SwiftShader é software; os seus tempos não são uma previsão de GPU. O teste de regressão de performance verifica invariantes, não demonstra uma meta de FPS.
- Os lançadores Windows e Linux abrem o **projeto-fonte** com Godot 4.7.2; não são binários nativos exportados. O Windows não foi validado nesta sessão.
- A continuidade dos checkpoints e das regras foi coberta pelos testes descritos, não por uma prova exaustiva de equivalência. O `RELATORIO_EXPRESSIVE_MOVEMENT_V1.md` é histórico e descreve uma versão anterior.

## Repetir

Com Godot oficial 4.7.2 instalado e os recursos importados:

```sh
GODOT=/caminho/para/godot tools/test-godot.sh
# Com X11 e GL Compatibility; COMBAT_RENDER_TEST_OUT é opcional:
COMBAT_RENDER_TEST_OUT=/tmp/ctm-combate GODOT=/caminho/para/godot tools/test-godot.sh --graphics
```

Os testes gráficos exigem renderer real e recusam `--headless`. O workflow `.github/workflows/godot-tests.yml` contém o exemplo com Xvfb e guarda os PNGs como artefacto.
