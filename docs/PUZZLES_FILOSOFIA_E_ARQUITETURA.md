# Puzzles de Neon Ruins — filosofia, contexto e arquitetura proposta

**Estado:** referência de design e auditoria, não uma implementação do Puzzle Forge. A Instalação Submersa é um protótipo separado no laboratório existente, ainda sujeito às evidências e limitações do [checkpoint](CHECKPOINT_GAME_FEEL.md). As propostas de chefe e travessia abaixo **não estão implementadas**.

**Data da varredura:** 4 de novembro de 2026.

**Base inspecionada:** `bd2f93183dc488c439ffa8fea354f1eb8a3daa2a`, após o merge do PR #10. O estado posterior deve ser novamente confrontado com as fontes.

## 1. Decisão e limites

**Decisão do proprietário:** seguir uma direção **híbrida**. Puzzles artesanais podem ensinar, criar descobertas e momentos memoráveis; variações procedurais de mecânicas compreendidas podem prolongar a experiência, desde que sejam validadas e selecionadas pela qualidade. O jogo já mistura câmaras desenhadas e andares gerados; isso não demonstra que a progressão ou a experiência desejadas estejam resolvidas.

A decisão não fixa uma percentagem de conteúdo, não exige um modo separado, não autoriza alterar saves ou layouts existentes e não aprova a implementação imediata de novos subsistemas. A proporção, a integração narrativa, a progressão e o orçamento serão decididos com protótipos e jogadores.

**Princípio central:** um puzzle difícil deve desafiar o raciocínio, não a capacidade de interpretar controlos ou regras escondidas. Uma solução encontrada por um algoritmo prova apenas uma propriedade do modelo usado; não prova clareza, interesse, diversão ou um momento Eureka para uma pessoa.

### Identidade de Game Design estabelecida pelo proprietário

No Come To Me, nada deve ser incluído apenas para ocupar espaço ou prolongar uma tarefa. Cada nível tem uma intenção e relações lógicas entre lugar, história, mecanismos e consequências. A experiência deve favorecer observação, experimentação, descoberta e surpresas compreensíveis em retrospetiva; o ambiente, os inimigos e os próprios recursos podem servir de ferramentas. Um objeto ou recompensa pode adquirir outros usos, custos e consequências quando isso for coerente e justo.

Isto **não** significa que todos os níveis precisem de puzzle, grande complexidade ou da mesma fórmula. Perseguição, combate, movimento, exploração, sobrevivência, pausas e níveis simples também podem ser significativos. Não forçar o estilo do autor a uma lista de convenções e não acrescentar caixas, placas, interruptores, transporte, repetições ou recompensas sem propósito. Integrar raciocínio e tensão quando essa combinação enriquecer a experiência, mantendo a lógica de turnos e permitindo que o jogador compreenda riscos e efeitos.

**Antes de aprovar um puzzle, responder:**

1. Qual é o problema que o jogador enfrenta?
2. Por que os mecanismos existem naquele local e estão relacionados?
3. O que se descobre pela observação e pela experimentação, e quais pistas tornam a descoberta justa?
4. Há raciocínio ou apenas uma sequência de execução e deslocações repetitivas?
5. O que muda no mundo como consequência da ação?
6. Como contribui para a identidade, história ou progressão?
7. Se fosse removido, o que de significativo se perderia? Se a resposta for apenas duração ou uma recompensa isolada, redesenhar ou eliminar.

Auditar separadamente **correção técnica**, **experiência real** e **identidade**. Pistas devem permitir inferência, não entregar automaticamente a solução; perigos, custos, controlos e recuperação precisam, porém, de feedback legível. Um solver, um teste automatizado e uma hipótese de designer não substituem observar jogadores.

### Duas ideias futuras — não são funcionalidades existentes

- **Colosso Condutor:** imaginar um chefe que adapta o comportamento ao jogador, incluindo os saltos, e possa ser atraído para um risco elétrico com uma relação causal visível. A descarga deve causar consequências limitadas e previsíveis; qualquer impulso ou recuo usa células válidas, fronteiras, colisões e uma reação finita. O combate deve continuar e nunca entrar numa animação ou ciclo infinito. O jogo atual já faz inimigos comuns serem derrotados e elites perderem uma vida por turno em eletricidade, mas **não possui este chefe adaptativo nem a reação proposta**. Não se pressupõe que inimigos ativem placas: atualmente não ativam.
- **Travessia Sacrificável:** explorar uma caixa reutilizável cuja posição ajude a resolver um circuito e um escudo que, como recurso de combate, possa ser conscientemente sacrificado para passar um perigo. Custo e resultado devem ser observáveis e previsíveis, com alternativa ou recuperação justa se o recurso for gasto cedo, sem armadilha irreversível. O escudo atual absorve dano elegível, mas **este encontro, a caixa de múltiplas funções e as garantias específicas ainda não foram implementados nem testados**.

Ambas são sementes para protótipos e playtests, não autorização para acrescentar um chefe, mudar o combate/campanha ou prometer um resultado. Investigá-las mais tarde, após definir contexto, riscos, estados, recuperação e como se relacionam com a progressão.

