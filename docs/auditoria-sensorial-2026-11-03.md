# Come To Me / Neon Ruins — auditoria sensorial e plano

**Data:** 3 de novembro de 2026<br>
**Referência auditada:** `b1c33998b9778aa6246a7bdc15f0ea94ee39d978`, branch `arena/0ff1c63e-ctm-come-to-me`<br>
**Estado:** diagnóstico e proposta; não é uma implementação nem uma aprovação estética. Nenhuma lógica do jogo foi alterada nesta auditoria.

## 1. Conclusão executiva

O proprietário relatou que várias mecânicas são intuitivas e funcionam, mas que a sua aplicação carece de **game taste** e **game feel**: em particular, a água depende demasiado de setas, as placas não parecem objetos físicos e falta uma expressão convincente da eletricidade. Essa crítica é um requisito de direção, não é refutada por testes automáticos nem aqui substituída por um juízo do auditor.

O exame confirma que há bases de regras, desenho, áudio e vibração que vale a pena **aproveitar**, mas também pontos concretos que quebram a relação causa–efeito:

1. **Jogador, caixa e portal não são apresentados em sincronia.** Numa ação controlada, a caixa avança imediatamente duas casas, a placa e o portal mudam logo, mas o jogador ainda interpola o movimento durante cerca de 115 ms. [Sequência reconstruída](evidencias-sensoriais-2026-11-03/animacao-empurrao-controlada.gif).
2. **O anel de turno pode aparecer na casa errada no gelo.** Na sonda, a posição final era `(4, 4)` e o centro do anel estava na casa anterior `(3, 4)`. [Captura controlada](evidencias-sensoriais-2026-11-03/05b-gelo-anel.png).
3. **A corrente já tem ondas, mas o seu sentido é comunicado por uma seta estática; as ondas não dependem da direção lógica.** A água eletrificada usa contorno e raio desenhados, sem faíscas próprias desse estado. As placas e o portão mudam sem transição física.
4. **Os eventos sensoriais não cobrem todas as consequências.** A primeira de duas placas ativa sem evento específico; empurrão, corrente, gelo e água eletrificada também não têm eventos próprios na referência. Uma armadilha absorvida pelo escudo emite dois eventos diferentes no mesmo turno; o código permite sobreposição, mas o resultado não foi ouvido.
5. **A segurança de apresentação merece prioridade.** A captura combina alternância de visibilidade, overlay pulsante, flash, tremor e uma nuvem densa de partículas, sem opção geral de redução. Não foi feito ensaio clínico nem medição fotométrica.
6. **Uma mudança visual pode interferir com a aleatoriedade de um caminho de jogo.** A mesma RNG alimenta efeitos e inicialização de inimigos. Numa sonda que resemeia antes de cada comparação, gerar uma partícula mudou fase ou direção do inimigo criado por `_make_enemy` em 19 de 20 seeds. Isso demonstra o acoplamento no cenário de criação usado pela ferramenta de desenvolvimento, **não** uma alteração já demonstrada na campanha normal; `generate_floor()` volta a definir a seed.

**Recomendação:** antes de remodelar o jogo inteiro, aprovar e experimentar uma única sala representativa. Primeiro resolver a coerência temporal e a redução de estímulos; depois procurar materiais, movimento e sons com identidade. Preservar as regras, o modo de laboratório, os testes e os controlos existentes. O plano completo está na secção 8.

## 2. Escopo, fontes e limites

A fonte principal foi o projeto Godot da referência acima: regras e turnos (`game.gd`, `environment_system.gd`, `environment_chambers.gd`), terreno (`terrain_renderer.gd`, `terrain_chunk.gd`, `terrain_effects.gd`), HUD, shaders, barramento tático, áudio, comando e háptica, recursos e testes. Os ficheiros HTML de protótipo não são a cena principal Godot e não foram tratados como prova do jogo atual. `Neon Ruins.html` e `Neon Ruins (1).html` são byte a byte iguais nesta referência; não se propõe apagá-los sem uma decisão separada.

A comparação com `origin/visual-overhaul-v2` foi feita na referência `cb67e75`; as suas capacidades não foram atribuídas automaticamente à branch auditada. Documentos históricos têm a sua própria data e commit: por exemplo, `docs/design-coracoes-e-habilidades.md` descreve a referência anterior `92f6126` e não deve ser lido como fotografia atual das superfícies. O PR #10 já estava aberto e tinha conflitos com a branch visual no momento da inspeção; esta auditoria não os resolve.

**Como ler as conclusões:**

- **Código:** o comportamento consta da fonte indicada. Existência de código ou de um evento registado não demonstra que seja usado em todas as situações.
- **Sonda/teste:** resultado numa amostra e condições descritas, não prova exaustiva.
- **Observação visual:** capturas produzidas por automação num renderizador de software; não são uma sessão humana.
- **Hipótese/proposta:** uma direção a experimentar, não um efeito já implementado nem uma decisão estética imposta.
- **Não avaliado:** som ouvido, satisfação, conforto, comando físico e desempenho na máquina do proprietário. Um PASS funcional não aprova *game feel*.

