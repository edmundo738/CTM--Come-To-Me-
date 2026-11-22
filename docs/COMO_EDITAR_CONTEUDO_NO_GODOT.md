# Editar conteúdo no Godot — guia de autoria

Este guia cobre as partes já ligadas ao Inspector. A arquitetura está a ser migrada; o facto de um elemento aparecer numa cena ou Resource ainda não significa que toda a sua lógica já seja editável.

> Para editar mapas sem abrir o Godot, inicia `Abrir_Oficina_CTM.cmd`. A [Oficina CTM independente](OFICINA_INDEPENDENTE.md) importa mapas, coloca inimigos e pickups, liga mecanismos, valida e grava as fases em ficheiros próprios.

## Oficina visual para criar e testar mapas

O projeto agora instala a extensão **Oficina CTM** como uma tela principal do Godot. Abre o projeto no Godot 4.7.2 e seleciona **Oficina CTM** no seletor de telas do editor.

Se o editor já estava aberto quando a extensão foi adicionada, guarda primeiro qualquer cena marcada com `*` no título e reabre o projeto para carregar a nova tela.

1. No seletor **Fase**, escolhe qualquer posição de 001 a 200. `WFC` significa que a campanha ainda usa a geração e a agenda normais; `MANUAL` significa que há uma cena da Oficina ligada.
2. Escolhe **Criar mapa desta fase** para abrir um mapa vazio com o tamanho correspondente à fase. Um mapa só passa a substituir a campanha quando usas **Ligar mapa atual**.
3. **Gerar layout com WFC** usa o TileSet, perfil de salas e dimensões do bioma daquela fase. O campo de seed é a seed base da campanha; para reproduzir um jogo existente, introduz a seed ativa desse jogo. A seed efetiva é `seed base + fase × 7919`. O layout gerado fica guardado na cena e pode ser pintado por cima.
4. Seleciona **Parede**, **Chão**, **Início**, **Portal**, **Colocar peça** ou **Apagar peça** e clica numa casa. O início e o portal ficam dentro da borda sólida.
5. Ao colocar uma peça, escolhe a caixa, placa, portão, gerador, relé ou recetor na lista. Cada cópia recebe um ID próprio e continua a ser uma cena real na árvore.
6. Escolhe origem e destino em **Ligações**. A lista de destinos mostra apenas canais compatíveis; as ligações aparecem sobre o tabuleiro e continuam validadas pelo catálogo.
7. Edita título, nota e objetivo, depois usa **Guardar** e **Validar**. `Ctrl+Z`/`Ctrl+Y` usa o histórico do próprio editor para alterações de mapa, peças e vínculo à campanha.
8. **Ligar mapa atual** guarda a cena e associa-a à fase selecionada. **Desligar** repõe WFC/agenda nessa fase. Mapas ligados substituem o mapa e a câmara especial agendada; a campanha continua a criar os inimigos, bosses dos andares correspondentes, recolhas e armadilhas normais. O catálogo guarda apenas as fases ligadas, sem criar 200 cenas vazias.
9. **Abrir mapa ligado** volta à cena dessa fase. **Testar no jogo** usa movimento, colisões e mecanismos reais, sem ler ou gravar o perfil da campanha; **R** reinicia a cena editada.

Também podes abrir `levels/editable_component_demo.tscn` para inspecionar e modificar o exemplo de três placas/portões e circuito. **Abrir catálogo de conteúdo** mostra os Resources de biomas, inimigos, bosses e poderes no Inspector.

### O que esta primeira oficina já cobre e o que falta

**Coberto:** escolher as 200 posições da campanha, criar/abrir mapa por fase, usar o WFC atual como base, guardar origem/seed no blueprint, ligar/desligar cenas ao catálogo real da campanha, importar os mecanismos para `EnvironmentSystem`, manter os spawns normais da campanha, editar as seis peças existentes, ligações, objetivo/título/nota, validar, desfazer/refazer e testar isoladamente.

**Ainda não coberto:** colocar inimigos/pickups/armadilhas/bosses manualmente no tabuleiro, editar os atores como cenas, produzir assets novos, mudar menus/economia/áudio/VFX ou provar solvabilidade de Sokoban. Um andar especial agendado é substituído quando recebe um mapa de campanha próprio; o boss/guardião que depende do número do andar continua no fluxo normal. O catálogo de conteúdo abre Resources existentes, não cria arte nova.

