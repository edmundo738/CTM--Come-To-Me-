# Árvore de habilidades, corações e campanhas

**Estado:** primeira implementação funcional para teste, não balanceamento final. Custos, probabilidades, quantidade de pontos e limite de habilidades são provisórios e podem precisar de ajuste depois de jogar. Os efeitos e dependências efetivos estão definidos em [`skill_tree.gd`](../skill_tree.gd) e aplicados em [`game.gd`](../game.gd).

## Como usar

1. Inicia ou continua uma das três campanhas. Uma campanha nova começa sem pontos, habilidades, corações extras ou recursos herdados das outras.
2. A primeira conclusão de cada andar dá **1 ponto de habilidade**. Repetir um andar já recompensado não dá outro ponto. Pontos são separados das moedas, que continuam a ser pontuação; não se gastam moedas na árvore.
3. Abre **HABILIDADES** no menu inicial, no resultado de um andar ou na pausa **no início de um andar, antes da primeira ação**. Escolhe um ramo e um nó. O texto mostra o custo, efeito e requisito.
4. **Desbloquear** gasta pontos; **ativar** é uma ação distinta e gratuita. Um nó descendente exige que o nó anterior esteja desbloqueado e ativo. Até **8 nós** podem estar ativos, incluindo os anteriores. Para desativar um anterior, desativa primeiro os dependentes ativos. A desativação não devolve os pontos; podes voltar a ativar sem pagar de novo.
5. Ao terminar um piso, equipar habilidades e depois escolher **PRÓXIMO**, as escolhas passam para o checkpoint seguinte. **R**, derrota e continuação restauram o estado de entrada desse andar, em vez de curar ou recuperar recursos automaticamente.

Os menus suportam rato/toque, teclado e comando. A árvore não pode ser alterada a meio de um piso: isso evita mudar capacidades depois de o checkpoint e os objetos já terem sido gerados. As câmaras experimentais não usam as habilidades da campanha nem alteram o seu progresso.

## Seis ramos, 36 nós

Cada ramo tem uma raiz e duas vias. Valores da mesma categoria somam-se quando os nós estão ativos. Os detalhes e custos individuais aparecem na interface.

| Ramo | Raiz e vias disponíveis | Efeito funcional |
|---|---|---|
| **Sobrevivência** | Coração I → II → III; Coração I → Olho I → II → III | Até três corações adicionais. Cada Olho acrescenta 12 pontos percentuais à chance de aparecer **um** coração recuperável num andar: 12%, 24% ou 36% conforme os nós ativos. Sem Olho não aparece nenhum. |
| **Escudos** | Reserva I → II → III; Reserva I → Coleta I → II → Contra-golpe | Aumenta a capacidade de escudos, as cargas ganhas por pickup e o dano do contra-ataque contra elites. A capacidade base é 3; excedentes herdados são preservados e novos escudos ficam no chão até haver espaço. |
| **Movimento** | Impulso I → II → III; Impulso I → Blink I → Salto Espacial → Blink II | Aumenta a duração do pickup de velocidade, as cargas de Blink por pickup e o seu alcance. Um Blink continua a gastar uma carga e uma ação. |
| **Controlo** | Tempo I → II → III; Tempo I → Aderência → Âncora → Tempo IV | Prolonga o congelamento; Aderência impede o deslizamento automático do jogador no gelo marcado e Âncora impede a corrente de o arrastar. A corrente continua a mover caixas normalmente. |
| **Exploração** | Íman I → II → III; Íman I → Alcance I → II → Prospeção | Prolonga o íman, amplia a recolha por caminhos transitáveis e aumenta o valor de cada moeda recolhida. Não transforma moedas em pontos de habilidade. |
| **Engenharia** | Demolição I → II → III; Demolição I → Impacto I → II → Reciclagem | Aumenta cargas por pickup, dano de demolição a elites e devolve uma carga ao derrotar um inimigo com demolição. O ataque continua a gastar uma ação e uma carga. |

Raízes custam 1 ponto; nós posteriores custam 2 ou 3. As dependências e descrições de cada um dos 36 nós são visíveis no jogo. Habilidades que prolongam power-ups aplicam a duração no momento da recolha: não acrescentam retroativamente turnos a um poder já apanhado.

