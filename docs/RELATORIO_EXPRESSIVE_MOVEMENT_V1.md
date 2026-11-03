# Come To Me — Expressive Movement, Combat & Materials V1

**Data:** 3 de novembro de 2026<br>
**Base de comparação:** `b1c33998b9778aa6246a7bdc15f0ea94ee39d978`<br>
**Estado:** implementação local jogável para avaliação do proprietário; sem commit, push ou merge nesta tarefa.

## 1. O que mudou

- **Movimento:** resposta lógica imediata continua a acontecer na grelha. A apresentação usa pequenos segmentos, aceleração/abrandamento, rotação dependente da direção, deformação, contacto e recuperação. Viragens e inversões passam pelas casas já resolvidas, em vez de cortar uma diagonal visual. A esfera mantém a face legível.
- **Entradas rápidas:** até três segmentos visuais, com atraso visual total limitado a 0,24 s. Se a cadência exceder essa capacidade, a apresentação avança para a última origem lógica e anima o segmento mais recente. É um compromisso explícito: nenhum comando é reenviado ou bloqueado, mas pode haver um salto visual sob sobrecarga extrema.
- **Materiais e caixas:** gelo e corrente mantêm a deslocação extra no mesmo turno, mas mostram as etapas consecutivas. Caixas empurradas ou arrastadas têm movimento próprio; contactos com água/gelo geram respostas discretas e limitadas. Placas e portões continuam a resolver-se logicamente no mesmo turno, podendo mudar antes de a animação da caixa terminar.
- **Bloqueio, salto, Blink e captura:** bloqueios reagem sem gastar um turno; o salto tem arco; Blink continua instantâneo e cancela um percurso visual obsoleto. A captura bloqueia input imediatamente, mas deixa o movimento já resolvido chegar à célula fatal antes da sequência de derrota. Pausa e reinício não reproduzem comandos guardados.
- **Combate e inimigos:** reação corporal no ataque e impacto, recuo visual, silhueta breve e não interativa na derrota, deformação e inclinação conforme movimento efetivamente ocorrido. Inimigos leves e pesados usam intensidades distintas; o cavalo tem um arco visual próprio. A lógica de vida, colisão e dano não depende da animação. Mantiveram-se os sons e vibrações existentes; não foram criados efeitos sonoros novos nem uma pausa global automática.
- **Sem previsões do movimento inimigo:** continuam a existir dados internos `next`/`path` para a lógica, mas não são desenhados. Foram retiradas a linha de scanner da sentinela, a linha e retícula remotas do Guardião e as linhas de velocidade do Rusher. Alerta, direção e personalidade permanecem na própria entidade. Esta regra está no guia e em `AGENTS.md`.

O trabalho é uma V1 localizada, não uma reinterpretação integral da arte nem uma afirmação de que todos os movimentos são esteticamente satisfatórios. A avaliação do *game feel* pertence ao proprietário.

## 2. Resultados de testes

Todos os resultados abaixo referem-se à versão final das fontes, em Godot oficial **4.7.2**, Linux no ambiente isolado. Os testes não provam aprovação estética.

| Resultado | Cobertura executada |
|---|---|
| **PASS** | Importação limpa do projeto em Godot. |
| **PASS** | `self_test.gd`: geração, desafios, chefes, poderes, captura e áudio simulado. |
| **PASS** | `environment_test.gd`: quatro câmaras, caixas, corrente, gelo, eletricidade, portões e reset. |
| **PASS** | `controller_test.gd`: menus, eixos, remapeamento e vibração **simulada**. |
| **PASS** | `tactical_feedback_test.gd`: eventos, prioridade, sons e perigo **simulados**. |
| **PASS** | `performance_regression_test.gd`: fingerprints de geração/RNG, culling, terrenos e captura. As expectativas de culling foram adaptadas à remoção deliberada da linha/retícula remota, e continuam a verificar entidades visíveis e margem de ecrã. |
| **PASS** | `expressive_movement_test.gd`: **151 verificações** de direções, continuidade, overflow, gelo, água, caixas, bloqueio, pausa, salto, Blink, captura, combate, inimigos e RNG. |
| **PASS** | `enemy_intention_render_test.gd`: **26 verificações gráficas** com oito tipos de inimigo, imagens reais, alteração de `next`/`path`, limites espaciais e controlo positivo no tabuleiro/HUD. Exige renderer real; não usar `--headless`. |
| **PASS** | Comparação A/B de **oito estados lógicos** e eventos: viragem, bloqueio, corrente, gelo, caixa/placa, escudo, demolição e captura. Valores de RNG comparados nesses cenários; não é prova exaustiva. |
| **PASS** | Sweep: andares 1–20, duas seeds por andar e bots de rota, aleatório e exploração; **5.644 ações**. |
| **NOT TESTED** | Windows 11, instalador/launcher Windows, Intel UHD 620, comando físico, vibração real, áudio audível, conforto/acessibilidade e testes com jogadores. |
| **NOT TESTED** | Exportação Windows nativa e 60 FPS no hardware de referência; o pacote usa projeto-fonte mais launcher e não contém um `.exe` do jogo exportado. |