As imagens foram geradas com Godot oficial `4.7.2.stable.official.ed1daf0bf`, X11 em Xvfb e Mesa llvmpipe, com áudio `Dummy`, em cópias isoladas do projeto. A maioria está em 1366×768; há também uma captura em 800×540. As câmaras e os andares foram posicionados por script; não constituem uma jogatina contínua ou prova de acessibilidade. O GIF usa a imagem anterior e sete quadros simulados de 0 a 150 ms, espaçados por 25 ms e apresentados a 60 ms por quadro, com pausas; é **reconstrução desacelerada**, não gravação em tempo real nem medição de FPS.

## 3. Inventário — o que existe e o que falta validar

**Estados:** **I** = implementado no código; **P** = parcial ou disperso; **N** = não encontrado na referência. As indicações funcionais referem-se aos cenários testados, não a todas as combinações. Toda a qualidade percebida permanece **por validar com pessoas**.

### 3.1 Imagem, ação e interação

| Elemento | Estado e evidência | Dependências, lacuna e risco |
|---|---|---|
| Direção visual geral | **I.** Biomas, paletas, grelha, halos, fundo procedural, painéis, partículas e shaders compõem uma identidade neon. `game.gd:628`, `2736`, `3188–3528`; `shaders/`. | Capturas revelam uma linguagem de símbolos e contornos sobre grelha; a comparação de gosto com a ilustração do menu é subjetiva. Não é necessário substituir todos os assets para testar uma direção melhor. |
| Terreno e profundidade | **I/P.** Terreno estático em chunks; água e outros elementos dinâmicos em camadas com redraw; sombras/halos são desenhados em 2D. `terrain_renderer.gd`, `terrain_chunk.gd`, `terrain_effects.gd`, `game.gd:3188–3528`. | Não se identificou iluminação física global: os brilhos e sombras atuais não demonstram luz dinâmica real. Os chunks existentes são reutilizados e acumulam-se durante a exploração até à reconstrução do terreno; não há aqui prova de fuga permanente. |
| Jogador | **I.** Corpo esférico gerado por código, squash/efeitos, interpolação do centro e anel após ação. `game.gd:1250`, `2806–2835`, `2858–2870`, `4501–4520`. | Há feedback visual real; o anel é calculado antes das deslocações ambientais e pode ficar atrás. Flash e efeito de captura necessitam de controlo de intensidade. |
| Movimento e colisão | **I, testes funcionais aprovados nos cenários cobertos.** Movimento lógico por casas/turnos; movimento visual independente. Parede bloqueada tem aviso e som, sem tremor no teste padrão. `game.gd:1715–1751`; `tests/self_test.gd:194–198`. | Não atrasar a resolução nem bloquear input apenas para fazer animação. Validar entradas rápidas e estados visuais interrompidos numa implementação futura. |
| Caixa de madeira/metal | **I/P.** A caixa tem material e desenho distintos e pode ser empurrada; madeira flutua numa corrente e metal pode conduzir. `environment_system.gd:90–126`, `game.gd:3738–3767`. | A posição visual é a lógica, sem interpolação, e não existe evento próprio de empurrão. Distinguir passo, contacto com caixa, eventual corrente e paragem sem alterar as regras de ocupação. |
| Água decorativa | **I/P.** Água/gelo de bioma usam `TILE_WATER` e têm aparência, mas as regras especiais dependem de casas explicitamente marcadas no sistema ambiental. `game.gd:3587–3706`; `environment_system.gd`. | Água semelhante pode ser apenas decorativa. Não insinuar fisicamente uma regra que não existe; diferenciar visual e contextualmente as casas interativas, sem alterar o mapa silenciosamente. |
| Corrente | **I/P.** Direção lógica por célula, flutuação e deslocação; ondas/burbulhas desenhadas, mais uma seta estática. `environment_system.gd:90–126`; `game.gd:3607–3637`, `3691–3697`. | Sonda e teste cobrem deslocação, não qualidade. Ondas não são orientadas pela direção lógica e não há evento próprio na branch atual. A direção precisa continuar legível também sem animação. |
| Gelo | **I/P.** A casa marcada pode acrescentar uma casa ao deslocamento; inimigos param nas ações pares. `game.gd:1941–1983`; `tests/environment_test.gd`. Há desenho de fissuras, não quebra funcional nesta referência. | Nenhum evento próprio; o anel de turno fica na posição intermédia na sonda. A promessa de anunciar a intenção parada do inimigo requer verificação visual adicional. |
| Água eletrificada | **I/P.** Energia propaga por água e caixas de metal conectadas; inimigos e jogador podem sofrer consequências. `environment_system.gd:157–216`; `game.gd:2049–2050`, `2179–2206`, `3698–3706`. | Raio e contorno são estáticos; não há partículas/faíscas dedicadas à água energizada. Existe um burst genérico amarelo em algumas consequências, o que não equivale a um sistema próprio de eletricidade. Não confundir decoração com água funcional. |
| Placas e portão | **I/P.** Placas de madeira/metal são retângulos com `L`/`M`; estado e portão mudam de forma imediata. `environment_system.gd:128–154`; `game.gd:3709–3735`. | Uma placa ativa sem evento próprio quando ainda falta outra. Em vez de trocar simplesmente letras por cor, combinar relevo e movimento com identificação acessível e testar a compreensão dos materiais. |
| Armadilha rítmica | **I.** Ciclo de três turnos; desenho de espinhos, três LEDs e marca para a próxima fase. `game.gd:2133–2156`, `4106–4124`; `tests/environment_test.gd`. | Já existe telegráfo: melhorá-lo não deve escondê-lo. Evento de armadilha e impacto de escudo podem coexistir; mistura audível não foi avaliada. |
| Inimigos e chefes | **I/P.** Silhuetas, orientação, estados de alerta e sinais de mira em alguns tipos; comportamento lógico usa `next`/`path`. `game.gd:1473`, `2725–2734`, `4177–4494`. | Não foi encontrada leitura explícita de `enemy.next`/`enemy.path` nas funções de desenho. Isso não significa ausência total de sinais, mas a intenção lógica exata — em especial a paragem no gelo descrita no README — não está demonstrada visualmente. Teste atual valida regra, não interpretação do jogador. |
| Portal | **I/P.** Visual fechado/aberto, sinais de abertura e entrada e mudança de piso. `game.gd:2470–2517`, `3931–3958`. | A abertura pode surgir no mesmo instante lógico em que a caixa salta visualmente; abertura e entrada partilham o efeito sonoro `portal`. Separar sinais só se melhorar a compreensão sem atrasar a regra. |
| Recompensas, escudo e poderes | **I.** Moedas, escudos, demolição, poderes e ruído visual de recolha têm desenho e eventos. `game.gd:2040–2092`, `3770–3930`; `tactical_feedback.gd`. | Já há tratamento sensorial; qualidade, equilíbrio de mistura e legibilidade sob carga não foram julgados por áudio/hardware. Não confundir o escudo atual com o futuro sistema de corações. |
| Corações e progressão | **N no estado de jogo.** Há um desenho auxiliar `_draw_heart` não chamado no HUD (`hud.gd:463`) e um documento de proposta. | Um ícone/função não é uma mecânica implementada. Esta auditoria não implementa corações nem altera progressão. |
| Partículas e tremor | **I/P.** Partículas desenhadas e atualizadas por arrays, bursts com cores, tremor de câmara e efeitos de captura. `game.gd:2337–2358`, `2778–2798`, `2918–2922`, `2980–3042`. | Não se encontrou controlo geral de densidade/tremor. Efeito usa a RNG partilhada; ajustar quantidades sem isolar aleatoriedade pode mudar estado gerado noutro caminho. A performance de explosões numa GPU real é desconhecida. |
| Captura e ecrã | **I/P.** Jogador pisca, cresce e rebenta; overlay procedural, flash, ruído e tremor. `game.gd:2337–2358`, `2426–2450`, `2464–2468`, `4501–4520`; `shaders/capture_overlay.gdshader`. | O shader não amostra a textura da cena: deslocações de UV e separação de componentes alteram o véu procedural, não demonstram refração ou aberração reais da imagem por trás. Não se fez avaliação de conforto. |
| HUD, dicas e minimapa | **I/P.** Estado, objetivo, botões, guia, minimapa e textos de laboratório/campanha. `hud.gd:117–165`, `337–460`, `726–740`. | A dica da corrente aparece em mais de um sítio na captura; a linguagem visual pode competir com texto e seta. Em 800×540 o texto parece pequeno, mas falta ensaio de leitura e dispositivo real. Não retirar legendas necessárias sem alternativa. |
| Câmaras experimentais | **I/P.** Existem quatro câmaras separadas; ao carregar uma, os inimigos são limpos. `environment_chambers.gd`, `game.gd:1572–1576`. | A câmara 3 contém gelo/armadilha e a dica menciona inimigos, mas nela não há inimigo; os testes injetam inimigos para testar a regra. Ainda não há sala única com todos os elementos pedidos. |
| Narrativa e Lia | **P/N.** A branch atual contém referências textuais à busca e ao andamento da história; a branch visual tem outros recursos e implementação da personagem. | Não atribuir à branch atual cenas/arte da outra branch. A versão visual inspecionada tem falhas de parsing e não foi validada como produto. |