O WFC nesta tela compõe paredes/salas com o mesmo gerador e recursos da campanha. O resultado passa a ser uma cena estática editável; a campanha não volta a colapsar esse mapa durante o jogo. A validação do blueprint comprova limites, ligação entre início e portal ignorando mecanismos, IDs e canais; não prova que um puzzle seja justo ou divertido.

## Abrir e editar os Resources atuais

1. Abre `project.godot` no Godot 4.7.2 e deixa a importação terminar.
2. No painel **FileSystem**, abre `content/game_content_catalog.tres`.
3. No **Inspector**, expande `biomes`, `bosses` ou `powerups`. Seleciona a entrada para abrir o seu Resource e ver os campos.
4. Os Resources individuais estão em `content/definitions/`. Alterações aos valores guardam-se no respetivo `.tres`.

### O que cada definição controla agora

- **Bioma:** `display_name`, `initial_size`, `wfc_tile_set` e `room_profile`; crescimento de campanha no próprio catálogo. Os cinco biomas ainda apontam para `components/wfc_default_tile_set.tres`, mas podem receber conjuntos diferentes pelo Inspector. Os perfis de sala estão em `content/definitions/room_profile_*.tres`.
- **Chefe:** ID, nome, resumo da regra, textura, cor, escala, perfil de movimento e vida. Os seis perfis existentes são selecionáveis no Inspector. Alterar números e arte não cria um comportamento novo; perfis novos ainda precisam de regra e testes no código.
- **Inimigo comum:** perfil de movimento, escala, duração da transição de casa e halo de chão/alerta para caçador, sentinela, espectro, investida, patrulha e reflexo. A silhueta ainda é desenhada por código; o Resource não instancia uma cena do inimigo.
- **Poder:** ID, nome, cor e duração em turnos. Blink usa cargas, por isso a duração é zero. O tipo de efeito continua a corresponder a uma regra já implementada.

O catálogo é lido pelo jogo. A ordem dos biomas afeta a sequência de andares, a ordem dos poderes a rotação dos pickups e os chefes entram a cada cinco andares. Antes de mudar essas ordens, confirma as consequências para campanha, saves e testes.

O `wfc_tile_set` do bioma deve ser um Resource com `build_tables()` válido e os 16 IDs de passagem. O jogo passa essa referência ao gerador. Neste momento, cada TileSet define máscaras de passagem e pesos; trocar isso altera mapas gerados. Os TileSets ainda não criam cenas de chão, objetos ou mecanismos por célula.

O `room_profile` define quantidade e dimensão de salas, largura de ligações, probabilidade de rotas extra e, no Trono do Guardião, o layout de arena. Os cinco Resources mantêm os parâmetros da versão anterior. Um perfil inválido é rejeitado pela validação do catálogo antes da geração.

## Editar mecanismos e ligações numa sala

Abre `levels/editable_component_demo.tscn`. Cada caixa, placa, portão, gerador, relé e recetor é uma instância que pode ser selecionada na árvore. `component_id` identifica a cópia, `cell` define a casa e `output_ids` aponta para os destinos concretos daquela instância. Podes repetir uma mesma cena muitas vezes e ligar cada cópia a um portão diferente.

Ao duplicar uma instância, dá um ID único. Cada destino deve existir, e os canais de entrada/saída têm de corresponder. A validação do blueprint apanha referências inexistentes ou duplicadas antes de compilar a sala. Guarda cópias de trabalho como uma cena nova em `levels/` para não alterar o exemplo original.

O catálogo de cenas e canais está em `components/component_catalog.tres`; as regras de ocupação/ativação permanecem no `EnvironmentSystem`. Criar uma aparência ou Resource novo não cria automaticamente uma regra de gameplay.

## Limites atuais

Personagens, muitos inimigos, pickups comuns, o desenho do tabuleiro, HUD/menus e alguns parâmetros de combate ainda são desenhados ou montados por `game.gd`/`hud.gd`. Biomas selecionam o TileSet e o perfil de salas, mas o WFC ainda não usa a biblioteca completa de definições funcionais dos blueprints nem instancia cenas funcionais por célula. Essas são migrações pendentes, não opções que este guia promete já editar no Inspector.
