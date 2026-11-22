# Arquitetura editável — Godot e Oficina CTM

**Estado:** direção híbrida atualizada em 12 de novembro de 2026. Godot continua a ser o runtime e espaço de edição profunda; mapas de campanha também são editáveis num programa independente. Sem commit ou push.

## Meta

O projeto não deve depender totalmente do editor Godot para autoria quotidiana. A **Oficina CTM independente** é o fluxo principal para criar/editar mapas e missões sem programar; o Godot continua como runtime, autoridade das regras, editor de cenas/Resources e ferramenta para WFC e conteúdo que ainda não migrou. As duas ferramentas devem usar o mesmo formato de nível e a mesma validação, sem duplicar a lógica de gameplay. O público principal é quem não programa: criar mapas, posicionar/ligar peças, testar e ver a alteração no jogo deve ser um fluxo visual e direto.

O destino continua a ser que todo o jogo seja compreensível e editável visualmente, sem exigir que toda a autoria passe pelo Godot. A reformulação é feita por migrações verificáveis, preservando o jogo ativo e substituindo famílias antigas até não dependerem de blocos monolíticos em `game.gd`/`hud.gd` para configurar conteúdo.

## Princípios que vieram das referências

- **Dados e cenas no Godot:** Resource guarda definições/configuração reutilizáveis; PackedScene dá peças visuais e funcionais que podem ser instanciadas; o Inspector edita as propriedades exportadas.
- **Autoria independente:** o programa externo grava um formato de mapa documentado e legível. O runtime converte esse formato para os mesmos dados de campanha e regras usados pelas cenas Godot.
- **Dados dirigem conteúdo, código implementa regras:** trocar vida, cor, dimensões, cena ou perfil configurável não exige editar uma tabela no script. Uma nova família de comportamento ainda pode exigir código e testes.
- **Referências explícitas e sinais locais:** relações importantes ficam visíveis na cena/Inspector ou em IDs estáveis validados. Sinais e um coordenador específico servem para avisos e fluxo entre sistemas; não há dependências escondidas num contentor global nem num mediador universal.
- **Fábricas/catalogadores com propósito:** catálogo resolve definição → cena/dados; assembler instancia e valida. Não se cria uma camada de fábricas para cada objeto quando uma cena ou Resource direto basta.
- **ECS é referência de desempenho, não mandato:** a simulação atual é uma grelha tática de baixa contagem, com regras por turnos. Não migrar para ECS por causa de uma animação; medir primeiro um gargalo real.

Estas são aplicações ao projeto das transcrições fornecidas, não regras universais atribuídas aos autores. A documentação oficial do Godot confirma cenas como unidades reutilizáveis, recursos como contentores de dados e propriedades exportadas como edição serializada no Inspector.

## Autoridade e composição

1. **Regras lógicas têm uma autoridade.** `EnvironmentSystem`/estado de grelha e o fluxo de turno existente continuam a decidir posição, colisão, ativação, combate e conclusão até cada domínio ser extraído com equivalência demonstrada. Nós de desenho não simulam uma segunda regra.
2. **A cena principal compõe sistemas e pontos de montagem nomeados.** O nó raiz liga gameplay, mundo, atores, apresentação, áudio, HUD e persistência por referências exportadas; cada sistema recebe dependências que usa. Não depender de caminhos globais ou de ordem implícita em autoloads.
3. **Definições e instâncias são diferentes.** Um Resource descreve a caixa ou o inimigo; cada instância editável tem posição, estado inicial e ligações próprias. Três placas podem reutilizar a mesma definição e ter três IDs/portas diferentes.
4. **Manual e procedural compartilham a biblioteca.** Blueprint de nível e WFC resolvem IDs para a mesma definição, cena, regras, orientações, conectores e validação. WFC decide composição compatível; assembler cria instâncias; validador consulta as regras reais.
5. **Editor seguro primeiro.** `@tool` serve para pré-visualização/validação sem efeitos colaterais; evitar mutações destrutivas de cenas em tempo de editor. Usar Undo explícito se um futuro plugin precisar criar/alterar nós.
6. **Migração compatível.** Manter adaptadores para níveis, seeds, progressão e saves existentes. Cada família só troca a origem quando os testes comprovam mesmos resultados para entradas fixas e os saves anteriores continuam a carregar.

## Estado observado e cobertura integral

