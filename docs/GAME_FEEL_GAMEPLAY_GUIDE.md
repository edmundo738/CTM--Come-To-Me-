# COME TO ME: NEON RUINS
# Game Feel & Gameplay

**Dicionário, gramática, princípios de design e manual de aplicação para Arena Super**<br>
**Versão:** 1.0 · 3 de novembro de 2026<br>
**Projeto:** Come To Me: Neon Ruins · **Motor de referência:** Godot 4.7.2<br>
**Género:** estratégia tática, exploração, puzzles e sobrevivência por turnos<br>
**Direção de movimento aprovada pelo proprietário:** Expressive + Hybrid

> **RESPECT THE PLAYER'S INTELLIGENCE. RESPECT THE GAME'S IDENTITY. MAKE EVERY ACTION FEEL INTENTIONAL.**

Este documento consolida a direção e os critérios fornecidos pelo proprietário. É uma **referência permanente**, não uma autorização para reescrever o jogo ou implementar todas as ideias. Uma proposta localizada deve ser apresentada antes de alterar código; alterações estruturais ou destrutivas exigem aprovação prévia. Nunca fazer commit sem autorização explícita.

**BUILD, DON'T FREEZE:** quando a evidência for suficiente **e a proposta tiver sido aprovada**, deixar de investigar indefinidamente e construir uma unidade pequena, testável e reversível. Não usar esta frase para ultrapassar a regra de aprovação.

A proposta inicial incidiu no **movimento do jogador**. Posteriormente, o proprietário autorizou expressamente a ampliação a combate, inimigos e materiais, sem alterar as regras lógicas. Essa autorização aplica-se a esta tarefa e não substitui as autorizações necessárias para trabalhos futuros. Ver [auditoria e proposta históricas de movimento](PLANO_MOVIMENTO_GAME_FEEL.md) e [auditoria sensorial anterior](auditoria-sensorial-2026-11-03.md).

## Como utilizar

O guia tem três funções:

1. **Dicionário:** dá nomes aos conceitos e distingue técnicas que parecem semelhantes.
2. **Gramática:** explica como combinar intenção, movimento, consequência e recuperação sem transformar tudo em espetáculo.
3. **Manual:** indica como investigar, propor, testar e aprovar uma melhoria concreta neste projeto.

Os exemplos de ataque, derrubar, destruir, materiais e efeitos são **direções ou cenários ilustrativos**. Não provam que uma mecânica, asset ou interação já exista. Consultar primeiro o código da branch efetivamente em uso. As imagens e jogos citados pelo proprietário são referências de intenção, não assets para copiar nem prova do estado atual; os links das imagens não foram inspecionados nesta etapa.

---

# PARTE I — FILOSOFIA FUNDAMENTAL

## 1. Game Feel não é uma lista de efeitos

**Game Feel** é a qualidade sensorial, comportamental e emocional da interação. Surge da relação entre intenção, resposta, movimento, regras, áudio, contexto e consequência. Uma ação pode passar todos os testes e ainda parecer fria, confusa ou pouco satisfatória.

Exemplo: uma personagem move-se corretamente uma casa, o turno é contabilizado e o inimigo reage. A regra funciona. Se a apresentação não transmitir intenção ou continuidade, a experiência ainda pode não alcançar a qualidade pretendida. A avaliação estética exige observação e pessoas; não se deduz do nome de uma função.

As cinco camadas são ferramentas, não uma lista obrigatória para cada ação:

| Camada | Função possível |
|---|---|
| Animação | Intenção, personalidade, continuidade e recuperação. |
| Física visual | Peso, resistência, impulso, contacto e reação. Não substitui a lógica. |
| Efeitos visuais | Energia, materialidade e consequência, quando acrescentam significado. |
| Som | Confirmação, textura, força, distância e atmosfera. |
| Câmara | Enquadramento e ênfase sem prejudicar a leitura do tabuleiro. |

A vibração pode complementar estas camadas quando há comando compatível, sem ser a única via para informação necessária. Nem toda interação merece todas as camadas; a escala do tratamento deve respeitar o acontecimento.

## 2. Princípios inegociáveis

### 2.1 Respeitar a inteligência do jogador

> **Never blame the player for a communication failure in the game design.**
>
> **Never add instructions to compensate for poorly designed mechanics. Improve the mechanics, visual language, environmental clues and feedback first.**

Se alguém não percebe o que aconteceu, investigar primeiro o design: a mecânica é coerente? O comportamento é consistente? A silhueta e o material sugerem a função? Há pista antes de uma consequência grave? O feedback surge no momento certo?

Não defender uma falha de comunicação dizendo que o jogador devia ter percebido. Também não concluir que toda falha de compreensão se resolve com uma seta ou texto. Observar, testar e corrigir a origem.

### 2.2 Comunicação sem poluição