### 3.2 Áudio, vibração, controlos e conforto

| Elemento | Estado e evidência | Dependências, lacuna e risco |
|---|---|---|
| Barramento tático | **I.** `tactical_feedback.gd` encaminha eventos para áudio, háptica e apresentação, sem esperar animações nem avançar turnos. `tests/tactical_feedback_test.gd` passou em simulação. | É uma base de coordenação, não solução automática para eventos em falta, sincronismo, mistura ou gosto. `TURN_COMMITTED` é emitido antes das consequências ambientais. Eventos `HIT` e `EXPLOSION` estão definidos, mas não aparecem como emissões literais em `game.gd`; o adaptador legado pode encaminhá-los. |
| Efeitos sonoros | **I/P.** Sons são sintetizados como WAVs mono, incluindo passo, bloqueio, moeda, escudo, impacto, portal, armadilha, poderes e captura. `audio_feedback.gd:24–30`, `131–222`; mapa em `tactical_feedback.gd:6–48`. | A existência de dados e a emissão não demonstram qualidade, separação ou volume adequado. Não há sons próprios para caixa, corrente, gelo, água elétrica ou placa ambiental na referência. A exportação de amostras é técnica; **não foram ouvidas**. |
| Música e ameaça | **I/P.** Faixa-base e camada de ameaça estéreo com cerca de 39,184 s; código ajusta a camada conforme estado do jogo. `audio_feedback.gd`, `audio/`, `tools/generate_music.py`, `game.gd:2725–2734`. | O teste verifica duração igual das faixas, não sincronismo audível nem mistura; há aviso de ameaça musical com base no estado dos inimigos, que não deve ser confundido com a aura/háptica de ameaça visível. Falta audição comparativa. |
| Comando e vibração | **I/P.** Detecção, remapeamento, seleção, teste, prioridade, limitação de pulsos, intensidade 0–200% e opção desligada; persistência. `controller_input.gd`, `haptic_mixer.gd`, `hud.gd:576–628`. | Testes usam dispositivo simulado. 200% é ganho de software com saturação por motor, não força física duplicada; novos perfis usam o máximo. Resposta, mapeamentos reais, latência e conforto dependem do hardware/driver e não foram medidos. Sem canais independentes de gatilho Xbox na API usada. |
| Teclado, rato e toque | **I/P.** Comandos e interação existem; remapeamento persistente encontrado é para comando. `game.gd` e `controller_input.gd`; botões em `hud.gd`. | Não foi identificada uma página geral de remapeamento de teclado/rato equivalente à de comando. Navegação e leitura requerem ensaios humanos e resoluções diversas. |
| Definições gerais | **P.** O menu permite música ligada/desligada e a página de comando permite controlar a vibração. `hud.gd:478–502`, `560–628`. | Não há quatro secções gerais completas **Áudio / Vídeo / Teclado e Mouse / Controle**, nem controlos gerais para volume dos efeitos, flashes, movimento, partículas e tremor. Ter `effects_enabled` interno não equivale a ter controlo exposto ao jogador. |
| Conforto visual | **P.** Alguns eventos são já breves e localizados, mas a captura tem várias camadas de estímulo sem preferência de redução. Alternância `int(capture_time * 26) % 2` e overlay `abs(sin(capture_time * 36))` estão em `game.gd:2426–2450, 4501–4520`. | Estes números descrevem fórmulas, não frequência medida do ecrã nem diagnóstico clínico. Propor modo reduzido, revisão de duração e contraste e teste específico; não prometer conformidade clínica sem análise adequada. |