| Família | Estado confirmado nesta revisão | Alvo editável (Godot e Oficina) | Situação |
|---|---|---|---|
| Cena principal e sistemas | `main.tscn` contém montagem nomeada; ainda há fluxo e criação em `game.gd`. | Root/orquestrador pequeno, sistemas nomeados, referências explícitas e cenas de jogo inspecionáveis. | Parcial |
| Grelha, terreno e biomas | regras de geração/turnos continuam no código; dimensões, TileSet WFC e perfil de salas de cada bioma vêm de Resources. | Definições de bioma, peças e variantes; TileSets/Scenes; regras de borda/conectores; preview e validação WFC. | Parcial |
| Personagem, Lia, inimigos e bosses | desenho continua em `game.gd`; seis inimigos comuns e seis bosses já têm Resources para perfis/dados selecionados. | Cenas instanciáveis com apresentação, perfil, parâmetros e estados expostos; animação separada da regra da grelha. Lia mantém forma de esfera. | Parcial |
| Caixas, placas, circuitos e portões | Scenes/Resources, instâncias com IDs e ligações; `EnvironmentSystem` ainda é autoridade. | Biblioteca completa de peças, tipos de conexão, estados locais, validação e montagem procedural pela mesma biblioteca. | Primeira fatia |
| Pickups, armadilhas e objetos | aparecem sobretudo como arrays/dicionários e desenho centralizados; quatro poderes têm Resources de cor/duração. | Definições, cenas, comportamento configurável e ligações ao sistema de recompensa/risco. | Parcial |
| Combate, habilidades e economia | sistemas de jogo existem, mas conteúdo e equilíbrio ainda dependem de código. | Recursos de habilidade, inimigo, recompensa e desafio; estados e eventos testáveis; valores de campanha editáveis. | Por migrar |
| HUD, menus e páginas de campanha | `hud.gd`/`game.gd` ainda concentram apresentação e seleção. | Cenas de UI por função, dados de páginas/cards, navegação e sinais; layout editável e acessível. | Por migrar |
| Áudio, VFX e feedback | existem módulos dedicados, mas eventos/conteúdo ainda não são inteiramente montáveis no editor. | Perfis de feedback e cenas/componentes vinculados a eventos lógicos, com opções de acessibilidade. | Parcial |
| Saves, opções e progresso | `CampaignStorage` já separa persistência; formato e consumidores precisam de inventário durante migração. | Recursos/configuração por versão, migração de saves, testes de compatibilidade e editor de campanha. | Parcial |
| Ferramentas de autoria | A Oficina Godot gera WFC e edita cenas/Resources. A Oficina independente abre/importa blueprints, edita grelha, atores, pickups e mecanismos, valida e grava JSON por fase; `game.gd` consulta o mapa externo antes da cena Godot. | Unificar o catálogo/validador; acrescentar WFC, água, armadilhas, arte e preview à Oficina independente; manter edição profunda de cenas/Resources no Godot e o mesmo resultado no jogo. | Mapas, atores, pickups e mecanismos editáveis fora do Godot; restantes camadas por migrar |

“Parcial” significa que há uma base real, não que a arquitetura dessa família esteja concluída. O objetivo é fechar todas as linhas sem introduzir sistemas vazios ou componentes só cosméticos.

Uma família de autoria não passa porque tem `@export` ou cenas instanciáveis: uma pessoa sem código deve completar o fluxo visual correspondente e observar o resultado no jogo. Para mapas, esse fluxo pode ser a Oficina independente; para cenas/Resources, continua no Godot. Ainda faltam WFC e camadas ambientais na Oficina independente, além das famílias restantes do jogo.

## Migrações e critérios de conclusão

| Ordem | Família a fechar | Critérios antes de avançar |
|---|---|---|
| A | Mecanismos e blueprints | múltiplas instâncias reutilizam definições; ligações específicas por instância aparecem no editor; IDs/canais inválidos falham cedo; circuito continua com a regra atual. |
| B | Terreno, biomas e WFC | construção manual e WFC usam o mesmo catálogo; conexões/orientações/bordas e camadas funcionais passam por validação; seed fixa mantém resultado; buscar truncada é inconclusiva, não “solúvel”. |
| C | Atores e comportamento | jogador, Lia, inimigos e bosses têm cenas/definições editáveis; perfis de movimento configuráveis; desenho não altera colisão; padrões existentes e encontros de campanha continuam reproduzíveis. |
| D | Pickups, riscos, combate e economia | cada recurso tem propósito e resultado explícitos; cenas reutilizáveis instanciam corretamente; recompensas/consumo persistem; pickups e inimigos continuam ligados à autoridade da grelha. |
| E | HUD, menus e campanha | páginas, seleção, resultados, ícones e estados editados por cenas/dados; navegação por teclado/comando; fluxo de níveis e saves existentes preservados. |
| F | Áudio, VFX, opções e acessibilidade | eventos roteados por interfaces/sinais locais; conteúdos/perfis editáveis; opções reduzem movimento/flash/volume sem retirar informação essencial. |
| G | Ferramentas e retirada dos adaptadores | validação do projeto em editor; cenas legadas migradas ou explicitamente documentadas; não restam catálogos centrais de conteúdo configurável em `game.gd`/`hud.gd`; profiling real confirma custo aceitável. |