Priorizar comportamento, postura, animação, som, forma, posicionamento e alterações do ambiente. Uma caixa, uma placa e um portão podem comunicar uma relação através da experiência, desde que essa relação seja **realmente observável**. Um inimigo pode preparar uma ação com postura e padrão consistente, sem necessariamente precisar de seta, zona vermelha e aviso textual ao mesmo tempo.

| Informação | Tratamento inicial |
|---|---|
| Já óbvia pelo contexto | Não repetir sem necessidade demonstrada. |
| Aprendível pela observação e experimentação segura | Mostrar pelo comportamento e pela consequência. |
| Essencial para uma decisão justa ou impossível de deduzir | Comunicar de forma clara e proporcional, mesmo que seja necessário um recurso adicional. |

**Regra permanente para inimigos:** não mostrar antecipadamente trajetórias, caminhos, células seguintes ou movimentos futuros, sobretudo dos básicos, usando linhas, setas, chão destacado ou previsões equivalentes. O planeamento interno (`next`/`path`) continua necessário à lógica, mas não é uma instrução para o desenho. Expressar ameaça na própria entidade — silhueta, distância, orientação, postura, comportamento, olhar, animação e consequências — e permitir aprender padrões pela observação. Preparação corporal não deve anunciar cada casa seguinte. Indicadores explícitos são exceções a justificar por necessidade real de compreensão ou justiça, nunca decoração por defeito.

Não confundir esta regra com ocultar toda a informação essencial: uma armadilha invisível que elimina o jogador sem pista observável pode ser injusta, não necessariamente profunda. Avaliar legibilidade e acessibilidade com pessoas, incluindo quando o inimigo está fora do ecrã.

**Acessibilidade não é ruído por definição.** As pessoas percebem som, cor, movimento e texto de formas diferentes. Fornecer alternativas textuais, estáticas, sonoras ou hápticas quando necessárias, sem depender exclusivamente de um canal. Legendas, ajuda opcional e indicações de controlos podem ser apropriadas; não servem para desculpar uma mecânica mal comunicada. Avaliar antes de remover pistas existentes.

Ciclo de aprendizagem: **Observar → Interpretar → Experimentar → Aprender → Dominar.**

### 2.3 Feedback não é ruído

Uma partícula, flash, vibração, som ou movimento de câmara precisa de uma função. Se tudo brilha e tudo explode, os acontecimentos importantes perdem contraste. Uma interação simples pode precisar apenas de uma resposta de material e um som breve.

### 2.4 Coerência antes de espetáculo

A apresentação deve respeitar material, direção e força aparente, contexto, escala e identidade do jogo. Pedra, metal, madeira, energia e gelo não precisam de usar a mesma reação. Não presumir que a tecnologia disponível obriga ao seu uso.

### 2.5 A regra manda; a apresentação comunica

A grelha, as colisões e a ordem dos turnos continuam autoritativas. A animação, a câmara e o áudio representam os resultados; não podem mudar posições lógicas, custos de ação, dano ou inteligência inimiga. A ação válida não deve esperar artificialmente pela animação.

**Expressive + Hybrid** significa posição lógica discreta e apresentação contínua e expressiva. Não significa movimento livre, física autoritativa, alteração de ritmo ou um novo sistema de turnos.

### 2.6 Nem uma animação bonita nem um PASS são aprovação

Avaliar cada mecânica em três dimensões separadas:

- **Funcionalidade:** a regra funciona, inclusive nos limites?
- **Game Feel:** a interação é responsiva, coerente e satisfatória para quem joga?
- **Direção artística:** a ação parece pertencer ao universo e respeita a hierarquia visual?

Uma pode estar aprovada e outra permanecer desconhecida. Não substituir a avaliação do proprietário ou de jogadores por uma apreciação técnica.

---

# PARTE II — DICIONÁRIO DE GAME FEEL

## 3. Movimento e resposta