## 4. Mapa dos eventos e da causalidade

| Acontecimento controlado | Estado/eventos observados ou lidos no código | Consequência para o plano |
|---|---|---|
| Câmara 1: empurrar madeira de `(3,4)` para a corrente | Caixa termina em `(5,4)` no mesmo turno; eventos observados: `MOVE`, `TURN_COMMITTED`, `PORTAL_OPEN`. Jogador lógico já em `(3,4)`, visual ainda no centro anterior. | Não esperar pela animação para a lógica. A apresentação deve representar contacto → empurrão → deriva → placa/portal na ordem compreensível, inclusive quando chegam mais comandos. |
| Câmara 4: ativar apenas a primeira placa | `active=1`, `gate_open=false`; eventos observados apenas `MOVE`, `TURN_COMMITTED`. | Propor transições semânticas de placa e portão, distinguindo ativar/desativar. Não produzir efeitos continuamente por frame. |
| Gelo: esperar e entrar na casa de gelo | Resultado lógico `(4,4)`, centro `(252,252)`; anel registado em `(196,252)`, centro de `(3,4)`. Eventos `MOVE`, `TURN_COMMITTED`. | Posicionar sinais pelo resultado final ou atribuí-los explicitamente a um local intermédio, de acordo com o seu significado; acrescentar teste de deslocação forçada. |
| Armadilha com uma carga de escudo | Carga passa a zero, jogo continua; eventos `MOVE`, `TURN_COMMITTED`, `SHIELD_IMPACT`, `RHYTHM_TRAP`. | Avaliar coexistência e prioridade; esses dois eventos são distintos, pelo que a deduplicação por nome não elimina a possibilidade de sons simultâneos. Não afirmar que a mistura é ruim sem ouvi-la. |
| Capture | Código desencadeia tremor, flashes, overlay, partículas e eventos de inflação/estouro. `tests/self_test.gd:977–1008` exige pelo menos 80 partículas na sequência padrão. | A futura opção reduzida precisará de testes próprios; não apagar a exigência da sequência padrão sem uma decisão explícita e teste equivalente. Evitar forçar exposição intensa durante os testes. |

## 5. Evidências visuais para inspeção

Todas as ligações abaixo apontam para ficheiros incluídos no projeto atualizado:

- [Corrente e caixa, antes](evidencias-sensoriais-2026-11-03/02-corrente-antes.png), [primeiro estado depois da ação](evidencias-sensoriais-2026-11-03/passo-00.png) e [posição visual final](evidencias-sensoriais-2026-11-03/03-corrente-depois.png).
- [GIF reconstruído e desacelerado do empurrão](evidencias-sensoriais-2026-11-03/animacao-empurrao-controlada.gif). A mudança imediata da caixa e do portal contrasta com a interpolação do jogador; a velocidade do GIF não é a velocidade real.
- [Água elétrica e caixa de metal](evidencias-sensoriais-2026-11-03/04-agua-eletrica.png); [gelo e armadilha](evidencias-sensoriais-2026-11-03/05-gelo-armadilha.png); [gelo com anel na casa anterior](evidencias-sensoriais-2026-11-03/05b-gelo-anel.png).
- [Placas e portão antes](evidencias-sensoriais-2026-11-03/06-placas-portao.png) e [depois das ações, com movimento visual estabilizado](evidencias-sensoriais-2026-11-03/07-placas-ativas.png).
- [Campanha, piso 6 posicionado por script](evidencias-sensoriais-2026-11-03/08-campanha-andar-6.png); [janela 800×540](evidencias-sensoriais-2026-11-03/10-tamanho-minimo.png).

