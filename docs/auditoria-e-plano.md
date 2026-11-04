# Come To Me: Neon Ruins — auditoria e plano de evolução

> **Nota posterior:** esta auditoria e as hipóteses abaixo são históricas. A árvore, corações e três campanhas foram implementados depois da referência: ver [estado atual](ARVORE_E_CAMPANHAS.md) e [comparação de versões](AUDITORIA_REPOSITORIO_2026-11-04.md). A direção atual não permite revelar antecipadamente a trajetória ou próxima casa dos inimigos, exceto necessidade de justiça comprovada; propostas antigas de zonas e percursos anunciados não são autorização para os implementar. Ver [guia atual](GAME_FEEL_GAMEPLAY_GUIDE.md) e [relatório V1](RELATORIO_EXPRESSIVE_MOVEMENT_V1.md).

**Referência auditada:** `8c0841bfd3dffbb3d708bdec7e60febf40a071af` (Godot 4.7.2). A auditoria abaixo descreve essa referência; as alterações posteriores são registadas no checkpoint no fim. O objetivo é melhorar as interações sem deitar fora sistemas funcionais nem lançar todas as funcionalidades de uma vez.

## Como ler as evidências

- **FACT**: verificado no código ou na documentação primária indicada.
- **MEASURED**: resultado de uma execução ou medição identificada.
- **OBSERVED**: visto ou ouvido em execução. Uma inspeção ao código não conta como observação visual.
- **INFERRED**: consequência deduzida do código, ainda não demonstrada em jogo real.
- **HYPOTHESIS**: proposta de design ou solução a experimentar.
- **UNKNOWN / NOT TESTED**: por verificar; nenhum destes estados significa PASS.