| Termo | Significado e aplicação | Cuidado em Neon Ruins |
|---|---|---|
| **Responsiveness** | Resposta rápida e consistente ao comando. Um primeiro sinal pode ser corporal, sonoro ou visual. | Uma preparação expressiva não deve esconder ou atrasar um comando válido. Medir latência real quando possível. |
| **Input buffering** | Guardar temporariamente um comando para o executar quando a regra o permitir. | Não é automaticamente necessário: a branch auditada resolve input válido imediatamente. Uma fila lógica altera a política de turnos e requer justificação e aprovação. Não confundir com fila de apresentação. |
| **Anticipation** | Preparação que comunica intenção, por exemplo compressão subtil antes do avanço. | Deve ser curta, opcional na intensidade e não adiar a lógica. |
| **Acceleration** | Velocidade visual aumenta progressivamente. | Pode coexistir com um sinal imediato de resposta. Não é uma mudança de velocidade da grelha. |
| **Deceleration** | Diminuição da velocidade ao aproximar-se do repouso. | Evitar sensação de travagem lenta e reduzir atraso em sequências rápidas. |
| **Easing** | Curva que controla a evolução visual. Linear mantém velocidade; ease-in acelera; ease-out desacelera; ease-in-out e smoothstep suavizam ambos os extremos; Bézier permite outra forma. | Escolher conforme a ação. Nenhuma curva é universalmente melhor; comparar antes/depois. |
| **Squash & stretch** | Compressão e extensão que comunicam elasticidade, velocidade ou contacto. | Respeitar a silhueta e o volume aparente, orientar de acordo com a ação e não deformar a hitbox lógica. |
| **Overshoot** | Ultrapassagem visual pequena seguida de retorno. | Nunca alterar a posição lógica nem sugerir passagem através de uma parede. Pode ser reduzido ou omitido. |
| **Follow-through** | Parte secundária continua depois do movimento principal. | Só quando a personagem tem um elemento e um material que o justifiquem; não inventar acessórios. |
| **Secondary motion** | Respiração, olhar, oscilação e outros detalhes complementares. | Discreto, não repetitivo e sem competir com ameaça ou puzzle. |
| **Inertia** | Impressão de resistência à mudança de movimento. | Não atrasar o reconhecimento de input nem introduzir física real indesejada. |
| **Momentum** | Impressão de conservação de energia e direção. | Útil no gelo ou em empurrões, mantendo o percurso e as consequências lógicas. |
| **Recoil** | Reação em sentido contrário a uma força. | Não confundir reação estética com repulsão que muda a célula lógica. |
| **Hitstop** | Breve pausa de apresentação para reforçar um impacto. | Não suspender turnos, produzir comandos perdidos ou ocultar perigo. Não presumir que é necessário. |
| **Landing** | Contacto, compressão, som e recuperação depois de aterrar ou chegar. | Sem explosão automática; coordenar o momento com a trajetória e o material. |
| **Idle** | Comportamento em repouso, como respiração, olhar ou piscar. | Subtil; a esfera atual já tem oscilação e expressão, pelo que não se começa do zero. |

## 4. Física visual e materiais

**Weight** é a sensação de massa, comunicada pelo tempo, resistência, som e reação. **Impact** liga uma força a uma consequência perceptível. **Friction** pode aparecer em contacto, perda de velocidade e som. **Collision response** deve considerar direção, massa aparente e material, sem inventar uma colisão nas regras.

| Material | Possíveis respostas, a validar | Não inferir automaticamente |
|---|---|---|
| Metal | Ressonância, vibração, deformação ou pequenas faíscas quando justificadas. | Que toda caixa metálica se parte ou produz faíscas. |
| Pedra | Fissuras, lascas, poeira e fragmentos orientados. | Que qualquer parede é destrutível. |
| Madeira | Flexão, rangido, fibras e estilhaços. | Que a massa, durabilidade ou física atual têm de mudar. |
| Vidro | Fratura e fragmentação próprias. | Que o jogo já contém vidro interativo. |
| Energia | Ondulação, dispersão e dissipação. | Que mais brilho significa mais clareza. |
| Gelo | Atrito baixo, contacto, fissuras ou quebra se a regra o suportar. | Que o gelo atual se parte. |
| Orgânico | Deformação e resposta própria do organismo. | Que todo elemento orgânico precisa de animação constante. |

Uma destruição expressiva pode seguir **impacto → reação → deformação/fissura → instabilidade → ruptura → fragmentos → vestígios**. A sequência é uma ferramenta: um objeto pequeno pode precisar de menos etapas. Não criar destroços persistentes ou alterar o tabuleiro sem uma regra e uma proposta aprovadas.

## 5. Vocabulário de efeitos visuais

| Termo | O que é | Pergunta antes de usar |
|---|---|---|
| **Particles** | Elementos pequenos para poeira, fagulha, água, fragmento, fumo ou energia. | Comunicam material e direção? Quantidade, vida, velocidade e custo são proporcionais? |
| **Burst** | Emissão breve a partir de uma origem. | A origem e a força correspondem ao contacto real? |
| **Trail** | Rasto que acompanha o deslocamento. | Ajuda a ler o movimento ou só cobre a grelha? |
| **Afterimage** | Imagem transitória de uma posição anterior. | Comunica velocidade extraordinária ou confunde a posição atual? |
| **Shockwave** | Expansão que sugere impacto ou libertação de energia. | Há um acontecimento com escala suficiente para justificá-la? |
| **Distortion** | Alteração aparente do espaço/imagem. | A técnica realmente afeta a cena ou apenas um véu procedural? O custo e o conforto justificam-na? |
| **Screen shake** | Deslocação temporária de câmara. | Reforça o impacto sem esconder casas? Pode ser reduzido/desligado? |
| **Flash** | Alteração rápida de luminosidade ou cor. | É necessário, curto e controlável? Há alternativa legível? |
| **Glow** | Brilho aparente associado a uma fonte. | Reforça a hierarquia ou apaga a silhueta e os detalhes? |
| **VFX layering** | Composição de deformação, fragmentos, som, luz e outros sinais. | Há hierarquia e silêncio visual entre acontecimentos importantes? |