O pacote complementar de evidências contém ainda as capturas restantes, os sete frames individuais, os logs e as sondas usadas. Inclui 11 WAVs exportados a partir dos efeitos sintetizados, para uma futura audição. **Ouvir com volume baixo inicialmente**; captura/impacto podem ter transientes. O laboratório usou saída de áudio fictícia: estes ficheiros não implicam que tenham sido ouvidos ou aprovados.

## 6. Verificação técnica realizada

### 6.1 Suites e geração

Importação e testes em snapshots separados com Godot 4.7.2, perfis isolados e sem erros de script nos logs:

| Verificação | Resultado | Significado limitado |
|---|---|---|
| `tests/self_test.gd` | `SELFTEST_PASS` | Contratos existentes, incluindo a sequência padrão de captura; não mede gosto, segurança visual nem audição. |
| `tests/environment_test.gd` | `ENVIRONMENT_TEST_PASS` | Regras ambientais cobertas em laboratório/arranjos injetados. |
| `tests/controller_test.gd` | `CONTROLLER_TEST_PASS` | Perfis, mapeamentos e comportamento simulado; sem comando físico. |
| `tests/tactical_feedback_test.gd` | `TACTICAL_FEEDBACK_TEST_PASS` | Eventos, prioridades e háptica simulada; não mede vibração ou som reais. |
| `tests/performance_regression_test.gd` | `PERFORMANCE_REGRESSION_PASS` | Contratos automatizados de geração/renderização; não é benchmark de GPU. |
| `tests/sweep.gd`, pisos 1–10 | `SWEEP_PASS`; geração com 2 seeds por piso; bots em pisos selecionados, 3.379 ações | Amostra de geração e caminhos simulados, não cobertura total. |
| Sweep, pisos 25–35 | `SWEEP_PASS`; geração com 1 seed por piso; bots em pisos selecionados, 2.460 ações | Mais uma amostra, não validação de equilíbrio ou sensação. |
| Sweep, pisos 100 e 200 | `SWEEP_PASS`; 1 seed por piso, sem bots | Verifica geração e invariantes, não jogatina completa. |

Os bots usam o seu próprio conjunto fixo de pisos e seeds: nesta execução foram os pisos 1–6 e 8–10, e depois 25, 28, 30, 33 e 35. Não percorreram todos os pisos da geração. Há diferentes estilos, incluindo um explorador invulnerável; isso não demonstra equilíbrio de combate.

**Benchmark de referência, não alvo de desempenho:** Godot 4.7.2, X11/Xvfb, Mesa llvmpipe por CPU, janela 1280×720, seeds `12900`, `48211`, `77123`, 40 frames e percurso de câmara sintético. Os tempos de geração agregam três seeds; os frames foram medidos apenas no último estado gerado por piso. O movimento de câmara não é movimento legal do jogador. Mediana e p95 abaixo em milissegundos:

| Piso | Geração mediana | Frame mediano | Frame p95 |
|---:|---:|---:|---:|
| 1 | 16,381 | 71,204 | 82,031 |
| 6 | 67,251 | 86,703 | 97,905 |
| 30 | 128,074 | 83,559 | 94,517 |

Esta amostra pequena, em renderização por software, **não prevê o FPS na Intel UHD 620 nem noutra GPU**. O driver virtual não suportou a configuração de VSync; o benchmark também terminou com aviso de quatro instâncias ObjectDB por libertar, cuja causa e relevância para o jogo normal não foram apuradas. Não se deve apresentar o aviso como fuga comprovada em produção. Antes/depois tem de usar a mesma máquina, renderer, resolução, seeds, percurso e duração, com amostra maior e medição separada de jogabilidade real.

### 6.2 Reproduzir em cópia descartável

Instala Godot oficial 4.7.2, extrai o projeto atualizado e o pacote complementar, e trabalha numa **cópia**, não no perfil real. Exemplos para Bash/Linux; substituir os caminhos locais. Os diretórios de perfil devem ser graváveis e isolados, pois vários testes manipulam persistência:

