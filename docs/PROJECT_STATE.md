# Estado do Projeto

> **Histórico da branch base:** este checkpoint descreve uma fase anterior e não é a autoridade para o estado integrado. Consulta [CHECKPOINT_GAME_FEEL.md](CHECKPOINT_GAME_FEEL.md) e o README para regras, testes e próximos passos atuais.

## PROJECT_STATE

Jogo tático 2D em Godot 4.7.2. A campanha, WFC, salas, chefes, poderes, resultados, checkpoint e personagem Lia em forma de bola já existem. Esta fatia acrescenta objetos empurráveis e regras de água/gelo dentro do tabuleiro por turnos.

## LAST_CHECKPOINT

Checkpoint local criado no ramo `visual-overhaul-v2`, sobre `d8a1e8a` (`feat: introduce Lia as a matching orb in the captor scene`). A fatia está guardada no histórico Git local; não foi enviada a um remoto. `desktop.ini`, já alterado antes do trabalho, fica fora.

## CURRENT_TASK

Fechar interação ambiental pequena e legível: corrente com deslocamento de jogador/caixa, deslizamento de gelo, fissura após três passagens, água elétrica tardia com rota alternativa, congelamento que suspende corrente e eletricidade, efeitos correspondentes e regressões.

## ACTIVE_ALGORITHM

Regras ambientais determinísticas executadas em `_take_turn`: recolher itens no percurso → mover caixas flutuantes e resolver corrente → recolher itens alcançados pelo fluxo → disparar armadilhas e água elétrica → acumular fissuras → interruptores → movimento/contacto dos inimigos → temporizadores → portal. O desenho lê os estados já calculados.

## LATEST_EVIDENCE

- Godot `4.7.2.stable.official.ed1daf0bf`: `SELFTEST_PASS`, `PERFORMANCE_REGRESSION_PASS`, `CONTROLLER_TEST_PASS` e `TACTICAL_FEEDBACK_TEST_PASS`.
- Varredura isolada de piso 4 com 3 seeds e bots: `SWEEP_PASS`, 225 ações de bot, pico local de geração 642 ms.
- O autoteste verifica colocação opcional das caixas, caminho para o portal, empurrão e corrente, deslizamento, fissura, dano elétrico protegido por escudo e segurança imediata do congelamento.
- A janela real confirmou a apresentação do menu e a campanha existente no andar 3. Não foi iniciada outra campanha para preservar esse progresso; os VFX de gameplay, som físico, equilíbrio e GPU continuam sem validação visual/auditiva.

## FAILED_EXPERIMENTS

Na primeira execução, arrays genéricos retornados por `duplicate()` não podiam ser atribuídos a `Array[Vector2i]`; a construção das rotas passou a copiar pontos explicitamente. Uma tentativa inicial de posicionar caixas antes dos inimigos aproximou um perseguidor do início (piso 4, seed 1124); as caixas foram movidas para depois da geração dos inimigos e os três casos de piso 4 passaram com bot. Nenhuma falha atual nas suítes executadas.

## CONSTRAINTS

- Manter a geração reproduzível e não bloquear caminho ao portal.
- As caixas não são objetivos obrigatórios e não podem cobrir portal ou interruptor; não anunciar Sokoban sem solver e reset testados.
- Não introduzir corações avulsos: precisam da árvore de habilidade e persistência por campanha descritas em `design-coracoes-e-habilidades.md`.
- Não assumir que o PASS headless comprova aparência, áudio, equilíbrio ou velocidade de GPU.
- `desktop.ini` é alteração anterior do utilizador e não faz parte desta tarefa.

## NEXT_ACTION

Isolar um perfil de teste para abrir uma fase e avaliar a leitura do gelo/água e apresentação das caixas sem tocar na campanha real; depois ajustar contraste/ritmo se necessário.