Avaliar partículas por propósito, origem, quantidade, distribuição, direção, velocidade, tamanho, duração, opacidade, cor, materialidade, sincronização e desempenho. Um sistema de partículas existente não prova qualidade.

## 6. Áudio e feedback tátil

| Termo | Significado | Aplicação responsável |
|---|---|---|
| **Sound feedback / SFX** | Som que confirma e caracteriza uma ação. | Não preencher todo silêncio; não depender dele como único canal essencial. |
| **Transient** | Ataque inicial de um som. | Dá definição ao contacto; cuidado com volumes e transientes abruptos. |
| **Pitch variation** | Pequena alteração de altura. | Útil contra repetição, mas aleatoriedade não substitui composição e não deve alterar RNG de gameplay. |
| **Layered audio** | Sons de contacto, corpo e ressonância com funções distintas. | Evitar empilhar efeitos sem prioridade ou saturar várias ações no mesmo turno. |
| **Spatial audio** | Posição/direção transmitida pelo som. | Pode reduzir necessidade de indicadores; não presumir que já existe ou que todos podem ouvi-lo. |
| **Hit confirmation** | Sinal que distingue contacto, bloqueio, falha ou alvo. | A apresentação tem de corresponder ao resultado real e não inventar dano. |
| **Audio variation** | Variações coerentes entre repetições. | Preservar identidade; testar na mistura real. |
| **Haptics** | Pulsos e padrões táteis em comando compatível. | Usar a infraestrutura existente, respeitar intensidade/desativação, prioridades e limites do dispositivo. Testar fisicamente. |

Som, vibração e animação devem ser coordenados sem fazer uma camada obrigatória para perceber o resultado. Gerar um WAV ou emitir um evento não prova que o som foi ouvido ou que o motor físico vibrou.

---

# PARTE III — GRAMÁTICA DE GAME FEEL

## 7. Como combinar os elementos

### 7.1 Ação

**Intenção → Antecipação → Execução → Contacto ou resultado → Reação → Recuperação.**

Nem todas as fases precisam de ser visíveis ou ter igual duração. Num passo, a recuperação pode ser leve; numa grande destruição, a resposta pode ter mais etapas. A função de cada elemento é tornar a ação intencional e compreensível.

### 7.2 Intensidade

| Intensidade | Exemplo de intenção | Tratamento possível |
|---|---|---|
| Baixa | Movimento normal. | Corpo subtil, contacto breve; sem tremor automático. |
| Média | Empurrão ou mecanismo resistente. | Esforço corporal e reação do material, se fizer sentido. |
| Alta | Impacto importante. | Preparação, contacto e reação mais claros; avaliar som/câmara. |
| Muito alta | Grande destruição pontual. | Composição audiovisual com hierarquia e consequências proporcionais. |

Não aplicar a tabela como ordem para acrescentar sistemas não existentes. O contraste entre acontecimentos pequenos e grandes cria significado.

### 7.3 Causalidade

A apresentação deve ligar causa e efeito na ordem compreensível. Num cenário hipotético de caixa, contacto e alvo, perceber a ação inicial, deslocação, contacto, reação e consequência. Só representar interações que as regras efetivamente suportem.

### 7.4 Continuidade

Evitar teletransportes acidentais, cantos cortados visualmente, rotação incoerente, interrupções bruscas e repetição sem relação com a trajetória. Preservar também a clareza: se comandos ocorrem mais depressa do que frames podem representar, é necessário um limite explícito de atraso e uma política de apresentação, não uma fila lógica infinita.

### 7.5 Contraste

Alternar repouso e movimento, silêncio e som, luz e sombra, tensão e libertação. O ambiente não precisa de estar permanentemente animado para parecer vivo.

---

# PARTE IV — DICIONÁRIO DE GAMEPLAY

## 8. Decisões, regras e aprendizagem