```bash
GODOT=/caminho/para/Godot_v4.7.2-stable_linux.x86_64
PROJETO=/caminho/para/copia-do-projeto
EVIDENCIAS=/caminho/para/pacote-de-evidencias
TMP=$(mktemp -d)
mkdir -p "$TMP"/{home,data,config,cache,sfx,imagens}
export HOME="$TMP/home" XDG_DATA_HOME="$TMP/data"
export XDG_CONFIG_HOME="$TMP/config" XDG_CACHE_HOME="$TMP/cache"

"$GODOT" --headless --path "$PROJETO" --editor --import >"$TMP/import.log" 2>&1
for teste in self_test environment_test controller_test tactical_feedback_test performance_regression_test; do
  mkdir -p "$TMP/$teste"/{home,data,config,cache}
  if env HOME="$TMP/$teste/home" XDG_DATA_HOME="$TMP/$teste/data" \
    XDG_CONFIG_HOME="$TMP/$teste/config" XDG_CACHE_HOME="$TMP/$teste/cache" \
    "$GODOT" --headless --path "$PROJETO" --script "res://tests/$teste.gd" >"$TMP/$teste.log" 2>&1; then
    echo "$teste: comando terminou; conferir PASS e erros no log"
  else
    echo "$teste: FALHOU; consultar $TMP/$teste.log" >&2
  fi
done
# Exemplo de sweep; seeds explícitas e número de ações constam do log.
"$GODOT" --headless --path "$PROJETO" --script res://tests/sweep.gd -- floors=1-10 seeds=2 bots=1 >"$TMP/sweep.log" 2>&1

# A sonda é adicionada apenas à cópia descartável, não ao jogo original.
cp "$EVIDENCIAS/reproducao/sensory_probe.gd" "$PROJETO/sensory_probe.gd"
SENSORY_AUDIO_OUT="$TMP/sfx" "$GODOT" --headless --path "$PROJETO" --script res://sensory_probe.gd >"$TMP/sonda.log" 2>&1
```

Verifica o código de saída de cada comando, os marcadores `*_PASS`/`SWEEP_PASS`, as linhas `PROBE_*` e também a existência de `SCRIPT ERROR` ou `ERROR:` nos logs. Uma importação pode terminar com código zero mesmo com erros de script, pelo que o código de saída **não basta**. O script da sonda emite os dados medidos e escreve WAVs no diretório criado; os valores `save_error` devem ser zero. Os resultados exatos de desempenho e imagens variam com sistema e renderer.

Para repetir as capturas, copiar `reproducao/sensory_visual_probe.gd` para a raiz da cópia e executá-lo com uma sessão gráfica funcional:

```bash
cp "$EVIDENCIAS/reproducao/sensory_visual_probe.gd" "$PROJETO/sensory_visual_probe.gd"
SENSORY_VISUAL_OUT="$TMP/imagens" "$GODOT" --path "$PROJETO" \
  --rendering-method gl_compatibility --audio-driver Dummy --resolution 1366x768 \
  --script res://sensory_visual_probe.gd >"$TMP/visual.log" 2>&1
```

A sonda desativa o processamento automático do jogo e avança alguns estados manualmente: é instrumento de inspeção, não um modo jogável nem um gravador de tempo real. Para o benchmark gráfico, usar a mesma sessão e `res://tools/performance_benchmark.gd -- floors=1,6,30 seeds=12900,48211,77123 frames=40 motion=1`. Em sistema sem ecrã físico é preciso configurar um display virtual; os números da tabela referem-se especificamente ao ambiente Xvfb/llvmpipe descrito.

## 7. Comparação com a branch visual — não integrar às cegas

Na referência `cb67e75` de `visual-overhaul-v2` há ideias relevantes: interpolação de caixas e eventos `CRATE_PUSH`, `CURRENT_DRIFT`, `ICE_CRACK` e `ELECTRIC_WATER`, com mapeamentos de áudio/háptica (`visual:game.gd:1905–1960` e ficheiros associados). Essa branch também muda regras e conteúdo: inclui Sokoban/ambiente e trabalho adicional sobre Lia e inimigos. É material para **estudar e reconciliar**, não prova de que a branch atual já tenha esses efeitos, nem autorização para copiar blocos inteiros.

Na inspeção da própria referência visual, `hud.gd` tinha uma chamada a `_draw_sokoban_guide()` sem implementação e um erro de inferência de tipo; o script principal falhava por dependência. Um teste em cópia com HUD substituído por stub ajudou a diagnosticar as regras, mas **não é correção validada**. A CI do PR #9 estava cancelada; o PR #10 tinha conflitos em `README.md`, `docs/auditoria-e-plano.md`, `game.gd` e `hud.gd`. Um simples `ours/theirs` pode eliminar trabalho de uma das duas linhas. O estado remoto deve ser reavaliado quando houver autorização específica para integração.

## 8. Plano priorizado para aprovação — sem implementação nesta etapa

### P0 — Preservar, medir e reduzir risco

1. **Acordar a base de trabalho antes de integrar:** rever o estado atual das duas branches e os conflitos; manter a mecânica, os testes, o perfil do utilizador, as câmaras existentes e a possibilidade de voltar atrás. Não é necessário resolver o PR para aprovar esta auditoria.
2. **Definir a semântica de cada evento e local final:** observar a sequência real após input, movimento forçado, dano, placa, portão e portal. Corrigir numa alteração futura o anel do gelo e a apresentação fora de sincronia, sem mudar a ordem nem o resultado das regras. Adicionar casos para múltiplas ações rápidas, bloqueio e captura interrompida.
3. **Conforto como requisito de base:** propor alternativas de flash, partículas, movimento e tremor com estados críticos ainda legíveis. Avaliar captura em particular e permitir reduzir/desligar vibração sem perder informação obrigatória. Não alegar segurança clínica sem validação própria.
4. **Separar aleatoriedade visual da lógica** de forma retrocompatível e testada, sem alterar seeds ou checkpoints inadvertidamente. O efeito pretendido é que quantidade de partículas, tremor e preferências não alterem estado jogável. Testar geração normal e também criação em desenvolvimento; a sonda atual cobre apenas o segundo caminho.
5. **Estabelecer o antes:** guardar seed, ações, resolução, renderer, FPS/frame time, opção de estímulos e versão. Manter capturas originais e o GIF identificado como reconstrução. Antes/depois de áudio precisa de audição, não só de registo de eventos.