### Aplicação inicial: Instalação Submersa

- **Problema e local:** uma instalação de manutenção inundada impede a passagem. Três portas intertravadas selecionam setores; uma placa ligada à escotilha permite aceder ao local onde se encaixa o gerador. São elementos de infraestrutura da instalação, não objetos distribuídos para conceder uma recompensa.
- **Relação e descoberta pretendidas:** o mesmo gerador alimenta passagem e painel, mas também eletrifica a água. A pista da sequência está no painel do setor, não na resposta permanente do HUD; cabos, mudanças de estado e o perigo devem permitir perceber a relação. A sequência correta é conteúdo de teste/desenvolvimento e não é apresentada aqui como pista que o jogador deva ler antes de jogar.
- **Consequência:** desligar o gerador montado corta o perigo sem o desmontar; a placa da segunda caixa aciona uma **comporta mecânica** ligada ao dreno, independente da energia elétrica. A água baixada revela três intertravamentos ligados à saída. A abertura, drenagem e sequência persistem dentro da tentativa, e o gerador permanece instalado.
- **Recuperação:** as portas intertravadas não apagam caixas sobre os seus limiares e podem ser selecionadas novamente; `Z` desfaz até 128 ações e `R` reconstrói a tentativa. Caixas presas num canto podem exigir desfazer ou reiniciar: não se afirma que todas as posições têm solução sem isso.
- **Revisão crítica, não veredito de diversão:** o mapa foi reduzido para limitar deslocações e a comunicação tenta mostrar ligações sem ditar a solução. Ainda é preciso observar se os trajetos e os três intertravamentos acrescentam intenção ou apenas repetição, se as pistas são visíveis com o HUD, se o custo de regressar à fonte é compreensível e se tudo combina com o ritmo de Come To Me. O protótipo não tem perseguição ou combate na sala e não demonstra, por si só, essa integração. O checkpoint distingue o que foi realmente testado.

### Proveniência das ideias