| Termo | Significado | Pergunta de avaliação |
|---|---|---|
| **Gameplay** | Regras, decisões, desafios, ações e consequências da experiência. | Que decisão real existe, além da aparência? |
| **Core loop** | Ciclo de atividades que sustenta o jogo. | O ciclo é observar → decidir → agir → resolver → reavaliar, e não apenas repetir recolha/portal? |
| **Game mechanic** | Regra que permite ou limita uma interação. | Está implementada, coerente e sujeita a que custo? |
| **Player agency** | Capacidade de influenciar resultados com escolhas significativas. | As opções produzem consequências distinguíveis? |
| **Decision space** | Conjunto de ações e informações disponíveis num momento. | O jogador pode raciocinar antes de escolher? |
| **Risk and reward** | Relação entre perigo e possível benefício. | O risco é observável e proporcional à recompensa? |
| **Skill ceiling** | Espaço para aumentar o domínio de uma mecânica. | Há profundidade além de memorização arbitrária? |
| **Fairness** | Possibilidade de relacionar decisões com consequências e conhecer pistas necessárias. | Uma falha oferece informação para aprender? |
| **Readability** | Clareza do estado relevante sem excesso de explicação. | A decisão é possível sem ler informação irrelevante? |
| **Telegraphing** | Comunicação antecipada de intenção através de postura, padrão, som ou outro sinal. | É consistente, detetável e não revela informação injustificada? |
| **Emergent gameplay** | Situações resultantes da combinação de regras existentes. | A combinação é realmente suportada? Não presumir que caixas possam atingir inimigos se a regra não o permite. |
| **Puzzle design** | Desafios de observação, interpretação, experimentação e resolução. | As regras e consequências são coerentes e a solução não é arbitrária? |
| **Environmental storytelling** | História comunicada por espaço, objetos, arquitetura e vestígios. | O ambiente acrescenta contexto sem depender sempre de diálogos? |
| **Enemy archetype** | Tipo de inimigo com identidade, silhueta e comportamento próprios. | Pode ser distinguido e aprendido? |
| **Enemy pattern** | Padrão consistente de comportamento. | Pode ser reconhecido sem revelar todos os movimentos? |
| **Spatial reasoning** | Leitura de posições, distâncias, obstáculos e trajetórias. | As animações mantêm clara a célula e o perigo relevantes? |
| **Turn economy** | Custo e valor de ações face ao avanço dos turnos. | Uma alteração visual muda acidentalmente o número ou a ordem de ações? |
| **Progression** | Evolução de capacidades, desafios e possibilidades. | Acrescenta decisões, não só números? |
| **Difficulty curve** | Evolução da complexidade e exigência. | Introduz combinações e sinais antes de punições injustas? |
| **Feedback loop** | Relação entre ação, resultado e informação recebida. | A pessoa percebe o que funcionou, falhou e porquê? |

---

# PARTE V — GRAMÁTICA DAS MECÂNICAS

Estas são orientações de avaliação e prototipagem. Verificar a existência e as regras de cada ação antes de a tratar como capacidade atual.

## 9. Movimento

**Objetivo:** a ação mais frequente deve ser agradável e expressiva sem perder precisão. Sinal imediato, preparação subtil, percurso contínuo, orientação, contacto, recuperação e repouso. Nunca alterar colisões ou turnos. Testar quatro direções, inputs consecutivos, mudança de direção, bloqueio, gelo, pausa e reinício. A personagem atual é uma esfera: comunicar esforço e movimento com a sua própria silhueta, sem presumir pés, pernas ou um rig novo.

## 10. Ataque

Quando uma ação de ataque existir, avaliar preparação, intenção, direção, execução, contacto, reação e recuperação; distinguir acerto, bloqueio e falha. Não implementar um ataque novo por existir uma secção no guia.

## 11. Empurrar

A personagem aplica força, o objeto reage e o material oferece resistência aparente. Coordenar corpo, caixa e consequência sem atrasar a regra. Madeira e metal não têm obrigatoriamente o mesmo som ou movimento. Não presumir que caixas possam ferir inimigos.

## 12. Derrubar

Se houver derrube suportado pelas regras, perda de equilíbrio, inclinação, queda e contacto podem comunicar o resultado. O estado final e eventuais bloqueios têm de ser reais; não simular uma queda que o tabuleiro não reconhece.

## 13. Destruir

Impacto, reação, ruptura e vestígios devem respeitar material e escala. Não trocar toda destruição por explosão genérica nem criar consequências persistentes que as regras não suportem.

## 14. Teletransporte

Preparação energética, desaparecimento, transição, reaparecimento e dissipação são possibilidades, não requisitos para cada frame. Preservar os limites reais do Blink, o custo e o facto de atravessar casas intermédias sem as tratar como percurso a pé. A distorção visual não deve ocultar a posição real nem gerar espera desnecessária.

## 15. Saltar

Preparação, impulso, trajetória, suspensão, contacto e recuperação podem caracterizar um salto. Preservar distância, recurso, destino permitido e turno. A apresentação não pode mostrar um obstáculo atravessado de forma contraditória.

## 16. Morrer

A pessoa deve compreender a causa e a consequência. Impacto, perda de energia, colapso e transformação podem formar uma sequência própria, sem espera excessiva. Oferecer redução de flashes/movimento e investigar conforto antes de aumentar intensidade; não substituir a regra de captura sem aprovação.

## 17. Interagir

Uma alteração do próprio objeto — pressão, movimento, luz, portão ou mecanismo — pode confirmar a interação. Adicionar interface apenas quando fornece informação necessária ou alternativa acessível. Não transformar cada ação numa notificação.

---

# PARTE VI — DIREÇÃO ARTÍSTICA E LINGUAGEM VISUAL

## 18. Identidade proposta pelo proprietário