**MEASURED:** a referência `8c0841b` passou o [workflow headless oficial](https://github.com/edmundo738/CTM--Come-To-Me-/actions/runs/41595845020), incluindo gameplay, comandos, feedback, regressões de geração/renderização e sweeps. Isso não comprova qualidade visual, som real, GPU nem equilíbrio. O benchmark anterior encontra-se descrito no README e é ilustrativo, não um FPS garantido.

**NOT TESTED:** nesta auditoria não houve janela gráfica, inspeção de pixels, escuta ou teste em hardware de destino. A crítica visual do jogador é aceite; não se declara que água, gelo, bosses ou escudo estejam visualmente aprovados.

## 1. Estado real do projeto

| Sistema | Evidência e estado | Consequência / lacuna |
|---|---|---|
| Estrutura e turnos | **FACT**: `main.tscn` contém um `Node2D` controlado por `game.gd`. O mundo usa uma grelha e desenho 2D próprio, não um TileMap. `_take_turn()` resolve recolhas, armadilhas, interruptores, colisão, movimento dos inimigos, duração dos poderes e portal por ordem. | Reutilizar essa ordem e testar qualquer nova consequência em ações reais; animação não deve aplicar dano adicional. |
| Geração | **FACT**: `level_generator.gd` usa WFC, salas/corredores e seleção adaptativa de entropia. `generate_floor()` coloca objetivos e entidades em células alcançáveis. | Sokoban exige validar estado de caixas e jogador, não apenas conectividade do chão. Não alterar seeds de níveis existentes sem definir compatibilidade. |
| Puzzles | **FACT**: `generate_floor()` cria sequências de três runas em andares `n % 5 == 3`, sem inimigos nem armadilhas; `_plan_puzzle_route()` faz BFS em posição + progresso. | As runas existem; caixas, alvos de pressão, puzzles mistos e reset local não existem. A BFS atual não prova que um puzzle de caixas é solucionável. |
| Inimigos | **FACT**: `hunter`, `sentry`, `wisp`, `patrol`, `mirror` e `rusher` têm diferenças em `_update_enemy_intents()`; o Guardião e os chefes têm vida própria. | Não existe ainda uma tabela de propriedades de água, gelo, impacto ou vulnerabilidade a armadilhas. |
| Escudo | **FACT** na referência: uma carga absorve o impacto. `_stagger_elite()` retira 1 HP e recua um elite; inimigos comuns usam `_apply_damage()` e não são projetados. O escudo também é gasto para saltar. | A crítica ao impacto dos inimigos comuns é procedente. Qualquer recuo precisa de respeitar paredes, ocupação, colisões, cruzamentos, uma só carga por turno e o salto existente. |
| Picareta / demolição | **FACT**: `try_break_wall()` gasta uma carga e um turno para abrir parede interior ou atacar um inimigo adjacente; inimigo comum é removido num golpe, elite perde 1 HP. Fronteiras não cedem. | Não existem blocos de gelo destrutíveis. Falta definir resistência por família antes de substituir o combate atual. |
| Armadilhas | **FACT**: `_trigger_traps()` compara a posição da armadilha apenas com a do jogador; há armadilhas de uso único e de ritmo. | Não ferem nem alteram inimigos. Implementar isso requer resolver quem entra, quando a armadilha dispara e conflitos com escudo/movimentos simultâneos. |
| Água e gelo | **FACT**: `_add_biome_landmarks()` coloca pequenas formas fixas em salas; ambas usam `TILE_WATER`. O bioma decide se são desenhadas como água ou gelo. `_is_floor()` trata ambas como chão transitável. | Não há curto-circuito, escorregamento nem gelo que liberte água. Não é possível distinguir água libertada de gelo apenas pelo bioma atual. |
| Aspeto de água e gelo | **FACT**: `_draw_water_base/_tile` e `_draw_ice_base/_tile` desenham retângulos e linhas por célula; não há shader de água/gelo. `terrain_renderer.gd` guarda blocos de 6×6 e lista as células aquáticas ao reconstruir o piso. | **INFERRED**: as bases insetadas e linhas por célula podem criar repetição e costuras; a forma escolhida na geração limita a silhueta. É preciso rever forma, bordas e superfície, não sobrepor um shader ao efeito atual. **NOT TESTED:** aspeto real e custo GPU. |
| Portal | **FACT**: `portal_open` é booleano; `_active_switches()` conta progresso; `_draw_portal()` diferencia aberto/fechado, mas não tem estado intermédio real. | Há dados suficientes para um estado intermédio, mas falta uma transição estrutural, sonora e visual. |
| HUD e apresentação | **FACT**: `hud.gd` mostra contadores de poderes e HP/regra do chefe. Mensagens contextuais são temporárias e partilham `last_notice`; recolher moeda ou ativar um interruptor no mesmo turno pode substituí-las. A aura do escudo é desenhada como hexágonos giratórios em `_draw_player()`; uma tentativa de andar contra uma parede também provoca tremor da câmara. | Não existe tutorial persistente de primeira aquisição. Rever o tremor repetido dos bloqueios mantendo sinal claro, e dar ao escudo nova direção visual validada em jogo, não mais partículas indiscriminadamente. |
| Áudio | **FACT**: `audio_feedback.gd` usa `AudioStreamPlayer` não posicional, efeitos sintetizados e duas faixas musicais. `tactical_feedback.gd` despacha eventos para som e háptica. | Não há oclusão por paredes, acústica espacial nem reverb por material. O barramento de eventos é um bom ponto de extensão. |
| Progressão | **FACT**: o perfil guarda progresso, estrelas e checkpoint de recursos/poderes; não há vida máxima do jogador, atributos de força, árvore, transformação, teletransportadores de mapa ou seleção de personagens. | Criar uma árvore sem inventário, persistência e regras de ativação seria apenas uma interface vazia. |
| Desempenho | **FACT**: terreno estático é retido em blocos; camadas animadas e objetos são limitados pela vista; há `tools/performance_benchmark.gd`. | Manter cache, invalidar vizinhos e atualizar a lista de superfícies quando um bloco mudar. Medir CPU **e** GPU antes de afirmar ganhos. |

### Inimigos e chefes: auditoria inicial

**FACT:** o chefe do andar 5 é o **Peão**, com 2 HP, movimento ortogonal de uma casa e contacto como ameaça. Os seis chefes partilham o mesmo planeador geral (`_boss_intent`), a mesma regra básica de dano e o mesmo ciclo de turnos; o portal não exige derrotá-los. Não existe uma máquina de estados de ataque anunciado/contagem/recuperação nem movimento independente do relógio de jogo.

**MEASURED:** num cenário de teste com corredor livre e Peão a quatro casas, esperar quatro ações termina em captura sem escudo; dois contra-ataques de escudo derrotam o Peão de 2 HP. Isto documenta o comportamento atual num cenário controlado, não prova equilíbrio ou qualidade do encontro.

| Chefe / primeira aparição | HP | Deslocação implementada | Falta a avaliar |
|---|---:|---|---|
| Peão / 5 | 2 | Ortogonal, 1 casa | Identidade, ataque anunciado e janela justa de resposta. |
| Torre / 10 | 3 | Linhas, até 3 casas | Corredores, cobertura e alerta do percurso. |
| Cavalo / 15 | 4 | Salto em L, chegada livre | Aviso da casa de chegada e resposta do jogador. |
| Bispo / 20 | 5 | Diagonal até 3, sem cortar cantos bloqueados | Leitura de diagonais e interação com paredes. |
| Rainha / 25 | 6 | Linhas e diagonais até 3 | Padrões próprios, não apenas mobilidade e HP. |
| Rei / 30 | 7 | 1 casa em oito direções | Presença e regras de ataque/recuperação próprias. |

**FACT:** se nenhuma jogada de peça reduzir a distância, o planeador pode recorrer a um passo ortogonal por caminho real. Não tratar as etiquetas da tabela como regras de xadrez estritas em todos os casos. **NOT TESTED:** equilíbrio, legibilidade das silhuetas e ataques em jogo real para cada chefe.

### Auditoria dos poderes existentes

| Poder | Regra real na referência | Lacuna a trabalhar |
|---|---|---|
| Velocidade | 6 ações válidas **incluindo a recolha**; inimigos ficam parados na recolha e em ações alternadas. Sobram 5 ações depois da recolha. Não é movimento contínuo nem duas casas automáticas. | O pedido de 4–5 turnos úteis não justifica reduzir cegamente a constante: medir clareza e equilíbrio, explicar os turnos e considerar se a recolha deve contar. |
| Íman | 8 ações incluindo recolha; recolhe instantaneamente moedas a até 2 passos por chão, sem atravessar paredes. Não atrai outros tipos. | Alcance/efeito sem rasto nem deslocação visível das moedas; avaliar alcance, visibilidade e duração separadamente. |
| Blink | +1 carga; Q/botão desloca até 3 casas, pode atravessar paredes interiores, não a fronteira; aplica consequências só na chegada. Sucesso custa 1 turno. | Explicação por tipo de comando e testes com obstáculos, alvos e futuras caixas. |
| Congelar tempo | 4 ações incluindo recolha; inimigos imóveis, mas contacto e armadilhas continuam; outros temporizadores continuam a contar. | Testar combinações e dar indicação clara da duração e das exceções. |

**FACT:** os estados e a fase da velocidade são incluídos no checkpoint, com valores nulos para perfis antigos (`_capture_power_state`, `_normalized_power_state`, `_restore_power_state`). Uma revisão não deve perder nem prolongar silenciosamente esses valores.

## 2. Proposta de arquitetura, sem decisões irreversíveis

### Turno e contacto

**HYPOTHESIS:** continuar a resolver o tabuleiro uma vez por ação válida e gerar eventos semânticos após cada consequência. Separar cálculo do impacto, escolha de destino legal, aplicação do estado e apresentação. Impedir dois consumos de escudo na mesma ação; paredes, fronteiras, outros inimigos e destinos já reservados bloqueiam a projeção. Preservar a fuga pelo portal e os checkpoints.

**HYPOTHESIS para o Peão:** primeiro protótipo apenas por turnos: aproxima-se, anuncia uma zona/direção, concede pelo menos uma ação de resposta e só depois ataca, com recuperação explícita. O anúncio não deve ser cancelado ou resolvido por frames. O uso de movimento livre em tempo real ainda necessita de uma regra acordada para pausas, velocidade, congelamento e possibilidade de reação; não misturar um ataque em tempo real com turnos sem esses critérios.

### Superfícies e objetos

**HYPOTHESIS:** separar a ocupação sólida da propriedade da superfície: chão, água e gelo como dados consultáveis por célula, e bloco de gelo/caixa como objeto sólido separado. A mesma área glacial deve poder conter gelo **e** água libertada. Uma tabela pequena por família de inimigo, por exemplo resistência à água e reação ao atrito, é preferível a condições dispersas. Não criar um sistema genérico complexo antes de existirem duas interações reais.

A mutação deve atualizar lista de células animadas, cache e vizinhos, estado das armadilhas quando aplicável e reconstrução/reinício. Consequências ocorrem numa fase definida do turno, não por `_draw()` ou por frame. **UNKNOWN:** durações, imunidades e dano por família; prototipar e testar antes de fixar equilíbrio.

### Árvore: categorias propostas, não decisão final

1. **Capacidade própria ativada:** uma ação escolhida pelo jogador, com custo, recarga e regras de turno.
2. **Melhoria de power-up:** modificação desbloqueada do efeito, duração, alcance ou cargas de um poder; especificar se necessita de ativação adicional ou se age quando o poder é utilizado.
3. **Capacidade ou atributo:** limite concedido por uma habilidade válida; no caso da sobrevivência, é a quantidade de corações adicionais, não uma barra abstrata de HP. A permanência de outras melhorias depende de aprovação.
4. **Efeito temporário:** estado ativo durante N ações ou usos; não é automaticamente uma habilidade adquirida na árvore.
5. **Capacidade especial temporária:** transformação, com forma, duração e matriz explícita de deteção por família.

**ATUALIZAÇÃO:** o jogador esclareceu que a sobrevivência é representada por corações adicionais: a habilidade pode exigir desbloqueio e ativação, mas o coração é consumido automaticamente num dano fatal elegível, sem comando por impacto. A ordem escolhida é escudo → coração → morte para inimigos e armadilhas protegíveis; perigos que ignorem ambos exigem regra e aviso explícitos. Não há turno adicional de invulnerabilidade contra um novo contacto legítimo. Desbloquear, equipar/ativar, usar e consumir são operações diferentes. O jogador também definiu três campanhas independentes, cosméticos globais e proteção/recuperação dos saves. As decisões, categorias e integração proposta estão em [design de corações e habilidades](design-coracoes-e-habilidades.md); a atualização não implica que estes sistemas estejam implementados.

## 3. Plano incremental, dependências e critérios de aceitação

### P1 — Combate, escudo, poderes e chefe do andar 5

1. **Impacto do escudo em inimigos comuns.** Recuo visível e audível, sem morte automática e sem atravessar paredes, fronteiras, inimigos ou posições reservadas. Testar impacto quando o jogador entra na casa, quando o inimigo chega e quando atravessa a casa; escudo ausente, impacto sem espaço, escudo + armadilha e múltiplos inimigos. Manter uma única carga gasta por ação, regras dos elites, salto, derrota e checkpoint. **Entrega inicial proposta.**
2. **Peão do andar 5.** Definir e prototipar estados anúncio → resposta → ataque → recuperação, com comportamento legível e derrota opcional. Testar contagens exatas, colisão, paredes, congelamento/velocidade, pausa, reinício, fuga e ausência de ataques inevitáveis em cenários de referência. A direção visual e áudio requerem observação real.
3. **Poderes.** Avaliar duração útil pós-recolha, HUD, efeitos combinados e tutorial da primeira aquisição sem perder mensagens ou corromper perfis. Para o íman, testar alcance por caminhos, visibilidade da atração e equilíbrio. Manter movimento contínuo como experiência opcional, não substituir as ações/colisões por frame.

**Dependências:** ordem atual dos turnos, reservas de movimento, barramento de feedback, estados de pausa e snapshots. Nenhum trabalho sobre o boss deve assumir que o projeto tem vida do jogador.

### P2 — Puzzles Sokoban e interações

1. **Sokoban delimitado:** caixas empurradas uma casa por ação, só com destino livre; alvos e portão/portal. Ao menos uma solução validada com BFS em `(posição do jogador, conjunto ordenado de caixas, objetivos)`, usando mapas pequenos e limite de busca. Gerar por estados reversíveis ou usar salas construídas e verificar com solver antes de aceitar. O percurso de fuga, caixas contra paredes/fronteiras/outras caixas, reinício e estado do portal têm testes próprios. Prever reset local do puzzle e R do piso; nunca prometer ausência de bloqueio quando só existe reset do piso.
2. **Ambiente:** água atinge famílias vulneráveis com estado de curto-circuito limitado e telegráfico; gelo altera o movimento de famílias selecionadas sem atravessar ocupantes/paredes; bloco de gelo destrutível vira água e atualiza renderizador. Definir imunidades e temporalidade como dados pequenos e explícitos. Testar cada família, nascimento/entrada, sobreposição com escudo/armadilha, bordas, reset e queda da cache.
3. **Armadilhas contra inimigos e portal intermédio:** estabelecer prioridade de efeitos, dano/imunidade e estados de alvos. Testar sequência incorreta, ativação parcial, simultânea, colisão e saída sem soft-lock. Só depois combinar inimigos com puzzles resolvíveis.

**Dependências:** especificação de ocupação, colisões e fases de turno de P1; sprites/cor para distinguir bloqueio, alvo e perigo; solver e reset antes de geração aleatória.

### P3 — Progressão e habilidades

- Detalhar as categorias passiva, ativa, descoberta e capacidade, que podem sobrepor-se; desenhar árvore com requisitos, custos, ativação e desbloqueios sem impor números finais antes de jogar. A proposta de sobrevivência e a atualização da auditoria estão em [design de corações e habilidades](design-coracoes-e-habilidades.md).
- Persistir versão e defaults seguros para perfis antigos; separar atributos, capacidade equipada e efeitos temporários.
- Transformação: matriz de reconhecimento explícita por forma e inimigo, duração por ação, riscos e comportamento na expiração; testar todos os pares e checkpoint.
- Teletransporte: destinos legais, limite de usos, riscos comunicados e teste de saída alcançável; nunca colocar o jogador numa parede ou numa região sem solução.

**Critérios:** cada nó tem efeito verificável, custo, estado persistido e teste; ativação/tempo/cargas são independentes. A transformação não concede invulnerabilidade geral. Sem validação de design, a árvore é proposta, não produto concluído.

### P4 — Identidade visual e feedback

- Reconstruir a forma dos lagos e manchas de gelo com transições de borda e variação controlada, sem interferir com caminhos/puzzles. Usar uma máscara/contorno coerente entre blocos; usar coordenadas globais no shader para textura contínua, com camadas discretas de profundidade, caústica, brilho e margem. Água libertada e gelo devem ser visualmente distinguíveis. Rastos/ondulações só quando correspondem a movimento real.
- Criar um visual de escudo mais integrado, com estado de carga legível e impacto curto; não voltar à aura circular rejeitada. Diferenciar estados do portal e refazer os chefes com silhueta, olhos e padrões próprios.
- Testar capturas de múltiplas seeds/biomas/zoom, margens de chunks e mudança gelo→água; pedir avaliação em execução real. Não chamar bonito nem aprovado a um teste headless.

**Dependências:** dados de superfície e eventos de P1–P2; manter contraste de perigo e acessibilidade. As transcrições são referências técnicas, não provas de que todos os efeitos devem ser copiados.

### P5 — Áudio, estabilidade e desempenho

- Usar o barramento atual para uma primeira experiência controlada de oclusão por grelha e ambiência, sem criar uma fonte complexa por célula. Medir latência e CPU; manter alternativa sem áudio espacial e sem dependências nativas para Web.
- A referência parece corresponder ao [Vercidium Audio 2D para Godot](https://github.com/vercidium-audio/vaudio-godot-native-openal-2d). **FACT:** o repositório indica extensão C++ para Godot 4 com OpenAL Soft e SDK Vercidium 1.11.0; o código do adaptador é MIT, mas o SDK é gratuito apenas para uso não comercial. O [manifesto](https://github.com/vercidium-audio/vaudio-godot-native-openal-2d/blob/main/addons/vaudio-godot-native-openal-2d/vaudio_godot_native_openal_2d.gdextension) declara Godot mínimo 4.5 e bibliotecas para Windows/Linux/macOS, não Web. **UNKNOWN:** compatibilidade efetiva com 4.7.2, licença aplicável ao projeto, custo real, suporte a outras plataformas e comportamento no hardware-alvo. Não integrar até verificar esses pontos e comparar com uma alternativa simples.
- Medir tempos de geração, mediana/p95 do ciclo e uso de memória no mesmo executável/dispositivo, com os mesmos mapas e número de entidades; perfilar GPU em janela real. Preservar os testes de fingerprints ou registar alterações de seed deliberadas.

## 4. Testes e definição de concluído

- **Regras:** testes determinísticos sobre ações válidas, limites, colisões simultâneas, reset/continuação, estados combinados e perfis antigos.
- **Geração:** sweeps de vários pisos/seeds, solver com solução reproduzível e fallback; verificar progressão de portal e ausência de soft-lock dentro das regras previstas.
- **Visual/áudio:** screenshots ou gravação em jogo, diferentes câmaras e bordas de chunk; escuta em hardware. Aprovação estética é separada do PASS de lógica.
- **Performance:** benchmark reprodutível antes/depois, mesmo cenário/executável, sem confundir tempo do `_draw()` principal com custo total das camadas nem resultado dummy com FPS real.
- **Regressão:** `self_test`, `controller_test`, `tactical_feedback_test`, `performance_regression_test` e sweeps; CI oficial, sem efeitos bloquearem comandos, háptica ou acessibilidade.

## 5. Checkpoint — primeiro passo de combate

**FACT — implementado:** o escudo continua a absorver um só impacto por ação e a partilhar as cargas com o salto. Um inimigo comum atingido pelo escudo é projetado até duas casas livres, sem perder vida nem ser removido. O recuo respeita paredes, fronteira, posições e trajetos reservados por outros inimigos; se a direção principal estiver bloqueada, escolhe outra direção livre de forma determinística. Se todas estiverem bloqueadas, não atravessa nada. Ao ser atingido em movimento, recua para o lado de onde vinha; se o jogador entrar na sua casa, recua na direção da ação. O movimento lógico é imediato, com interpolação e um pequeno arco apenas visual. As seis famílias comuns usam por enquanto a mesma força de recuo; resistências e força por família ainda precisam de design e equilíbrio. O contra-ataque dos elites, a duração dos poderes, armadilhas e regras de derrota não foram substituídos. Ficheiros: `game.gd`, `tests/self_test.gd`, `README.md` e `tools/shield_impact_benchmark.gd`.

**MEASURED — regressões:** com o executável oficial Godot `4.7.2.stable.official.ed1daf0bf`, importação e `SELFTEST_PASS`, `CONTROLLER_TEST_PASS`, `TACTICAL_FEEDBACK_TEST_PASS` e `PERFORMANCE_REGRESSION_PASS`. Os testes do escudo cobrem as seis famílias comuns, duas colisões consecutivas sem morte, entrada do jogador, entrada e travessia do inimigo, paredes, fronteira, ocupação, trajetos reservados, ausência de espaço, ausência de escudo, armadilha no mesmo turno e modo invulnerável. Verificam ainda 1.024 combinações locais de paredes e direções de impacto. Sweeps com três seeds e bots passaram nos andares 1–40, 100 e 200. Os bots usam invulnerabilidade: o sweep verifica progressão/geração, não é um teste de equilíbrio do novo recuo.

**MEASURED — custo isolado:** o microbenchmark seguinte executa apenas um contacto com escudo num tabuleiro sintético; inclui o custo existente das partículas e do barramento de feedback, sem renderização real. Três ensaios alternados de 3.000 contactos deram, com oito inimigos, medianas de **23–24 µs antes** e **35 µs depois**, e p95 de **33–38 µs antes** e **51–57 µs depois**. Com 64 inimigos sintéticos, medianas de **24–25 µs antes** e **69–87 µs depois**. A nova versão faz mais trabalho para verificar trajetos/ocupação e animar o recuo; isto não prova melhoria de velocidade. São medições locais de CPU/escalonamento por contacto, não FPS ou custo de GPU, e podem variar entre máquinas.

```sh
godot --headless --path . --script res://tools/shield_impact_benchmark.gd -- iterations=3000 enemies=8
```

Para repetir a comparação, copiar o mesmo script para uma cópia da referência `8c0841b`, importar os recursos das duas versões e alternar execuções na mesma máquina. O cenário de 64 inimigos é um teste de esforço sintético, não a quantidade normal do gerador.

**NOT TESTED:** a qualidade visual do arco e do impacto em janela real, som em dispositivo físico, GPU e equilíbrio por jogadores. Água/gelo funcionais e redesenhados, Sokoban, revisão do Peão, árvore e restantes sistemas continuam por implementar; este checkpoint não os apresenta como concluídos.

## 6. Checkpoint — interações ambientais incrementais

**FACT — implementado:** madeira e metal são sólidos empurráveis; a corrente move madeira, a água e o metal conduzem eletricidade, o gelo marcado desloca o jogador e pode atrasar inimigos, e placas mantidas acionam portões. Tudo é resolvido por ações no fluxo existente, inclusive itens, armadilhas, contacto, IA e portal; há no máximo um impacto ao jogador por ação. As quatro câmaras do menu usam esses mesmos turnos e não dão progressão de campanha. O desafio opcional também aparece na campanha, nos andares 6, 26, 46… quando existe uma posição segura, com uma carga de escudo atribuída uma vez. A validação da posição conserva a acessibilidade do chão antes e após o movimento da caixa **sem depender de atravessar a corrente**; o limite de ações e as setas para o portal são calculados sem usar essa corrente. Reiniciar restaura a seed e os recursos do início do andar.

**MEASURED — testes:** `environment_test.gd` percorre soluções reais das quatro câmaras, testa perfil/checkpoint, reinício, colisões, corrente, gelo, eletricidade, inimigos, placas e portões. Também percorre a solução opcional e conclui o objetivo normal da campanha em várias seeds dos andares 6 e 26, com inimigos removidos e invulnerabilidade para isolar a progressão; isso não é um teste de equilíbrio. Os testes de comandos verificam a navegação até às câmaras, empurrão e reinício pelo menu de pausa. As cinco suites passaram; a varredura com três seeds passou nos andares 1–40 (10.114 ações de bots), 100 e 200. A configuração da CI inclui o teste ambiental e verifica erros de script mesmo quando o processo termina com sucesso.

**OBSERVED — apresentação:** foram inspecionadas capturas geradas numa janela Godot com OpenGL **llvmpipe por software**, a 1280×720 e 800×540: menu, quatro câmaras, placa ativa, desafio de campanha antes/depois e água do Jardim de Vidro. A água une superfícies adjacentes e as suas ondas partilham extremos entre células; o gelo funcional tem marca própria, além da armadilha, e a caixa tem sombra e faces distintas. Isto confirma apenas o conteúdo dessas capturas, não aprovação estética nem a experiência em todos os dispositivos.

**LIMITES / NOT TESTED:** as câmaras têm soluções testadas, mas não há solver genérico de todos os estados de caixas. A garantia da campanha cobre a posição inicial e a solução prevista; empurrões posteriores podem criar bloqueios recuperáveis com **R**. O gelo ainda não se parte nem liberta água; os lagos legados permanecem decorativos. Os tempos comparativos e as suas limitações estão no README. GPU/hardware de destino, áudio e comando físicos, e equilíbrio com jogadores continuam por verificar.