Os scripts de testes estão em `tests/`; no pacote de entrega, os logs e sondas usadas na comparação estão em `Evidencias/`. As primeiras tentativas encontraram um erro de inferência no salto do cavalo e um erro de alinhamento ao gerar GIFs; ambos foram corrigidos e os testes/capturas finais foram refeitos, em vez de tratar os resultados anteriores como finais.

## 3. Comparações visuais

A pasta `Comparacoes/` da entrega contém 14 GIFs lado a lado: passo, viragem, gelo, corrente, caixa/placa, combate, bloqueio, salto, Blink, captura, Hunter, Sentinela, Guardião e cavalo. São capturas reais do jogo nas duas versões, em cenários controlados, Godot X11/llvmpipe a 1366×768; os GIFs recortam a região relevante, não reconstituem a arte. Amostras a cada **30 ms simulados** são exibidas durante **40 ms**, cerca de 0,75× da velocidade simulada; o último fotograma é mantido 650 ms. Não têm som.

Na viragem controlada, a base cortava da posição parcial para o destino diagonal e concluía em aproximadamente 120 ms; a V1 passa pela célula de viragem e conclui em aproximadamente 240 ms. No gelo e corrente a base mostrava duas casas em cerca de 120 ms; a V1 apresenta segmentos em cerca de 240 ms. Estes tempos referem-se à apresentação neste ensaio: as posições e consequências lógicas já estavam resolvidas em ambos os casos.

## 4. Performance observada — não extrapolar para UHD 620

Godot 4.7.2, X11, renderer **llvmpipe por software**, 1366×768, 20 frames de aquecimento, 80 frames medidos e 10 comandos/turnos. Os números são duração de frame, em milissegundos, mediana/p95:

| Ensaio | Base | V1 final |
|---|---:|---:|
| Arena sem inimigos, corrida 1 | 79,379 / 89,939 | 77,350 / 85,053 |
| Arena sem inimigos, corrida 2 | 78,666 / 83,590 | 80,795 / 85,268 |
| Arena com seis inimigos, uma corrida | 84,261 / 92,777 | 80,944 / 92,904 |

O renderer de software é lento e variável. Estes dados servem apenas para comparação local, não são previsão da GPU do proprietário nem demonstram 60 FPS. VSync não estava disponível neste renderer.

## 5. Limitações e riscos conhecidos

1. **Windows ainda precisa de validação real.** O launcher descarrega o editor oficial Godot 4.7.2 e verifica o SHA-256 do ZIP antes de o extrair; é uma forma de executar o projeto-fonte, não um jogo nativo exportado. Alternativamente pode usar-se o ZIP oficial já descarregado. O caminho automático não foi executado em Windows nesta sessão.
2. O renderer de software emitiu **quatro avisos ObjectDB ao sair**, na base e na V1. A execução `--verbose` identificou duas `AudioStreamWAV` e duas `AudioStreamPlaybackWAV`; o ciclo de vida exato não foi comprovado e não há evidência de que a V1 tenha introduzido o aviso.
3. No extremo de entradas muito rápidas pode ocorrer o salto visual de overflow descrito acima. A política não perde comandos, mas merece avaliação humana com teclado e comando reais.
4. A remoção da linha/retícula do Guardião também elimina esse sinal quando ele está fora do ecrã. Avaliar justiça, perceção de ameaça e acessibilidade em jogo; manter a regra de não revelar a próxima casa e só considerar uma exceção se houver necessidade demonstrada.
5. Há um risco **preexistente** de RNG partilhado entre alguns efeitos/tremor e comportamento; as novas poses não consomem RNG, mas isso não resolve todo o acoplamento anterior.
6. Som real, música, vibração, variações de FPS e identidade artística precisam de avaliação no dispositivo alvo. Os testes automáticos e GIFs não substituem o julgamento do proprietário.

## 6. Repetir os testes

Com Godot 4.7.2 importado, a partir da raiz do projeto:

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/self_test.gd
godot --headless --path . --script res://tests/environment_test.gd
godot --headless --path . --script res://tests/controller_test.gd
godot --headless --path . --script res://tests/tactical_feedback_test.gd
godot --headless --path . --script res://tests/performance_regression_test.gd
godot --headless --path . --script res://tests/expressive_movement_test.gd
godot --headless --path . --script res://tests/sweep.gd -- floors=1-20 seeds=2 bots=1
# Com sessão gráfica e GL compatibility:
godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/enemy_intention_render_test.gd
```

O nome do executável `godot` varia conforme a instalação. Em Windows, execute os comandos equivalentes com o executável de consola do Godot.