- Ruínas futuristas misteriosas, com profundidade e atmosfera.
- Azul profundo e verde-azulado como base; âmbar/dourado e outras cores reservados a funções ou materiais específicos.
- Personagem expressiva e imediatamente reconhecível.
- Pedra, metal, energia e estruturas orgânicas com respostas coerentes e distintas.
- Energia visual controlada: não iluminar tudo nem cobrir o tabuleiro de efeitos.
- Câmara que valoriza o acontecimento sem prejudicar decisões espaciais.

É direção de trabalho, não autorização para substituir os assets, paletas ou sistemas existentes globalmente. A paleta concreta, saturação, materiais e intensidade devem ser aprovados com uma amostra.

## 19. Silhouette

A forma exterior deve ajudar a reconhecer personagem, ameaça e objeto quando os detalhes são pequenos ou estão sob iluminação diferente. Validar na resolução alvo e no tabuleiro real.

## 20. Shape language

Formas arredondadas, angulares, verticais ou irregulares podem sugerir elasticidade, perigo, autoridade ou instabilidade. Não são leis universais: usar de forma consistente com o universo e confirmar se as pessoas interpretam corretamente.

## 21. Visual hierarchy

Distinguir jogador, ameaças, interações, obstáculos, objetivos e decoração por composição, escala, contraste e movimento. Não resolver automaticamente todos os conflitos com ícones, cores saturadas, setas ou texto.

## 22. Lighting

Iluminação pode criar profundidade, atmosfera e foco. Não sacrificar legibilidade nem assumir que um halo desenhado equivale a iluminação física. Medir custo real antes de introduzir efeitos dispendiosos.

## 23. Environmental feedback

Portas, luzes, água, máquinas e estruturas podem responder às ações quando as respetivas regras existirem. O mundo deve parecer coerente, e uma superfície decorativa não deve fingir ter uma regra que não possui.

---

# PARTE VII — SISTEMA DE AVALIAÇÃO

## 24. Dez dimensões

Cada sistema deve ser analisado separadamente em: **Existence**, **Functionality**, **Integration**, **Game Feel**, **Readability**, **Art Direction**, **Timing**, **Coherence**, **Performance** e **Player Experience**.

| Nota, quando houver evidência | Interpretação |
|---:|---|
| 0 | Inexistente. |
| 1 | Muito deficiente. |
| 2 | Deficiente. |
| 3 | Funcional, mas rudimentar. |
| 4 | Bom. |
| 5 | Excelente. |
| **UNKNOWN** | Não há evidência suficiente para atribuir nota. Não converter em zero nem em aprovação. |

A escala não é um prémio por quantidade de código. Associar a cada nota fonte, condições, observador e limitações. Para Game Feel e Player Experience, recolher opiniões e observações humanas; uma sonda de posições não permite inventar uma nota de satisfação.

### 24.1 Estados de evidência

- **FACT:** confirmado numa fonte ou implementação identificável.
- **MEASURED:** medido por teste ou instrumento, com condições e amostra.
- **OBSERVED:** observado diretamente durante execução ou captura, identificando se é simulação controlada ou jogo real.
- **INFERRED:** conclusão derivada de evidências; explicar o raciocínio.
- **HYPOTHESIS:** possibilidade a testar, não conclusão.
- **UNKNOWN:** ainda não conhecido; especificar o que falta.

**UNKNOWN ≠ FALSE; NOT TESTED ≠ PASS; NOT OBSERVED ≠ DOES NOT EXIST; INFERRED ≠ FACT.** Código não prova qualidade; teste escrito não prova execução; compilação não prova experiência agradável. Crítica do proprietário é uma observação relevante e não deve ser descartada por um teste funcional.

---

# PARTE VIII — MANUAL DE IMPLEMENTAÇÃO

## 25. Ciclo de uma unidade de trabalho

1. Inspecionar branch, estado local, regras, desenho, input e sistemas dependentes.
2. Identificar a mecânica e observar o comportamento atual.
3. Distinguir relato do jogador, factos, medições e hipóteses.
4. Definir resultado, invariantes, riscos e testes.
5. **Apresentar uma proposta localizada e obter aprovação antes de alterar código.**
6. Implementar uma unidade, reutilizando o que é adequado.
7. Executar testes funcionais e de regressão.
8. Observar a execução visual e, quando aplicável, ouvir e testar um comando real.
9. Medir no hardware alvo, comparar, corrigir regressões e registar limites.
10. Entregar projeto e evidências; fazer checkpoint/commit somente com autorização explícita.

Investigar o suficiente para agir com segurança, não indefinidamente. A aprovação de uma direção geral não autoriza alterar outras mecânicas, integrar branches ou fazer commit.

## 26. Regras de engenharia

