# Neon Ruins — proposta de corações e progressão

> **Nota posterior:** os exemplos de ataques e sinais neste documento são propostas históricas, não implementação aprovada. A regra atual é não revelar antecipadamente trajetórias ou próximas casas de inimigos; qualquer indicador explícito exige necessidade real de compreensão ou justiça. Ver [guia atual](GAME_FEEL_GAMEPLAY_GUIDE.md).

> **Atualização de implementação:** a primeira árvore, os corações e três campanhas estão agora funcionais. [Árvore e campanhas](ARVORE_E_CAMPANHAS.md) descreve o comportamento atual; valores são provisórios e as propostas futuras abaixo não estão automaticamente implementadas.

**Estado histórico:** documento de design e auditoria na referência examinada: `92f6126abb2463aee787237d665c337482e08ed0`, depois do PR #7. Complementa [a auditoria geral e o plano de prioridades](auditoria-e-plano.md). As regras de corações descritas pelo jogador são requisitos; as escolhas técnicas e os números explicitamente marcados como propostas ainda precisam de aprovação e testes.

## 1. Objetivo e decisões já esclarecidas

Um coração adicional é **uma oportunidade de sobreviver a um dano fatal elegível**, seja de um inimigo ou de uma armadilha protegível. Não representa uma barra de HP genérica e não obriga o jogador a carregar num botão quando é atingido.

| Corações adicionais disponíveis | Comportamento nos danos fatais elegíveis consecutivos, sem escudo nem modo de teste |
|---:|---|
| 0 | O primeiro contacto provoca captura e morte. |
| 1 | O primeiro consome um coração e provoca repulsão; o segundo provoca morte. |
| 2 | Os dois primeiros consomem um coração cada e provocam repulsão; o terceiro provoca morte. |
| 3 | Os três primeiros consomem um coração cada e provocam repulsão; o quarto provoca morte. |

A separação é essencial: **desbloquear uma habilidade**, **equipar/ativar a habilidade**, **usar uma capacidade ativa** e **consumir um coração** são operações distintas. Depois de uma habilidade de sobrevivência ser validamente ativada, o coração concedido funciona automaticamente. A preferência anterior por capacidades ligadas ao jogador e aos power-ups ativas não significa pedir um comando durante cada colisão. As categorias abaixo descrevem *como o efeito funciona*, não anulam o requisito de desbloqueio e ativação.

Requisitos adicionais: corações no HUD; feedback visual e sonoro na perda; recuperação por pickups sem ultrapassar a capacidade; um mesmo contacto não pode consumir vários corações; movimentos forçados têm de respeitar a grelha e os turnos. Cada campanha nova deve começar com **zero corações adicionais**, sem habilidades de sobrevivência desbloqueadas ou ativadas. Deverão existir três slots independentes: regressar a um andar anterior na mesma campanha preservará a sua progressão e os seus poderes; uma campanha noutro slot não os herdará. Os cosméticos deverão pertencer ao perfil global e poder ser usados nas três campanhas.

## 2. Auditoria do código existente

| Área | Evidência na referência | Consequência para o design |
|---|---|---|
| Jogador | **FACT:** `game.gd` guarda `charges`, `breach_charges` e estados dos quatro poderes, mas não tem capacidade nem saldo de corações do jogador, árvore ou pontos de habilidade. `new_game()` inicia as cargas de escudo a zero. | Os corações são um estado novo, não uma alteração ao HP dos bosses. Zero corações não significa zero escudos. |
| Ordem do turno | **FACT:** `_take_turn()` inicia `damage_this_turn`, incrementa o turno e resolve recolhas → armadilhas → interruptores → contacto inicial → intenções/movimento dos inimigos → contacto final e percursos atravessados → novas intenções → duração dos poderes → portal. | A solução tem de agir nessa ordem, inclusive ao ser empurrado para outra casa; não pode depender da velocidade dos frames. |
| Dano e contacto | **FACT:** `_apply_damage()` e `_stagger_elite()` partilham a proteção `damage_this_turn`; o primeiro consome um escudo ou chama `_begin_capture()`. A armadilha também usa `_apply_damage()`, antes dos contactos inimigos. | Há uma base para limitar dano a uma resolução por ação, mas a mesma variável não resolve por si só a sobreposição que persista para o turno seguinte. O contra-ataque de elite tem um caminho próprio e não pode gastar duas cargas após a integração. |
| Escudo | **FACT:** a recolha normal em `_collect_pickups()` faz `charges += 1` sem limite. O gerador coloca de 2 a 4 pickups de escudo por piso quando há espaço; `dev_give_resources()` limita a 3 apenas na ferramenta de desenvolvimento. | **MEASURED:** partindo de 3 cargas, recolher um escudo normal passa para 4. A capacidade-base de 3 pedida é uma alteração futura; não deve ser confundida com começar com 3 cargas ou com o número de pickups no mapa. |
| Falta de espaço | **MEASURED:** num tabuleiro controlado, com o jogador e um inimigo sobrepostos e quatro paredes em volta, um escudo é consumido sem movimento legal. Ao esperar na ação seguinte, a mesma sobreposição causa captura. | Para corações, é necessário separar a prevenção de dano na ação do tratamento de um contacto ainda não separado, sem atravessar paredes nem conceder invulnerabilidade geral. |
| HUD | **FACT:** `_draw_header()` mostra escudo, moedas, interruptores e demolição; o minimapa e o guia de puzzle ocupam parte dos cantos. Existe um auxiliar `_draw_heart()` em `hud.gd`, mas não é chamado nem representa vida. | Reservar espaço para corações com layout responsivo; a existência do desenho não prova que o sistema já funcione ou que a aparência esteja aprovada. |
| Feedback | **FACT:** `tactical_feedback.gd` encaminha eventos semânticos para áudio e vibração sem alterar o tabuleiro. `audio_feedback.gd` já tem sinais para escudo e captura, mas não para perda/recuperação de coração. | Acrescentar eventos próprios na futura implementação, preservando o ganho e os limites de vibração existentes, inclusive com o som silenciado. |
| Continuidade | **FACT:** `_tick_power_effects()` corre antes de `_check_portal()`. `_save_resume()` e `generate_floor()` preservam os estados e a fase de velocidade; `advance_floor()` não os reinicia. | **MEASURED:** ao entrar no portal com velocidade 2, íman 3, congelamento 1 e Blink 2, o checkpoint e o piso seguinte ficam com velocidade 1, íman 2, congelamento 0 e Blink 2. A continuidade básica já existe e não precisa de ser vendida como uma nova habilidade. |
| Persistência e slots | **FACT:** existe um único `ConfigFile` em `user://come_to_me_profile.cfg`, com definições de comando e um único conjunto de progresso/checkpoint; não há três slots nem inventário global de cosméticos. `floor_start_snapshot`, R, derrota e continuação restauram os recursos do início do piso. Perfis antigos recebem valores zero para poderes ausentes. | Separar o perfil global das três campanhas com migração segura, backups e testes; não restaurar automaticamente todos os corações ao atravessar um portal. |
| Revisitar e nova campanha | **FACT:** `start_level()` para um piso desbloqueado gera uma nova seed e repõe moedas, escudos, demolição e poderes a zero; preserva o diário global de estrelas/andar máximo e substitui o checkpoint de continuação. `new_game()` também substitui o checkpoint único. | **MEASURED:** selecionar o andar 3 depois de chegar ao 25 preservou o diário, mas zerou os recursos e alterou o checkpoint para o 3. Isto contraria o regresso à mesma campanha agora pedido; não reutilizar `start_level()` sem o adaptar. |
| Outros sistemas | **FACT:** as runas dos pisos `% 5 == 3` não têm caixas, inimigos nem armadilhas; água e gelo partilham `TILE_WATER` e não têm interações funcionais; não existe transformação em inimigos. O Blink atual é um poder diferente dos pontos de teletransporte propostos. | Sokoban, superfícies e transformação são dependências futuras, não capacidades prontas a desbloquear. Manter a prioridade do combate e do Peão do piso 5. |