## Corações e danos

- O HUD mostra **EXTRAS**: a capacidade sem habilidades é zero. Cada nó de Coração concede uma carga **uma vez na primeira ativação daquela campanha**. Desativar e reativar não cria cargas infinitas; o crédito é guardado.
- Num dano fatal elegível, a ordem é **escudo → coração → captura**. Um coração é consumido automaticamente e tenta afastar o jogador para uma casa válida; a proteção não exige um botão. Se não houver casa livre, o jogador permanece na posição.
- O recuo respeita paredes, fronteira, caixas, portões, inimigos, posições reservadas e perigos conhecidos; recolhas e interruptores de chegada seguem a lógica normal sem cobrar outro turno. Um mesmo contacto não separado e ameaças resolvidas na mesma ação não devem consumir múltiplos corações. Uma nova ativação de armadilha ou contacto separado pode causar dano novamente; não existe invulnerabilidade temporizada extra.
- Um pickup de coração recupera uma carga até à capacidade. Se estiver cheio, o pickup fica no chão. A sua colocação usa RNG separado para não consumir a sequência de geração ou IA; é omitido se não existir casa elegível.
- Desativar uma habilidade de coração quando o saldo ficaria acima da nova capacidade pede confirmação e descarta apenas o excedente. Reativar não o restitui.

## Campanhas, checkpoints e recuperação

O perfil global continua em `user://come_to_me_profile.cfg`; as campanhas são `come_to_me_profile.cfg.campaign-1.cfg` até `campaign-3.cfg`, no mesmo diretório de dados do Godot. O perfil mantém definições de comando e campos globais desconhecidos. **Um sistema de cosméticos jogável ainda não foi implementado.**

O save é um checkpoint do **início do piso**, não um retrato de cada movimento. Passar um portal guarda os recursos restantes para o próximo piso. No diário, revisitar um piso na mesma campanha preserva os recursos e poderes disponíveis na altura da escolha, bem como habilidades, pontos, estrelas e piso máximo; o mapa é regenerado com a seed da campanha, não com alterações de uma visita anterior. Visitar repetidamente pode gerar moedas/pickups de novo: o equilíbrio desse comportamento ainda deve ser avaliado.

Na primeira gravação de um perfil antigo, o jogo conserva os bytes originais em `.legacy.bak`, migra a campanha para o primeiro slot e mantém as definições globais. Pisos antigos com estrelas são marcados como já recompensados, **sem atribuição retroativa de pontos**. Um conflito, corrupção ou versão futura não é silenciosamente substituído. Se a migração for interrompida depois de gravar o slot, o hash do perfil antigo permite retomá-la sem duplicar nem apagar o checkpoint.

- Cada slot tem `.bak`, o checkpoint válido anterior. **REST. CHECKPOINT** pede confirmação e arquiva o ficheiro atual antes de restaurar.
- Substituir uma campanha ocupada exige confirmação e cria `.replaced.bak`, independente da rotação de checkpoints. **REST. SUBSTITUÍDA** recupera essa campanha anterior; versões anteriores desse backup podem ser arquivadas por hash.
- Existe backup do perfil global. Se for necessário restaurá-lo, a interface pede confirmação; campanhas dos outros slots não são alteradas. Ficheiros danificados ou mais recentes são arquivados antes de uma restauração explícita.
- As escritas usam temporários verificados e substituição por rename, sem apagar o original para forçar uma falha. Se a gravação falhar, aparece um aviso; não se deve assumir que o último progresso ficou guardado. Não é uma garantia contra todas as falhas de disco, falta de energia ou diferenças entre sistemas de ficheiros. Faz uma cópia de todos os ficheiros do perfil antes de os manipular manualmente.

## Validação e limites

Os testes automatizados cobrem a árvore, efeitos, danos e recuos, ausência de espaço, checkpoints, migração, três slots, backups, ficheiros corrompidos/mais recentes e uma falha de escrita simulada. O teste gráfico usa X11/OpenGL por software e verifica dois tamanhos de janela, botões, confirmações e o aviso de save. Estes testes não demonstram equilíbrio, qualidade estética ou experiência num dispositivo físico. O executável Windows, som audível, vibração física e a GPU de destino continuam por testar.