- Preservar regras, turnos determinísticos, colisões, geração, saves e entradas existentes, salvo autorização específica.
- Separar resultado lógico de apresentação; não duplicar ou executar ações duas vezes.
- Reutilizar arquitetura existente quando adequada e não criar sistemas paralelos por elegância.
- Não introduzir funcionalidades, assets, bibliotecas ou efeitos não solicitados.
- Tratar interrupção, captura, mudança de sala, pausa, reinício, input rápido e frame lento como cenários explícitos.
- Não consumir RNG de gameplay para variação cosmética; a auditoria identificou partilha de RNG a investigar em tarefa própria.
- Manter informação essencial por meios acessíveis e evitar movimento/flash/tremor excessivos.
- Não remover pistas, textos, efeitos ou testes sem demonstrar que a alternativa comunica e preserva acessibilidade.

## 27. Plano de testes para cada mecânica

**Funcionais:** execução isolada, repetida e consecutiva; bloqueio e colisão; regras e custo de turnos; mudanças de direção; interrupções, pausa/retoma, reinício e troca de sala; resultados com efeitos sonoros ou vibração desligados; regressão de perfis e checkpoints quando afetados.

**Visuais e sensoriais:** capturar contexto e ações iguais antes/depois; separar vídeo em tempo real de frames simulados; verificar antecipação, continuidade, contacto, legibilidade e hierarquia. Ouvir a mistura a volumes equilibrados; testar hardware físico quando disponível. Não aprovar Game Feel apenas por análise de curvas.

**Pessoas:** observar tarefas sem dar a solução; pedir previsão de corrente, perigo, ação e consequência quando aplicável. Registar erros e comentários sem culpar ninguém. Testar alternativas acessíveis, não apenas a preferência do auditor.

**Movimento:** quatro direções; sequência rápida, inversão e curva; bloqueio no início e durante animação; gelo/corrente; caixa; contacto com inimigo; captura; salto e Blink como regressões; repouso, pausa, reset e mudança de sala. Conferir que o visual converge à posição lógica e nunca inventa colisão ou ação.

**Performance:** mesma resolução, renderer, sementes, ações e opções antes/depois; medir frame time mediano, p95 e casos de pico, além de perceber fluidez. Definir um cenário com efeitos simultâneos e outro sem; não anunciar hardware não testado.

## 28. Hardware e orçamento

Referência do proprietário: **Intel Core i5-8250U, Intel UHD 620, 12 GB RAM, Windows 11, 1366×768**; objetivo **60 FPS sempre que possível**, não resultado já comprovado. Testar também a resolução mínima suportada e o hardware mais limitado disponível.

Evitar partículas excessivas, pós-processamento sem benefício, shaders dispendiosos, redraw e processamento duplicados, e animações ativas sem necessidade. Uma medição headless ou llvmpipe por CPU não substitui a GPU física. Anotar ambiente, amostra, VSync e limitações.

---

# PARTE IX — DIRETRIZES PARA ARENA SUPER

## 29. Interpretação e limites

Ler este guia como critério, não como backlog a executar todo de uma vez. Consultar a branch e documentos atuais; distinguir design futuro de comportamento existente; propor uma unidade, implementar somente após a autorização aplicável, testar e apresentar evidências.

Não adicionar linhas de trajetória piscantes, grandes avisos de turno, células vermelhas, brilhos ou sons em cada clique apenas porque constam de uma sugestão genérica. Primeiro verificar se o problema existe, se o sinal acrescenta informação e se respeita a filosofia e acessibilidade.

## 30. Princípio de diagnóstico

- **Andar parece tedioso:** investigar curva, rapidez da resposta, orientação, continuidade, aterragem, personalidade e som; não presumir que faltam partículas.
- **Ameaça não é compreendida:** investigar silhueta, consistência, postura, tempo de antecipação e consequência; não adicionar automaticamente setas e avisos.
- **Destruição não satisfaz:** investigar contacto, material, reação, ritmo, som e vestígio; não assumir que basta aumentar partículas.
- **Puzzle não é compreendido:** investigar a ligação entre estado dos objetos e mecanismo; só depois avaliar ajuda contextual ou alternativa acessível.

## 31. Formato obrigatório para cada tarefa

| Secção | Conteúdo |
|---|---|
| `PROJECT_STATE` | Branch, referência, alterações locais relevantes e limites. |
| `CURRENT_TASK` | Unidade em análise e exclusões. |
| `EXISTING_IMPLEMENTATION` | O que existe, onde e como se relaciona. |
| `OBSERVED_PROBLEM` | Crítica recebida e problemas concretos observados, sem atribuição de culpa ao jogador. |
| `EVIDENCE` | FACT, MEASURED, OBSERVED, INFERRED, HYPOTHESIS ou UNKNOWN, com condições. |
| `PROPOSED_SOLUTION` | Alteração localizada, decisões e justificação. |
| `ARCHITECTURAL_IMPACT` | Ficheiros, sistemas, dependências e invariantes. |
| `TEST_PLAN` | Testes funcionais, sensoriais, humanos e de performance. |
| `RESULTS` | O que foi realmente executado e o que permanece pendente. |
| `FAILED_EXPERIMENTS` | Tentativas falhadas e causa conhecida; se nenhuma, dizer isso. |
| `PERFORMANCE` | Medições identificadas ou limitação do ambiente. |
| `NEXT_ACTION` | Próxima ação concreta e autorizações necessárias. |