### P1 — Uma sala vertical com peso e clareza

6. **Câmara representativa única, em modo de teste:** desenhar um layout fixo e solucionável com jogador, madeira, metal, corrente e água normal/eletrificada, gelo, inimigo, armadilha rítmica, placas/portão e portal. Isolar um percurso seguro e dar ao inimigo uma rota/estado reproduzível; confirmar a solução por teste em vez de assumir que um esboço é jogável. Não substituir as quatro câmaras sem aprovação.
7. **Sincronizar as camadas:** reaproveitar a interpolação do jogador e avaliar a ideia de interpolar caixas da branch visual, com estados visuais transitórios não autoritativos. Mostrar empurrão, deriva, pressão, abertura e descanso em sequência curta; rever entradas rápidas para não atrasar turnos, atravessar paredes, perder eventos ou desalinhar visual definitivamente. Durações exatas devem sair de ensaios, não ser tratadas como números aprovados.
8. **Água e materiais:** orientar a animação da água pela direção lógica e experimentar espuma/fluxo localizado em vez de depender principalmente de setas. Mostrar de forma diferenciada água meramente decorativa, corrente ativa e eletricidade. Uma indicação estática/contextual ou acessível deve continuar disponível quando o movimento estiver reduzido; não depender apenas de cor ou movimento.
9. **Placas, portão, gelo e eletricidade:** desenhar compressão/relevo da placa e movimento do portão; dar à madeira e ao metal leitura material distinta. Avaliar pequenos arcos/faíscas localizadas e não permanentes para eletricidade e contacto/fricção para gelo. Manter os sinais de perigo e o ciclo da armadilha legíveis, inclusive em modo reduzido.
10. **Áudio e háptica em conjunto, não em competição:** estudar eventos próprios no barramento existente para empurrão, deriva, placa/portão e mudança de eletrificação; avaliar se o gelo precisa de um sinal contínuo ou apenas de entrada/contacto. Definir prioridade, agrupamento e intervalos para uma ação que produz várias consequências. Não disparar sons/vibrações longos ou repetidos por frame; manter a independência entre efeitos silenciados e vibração. Testar em volumes equilibrados e comando físico.
11. **Inimigo e ameaça:** mostrar o que o inimigo realmente fará ou quando ficará parado, sem anunciar uma intenção incorreta nem encher a grelha de setas. Manter sinais existentes por tipo e validar rapidamente se a intenção é compreendida antes de investir em animações caras.

### P2 — Escalar apenas o que funcionar

12. **Definições organizadas:** desenhar as quatro categorias abaixo, com persistência/migração segura e acesso tanto por menu como por pausa. Aproveitar o menu de comando e a opção de vibração existentes. Respeitar o valor do utilizador ao migrar perfis.
13. **Hierarquia de HUD e dicas:** apresentar instrução contextual quando necessária, reduzir duplicação, testar legibilidade em 800×540 e 1366×768 e não depender de texto minúsculo. Testar navegação por teclado, rato e comando.
14. **Restante campanha, bosses, narrativa e biomas:** aplicar só as soluções aprovadas na câmara, verificando que cada bioma/efeito mantém contraste e semântica. Não assumir que a arte ou os scripts da branch visual podem ser integrados sem resolver o conflito e os erros.
15. **Desempenho:** estabelecer orçamento de partículas e trabalho por frame, sem piorar previsibilidade; comparar em hardware alvo e investigar o aviso de saída do benchmark se persistir. Não confundir a medição llvmpipe com desempenho de hardware real.

### 8.1 Contrato proposto para a sala representativa

O layout, a arte e a solução final ainda não estão decididos. Esta é uma **especificação de teste**, não uma afirmação de que a sala já existe:

| Situação | Resultado lógico a preservar/confirmar | Resposta sensorial a prototipar | Verificação futura |
|---|---|---|---|
| Empurrar madeira para corrente que leva a uma placa | Empurrão e flutuação no mesmo turno segundo as regras; placa conta apenas o material correto. | Contacto, avanço, deriva e pressão sequenciados; som de madeira e água sem duplicação excessiva. | Posição e eventos certos, inclusive com input rápido; animação não introduz atraso lógico. |
| Tirar ou pôr metal no caminho da condução | Recálculo determinístico das células energizadas; perigo e dano continuam definidos pelas regras. | Arcos/faíscas de baixa densidade ou alternativa estática; som curto de transição, não zumbido obrigatório por célula. | Ligar/desligar, escudo, inimigo comum/elite e modo reduzido; nenhum estado perigoso sem marca legível. |
| Pisar/deslizar no gelo perto da armadilha | Deslocação extra e fase da armadilha continuam contadas em turnos; evitar contacto forçado inevitável no layout. | Deslizamento, travagem e telegráfo coerentes; anel no local que representa. | Assert de casa final e local do anel; fases seguras/perigosas e captura na primeira casa. |
| Inimigo sobre gelo | Regra atual de paragem nas ações pares, sem eliminar seu papel ou tornar a rota injusta. | Estado/intent de paragem claro antes da decisão do jogador. | Teste lógico e sessão sem pistas verbais para verificar se a intenção é compreendida. |
| Ativar as placas e abrir o portão/portal | Condições e bloqueios atuais; portal só utilizável quando autorizado. | Placa pressionada, portão a abrir e confirmação de objetivo em hierarquia visível. | Ativar, desativar, material errado e várias consequências numa ação; som/vibração sem atropelar ameaça. |
| Mesmo percurso com opções reduzidas | Resultado de jogo e seeds não mudam por reduzir efeitos. | Indicação persistente por forma/estado/texto, com menos movimento/flash/partículas e sem tremor se escolhido. | Mesmos resultados lógicos e eventos essenciais; não depender só de cor, som, vibração ou movimento. |

### 8.2 Definições propostas, a aprovar

- **Áudio:** volume geral, música e efeitos separados; opção de silenciar, teste de mistura e indicação visual/textual para informação indispensável. Validar que música e efeitos se comportam independentemente.
- **Vídeo:** resolução/escala de interface e opções independentes para movimento, tremor, intensidade de flashes e densidade de partículas; estados críticos mantêm uma forma estática legível. Compatibilidade com hardware e valores padrão dependem de testes.
- **Teclado e Mouse:** mapeamento, reposição, foco visível e navegação, sem quebrar os atalhos já usados nem o toque.
- **Controle:** manter seleção, calibração, teste, intensidade e desativação existentes; documentar limites reais de cada motor. Verificar USB/Bluetooth quando disponíveis e não presumir suporte a gatilhos hápticos.

A organização e os valores são propostas, não uma interface já existente. Guardar as escolhas e testá-las com perfis novos e antigos antes de substituir qualquer configuração.

## 9. Critérios de aceitação e ensaios humanos

Uma eventual implementação só estará pronta para avaliação quando:

1. **Integridade:** suites existentes e sweeps acordados passam; regras, mapas, ordem dos turnos, checkpoints, perfis antigos e comandos permanecem válidos. A sequência padrão de captura mantém cobertura explícita; o modo reduzido ganha critérios próprios. Seeds e resultados jogáveis não mudam ao variar efeitos.
2. **Causalidade:** testes automáticos registam posição lógica e visual, eventos e localização dos sinais para empurrão, corrente, gelo, placas, eletricidade, armadilha/escudo e portal; incluem repetição rápida de input, animação interrompida e cancelamento/pausa. Sem novos eventos contínuos a cada frame.
3. **Legibilidade:** com e sem animação, observar se se distinguem corrente e direção, eletricidade ativa, material exigido, fase da armadilha, intenção do inimigo e estado do portão. Incluir verificação em escala de cinzentos/contraste e texto ampliado; oferecer sinais redundantes sem depender apenas de cor.
4. **Audição e vibração reais:** comparar som atual e protótipo ao mesmo volume, com auscultadores e colunas quando disponíveis; testar mistura de eventos simultâneos, opções de volume e silêncio. Testar pelo menos um comando físico suportado em várias intensidades, registando modelo, sistema e ligação. Solicitar impressões, não declarar qualidade com base no WAV.
5. **Game feel:** pedir a jogadores que façam pequenos objetivos sem dicas verbais: prever sentido da corrente, escolher material, avaliar a fase da armadilha e antecipar o inimigo; registar erros, tempo, comentários e conforto. Depois comparar antes/depois sob as mesmas condições. Nenhuma pontuação de satisfação foi recolhida nesta auditoria.
6. **Desempenho:** comparar o mesmo percurso/seed, resolução e opções na máquina-alvo, incluindo cena com efeitos simultâneos; recolher distribuição de frame times e não apenas FPS médio. Verificar também máquinas mais fracas quando disponíveis.
7. **Entrega e revisão:** mostrar vídeos/capturas reais, descrição de alterações e limitações, projeto descarregável e resultados ao proprietário. Pedir aprovação antes de expandir a linguagem para todos os pisos ou de fazer integração, commit ou PR.

## 10. Decisões a confirmar com o proprietário

1. Aprovar a **câmara única como protótipo**, mantendo as quatro câmaras atuais, ou escolher outro ponto de partida?
2. Que intensidade e estilo pretende para o neon: mais material e discreto, ou efeitos mais expressivos sem sacrificar clareza e conforto?
3. A direção da corrente deve ter indicação estática sempre visível ou apenas contextual/acessível? Em qualquer caso, a direção tem de ser clara sem depender exclusivamente da animação.
4. Quais são os dispositivos reais de referência para áudio, ecrã/GPU e comando, e qual a resolução mínima de leitura desejada?
5. Quando houver autorização de implementação, qual a estratégia de reconciliação das branches e do PR existente? Esta auditoria não escolhe nem executa uma integração.

**Resultado da etapa:** inventário, evidências e plano prontos para revisão. Não foi alterada lógica nem feito commit, push, merge ou novo pull request.
