# Revisão visual — evidências para avaliação

Estas capturas foram produzidas pelo renderer do jogo em Godot Web 4.7.2 / Chromium / WebGL2 com SwiftShader, em 1280 × 720 e 800 × 540. **São estados preparados, não gravações de uma partida nem aprovação artística.** Podem conter pistas e estados avançados da instalação.

- `01`–`03`: câmara de duas placas; portão na parede vertical, fechado, em transição e aberto.
- `04`: placa pressionada isolada para inspeção. **Diagnóstico artificial:** a placa está ativa sem caixa em cima; esse não é um estado normal das regras.
- `05`, `09` e `10`: gerador e portas na parede horizontal, incluindo uma transição e a abertura.
- `06`–`08`: encaixe vazio, gerador instalado e aviso de água eletrificada. O estado e a posição do jogador foram preparados para a captura; não representam um percurso jogado.
- `11`: placa de energia do modelo de câmara de circuito, em estado preparado.
- `12` (apenas 800 × 540): final de um percurso automatizado de 198 ações de teclado no projeto normal, separado da cena de captura. A rota terminou sem erros de consola, mas é apenas um percurso possível.
- `13` (apenas 800 × 540): na prévia interativa, as duas placas foram alcançadas por nove ações de teclado e o portão abriu; a execução não registou erros de consola.

A cena `tools/mechanism_visual_fixture.tscn` reproduz os mesmos estados e desliga persistência e áudio. Por exemplo, com Godot 4.7.2 e um backend gráfico real (não `--headless`):

```sh
mkdir -p /tmp/ctm-capturas
MECHANISM_FIXTURE_OUT=/tmp/ctm-capturas godot --path . res://tools/mechanism_visual_fixture.tscn
```

Sem `MECHANISM_FIXTURE_OUT`, a cena imprime os PNGs como base64 na consola para recolha no Web. Encerra automaticamente após as capturas. As dimensões, o dispositivo e o renderer podem alterar o resultado. O teste de geometria automatizado verifica eixos e superfícies quadradas; só uma avaliação humana pode julgar clareza, integração estética e sensação de jogo.