Não apresentar como concluído algo que ainda não foi implementado ou validado. Não fazer commit sem autorização explícita.

---

# PARTE X — PRIMEIRA APLICAÇÃO: MOVIMENTO

## 32. Direção aprovada e limite atual

- **Estilo:** Expressive.
- **Deslocação:** Hybrid.
- **Lógica:** grelha e turnos determinísticos.
- **Apresentação:** deslocação contínua, corpo expressivo e consequências legíveis.
- **Primeira unidade proposta:** movimento do jogador, documentado no plano histórico.
- **Âmbito desta tarefa, entretanto ampliado e autorizado:** movimento, combate, reações dos inimigos e materiais, mantendo as regras existentes. Não se presume autorização para alterações futuras fora deste âmbito nem para mudanças estruturais ou destrutivas.

### 32.1 Gramática pretendida

**Reconhecimento imediato → preparação subtil → aceleração/travel → rotação coerente → chegada e compressão → eventual overshoot → recuperação → idle.** A sequência é uma direção, não uma obrigação de introduzir todas as fases com durações fixas. Testar se resulta agradável e responsiva.

### 32.2 Personalidade

Respiração, olhar, piscar, pequenas reações e variação de postura podem dar vida à esfera. Usar de forma contextual e com baixo custo; não inventar pernas nem saturar o repouso. A animação deve continuar legível em baixa resolução e sem depender de flash ou som.

### 32.3 Invariantes

Não alterar célula lógica, colisão, custo ou ordem do turno; não atravessar obstáculos nem alterar regras ou comportamento dos inimigos; não introduzir movimento livre; preservar gelo, salto e Blink; não perder ou duplicar comandos; não substituir desenho/textura sem necessidade demonstrada. Entradas rápidas precisam de política explícita. A apresentação não deve esconder o estado real nem revelar o próximo movimento inimigo.

### 32.4 Aprovação

Resposta consistente, trajetória clara, personalidade, aterragem e recuperação convincentes, interrupções previsíveis, ausência de regressões e performance aceitável. A qualidade deve ser observada e julgada com pessoas; o objetivo de 60 FPS no hardware de referência deve ser medido, não presumido.

---

# PARTE XI — GLOSSÁRIO RÁPIDO

| Termo | Significado | Termo | Significado |
|---|---|---|---|
| Game Feel | Sensação da interação. | Game Juice | Reforço sensorial e expressivo adequado à ação. |
| Gameplay | Regras e experiência de jogo. | Responsiveness | Capacidade de resposta. |
| Input buffer | Armazenamento temporário de comandos. | Anticipation | Preparação de uma ação. |
| Squash & stretch | Compressão e extensão. | Easing | Curva de interpolação. |
| Overshoot | Ultrapassagem visual. | Follow-through | Continuação do movimento secundário. |
| Secondary motion | Movimento complementar. | Inertia | Resistência aparente à alteração de movimento. |
| Momentum | Conservação aparente de direção/energia. | Recoil | Recuo ou reação. |
| Hitstop | Pausa visual de impacto. | Landing | Contacto/aterragem. |
| Idle | Repouso expressivo. | Hitbox | Região usada para detetar contactos. |
| Hurtbox | Região vulnerável de uma entidade. | VFX | Efeitos visuais. |
| SFX | Efeitos sonoros. | Particle system | Sistema de partículas. |
| Trail | Rasto. | Afterimage | Pós-imagem temporária. |
| Shockwave | Onda de choque. | Screen shake | Movimento de câmara por impacto. |
| Material response | Resposta específica do material. | Game mechanic | Regra de interação. |
| Core loop | Ciclo principal. | Player agency | Agência do jogador. |
| Readability | Legibilidade. | Telegraphing | Comunicação antecipada de uma intenção. |
| Emergent gameplay | Situações originadas pela combinação de regras. | Environmental storytelling | Narrativa ambiental. |
| Enemy archetype | Tipo de inimigo com identidade própria. | Turn economy | Economia de ações e turnos. |
| Difficulty curve | Curva de dificuldade. | Feedback loop | Ciclo de ação, resultado e informação. |
| Visual hierarchy | Hierarquia visual. | Shape language | Linguagem de formas. |
| Silhouette | Forma exterior reconhecível. | Diegetic UI | Interface integrada no mundo do jogo. |
| Polish | Refinamento da experiência. | Regression | Problema introduzido numa funcionalidade anterior. |

## Conclusão

O jogador não tem de aprender a pensar como o programador. O jogo tem de aprender a comunicar com o jogador. Não precisamos de explicar tudo, aplicar efeitos a tudo ou substituir o que funciona. Precisamos de um mundo coerente, ações intencionais e uma experiência que funcione, comunique, satisfaça e pertença à identidade de Come To Me.