### Verificação desta auditoria

- **MEASURED:** importação e `SELFTEST_PASS`, `CONTROLLER_TEST_PASS`, `TACTICAL_FEEDBACK_TEST_PASS` e `PERFORMANCE_REGRESSION_PASS` com o Godot oficial `4.7.2.stable.official.ed1daf0bf`, em modo headless, na referência acima. Os sweeps passaram nos pisos 1–10 (duas seeds, bots invulneráveis) e nos pisos 100 e 200 (uma seed, sem bots); não são testes de equilíbrio.
- **MEASURED:** cenários controlados em headless verificaram a recolha do quarto escudo, a continuidade na passagem real de piso, a sobreposição descrita na tabela, a reposição de recursos ao selecionar um andar anterior e a substituição do checkpoint único ao iniciar uma campanha. O cenário de sobreposição é uma observação do escudo atual; **não** é um teste de corações, que ainda não existem.
- **MEASURED:** o [workflow do commit de referência](https://github.com/edmundo738/CTM--Come-To-Me-/actions/runs/41607138429) terminou com sucesso. Os testes de referência cobrem também checkpoints, perfis antigos, escudo e duração dos poderes.
- **NOT TESTED:** corações, árvore, aparência do HUD proposto, sons novos, vibração física, GPU e equilíbrio com jogadores. A aprovação do CI não substitui estas verificações.

Para repetir as suites existentes, depois de importar o projeto com Godot 4.7.2:

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/self_test.gd
godot --headless --path . --script res://tests/tactical_feedback_test.gd
```

## 3. Modelo proposto de corações

### 3.1 Estados e invariantes

**HYPOTHESIS — estrutura mínima:**

- `hearts_capacity`: capacidade adicional atualmente concedida pelas habilidades válidas; não é o número de contactos fatais totais.
- `hearts_current`: corações adicionais ainda disponíveis. Sem um estado legado excecional, `0 ≤ hearts_current ≤ hearts_capacity`.
- Os nós desbloqueados, os nós equipados/ativados e os créditos de concessão inicial são estados separados. A capacidade pode ser calculada a partir dos nós válidos, em vez de somada repetidamente a cada carregamento.
- Uma primeira ativação válida de um nó que **concede** um coração aumenta capacidade e saldo em 1. Uma ativação repetida, troca de equipamento, carregamento ou confirmação repetida **não** concede recarga infinita; guardar o crédito de concessão já utilizado para o âmbito da run.
- Um pickup de vida recupera `min(1, hearts_capacity - hearts_current)`, não aumenta a capacidade e não desbloqueia a habilidade. Com a capacidade cheia, a proposta é deixá-lo no chão para utilização posterior.
- Equipar ou retirar uma melhoria só seria possível na janela de progressão aprovada; se diminuir a capacidade, o saldo é limitado ao novo máximo, com aviso antes da confirmação. O jogador não pode desligar uma dependência enquanto um nó descendente continua ativo.
- **DECISÃO:** uma campanha nova, seja em slot vazio ou após substituição explicitamente confirmada, começa sem desbloqueios, equipamento ou corações adicionais de outra campanha. Na mesma campanha, revisitar um andar preserva as habilidades adquiridas e ativas e os corações existentes; não volta a atribuir o crédito inicial.

### 3.2 Prioridade de proteção e perigos

**DECISÃO:** para um dano fatal elegível, seja de um inimigo ou de uma armadilha, a ordem é **escudo → coração → morte**. Um escudo disponível absorve o impacto sem gastar coração. Sem escudo, perde-se exatamente um coração e o jogador é empurrado; sem nenhum dos dois, inicia-se a captura. O salto continua a gastar escudo *antes* da ação: se consumir a última carga e houver um dano elegível na chegada, a proteção seguinte é um coração.

Os perigos devem declarar a sua política: danos não fatais não consomem automaticamente um coração; perigos fatais protegíveis seguem a ordem acima; perigos especiais podem ignorar **ambos** o escudo e os corações, mas isso tem de ser uma propriedade explícita e claramente anunciada antes de o jogador se expor, nunca uma surpresa. **HYPOTHESIS:** classificar inicialmente as duas armadilhas fatais existentes (`one_shot` e `rhythm`) como protegíveis. Ataques futuros de inimigos e boss também terão uma política explícita; não inferir exceções pela aparência.

A mesma ação conserva a proteção partilhada já existente: uma armadilha seguida de contacto inimigo, ou vários inimigos na mesma ação, não consomem simultaneamente escudo e coração nem vários corações. Um perigo que ignore escudos e corações não deve ignorar a proteção contra duplicação da mesma resolução. Isto não significa imunidade no turno seguinte contra um **novo** contacto legítimo. A perda de um coração incrementa `hits_this_floor` uma única vez, fazendo falhar o desafio de não sofrer dano, tal como um impacto no escudo.

### 3.3 Resolução do contacto, sem duplicação

**HYPOTHESIS — esboço, não código existente:**

```text
entrada: origem e identidade estável da ameaça, política de proteção,
         identidade da ativação, fase do turno, célula e percurso comprometido
se não estiver a jogar ou god mode: ignorar sem gastar recursos
se já houve consequência de dano nesta ação: não gastar outro recurso
se o mesmo contacto físico persistir sem separação ou a ativação já tiver sido resolvida:
    não voltar a contá-lo como um evento novo
se o perigo fatal anunciar que ignora escudo e coração: iniciar a captura
senão, se o dano fatal for protegível e houver escudo:
    consumir exatamente 1; aplicar a reação de escudo apropriada
senão, se o dano fatal for protegível e houver coração:
    consumir exatamente 1; resolver separação/empurrão; emitir HEART_LOST
senão, se o dano for fatal: iniciar a captura existente
```

A resolução deve devolver um resultado explícito (`IGNORADO`, `ESCUDO`, `CORACAO`, `CAPTURA`) aos chamadores, em vez de inferir o resultado apenas a partir do saldo de cargas. O caminho de elite deve conservar o dano e o recuo atuais **apenas quando o resultado for ESCUDO**. Não emitir novamente o evento nem aplicar o efeito na animação. A identificação de uma ameaça tem de sobreviver a alterações dos índices do array; uma possível identidade local por piso não deve consumir RNG nem modificar silenciosamente as fingerprints históricas de geração.

**DECISÃO:** a proteção é **lógica durante a resolução da ação e para o mesmo contacto ainda não separado**, não um temporizador em segundos nem um turno completo extra de invulnerabilidade. Isso satisfaz a sequência 1 coração → sobrevive ao primeiro contacto legítimo → morre no segundo. Uma animação breve de dano é apenas apresentação; um perigo novo numa ação posterior volta a contar.

Para a exceção em que ainda existe sobreposição por falta de espaço, marcar o par jogador–inimigo como **contacto não separado**: a mesma sobreposição não volta a consumir recursos só porque se verificou a colisão outra vez. A ocupação precisa de ser reconciliada também para ameaças cuja consequência de dano foi ignorada pela guarda da ação: separá-las legalmente ou marcar cada sobreposição persistente, sem aplicar outro dano. Quando ambos se separam, a marca respetiva é limpa e um contacto posterior volta a contar. Outros inimigos e perigos não ficam globalmente desativados.

Uma armadilha tem **identidade de ativação**, não apenas de sobreposição. A armadilha de uso único não pode disparar duas vezes; uma armadilha de ritmo que saiu da fase perigosa e voltou a ela pode produzir uma nova ativação legítima, mesmo que o jogador continue na casa. Um ataque futuro explicitamente anunciado e iniciado como novo evento também deve ter a sua própria regra; não tratar frames ou callbacks repetidos como ataques novos.

### 3.4 Empurrão e chegada

**HYPOTHESIS — proposta inicial de uma casa:**

1. Determinar a direção pelo movimento real: se o jogador entrou na casa ocupada ou numa armadilha, tentar recuar no sentido contrário à entrada; se o inimigo avançou, tentar afastar o jogador da origem do ataque. Se uma armadilha de ritmo disparar enquanto o jogador espera, usar uma direção cardinal de reserva explícita e determinística, não uma origem inventada. Para trajetos diagonais ou saltos, usar desempate cardinal documentado e testado. O Blink não deve ser revertido automaticamente através de paredes como se fosse um passo normal.
2. Validar a casa: dentro do mapa, chão transitável, sem fronteira ou parede, sem inimigo presente e sem destino/trajeto inimigo já comprometido. Preferir alternativas laterais seguras se a direção principal estiver bloqueada; não deslocar o jogador para uma armadilha ativa inevitável apenas para fingir que houve espaço.
3. Se o contacto acontecer antes da fase inimiga, reservar a chegada e cancelar ou recalcular, de forma determinística, intenções que a ocupariam; no contacto após o movimento, validar as posições já resolvidas. Não avançar o relógio nem fazer os inimigos jogar um turno adicional. A posição lógica muda uma vez; a interpolação é visual.
4. A chegada forçada deve processar uma vez as recolhas e os interruptores da casa de destino, sem repetir uma fase que ainda será executada normalmente. Isto é importante tanto para um empurrão por armadilha antes dos interruptores como para um contacto inimigo posterior. O portal é avaliado na fase final habitual, na posição final; uma segunda ameaça na mesma ação não aplica outro dano. Futuras superfícies e armadilhas exigem ordem explícita, sem ciclos de ativações.
5. **Sem casa legal:** não atravessar paredes nem inventar uma posição. Mostrar impacto sem deslocação lógica e manter o contacto não separado descrito acima, tentando novamente a separação quando o estado mudar. É uma exceção explícita à repulsão física, não uma segunda perda de coração nem uma imunidade geral. A política para uma situação realmente encerrada terá de ser validada com o jogador e testada para não gerar bloqueios artificiais.

A resolução de trajetos, reserva e fallback deve ser implementada e testada antes de acrescentar efeitos de gelo, caixas móveis ou ataques de boss. A lógica de repulsão do inimigo pelo escudo pode servir de referência, mas a direção, o ocupante deslocado e a fase do turno são diferentes; não a reutilizar cegamente.

### 3.5 HUD, som e acessibilidade

- Proposta: faixa ancorada num canto do HUD, reposicionada quando o guia de runas, o minimapa, os botões e o indicador de boss estiverem presentes, incluindo a largura mínima de 800 px. Mostrar corações cheios e vazios até à capacidade e uma indicação textual inequívoca de **0 extras** quando não existir capacidade; não mostrar uma barra vazia como se o jogador já estivesse morto.
- Ao perder um coração: atualizar o saldo no mesmo resultado lógico, animar esse ícone brevemente, som distinto do escudo e da captura e feedback corporal contido. Não depender só da cor. Câmara apenas em acontecimentos relevantes, não em passos ou moedas.
- Criar eventos separados, por exemplo `HEART_LOST` e `HEART_RECOVERED`, no Tactical Feedback Bus; o HUD observa os factos e não provoca dano. Preservar o comportamento de vibração atual, inclusive a opção de silenciar e a limitação física.
- **NOT TESTED:** se o auxiliar visual `_draw_heart()` é adequado ao estilo final. Pode ser ponto de partida, não aprovação estética.

## 4. Taxonomia e ciclo de vida das habilidades

As quatro categorias são **rótulos sobrepostos**:

| Categoria | Significado nesta proposta | Exemplos |
|---|---|---|
| Passiva | Uma vez devidamente ativada/equipada, opera automaticamente nas condições definidas. | O coração concedido; eficiência de uma ferramenta. |
| Ativa | O jogador decide quando usar; há condição e custo de utilização. | Transformação, golpe de força, colocação de armadilha. |
| Descoberta | Altera o que pode aparecer no mundo; não recolhe automaticamente o objeto. | Olho do Explorador. |
| Capacidade/melhoria | Altera um limite ou parâmetro de outro sistema. Pode também ser passiva ou afetar uma ativa. | Capacidade de escudos, duração da transformação. |

| Operação | Verificação e efeito propostos |
|---|---|
| **Desbloquear** | Conferir pontos, pré-requisitos e versão da árvore; cobrar uma vez. Não conceder a capacidade nem usar um poder só por desenhar o nó na interface. |
| **Equipar/ativar a habilidade** | Conferir desbloqueio, dependências ativas, limites de equipamento e janela permitida. A proposta é permitir mudanças numa interface segura entre pisos, não a qualquer momento em combate. Um nó que concede coração pode atribuir o seu crédito inicial apenas uma vez. |
| **Usar uma ativa** | Conferir que está equipada, que a ação é válida e que existe carga/recurso ou recarga disponível; uma utilização bem-sucedida segue as regras de turno próprias. Uma tentativa inválida não deve gastar recurso ou turno sem aviso. |
| **Consumir recurso** | A consequência retira uma carga, recurso ou coração segundo a sua própria regra. A perda de coração é automática, não outra ativação. |
| **Desativar/trocar** | Só na janela definida; validar descendentes e limites, sem converter a troca em recarga gratuita. Guardar a alteração com o checkpoint antes de entrar no piso seguinte. |

**PENDENTE:** número de espaços para habilidades equipadas e se todos os nós passivos precisam de ocupar um desses espaços. Estes espaços não são os três slots de save. As habilidades ativas e desbloqueadas são próprias da campanha e persistem ao revisitar andares nessa campanha, mas não passam para outra. Não tratar estes rótulos como decisão definitiva sobre cada poder existente; em particular, o íman atual é aplicado automaticamente ao recolher o pickup e não deve ser convertido silenciosamente numa habilidade de botão.

## 5. Esqueleto de árvore e dependências

Esta não é uma lista de funcionalidades já disponíveis. Cada nó só pode aparecer como utilizável quando a mecânica subjacente existir e tiver testes; os restantes ficam claramente identificados como futuros, não como botões vazios.

**HYPOTHESIS — exemplo de orçamento, não valores finais:** uma unidade de ponto por primeira conclusão de piso em cada campanha, sem prémio repetido pelo mesmo piso; custos ilustrativos 1/2/3 para os três patamares. Ao ter 3 pontos, escolher Sobrevivência I + II gastaria os 3, deixando Exploração I para mais tarde. É apenas um modelo para simular escolhas: o saldo ao longo de 200 andares, os limites de equipamento, a eventual atribuição retroativa de pontos a campanhas antigas e a economia real ainda precisam de testes. Pontos de habilidade não devem ser retirados diretamente de `total_coins`, que também é pontuação/recorde da campanha.

| Ramo / nó de exemplo | Dependência para desbloquear; condição para ativar | Efeito e limite **propostos** | Custo ilustrativo |
|---|---|---|---:|
| Sobrevivência I | Núcleo; janela de progressão | Concede +1 capacidade e +1 coração uma vez; depois é automático ao contacto elegível. | 1 |
| Sobrevivência II | I desbloqueado; I ativo | Concede mais 1, sem repetir o crédito na reativação. | 2 |
| Sobrevivência III | II desbloqueado; I e II ativos | Concede mais 1. Três é apenas o teto do exemplo, não um máximo final decidido. | 3 |
| Olho do Explorador I | Sobrevivência I desbloqueado; capacidade de coração ativa | Abre a possibilidade **rara**, não garantida, de gerar um pickup de recuperação alcançável. | 1 |
| Olho II / III | Nível anterior desbloqueado e ativo | Aumentar a oportunidade de spawn; III pode revelar esconderijos. Probabilidades e conteúdo de esconderijos por testar, sem valores arbitrários. | 2 / 3 |
| Escudo I / II | Base de escudo; II requer I desbloqueado e ativo | Aumentos de capacidade de transporte, por exemplo +1 por nível num protótipo; não alteram quantidade de pickups no mapa. | 1 / 2 |
| Técnica de Demolição | Demolição existente; materiais/interações respetivos implementados | Melhorar uma interação concreta com blocos ou gelo; não publicar um nó que ainda não faça nada. | por definir |
| Força Bruta | Técnica de Demolição e ferramenta elegível | Golpe deliberado, com custo de recurso, interrupção e projeção proposta de 2–3 casas conforme força, tipo e espaço; não substitui o escudo nem atravessa obstáculos. | por definir |
| Transformação | Ramo de infiltração; estado e matriz de deteção implementados | Uso deliberado, forma temporária e custo; duração/reconhecimento têm melhorias separadas. | por definir |
| Rede de Armadilhas | Ramo de engenharia; armadilhas de jogador implementadas | Instalar um tipo desbloqueado gastando um recurso; também pode atingir o jogador. Melhorias não permitem preencher o mapa gratuitamente. | por definir |
| Melhoria de velocidade/íman | Power-up respetivo existente e melhoria ativada | Ajustar **um** parâmetro como duração ou alcance, com limite; não restaurar efeitos ao atravessar o portal. | por definir |

Os exemplos adicionais como Passo Fantasma, Pulso de Interferência ou Último Recurso continuam **propostas não aprovadas**. Cada uma precisa de um problema identificável, contrajogo, custo, condição de uso e testes antes de entrar no produto. Especialização deve resultar de pré-requisitos e escolhas/limites relevantes, não apenas de uma lista longa de nós.

### 5.1 Recuperação e Olho do Explorador

Spawn e recolha são operações diferentes. O Olho modifica a possibilidade de **geração**; só a recolha recupera um coração perdido. Não fixar uma percentagem sem amostras e testes. Proposta de protótipo: no máximo um pickup de recuperação por piso, sem garantia de aparecer, apenas em chão alcançável e não ocupado; ajustar o limite após medições. Não substituir escudos, caixas ou objetivos obrigatórios, nem fazer o progresso depender do pickup raro.

O gerador é determinístico e os testes comparam mapa, itens, inimigos e estados de RNG. Para uma futura geração de corações, estudar um RNG separado derivado da seed e do estado de habilidade, evitando alterar a sequência e os mapas dos sistemas já existentes. Repetir com a mesma seed e estado deve produzir o mesmo resultado. **PENDENTE:** se uma outra habilidade de recuperação poderá existir; não é necessária para a primeira versão de pickups.

### 5.2 Escudos e compatibilidade

A intenção é **capacidade de transporte inicial 3**, não começar com três cargas. O limite de pickups em cada mapa é independente. Ao atingir o limite, a proposta é deixar o escudo não recolhido no chão e informar o jogador sem repetir efeitos a cada frame.

A mudança pode afetar perfis já guardados com mais de 3 cargas, pois hoje isso é possível. Proposta conservadora: preservar todas as cargas legadas, mesmo temporariamente acima do novo limite; impedir novas recolhas até o saldo descer abaixo da capacidade, sem apagar recursos. O HUD deve explicar o excesso. Testar também `dev_give_resources()`, que atualmente aplica `min(..., 3)` e poderia reduzir um saldo legado ao ser usado.

### 5.3 Continuidade e custos dos poderes

A continuidade de velocidade, íman, congelamento e Blink **já funciona**. Preservar o saldo depois da ação de entrada no portal, sem nova cobrança pelo ecrã de resultado, sem recarregar nem restaurar durações. R e continuar reconstituem o estado de entrada do piso, não um estado intermédio. Uma melhoria futura pode alterar duração, alcance ou capacidade, mas não deve desativar a continuidade básica sem uma decisão explícita.

Custos não precisam de ser iguais para todas as ativas: transformação pode usar carga e/ou recarga; armadilhas podem consumir componentes; Força Bruta pode depender das cargas de demolição; Blink já usa cargas. Todos esses modelos, salvo as regras já existentes, são **propostas**, não valores finais. Evitar transformar cada efeito passivo num botão de reação obrigatória.

## 6. Transformação e deteção — matriz inicial para discussão

A habilidade proposta escolhe um inimigo elegível próximo, com desempate determinístico, assume a forma durante um tempo limitado e pode confundir inimigos durante três turnos. A distância, custos, quais capacidades são copiadas e o limite de formas elegíveis ainda não estão fixados. Os oito turnos mencionados são um teto possível de reconhecimento para *alguns* inimigos, não uma invisibilidade universal.

Legenda: **T** = não reconhece imediatamente, mas continua sujeito a duração e regras; **D** = reconhece; **?** = por definir. Formas de elites são consideradas inelegíveis nesta hipótese. A matriz é uma proposta de design, não comportamento existente.

| Observador no código atual | Disfarce `hunter` | `sentry` | `wisp` | `patrol` / `mirror` / `rusher` | Observação |
|---|---:|---:|---:|---:|---|
| `hunter` | T | T | ? | ? | Definir que disfarces confundem o perseguidor vermelho. |
| `sentry` | ? | T | ? | ? | É o robô dourado atual; não assumir que já é a sentinela avançada proposta. |
| `wisp` | D | D | T | D | A esfera identifica formas de outras espécies; nem a sua própria forma implica invisibilidade ilimitada. |
| `patrol` | ? | ? | ? | ? | Regras de campo de visão e reconhecimento a desenhar. |
| `mirror` | ? | ? | ? | ? | Regras próprias por desenhar; preservar a reação atual até existir substituto testado. |
| `rusher` | ? | ? | ? | ? | Regras de reconhecimento e investida a desenhar. |
| `warden` / Guardião | D | D | D | D | Proposta: o mini-chefe identifica o impostor. |
| `chess_boss` | ? | ? | ? | ? | Definir peça a peça; não assumir imunidade ou deteção perfeita para todos. |

Durante um protótipo, pares ainda sem regra devem manter o reconhecimento normal, não conceder invisibilidade acidental. Testar cada par, expiração, ausência de alvo, empate, pausa, checkpoint e transformação perto de ataques anunciados. A capacidade copiada de uma forma não deve ultrapassar paredes ou anular todos os riscos.

## 7. Relações com inimigos, ambiente e puzzles

- **Serpente:** proposta de controlador de território com segmentos e contrajogo; não existe como tal no código auditado. Reservas multi-célula e uma rota/solução verificável são pré-requisitos, para não bloquear permanentemente o portal.
- **Sonda:** proposta de caçadora com ataque anunciado; por exemplo, um laser com três ações de preparação, direção e área visíveis e oportunidade real de sair. Não presumir que a `sentry` existente já tem esse ataque.
- **Sentinela avançada:** proposta de deteção e reação particulares; distinguir o conceito novo do papel atual chamado `sentry`.
- **Guardião:** `warden` já existe como mini-chefe com 3 HP. Novos padrões devem preservar o que funciona e introduzir contrajogo, não simplesmente aumentar HP. O Peão do piso 5 continua a primeira revisão de boss.
- **Água e gelo:** mantê-los e redesenhá-los; posteriormente separar a identidade por célula, definir vulnerabilidades/imunidades e testar curto-circuito, deslizamento e água libertada. Não afirmar que o shader ou as interações já estão feitos.
- **Sokoban:** caixas, alvos, reset e solver de estados antes de combiná-los com perseguidores e terreno. Empurrão do jogador por dano não pode mover uma caixa implicitamente nem atravessá-la; a política de ocupação das futuras caixas será integrada ao teste de casa livre.
- **Portais, teletransporte e armadilhas:** guardar ordem de efeitos e acessibilidade. Um teletransporte arriscado não pode tornar a saída impossível; armadilhas de jogador precisam de regras explícitas para o seu criador e para cada família inimiga.

O plano amplo e as referências de shaders e áudio permanecem no documento de auditoria. Nenhuma destas propostas autoriza substituir sistemas existentes sem verificação nem adotar um plugin sem confirmar licença, compatibilidade e custo.

## 8. Três campanhas, persistência e recuperação

### 8.1 Âmbitos de dados — decisão do jogador

| Âmbito | Conteúdo e regras |
|---|---|
| **Perfil global** | Inventário de cosméticos desbloqueados, utilizável nas três campanhas; definições do comando e outras preferências globais já existentes. O sistema de cosméticos ainda não existe. Apagar uma campanha não apaga o perfil nem os cosméticos. |
| **Cada um dos três slots de campanha** | Seed, andar atual e máximo alcançado, diário/estrelas, moedas, escudos, demolição, poderes e os seus estados, corações, habilidades desbloqueadas e ativadas, melhorias, pontos, créditos de concessão e checkpoints. Nada disto passa automaticamente para outro slot. |
| **Turno corrente** | Guarda de dano, identidades de ativação e marcas de contactos não separados; não dependem dos frames e não devem sobreviver como referências inválidas após regenerar um piso. |

**DECISÃO:** um slot vazio inicia uma campanha completamente nova, sem habilidades, melhorias, moedas, power-ups ou corações adicionais herdados de outras campanhas. Por exemplo, a habilidade de coração do Slot 1 não aparece desbloqueada no Slot 2. Os cosméticos globais continuam disponíveis. Substituir uma campanha existente exige uma operação de eliminação explícita, protegida e recuperável; não é uma consequência de iniciar noutro slot.

**HYPOTHESIS — organização técnica:** manter os dados globais num perfil versionado e cada campanha num ficheiro versionado independente em `user://`, com backups por slot. Por exemplo, `campaign_slot_1.cfg` a `campaign_slot_3.cfg`; os nomes são proposta, não ficheiros existentes. As opções de controlo continuam globais como hoje. A escolha do cosmético atualmente equipado pode ser global ou específica da campanha: o **inventário** é obrigatoriamente global, mas o âmbito da seleção ainda precisa de ser definido.

### 8.2 Regressar a um andar na mesma campanha

**DECISÃO:** ao chegar ao andar 25 no Slot 1 e voltar ao andar 3 no mesmo slot, o jogador mantém habilidades desbloqueadas e ativas, melhorias, poderes e progressão desse slot. Uma campanha nova no Slot 2 continua a começar do zero.

**HYPOTHESIS — integração:** criar um caminho explícito de **revisitar na campanha atual**, não chamar a função `start_level()` atual que apaga recursos. Preservar também moedas, escudos, demolição, corações, cargas, durações e fase da velocidade que existirem no momento da escolha; a navegação no menu não deve gastar turno nem renovar efeitos. O maior andar desbloqueado e o diário não regridem. Registar o piso escolhido como checkpoint de continuação dessa mesma campanha e capturar os recursos de entrada antes de jogar.

Proposta inicial: regenerar o andar escolhido com a seed da campanha, sem prometer a preservação de alterações individuais feitas no mapa numa visita antiga. Explicar essa regra ao jogador. Concluir novamente um andar não atribui outra vez uma recompensa de **primeira** conclusão ou pontos de habilidade correspondentes; a economia de moedas e pickups repetidos precisa de testes de equilíbrio. `R` reinicia o andar revisitado com o estado guardado na sua entrada, sem duplicar benefícios.

O checkpoint atual é de **início de piso**, não um save completo a cada movimento. O novo caminho de revisita tem de transportar o inventário atual ao escolher o andar; a recuperação após encerrar ou falhar a aplicação deve informar claramente qual foi o último checkpoint persistido. Não anunciar recuperação exata de um estado a meio do piso sem a implementar e testar.

### 8.3 Checkpoint, migração e proteção contra perda

- O checkpoint de cada slot inclui corações atuais, capacidade/equipamento efetivamente aplicáveis, créditos de concessão usados, escudos, poderes, seed e os campos existentes. Mudanças de equipamento entre pisos devem ser guardadas juntamente com o checkpoint de destino, sem duplicar concessões se o jogo for encerrado nesse momento.
- `R`, derrota e continuar restauram o retrato do início do piso dessa campanha, incluindo corações e créditos, como hoje fazem com os restantes recursos; não curam automaticamente até ao máximo. A passagem normal guarda o estado restante após a ação.
- **HYPOTHESIS — migração do perfil antigo:** antes de alterar qualquer ficheiro, guardar uma cópia verificável do `come_to_me_profile.cfg`; migrar o progresso e checkpoint existentes para um slot vazio, propondo o Slot 1 quando disponível, e manter as definições globais. Preservar escudos legados acima de 3. Validar leitura, conteúdo e reabertura antes de marcar a migração como concluída. Se falhar ou existir um slot de destino ocupado, não o substituir: manter o original recuperável e pedir uma escolha segura.
- Perfis antigos não têm árvore nem corações: estes começam a zero, sem pontos ou habilidades fabricados. A eventual atribuição retroativa de pontos de habilidade por andares já concluídos é uma decisão económica separada; não apagar o progresso nem conceder pontos duplicados silenciosamente.
- Criar backups versionados por campanha antes de substituir/eliminar dados e ao guardar checkpoints, com retenção a definir. Guardar e validar dados temporários antes de substituir a versão ativa; usar substituição atómica quando a plataforma o permitir e tratar falhas sem apagar o último save íntegro. Backups do perfil global protegem cosméticos e definições separadamente.
- A interface de apagar identifica o slot e o progresso, exige uma segunda confirmação com **Cancelar** em foco e oferece recuperação a partir de backup. Apagar ou restaurar um slot nunca altera os outros dois nem os cosméticos. Detetar corrupção, preservar a cópia danificada, oferecer uma versão recuperável com data e pedir confirmação antes de restaurar; não substituir silenciosamente por um save vazio.
- Testar gravação interrompida, ficheiro truncado, erro de escrita, incompatibilidade de versão e operações repetidas. A retenção, o armazenamento e o comportamento da versão Web têm de ser verificados na plataforma real; backups locais não garantem recuperação se o utilizador apagar todos os dados do jogo ou perder o dispositivo. Exportação externa pode ser estudada, não é uma funcionalidade existente.

### 8.4 Determinismo

As fingerprints atuais incluem os dicionários completos dos inimigos e ambos os estados de RNG. Acrescentar IDs de combate ou pickups pode mudar hashes mesmo que a geometria continue igual. Preferir metadados separados ou normalização explícita, comparar também o conteúdo semântico e não atualizar fingerprints de referência cegamente para esconder regressões.

## 9. Critérios de aceitação e testes para a futura implementação

| Caso | Resultado exigido |
|---|---|
| 0 / 1 / 2 / 3 corações, sem escudo | Para danos fatais elegíveis de inimigos e de armadilhas, morte no evento distinto número 1 / 2 / 3 / 4; perda de exatamente um e um empurrão válido por evento sobrevivido. |
| Um contacto verificado várias vezes no mesmo turno | Uma única consequência e um único evento visual/sonoro. Animação, pausa ou frames não aplicam dano. |
| Dois inimigos, ou armadilha + inimigo na mesma ação | No máximo uma consequência de dano total; preservar a prioridade das armadilhas atuais e não gastar simultaneamente escudo e coração. |
| Mesmo inimigo sobreposto sem espaço | Uma única perda enquanto o contacto permanece não separado; nenhuma passagem através de obstáculos. Depois de separar e voltar a entrar, o novo contacto conta. Outros perigos continuam ativos. |
| Armadilha de ritmo e perigo especial | Não repetir a mesma ativação; uma nova fase perigosa é um evento legítimo. Um perigo que ignore escudo e coração anuncia claramente a exceção e não ignora a guarda contra duplicação. |
| Paredes, fronteira, sem espaço, destinos e trajetos reservados | Repulsão determinística apenas para casa válida; sem movimento ilegal e sem corrida de ocupação. Testar também jogador a entrar, inimigo a chegar, troca de casas, rusher a atravessar, elites, salto e Blink. |
| Empurrão para pickup, interruptor ou portal | Uma ativação por chegada, portal apenas na fase final, sem dupla recolha, ativação recursiva nem segundo dano na ação. |
| Escudo + coração | Em ameaça fatal protegível, uma carga de escudo primeiro; elite mantém o contra-ataque existente; dano legítimo posterior sem escudo consome coração. God mode não gasta nenhum recurso. |
| Desafio sem dano | Um escudo absorvido ou coração perdido conta uma vez; a animação não muda o contador. |
| Recuperação | Pickup só restaura até ao máximo, não aumenta capacidade nem desaparece com saldo cheio; spawn raro, acessível e independente da recolha. |
| Ativação e economia | Não ativar nó bloqueado, sem dependências, fora da janela ou sem slot; gastar pontos uma vez; reativar/trocar/carregar não gera corações infinitos. |
| Continuação / R / perfil antigo | Restaurar o snapshot correto e seed; campos ausentes são seguros; não perder escudos legados acima de 3; não atribuir pontos ou corações duplicados. |
| Três slots e cosméticos | Um slot novo começa do zero; desbloqueios, recursos, pontos e checkpoints não passam entre slots; os cosméticos do perfil estão disponíveis nos três. |
| Revisitar andar na mesma campanha | Ir do 25 ao 3 mantém habilidades ativas/desbloqueadas, melhorias, corações, moedas, escudos, poderes, durações, fase e progresso da própria campanha; não repetir prémios de primeira conclusão. R restaura a entrada do piso revisitado. |
| Apagar e recuperar | Confirmar antes de apagar; cancelar não altera nada. Restaurar um backup válido recupera apenas o slot escolhido. Corrupção, migração interrompida e falhas de escrita não destroem outros slots ou cosméticos. |
| Poderes através do portal | Preservar valores após o tick normal, sem reset nem carga gratuita; verificar velocidade, fase, íman, congelamento e Blink. |
| UI e feedback | HUD legível em tamanhos mínimos, sem sobreposição com minimapa, puzzle ou boss; perda e recuperação têm eventos distintos, sem depender apenas de som/cor. Confirmar som e comando físico fora de headless. |

Além das suites existentes, acrescentar testes pequenos de domínio para a árvore, testes de ação real em `_take_turn()` e round-trip de perfis isolados. Usar várias seeds e cenários sem god mode para sobrevivência; bots invulneráveis verificam geração, não equilíbrio. Medir combinação de corações, escudo, velocidade, recuperação e armadilhas; recolher durações, taxas de conclusão e uso de recursos em playtests antes de fixar custos ou frequências. Medir desempenho antes/depois em hardware real; testes headless não medem FPS ou GPU.

## 10. Sequência incremental e decisões abertas

1. **Agora:** esta auditoria e proposta; nenhuma alteração de gameplay, HUD, perfil ou geração.
2. **Depois de aprovar a arquitetura:** preparar a separação de perfil e três campanhas, migração verificável, backups e regresso a andares anteriores com recursos preservados. O armazenamento por campanha é dependência da progressão; implementar e testar uma fatia de cada vez, sem expor uma interface que apague o save antigo.
3. **Corações:** resolver contacto, prioridade, armadilhas protegíveis, exceções anunciadas, fallback sem espaço e persistência num pequeno núcleo com estado-base zero, feedback/HUD e testes. Permitir cenários de teste sem criar uma árvore inteira falsa.
4. **Progressão mínima utilizável:** introduzir uma via real de desbloquear e ativar Sobrevivência I com pontos, dependências, janela e persistência em cada campanha. Testar uma concessão inicial e impedir recargas por repetição. Só depois acrescentar outros nós por fatias.
5. **Exploração e escudos:** pickups raros com RNG independente e recuperação limitada; implementar a capacidade de transporte 3 com migração sem perda quando esses passos forem validados.
6. **Restantes ramos:** integrar transformação, armadilhas, melhorias de poderes e ambiente quando cada mecânica existir. Continuar o plano geral de combate e revisão do Peão, seguido de Sokoban e interações ambientais; este documento não altera essa prioridade automaticamente.

**DECISÕES recebidas:** escudo → coração → morte para danos fatais elegíveis de inimigos e armadilhas; perigos que ignorem ambos precisam de regra e aviso explícitos; proteção só para a resolução atual e o mesmo contacto não separado, sem ação extra de invulnerabilidade; três campanhas independentes com cosméticos globais, regresso preservado dentro da campanha e backups/recuperação protegidos.

**Decisões posteriores:** se haverá outra habilidade de recuperação além de pickups; espaços de habilidades equipadas, custos e pontos finais; política de pontos retroativos; retenção de backups; seleção de cosmético global ou por campanha; modelos de custo por ativa; probabilidades do Olho; reconhecimento por família; valores de duração e limites. A continuidade básica dos poderes entre pisos já está implementada e testada, pelo que não é necessário decidir se deve ser desbloqueada para manter o comportamento atual.