Uma família passa quando tem uma origem de edição clara, é instanciável, tem validação útil, usa a mesma regra no modo manual/procedural quando aplicável, carrega os dados antigos e tem testes de comportamento. Teste automatizado prova contratos, não gosto visual nem diversão. Inspeção no editor e playtest continuam separados.

## Fatias que já existem

### Mecanismos e nível de laboratório

`levels/editable_component_demo.tscn` tem três placas instanciadas com saídas distintas para três portões e um circuito gerador → relé → recetor → portão. Scenes usam propriedades exportadas; `component_catalog.tres` resolve cenas/canais; `LevelBlueprint` compila no formato aceito pelo `EnvironmentSystem`. IDs e canais errados são rejeitados. O laboratório é um exemplo jogável e testável, não o limite da edição pretendida.

### Definições ativas de biomas, bosses e poderes

`content/game_content_catalog.tres` agrupa 5 `BiomeDefinition`, 6 `BossDefinition`, 6 `EnemyDefinition` e 4 `PowerupDefinition`, cada qual num Resource reutilizável sob `content/definitions/`. O fluxo ativo lê daí nomes/tamanhos, crescimento de mapa, vida/descrição/textura/cor/escala/perfil de bosses, perfil de movimento/escala/duração de animação/halo dos inimigos comuns e seleção/cor/duração dos poderes. As regras atuais, valores padrão, seeds e arte permanecem; `_boss_intent` e a intenção dos inimigos comuns consultam os perfis dos Resources sem acrescentar campos ao estado persistido. Este passo não converte atores em cenas nem torna parâmetros de habilidade/economia todos editáveis.

O guia [Editar conteúdo no Godot](COMO_EDITAR_CONTEUDO_NO_GODOT.md) mostra o fluxo nativo de cenas/Resources e liga para a [Oficina independente](OFICINA_INDEPENDENTE.md), separando o que já funciona do que ainda está em migração.

**Progresso seguinte — WFC e biomas:** cada `BiomeDefinition` expõe `wfc_tile_set` e `room_profile`; o fluxo da campanha passa os dois Resources ao gerador. Os cinco biomas continuam no TileSet de 16 máscaras/pesos atual, e os perfis de sala mantêm exatamente os valores anteriores. A validação do catálogo rejeita recursos inválidos; testes com seed fixa e regressão passaram. Isto migra a configuração, mas não conclui a família: o assembler ainda não resolve definições funcionais, cenas, conectores ou propriedades ambientais por célula. A próxima migração deve fazer peças manuais e procedurais partilharem definições e validação sem introduzir uma segunda autoridade de gameplay.

## Como lidar com ligações e custo

- Reutilizar a mesma definição não significa partilhar estado de instância. ID, célula e destinos são dados locais.
- Uma ligação é explícita: `placa_A → portão_A`; `placa_B → portão_B`. Validar referências/canais ao carregar o blueprint e manter a representação visível. Não usar uma placa global “mãe” nem uma tabela oculta que substitua as conexões da sala.
- Conteúdo em Resources não duplica autoridade: definições descrevem; `EnvironmentSystem` aplica regras. Só extrair regra para outro sistema quando houver fronteira clara e equivalência testada.
- Instâncias são o formato de autoria. Não supor que um nó por célula precise executar `_process`; agrupar a execução e instanciar apresentações apenas quando fizer sentido. Medir geração, memória e runtime num mapa representativo antes de otimizar.
- Eventos atravessam fronteiras por sinal ou coordenador da cena quando desacoplam participantes reais. Evitar um event bus único que torne fluxo e depuração opacos.

## Referências técnicas consultadas

- Godot 4.7: [conceitos centrais e cenas](https://docs.godotengine.org/en/4.7/getting_started/introduction/key_concepts_overview.html), [propriedades exportadas e grupos do Inspector](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_exports.html), [PackedScene](https://docs.godotengine.org/en/4.7/classes/class_packedscene.html), [Resources](https://docs.godotengine.org/en/4.6/classes/class_resource.html) e [código executado no editor](https://docs.godotengine.org/en/4.7/tutorials/plugins/running_code_in_the_editor.html).
- Minecraft Bedrock: [permutations de estado de blocos](https://learn.microsoft.com/en-us/minecraft/creator/reference/content/blockreference/examples/blockstatesandpermutations?view=minecraft-bedrock-stable), usadas apenas como inspiração para definição compartilhada + estado local de instância.
- Transcrições enviadas pelo proprietário: conceitos de Resources/data-driven, composição, referências explícitas/DI, factories, sinais/mediator e localidade ECS. O que não reduz acoplamento ou resolve um caso observado não entra só por aparecer num vídeo.