- O proprietário forneceu a transcrição de **Patrick Traynor**, *System-Centric Puzzle Design in 'Patrick's Parabox'*, aproximadamente 0:07–27:35. O título e a identificação do autor são corroborados pelo vídeo [1](https://www.youtube.com/watch?v=HAvS-RwkjdA) e pelos slides oficiais [2](https://media.gdcvault.com/gdc2024/Slides/GDC+slide+presentations/Traynor_Patrick_SystemCentricPuzzle.pdf).
- O proprietário também forneceu a continuação de **Brett Taylor**, *Puzzle Game Magic Secrets*: a transcrição vai de aproximadamente 0:02 a 1:00:41 e inclui perguntas e respostas. A anterior limitação aos 2:15 deixou de se aplicar. O vídeo é [3](https://www.youtube.com/watch?v=B36_OL1ZXVM); os slides oficiais estão em [4](https://media.gdcvault.com/gdc2019/presentations/Taylor_Brett_PuzzleGameMagic.pdf). O jogo referido é **Linelight**, apesar dos erros de transcrição automática.
- As sínteses partem das transcrições fornecidas e foram confrontadas com os slides de ambas as palestras, trechos das transcrições disponíveis nas páginas dos vídeos e os seus capítulos gerados automaticamente; os vídeos não foram ouvidos nesta tarefa. Os tempos abaixo são referências aproximadas a esses capítulos, não citações literais. Apresentamos as aplicações a Neon Ruins como propostas do projeto, não como afirmações dos autores sobre este jogo.
- As descrições anteriores de **Mark Brown / Game Maker's Toolkit**, do material sobre longevidade atribuído a **Fábrica de Jogos**, e das aulas de progressão e game feel continuam a ser resumos do proprietário, sem transcrições independentes aqui. Não inventar citações ou tempos para elas.

### Contribuições das duas palestras

| Fonte e trecho aproximado | O que o autor descreve | Aplicação a investigar em Neon Ruins |
| --- | --- | --- |
| Traynor, 1:58 e 5:15 | Construir puzzles para mostrar um sistema interessante; simplificar etapas e possibilidades pode ampliar o acesso, mas também permitir soluções acidentais sem compreensão. | Testar uma introdução pequena e uma segunda oportunidade de demonstrar a mesma relação, sem exigir que toda sala tenha uma pegadinha ou seja difícil. |
| Traynor, 9:05 | A ordenação é uma atividade própria: inserir, modificar, remover, reordenar ou tornar opcional; oferecer caminhos alternativos pode evitar bloqueio. | Rever a passagem entre conceitos e prototipar reforços/opções antes de alterar a campanha, sem presumir que a agenda atual já acompanha aprendizagem. |
| Traynor, a partir de 14:56 | Explorar interações, espaços de teste e pares de mecânicas; observar tentativas que quase funcionam; criar *show levels* e investigar variantes. A enumeração de pares é creditada a Taylor. | Usar caixas, materiais, corrente e energia existentes como terreno de investigação. Tentativas dos jogadores são oportunidades de design, não prova de que uma regra deva ser alterada. |
| Traynor, parte final | Comparar variantes de regras e preferir, no seu jogo, as mais coerentes com o sistema; algumas foram isoladas em conteúdo posterior. | Evitar regras arbitrárias e avaliar onde uma exceção seria compreensível. Recursão de caixas e conteúdo pós-jogo são exemplos de outro jogo, não requisitos de implementação. |
| Taylor, 3:53, 5:50 e 8:16 | Usa “RAM humana” e barras percentuais **metafóricas** para falar de memória de trabalho e espaço de possibilidades; compara experiências artesanais e procedurais. | Distinguir novidade, memória, perceção e opções; não calcular uma percentagem de memória nem supor que um principiante conhece as mesmas possibilidades de um especialista. |
| Taylor, 11:14 e 17:42 | Define ruído, propõe descrever a solução para o encontrar e admite usá-lo intencionalmente, por exemplo para evitar resolução acidental. | Identificar custo e propósito dos elementos; testar uma versão simplificada sem apagar automaticamente feedback, alternativas ou contexto. |
| Taylor, 36:58, 38:34, 41:24 e perguntas a partir de 53:23 | Explora mecânicas, combinações e frases de solução; na pergunta sobre geração procedural admite não ter resposta definitiva e continuar a experimentar. | A matriz e a frase são ferramentas de descoberta; nem solubilidade nem um catálogo de combinações substituem seleção e playtesting. |

Taylor apresenta **sete lições de Linelight** a partir de 17:42: simplificar e rever; cortar níveis sem propósito; não confundir saber a solução com conseguir executá-la; separar ação e lógica sobretudo em puzzles de solução única ou poucas soluções; tornar claro o resultado e as ações possíveis; proteger a confiança estabelecida pelo jogo; e escolher entre explorar exaustivamente o sistema e favorecer a experiência desejada. São lições situadas no seu contexto, não leis universais: em Neon Ruins podem existir encontros táticos mistos, desde que a promessa e as consequências sejam compreensíveis. “Solução inequívoca” significa que o jogador compreende o que aconteceu, não que haja obrigatoriamente uma única rota.

Traynor relata sessões gravadas com pensamento em voz alta, muitas vezes com uma ou duas pessoas por ciclo e atenção a jogadores novos (capítulo de 11:49). Isso é uma técnica útil, não um protocolo obrigatório: gravação, fala e recolha de dados devem ser voluntárias, acessíveis e consentidas. Taylor define diversão, na introdução da palestra, em termos de demonstrar perícia, mestria ou engenho; essa definição não esgota as formas de diversão.

## 2. Varredura: o que já existe

| Área | Estado observado no código | Limite importante |
| --- | --- | --- |
| Geração de mundo | `level_generator.gd::generate()` usa WFC de adjacências e depois constrói um grafo de salas; há limite de tentativas e fallback. `game.gd::generate_floor()` instancia o andar. | WFC e conectividade não compreendem a solução de um puzzle nem provam que é interessante. |
| Agenda | `special_schedule.gd::family_for()` usa RNG próprio por seed, propõe especiais a intervalos de 3–9 andares, evita repetição consecutiva e preserva marcos reservados. Pode haver fallback quando não se verifica uma câmara. | A agenda varia famílias, mas não acompanha o que cada jogador realmente aprendeu; não garante a sequência ensinar → reforçar → combinar. |
| Conteúdo artesanal | `environment_chambers.gd` contém quatro câmaras originais e o protótipo Instalação Submersa; `special_levels.gd` e `sokoban_generator.gd` contêm modelos de caixas, portão e circuito, com reflexões por seed. | São modelos delimitados; refleções não constituem geração ilimitada nem provam diversidade de raciocínio. As câmaras de laboratório são separadas da campanha e não a gravam; a nova exige validação indicada no checkpoint. |
| Mecânicas | `environment_system.gd` concentra caixas, corrente, gelo, condução, placas e portões. `game.gd` resolve movimento, espera, salto, Blink, demolição, inimigos e perigos por ações válidas. | As combinações não são todas equivalentes: os exemplos de design não devem ser confundidos com regras já implementadas. |
| Runas | `game.gd::_plan_puzzle_route()` pesquisa posição e progresso da sequência, incluindo reinício quando se pisa uma runa futura. `tests/self_test.gd` exercita uma sequência conectada mas impossível e outra concluída com ações reais. | Não é um solver universal para caixas, ameaças ou todas as habilidades. |
| Câmaras | `special_levels.gd::solve()` faz BFS limitada em posição e posições de uma ou duas caixas; modela materiais, placas e condução e evita atravessar água eletrificada. `generate_floor()` não aceita um resultado sem rota verificada. | A pesquisa limita-se ao modelo e às ações de andar/empurrar; não modela inimigos, correntes, armadilhas, salto, Blink, demolição ou todos os recursos. O limite é 120.000 estados; busca truncada é **desconhecida**, não prova de impossibilidade. Uma rota não prova solução única nem ausência de bloqueios posteriores. |
| Recuperação | `game.gd::restart_floor()` recompõe o início do andar, incluindo recursos. `undo_sokoban_move()` oferece até 128 ações de desfazer nas câmaras Sokoban e no protótipo Instalação Submersa. | Desfazer não é universal para circuito, portão, runas ou todo o jogo. `R` reinicia o andar e perde o que foi feito nesse andar; não é reset local de cada objeto. |
| Comunicação | `hud.gd` mostra objetivo, contagem de placas/runas, estado do portal e instruções; `game.gd` desenha materiais, placas, portões e corrente. | Presença de texto ou ícones não prova que o jogador os entenda. O aviso de circuito já explica diretamente a ligação água/metal: pode ensinar, mas também pode reduzir a descoberta; comparar com jogadores antes de mudar. |
| Recompensas e ruído potencial | `_generate_special_room()` pode colocar moedas, escudos e poder adicional; os desafios e recompensas continuam a existir. | Estes elementos podem competir pela atenção **ou** servir economia, aprendizagem e mundo. Não são automaticamente lixo só por não integrarem uma rota do solver. |
| Avaliação | Há testes lógicos, sweeps e suítes de renderização em `tools/test-godot.sh`; o [CI da integração](https://github.com/edmundo738/CTM--Come-To-Me-/actions/runs/41813040723) passou no commit `f305dd0`, cuja árvore corresponde à base desta varredura. | É evidência histórica de regressão técnica, não um novo teste desta tarefa nem aprovação humana. Não existem aqui avaliadores automáticos de diversão, clareza ou carga cognitiva. |

**Exemplos que não devem ser anunciados como existentes:** inimigos não ativam placas em `EnvironmentSystem.update_mechanisms()`; podem impedir que um portão já aberto feche ao ocupá-lo. `_trigger_traps()` afeta o jogador, não os inimigos. O portal atual conclui o andar; não transporta caixas. Blink transporta o jogador, não objetos. Água eletrificada, por outro lado, pode atingir inimigos. Queda com gravidade e portais intermédios de objetos são propostas, não regras estabelecidas.

## 3. Princípios permanentes

### Obrigatórios ao projetar ou rever um puzzle

1. **Objetivo legível; solução descoberta.** Comunicar o que precisa de ser alcançado, os estados relevantes e as consequências das ações sem necessariamente contar a sequência. O jogador pode desconhecer a solução; não deve precisar de adivinhar regras escondidas.
2. **Mecânicas consistentes e restrições significativas.** Explorar limites já compreensíveis — por exemplo, empurrar sem puxar, materiais ou direção da corrente — em vez de adicionar regras arbitrárias para produzir dificuldade.
3. **Propósito por encontro.** Distinguir ensinar, reforçar, combinar, surpreender, explorar, oferecer uma pausa ou criar pressão tática. Nem todo andar precisa de um Eureka; até uma pausa deve servir o ritmo ou o mundo.
4. **Progressão.** Introduzir uma relação de cada vez, dar oportunidade de experimentá-la, reforçar e só depois combiná-la; não presumir que um jogador aprendeu porque passou por uma sala ou viu um texto. Uma demonstração muito simples pode servir a aprendizagem; se alguém a resolver por acaso, oferecer outra oportunidade de compreender. Rever a ordem com jogadores, incluindo saltos conceptuais, revisitas e percursos alternativos.
5. **Conflito e revelação quando apropriados.** Descrever, numa frase, a relação que queremos que seja descoberta. Uma hipótese inicial plausível pode falhar, desde que o resultado seja compreensível e não dependa de informação essencial escondida. Não impor uma única solução ou surpresa a todas as salas.
6. **Ação, lógica e recuperação honestas.** Distinguir pressão por turnos de reflexos em tempo real. Uma ação bloqueada, consequência, derrota, desfazer e reinício devem comportar-se de forma previsível. Combate pode coexistir com puzzles quando a experiência e as regras o justificam; não adicionar temporização inesperada como substituto de raciocínio.
7. **Feedback com parcimónia.** Comunicar progresso, risco, causa e estado com materiais, posição, movimento, som e símbolos acessíveis. Não depender só de uma cor ou som, acrescentar sinais redundantes automaticamente, nem revelar trajetórias ou próximas células de inimigos, respeitando `AGENTS.md`.
8. **Auditar ruído com contexto.** Escrever as frases das soluções e identificar elementos que não contribuem para elas. Remover ou simplificar o que não tem propósito comprovado; justificar o que ficar por razões de acessibilidade, atmosfera, economia, aprendizagem, alternativas ou desvio intencional. Não eliminar automaticamente uma rota alternativa, recompensa, pista essencial ou identidade do mundo apenas porque não aparece numa solução.
9. **Qualidade antes de quantidade.** Uma sala tecnicamente solucionável pode ser trivial, confusa ou repetitiva. Usar indicadores e observação para separar essas hipóteses; não otimizar apenas o número de salas ou passos.
10. **Experiência pertence ao jogador.** A clareza, justiça, satisfação, dificuldade e descoberta precisam de observação e julgamento humano. Um PASS, uma pontuação heurística ou uma renderização não as garantem.

### Técnicas disponíveis, não obrigações

Modelos artesanais; geração por regras e sementes; WFC para layouts compatíveis; solvers específicos; reexecução das ações no jogo real; auditoria de ruído; análise de estados e decisões; comparação de variantes; playtesting. Cada técnica deve ser escolhida pelo problema e pelas garantias que realmente oferece.

### Experiências ainda abertas

Inimigos como mecanismos, armadilhas que os afetam, portais de objetos, novas relações de circuitos, dicas progressivas e recompensas por ajuda são possibilidades. Antes de qualquer implementação, definir regras, acessibilidade, economia, interações e testes; não presumir que já existem nem exigir que todas entrem no jogo. Dicas são opcionais e não devem revelar a solução por defeito.

## 4. Processo proposto: da intenção à seleção

Os nomes abaixo descrevem **responsabilidades**, não serviços já existentes ou uma promessa de sete sistemas separados. Podem começar como fichas e testes humanos; só se transformam em código quando houver uma fatia aprovada e uma necessidade comprovada.

1. **Mechanics Lab / ficha de mecânica.** Registar o que uma regra permite e impede, ordem dos efeitos, feedback, custo, recuperação e interações conhecidas. O laboratório atual é útil, mas não é uma ferramenta genérica de autoria.
2. **Puzzle Forge / intenção.** Descrever objetivo, propósito, frase de descoberta, conflito ou hipótese inicial quando existirem, regras permitidas, pré-requisitos e contexto no mundo. Produzir candidatos artesanais ou combinações procedurais; WFC pode ajudar na geometria, mas não substitui a construção lógica.
3. **Puzzle Validator / garantia técnica.** Identificar versão de regras, família, seed e ações/recursos modelados; procurar uma rota num limite de tempo/estados e reexecutá-la no jogo real. Verificar reset/desfazer e efeitos relevantes. Cada transformação ou variante aceita precisa da sua própria validação ou de uma equivalência demonstrada.
4. **Puzzle Structure Analyzer / revisão estrutural.** Documentar objetivo, condições em tensão, hipótese inicial plausível, relação revelada, alternativas conhecidas e regras aprendidas. Nem toda sala necessita de pegadinha. Testar se ações já disponíveis, como Blink e demolição, criam atalhos não previstos antes de afirmar que uma interação é necessária ou uma solução é única.
5. **Cognitive & Difficulty Evaluator / indicadores.** Observar regras simultâneas, decisões, memória e perceção, com métricas limitadas e anotadas na secção seguinte. Tratar estimativas como hipóteses; não somá-las num número que finja medir memória de trabalho ou dificuldade humana.
6. **Noise Audit e Player Experience Evaluator / seleção.** Comparar a solução, papéis dos elementos e feedback; depois observar pessoas, anotar tentativas e recolher comentários sem revelar a resposta. A decisão de aceitar pertence ao designer e ao proprietário, não a um classificador automático.
7. **Integração e regressão.** Rejeitar ou substituir candidatos não verificados; preservar seed, saves, recursos, controlos, desempenho e comportamento dos pisos existentes. Alterações no gerador podem modificar mapas antigos: definir explicitamente a política de compatibilidade antes de as publicar.

### Contrato de validação proposto

Uma futura ferramenta deve distinguir, no mínimo:

| Resultado | Significado e tratamento |
| --- | --- |
| `SOLUCAO_ENCONTRADA` | Existe uma rota no conjunto de regras e ações explicitamente modelado. Ainda falta reproduzir e avaliar no jogo. |
| `REPLAY_VALIDADO` | A rota foi executada no jogo real nas condições registadas, com objetivo alcançado e sem erro inesperado. Não demonstra que todas as outras ações sejam seguras. |
| `SEM_SOLUCAO_NO_MODELO` | A busca **completa** esgotou o espaço finito modelado sem rota. Não afirmar impossibilidade no jogo se o modelo omite ações ou recursos. |
| `INCONCLUSIVO_LIMITE` | Tempo ou estados acabaram; rejeitar o candidato da seleção automática ou usar fallback seguro, sem classificá-lo como impossível. |
| `NAO_SUPORTADO_OU_DIVERGENTE` | Uma regra, transformação ou replay está fora do modelo, ou os resultados diferem. Investigar e não aceitar o candidato como verificado. |

Registar o resultado com seed, versão do gerador/modelo, estado inicial, ações permitidas, limites, rota quando houver e motivo de rejeição. Para risco de *softlock*, distinguir: posição sem solução no modelo; posição recuperável com desfazer; e posição recuperável apenas ao reiniciar o andar. Garantir que a recuperação prometida está realmente acessível e comunicada. Um teste inicial não prova que todos os estados alcançáveis sejam recuperáveis; para isso seria necessário um modelo completo e uma verificação apropriada.

## 5. Avaliação cognitiva e de dificuldade — aproximações, não diagnóstico

| Dimensão | Perguntas e possíveis registos | Limite da inferência |
| --- | --- | --- |
| Regras e novidade | Que regras são novas, quais interagem e quais o jogador teve oportunidade de experimentar? | Número de objetos não equivale ao número de conceitos; experiência anterior varia. |
| Planeamento | Comprimento da rota encontrada; decisões significativas; relações que exigem antecipação. | O BFS atual mede uma rota sob as suas ações, não a dificuldade nem necessariamente a melhor rota do jogo completo. |
| Opções e espaço de possibilidades | Ações legais e escolhas relevantes em estados selecionados; becos sem saída e alternativas. | Contar caminhos brutos inclui ciclos e simetrias. Uma solução única só pode ser afirmada com modelo completo, critério de equivalência e busca suficiente. |
| Memória | Que estado não está visível? O jogador precisa de recordar uma sequência, uma mudança ou um temporizador? | É uma análise de design, não uma medição direta da memória de trabalho. |
| Perceção e clareza | O objetivo, ligação entre mecanismo e consequência, perigos, materiais e estado atual são distinguíveis? | Capturas e testes de pixels não mostram por si só se uma pessoa entendeu. |
| Pressão e execução | Ameaças avançam por turno? Existe limite de ações ou uma janela real de reflexos? Controlos e feedback permitem executar a ideia? | Pressão de planeamento por turnos não é automaticamente pressão de tempo real. Uma animação não deve mudar a regra. |
| Ritmo e recuperação | Custo de experimentar, desfazer, reiniciar; intensidade dos encontros vizinhos e pausas. | Um tempo longo pode ser exploração deliberada, dificuldade ou confusão; investigar antes de concluir. |

Não definir limiares universais, taxa de satisfação ou uma pontuação única sem calibração humana. As barras e percentagens usadas por Taylor para ilustrar “RAM” são uma metáfora, não uma escala validada ou meta a reproduzir. Guardar separadamente o que foi medido, o que o jogador relatou e a interpretação da equipa.

Separar também **ações legais no modelo** de **possibilidades percebidas pelo jogador**: um solver pode enumerar estados que a pessoa ainda não entende, enquanto o jogador pode considerar ações plausíveis que o modelo não permite. Ambas as análises ajudam a formular hipóteses, mas não se convertem uma na outra por uma fórmula. Conhecimento prévio, clareza das pistas e apresentação alteram o espaço que cada pessoa explora.

### Distinguir situações sem inventar uma nota de qualidade

| Situação | Evidência a procurar | Estado sem essa evidência |
| --- | --- | --- |
| Solucionável | Rota encontrada no modelo declarado e reproduzida no jogo. | Não verificado; uma busca truncada é inconclusiva. |
| Potencialmente trivial | Poucas decisões significativas para o público pretendido; observar se a sala serve para introdução ou pausa. | Hipótese, não defeito automático: uma primeira sala pode ser deliberadamente simples. |
| Potencialmente confuso | Jogadores interpretam de modo diferente regras/estados e o feedback não explica a consequência; verificar interface e execução. | Hipótese até observar o comportamento; não culpar o jogador. |
| Complexo mas repetitivo | Salas com a mesma relação e decisão centrais, ainda que mudem seed ou orientação; comparar a experiência. | Sem avaliação da novidade percebida. |
| Simples e satisfatório | Pessoas relatam ou demonstram descoberta e satisfação; recolher também respostas discordantes. | Não avaliado por humanos; a simplicidade não garante satisfação. |

Uma ficha de candidato pode juntar: propósito e público; objetivo e frase de solução; regras/pré-requisitos; hipótese inicial e alternativas; seed e estado; ações/recursos cobertos; resultado do solver e replay; recuperação; auditoria de ruído; observações de pessoas e decisão. É um modelo de revisão, não um formato de dados ou funcionalidade já implementada.

## 6. Auditoria de ruído: procedimento concreto

1. Escolher uma sala, público, pré-requisitos e propósito; registar seed, versão, recursos e estado inicial.
2. Escrever o objetivo e uma ou mais frases de solução; enumerar também soluções alternativas conhecidas, não apenas o primeiro caminho encontrado.
3. Inventariar objetos, perigos, texto, efeitos, recompensas e espaços com uma função: **necessário à solução**, **alternativa**, **feedback/acessibilidade**, **aprendizagem**, **mundo/economia/ritmo** ou **hipótese de desvio intencional**. Elementos ainda sem função ficam por investigar.
4. Perguntar o que o jogador pode razoavelmente pensar que é interativo e o que precisa de recordar. Uma decoração que parece um botão e não reage pode causar confusão; uma pista redundante pode ser essencial para acessibilidade.
5. Comparar uma variante mais simples com a original, mantendo regras e objetivo. Validar ambas e observar pessoas; reduzir/remover apenas o que não justifique o custo. Não publicar mudanças de loot, economia ou interface sem aprovar o âmbito.
6. Registar decisão e evidência: **observado**, **hipótese** ou **não testado**. Ruído deliberado deve ter propósito, ser justo e poder ser revisto; não é licença para esconder regras.

**Trade-off entre autores:** Traynor aceita que uma sala muito acessível possa ser resolvida por acaso; Taylor descreve a adição deliberada de ruído para, em certos casos, evitar soluções acidentais. Não há uma resposta universal a escolher de antemão. Comparar a compreensão e o custo de atenção de ambas as variantes; uma segunda oportunidade clara pode ser preferível a acrescentar distração, mas isso também precisa de teste.

**Ponto de investigação concreto:** a câmara de circuito acrescenta recolhas e mostra uma instrução explícita de ligar águas com metal. Podem apoiar aprendizagem e recompensa ou competir com o momento de descoberta. Preparar uma comparação controlada antes de concluir ou apagar conteúdo. Capturas em `docs/evidencias-sensoriais-2026-11-03/` são históricas; não devem ser apresentadas como imagens do estado atual nem como validação de jogadores.

## 7. Matriz inicial de interações

Esta matriz documenta exemplos do estado atual, não uma cobertura exaustiva. As células experimentais não autorizam acrescentar regras.

| Elemento A | Elemento B | Estado / pergunta |
| --- | --- | --- |
| Madeira | Corrente | **Implementado:** madeira pode flutuar uma casa por ação; congelar suspende a corrente. `environment_system.gd::advance_currents()`, `game.gd::_take_turn()`. |
| Metal | Fonte + água | **Implementado:** o metal pode ligar água e ativar uma placa alimentada; água energizada pode ferir. `refresh_electricity()`, `update_mechanisms()`. |
| Gelo frágil | Movimento | **Implementado:** uma casa marcada acumula tensão e deixa de deslizar após a terceira ação sobre ela. Ações e efeitos devem ser considerados na ordem do turno. |
| Inimigo | Água energizada | **Implementado:** inimigos comuns são derrotados e elites sofrem dano; isso não significa que o solver das câmaras modele inimigos. |
| Inimigo | Placa / portão | **Limitado:** não ativa placa; pode manter aberto um portão já aberto enquanto o ocupa. Usar inimigos para ativar mecanismos exige nova regra e testes. |
| Armadilha | Inimigo | **Não implementado:** as armadilhas atuais verificam a posição do jogador. |
| Portal | Caixa | **Não implementado:** o portal atual é saída de andar. Blink não transporta caixas. |
| Salto, Blink, demolição | Câmara de caixas | **Disponíveis no jogo:** o solver restrito não os considera. Verificar atalhos e recursos antes de concluir que uma solução é única ou que certo empurrão é obrigatório. |

### Exemplo para uma primeira revisão humana: ponte de energia

Na configuração não refletida de `SpecialLevels.make("circuit", 3, 17)`, a fonte está em `(5, 2)`, a placa alimentada em `(5, 4)`, a caixa de metal em `(3, 3)` e o portal em `(8, 3)`. A relação pretendida pode ser expressa assim: **«o metal colocado entre as duas águas completa a ligação e alimenta a placa; depois é preciso chegar ao portal sem pisar água energizada»**. O solver e o teste existente cobrem este tipo de câmara e reexecutam rotas geradas para seeds selecionadas; isso não é uma observação nova de jogadores nesta tarefa.

- **Hipótese de ensino:** o estado da placa e dos arcos pode tornar visível a relação entre metal e energia.
- **Hipótese de descoberta:** instruir explicitamente “liga as águas com metal” pode ajudar um principiante ou antecipar a relação. Comparar texto, contexto e feedback; não retirar uma pista de segurança apenas para criar surpresa.
- **Auditoria:** distinguir caixa, fonte, placa e portal das recolhas e mensagens adicionais, avaliando também o papel de cada recompensa e das opções de acessibilidade.
- **Limites:** o solver não cobre Blink/demolição nem demonstra exclusividade da solução. Um caminho válido e pixels legíveis não provam Eureka, satisfação ou compreensão.

### Segunda revisão: primeira oficina de caixas

A configuração `SpecialLevels.make("sokoban", 1, 7)` tem a bola em `(2, 3)`, uma caixa de madeira em `(3, 3)`, placa de madeira em `(5, 3)` e portal em `(8, 3)`. A relação declarada é: **«empurrar a caixa de madeira até à placa, mantê-la lá e contornar a caixa para alcançar o portal aberto»**. A suite existente verifica uma rota e a execução real para esta família, seed e andar; o CI referido acima passou antes desta revisão.

- **Função potencial:** apresentar empurrão e placa mantida. Isto é coerente com o modelo inicial de uma caixa, mas não prova que todo jogador a encontrará antes das outras famílias: a agenda não acompanha aprendizagem individual.
- **Contributos para a solução:** bola, caixa, placa, portal e espaço para contornar a caixa. Os símbolos, estados e feedback comunicam a relação, mesmo quando não pertencem à sequência de movimentos.
- **Elementos a justificar:** moedas, escudos, poder e desafio secundário são colocados pela campanha para outros objetivos; podem distrair numa introdução ou apoiar economia e exploração. A instrução diz explicitamente para empurrar madeira à placa; pode ser uma ajuda apropriada de ensino. Não se remove nenhum desses elementos com base nesta análise estática.
- **Classificação honesta:** há evidência técnica histórica de uma rota; a hipótese de que é simples e legível precisa de playtest. Não há base para declarar Eureka, diversão, confusão ou ausência de outras soluções.

### Sequência candidata para estudar, não instalada na campanha

Esta sequência usa situações que já existem como referências; não afirma que a campanha as apresenta nesta ordem nem altera o agendador:

1. **Mostrar:** a oficina de uma caixa introduz empurrão e placa mantida. Observar se a pessoa entende que a caixa permanece na placa e se consegue contorná-la. A solução pode ser imediata, o que não é automaticamente mau.
2. **Reforçar e variar:** na primeira câmara do laboratório, madeira empurrada para a corrente pode chegar à placa na mesma ação. Verificar se a pessoa percebe o movimento causado pela corrente, em vez de atribuir o resultado apenas ao empurrão. `tests/environment_test.gd` contém um caso de turno real para esta situação; o solver de câmaras especiais não modela correntes.
3. **Contrastar:** na segunda câmara do laboratório, a caixa metálica não flutua como madeira e pode ligar duas águas. A ponte de energia oferece outra configuração dessa relação. Dar nova oportunidade de experimentar antes de combinar as duas propriedades.
4. **Combinar ou aliviar:** a oficina de portão usa placas de madeira e de metal; uma variação mais exigente poderia ser opcional e uma sala mais aberta poderia oferecer pausa. Isto é uma hipótese de ordenação, não prova de que as salas tenham a dificuldade ou a função certas.

Para cada transição, registar o que a pessoa acredita que acontece, onde tentou algo que quase funcionou e se uma solução acidental deixou uma regra por compreender. Se houver um salto, experimentar uma sala-ponte, uma alteração ou uma opção sem bloqueio obrigatório. Qualquer nova ordenação ou acesso alternativo exige projeto e aprovação, teste de progresso/saves e uma política de compatibilidade de seed; não basta mudar a lista de famílias.

## 8. Protocolo de playtest e critérios de aprovação

Começar com um pequeno piloto de pessoas que não conhecem a sala e, se possível, comparar com pessoas que já conhecem as regras. Um ou dois participantes podem orientar uma primeira iteração; são insuficientes para generalizar e devem ser seguidos por mais perfis, incluindo necessidades de acessibilidade relevantes. Pedir consentimento, recolher apenas o necessário, não acrescentar telemetria de produção automaticamente e permitir interromper a sessão. Gravação e pensamento em voz alta são úteis, mas opcionais: acordar finalidade, acesso e conservação antes de gravar, sem condicionar a participação à gravação ou à fala.

1. **Antes:** anotar experiência prévia, plataforma, variante/seed, recursos e adaptações de teste solicitadas, sem explicar a solução nem pedir dados pessoais desnecessários.
2. **Durante:** observar primeira ação, interpretações do objetivo e dos mecanismos, tentativas, consequências, momentos de bloqueio, uso de ajuda/desfazer/reinício e conclusão. Se a pessoa concordar, pode narrar o raciocínio ou a equipa pode tomar notas; ambos os métodos podem influenciar a sessão. Tempos e contagens são contexto, não notas de inteligência.
3. **Depois:** pedir ao jogador que descreva o objetivo, a regra que percebeu, o que o fez mudar de hipótese, o que pareceu injusto ou confuso e o que sentiu. Uma pergunta de transferência ou segunda situação pode distinguir descoberta de solução acidental. Não conduzir a resposta nem tratar silêncio como prova de entendimento.
4. **Comparar:** analisar variantes e perfis, separar problemas de controlo, comunicação, planeamento e satisfação; voltar a testar após mudanças. Manter notas de falhas e exemplos discordantes, não apenas sucessos.

**Critérios técnicos mínimos para uma futura alteração:** testes das regras e ordem por turno; determinismo para seed e versão declaradas; tratamento de busca truncada; rota de cada candidato aceite reexecutada no jogo; testes de perigos, materiais, bloqueios e recuperação prometida; regressões de campanha, save e controlos. Se uma regra ou ação está fora do modelo, a garantia deve dizê-lo. Uma alteração apenas documental não executa estes testes por si só.

**Critérios de experiência:** o objetivo e as consequências essenciais devem ser compreensíveis, a execução deve corresponder à intenção e a recuperação não deve ser enganosa. Registar dificuldades observadas e corrigir problemas reais; o proprietário/designer decide a aceitação depois de ver evidência suficiente. A existência de uma frase de descoberta é uma hipótese de design, não prova de satisfação. Não aprovar como “divertido”, “claro para todos” ou “sem softlocks” apenas por um PASS.

## 9. Próximas decisões

1. Preparar cenários de teste com jogadores a partir das revisões de circuito e oficina e, se adequado, da sequência candidata; completar as fichas com observação humana, sem alterar gameplay nesta fase.
2. Comparar compreensão, execução e alternativas, incluindo resolução acidental, custo das pistas e papel das recompensas; registar se uma sala simples ensina, reforça ou oferece pausa.
3. Se o proprietário aprovar uma fatia de implementação, escolher **uma** interação existente, adaptar ou construir um modelo verificável e comparar variantes. Planear regressões e compatibilidade de saves/seed antes de alterar gerador, progressão ou HUD.
4. Decidir mais tarde proporção artesanal/procedural, condições de ensino e ritmo, necessidade de ferramentas automatizadas e política de ajuda. Não implementar todos os módulos só porque têm nomes.
