/* ═══════════════════════════════════════════════════════════════════════
   COME TO ME: NEON RUINS — OFICINA PRO ENGINE
   Editor Tático de Fases Futurista (Blender / Photoshop Style)
   ═══════════════════════════════════════════════════════════════════════ */

(() => {
  'use strict';

  // Utilitário de captura de elemento
  const $ = (id) => document.getElementById(id);

  // ─── DEFINIÇÕES DE ASSETS E GLIFOS ───
  const NAMES = {
    hunter: "Caçador Tático", sentry: "Sentinela Laser", wisp: "Espectro Furtivo",
    rusher: "Investida Veloz", patrol: "Patrulheiro de Rota", mirror: "Reflexo Quântico", warden: "Guardião Blindado",
    "boss/pawn": "Boss Peão Alfa", "boss/rook": "Boss Torre Fortaleza", "boss/knight": "Boss Cavalo Quântico",
    "boss/bishop": "Boss Bispo Diagonal", "boss/queen": "Boss Dama Suprema", "boss/king": "Boss Rei Soberano",
    coin: "Célula de Energia", shield: "Barreira de Escudo", breaker: "Ruptor de Paredes", heart: "Coração Vital",
    "powerup/blink": "Módulo Salto / Blink", "powerup/magnet": "Módulo Íman",
    "powerup/speed": "Módulo Sobrecarga", "powerup/time_freeze": "Módulo Congelar Tempo",
    crate: "Caixa Móvel", pressure_plate: "Placa de Pressão", gate: "Portão Eletromagnético",
    power_source: "Gerador de Plasma", circuit_relay: "Relé de Circuito", circuit_receiver: "Receptor Quântico"
  };

  const SHORT_NAMES = {
    hunter: "Caçador", sentry: "Sentinela", wisp: "Espectro", rusher: "Investida",
    patrol: "Patrulha", mirror: "Reflexo", warden: "Guardião",
    "boss/pawn": "Boss Peão", "boss/rook": "Boss Torre", "boss/knight": "Boss Cavalo",
    "boss/bishop": "Boss Bispo", "boss/queen": "Boss Dama", "boss/king": "Boss Rei",
    coin: "Moeda", shield: "Escudo", breaker: "Ruptor", heart: "Coração",
    "powerup/blink": "Salto", "powerup/magnet": "Íman", "powerup/speed": "Velocidade",
    "powerup/time_freeze": "Congelar",
    crate: "Caixa", pressure_plate: "Placa", gate: "Portão",
    power_source: "Gerador", circuit_relay: "Relé", circuit_receiver: "Receptor"
  };

  const GLYPHS = {
    hunter: "C", sentry: "S", wisp: "E", rusher: "I", patrol: "P", mirror: "R", warden: "G",
    "boss/pawn": "♟", "boss/rook": "♜", "boss/knight": "♞", "boss/bishop": "♝", "boss/queen": "♛", "boss/king": "♚",
    coin: "◉", shield: "⬡", breaker: "⚡", heart: "♥",
    "powerup/blink": "↗", "powerup/magnet": "∩", "powerup/speed": "»", "powerup/time_freeze": "✦",
    crate: "▣", pressure_plate: "⊙", gate: "▥", power_source: "ϟ", circuit_relay: "↗", circuit_receiver: "◎"
  };

  const PIECE_CATEGORIES = {
    enemy: [
      "hunter", "sentry", "wisp", "rusher", "patrol", "mirror", "warden",
      "boss/pawn", "boss/rook", "boss/knight", "boss/bishop", "boss/queen", "boss/king"
    ],
    pickup: [
      "coin", "shield", "breaker", "heart",
      "powerup/blink", "powerup/magnet", "powerup/speed", "powerup/time_freeze"
    ],
    mechanism: [
      "crate", "pressure_plate", "gate", "power_source", "circuit_relay", "circuit_receiver"
    ]
  };

  // ─── ESTADO GLOBAL DO EDITOR ───
  const state = {
    map: null,
    floor: 1,
    source: "",
    saved: false,
    dirty: false,
    tool: "select",          // select, wall, boxwall, flood, erase, start, portal, link, place
    category: "enemy",
    piece: "hunter",
    mirrorH: false,
    selected: null,          // { group: 'entity'|'mechanism'|'start'|'portal'|'wall', index?, point? }
    linkStart: null,
    zoom: 1.0,
    pan: { x: 0, y: 0 },
    geom: null,
    pointer: null,
    hoverCell: null,
    boxDrag: null,           // { start: [x,y], current: [x,y] }
    painting: false,
    painted: new Set(),
    undo: [],
    redo: [],
    showGrid: true,
    animFrame: null,
    particlePhase: 0,
    routeStatus: "unknown"   // 'valid' | 'blocked'
  };

  const canvas = $("map-canvas");
  const ctx = canvas.getContext("2d");
  const miniCanvas = $("minimap-canvas");
  const miniCtx = miniCanvas ? miniCanvas.getContext("2d") : null;

  let toastTimer = null;

  // ─── FEEDBACK VISUAL & NOTIFICAÇÕES ───
  function showToast(text, isError = false, icon = "⚡") {
    const el = $("toast");
    if (!el) return;
    $("toast-text").textContent = text;
    $("toast-icon").textContent = icon;
    el.classList.toggle("error", isError);
    el.classList.add("show");
    
    const meter = $("toast-meter");
    if (meter) {
      meter.style.transition = 'none';
      meter.style.width = '100%';
      setTimeout(() => {
        meter.style.transition = 'width 2.8s linear';
        meter.style.width = '0%';
      }, 20);
    }

    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove("show"), 3000);
  }

  function setStatus(text, ok = true) {
    const sText = $("status-text");
    const sDot = $("status-dot");
    if (sText) sText.textContent = text;
    if (sDot) {
      sDot.style.background = ok ? "var(--neon-teal)" : "var(--neon-red)";
      sDot.style.boxShadow = ok ? "0 0 8px var(--neon-teal)" : "0 0 8px var(--neon-red)";
    }
  }

  function markDirty() {
    state.dirty = true;
    const badge = $("saved-state");
    if (badge) {
      badge.className = "sync-indicator dirty";
      badge.querySelector(".sync-text").textContent = "Modificações por salvar";
    }
    checkRouteConnectivity();
  }

  function setSaved(label = "Sincronizado no jogo") {
    state.dirty = false;
    state.saved = true;
    const badge = $("saved-state");
    if (badge) {
      badge.className = "sync-indicator";
      badge.querySelector(".sync-text").textContent = label;
    }
  }

  // ─── SISTEMA DE UNDO / REDO ───
  function snapshot() {
    state.undo.push(JSON.stringify(state.map));
    if (state.undo.length > 90) state.undo.shift();
    state.redo.length = 0;
    updateHistoryButtons();
  }

  function undo() {
    if (!state.undo.length) return;
    state.redo.push(JSON.stringify(state.map));
    state.map = JSON.parse(state.undo.pop());
    state.selected = null;
    state.linkStart = null;
    markDirty();
    render();
    updateHistoryButtons();
    setStatus("Ação desfeita com sucesso.");
  }

  function redo() {
    if (!state.redo.length) return;
    state.undo.push(JSON.stringify(state.map));
    state.map = JSON.parse(state.redo.pop());
    state.selected = null;
    state.linkStart = null;
    markDirty();
    render();
    updateHistoryButtons();
    setStatus("Ação reaplicada com sucesso.");
  }

  function updateHistoryButtons() {
    if ($("undo-btn")) $("undo-btn").disabled = !state.undo.length;
    if ($("redo-btn")) $("redo-btn").disabled = !state.redo.length;
  }

  // ─── COMUNICAÇÃO COM O SERVIDOR (API) ───
  async function api(path, body = null) {
    const res = await fetch(path, {
      method: body ? "POST" : "GET",
      headers: body ? { "Content-Type": "application/json" } : {},
      body: body ? JSON.stringify(body) : undefined
    });
    const data = await res.json();
    if (!res.ok || data.ok === false) {
      const errList = data.errors || [data.error || "Operação recusada pelo servidor."];
      throw new Error(errList.join("\n"));
    }
    return data;
  }

  function syncFields() {
    if (!state.map) return;
    const nameEl = $("map-name");
    const hintEl = $("map-hint");
    const objEl = $("objective");
    const authEl = $("authoritative");
    
    if (nameEl) state.map.name = nameEl.value.trim() || `Fase ${String(state.floor).padStart(3, "0")}`;
    if (hintEl) state.map.hint = hintEl.value;
    if (objEl) state.map.objective = objEl.value;
    if (authEl) state.map.authoritative_spawns = authEl.checked;
  }

  // ─── CARREGAMENTO DE FASE ───
  function loadMap(data, source, saved = false) {
    state.map = data;
    state.floor = Number(data.floor) || 1;
    state.source = source;
    state.saved = saved;
    state.undo = [];
    state.redo = [];
    state.selected = null;
    state.linkStart = null;
    state.zoom = 1.0;
    state.pan = { x: 0, y: 0 };
    state.dirty = false;

    // Sincronizar inputs da interface
    if ($("floor")) $("floor").value = state.floor;
    if ($("map-name")) $("map-name").value = data.name || `Fase ${String(state.floor).padStart(3, "0")}`;
    if ($("map-hint")) $("map-hint").value = data.hint || "";
    if ($("objective")) $("objective").value = data.objective || "escape";
    if ($("authoritative")) $("authoritative").checked = !!data.authoritative_spawns;
    if ($("width-input")) $("width-input").value = data.width;
    if ($("height-input")) $("height-input").value = data.height;
    if ($("stage-title")) $("stage-title").textContent = data.name || `Fase ${String(state.floor).padStart(3, "0")}`;
    if ($("stage-source")) $("stage-source").textContent = `ORIGEM: ${source.toUpperCase()}`;

    setSaved(saved ? "Sincronizado no jogo" : "Mapa novo em rascunho");
    setStatus(`${source} carregado. Selecione ferramentas para editar.`);
    
    setTool("select");
    setCategory("enemy");
    render();
    updateHistoryButtons();
    checkRouteConnectivity();
  }

  async function loadFloor(floor) {
    if (state.dirty && !confirm("Existem alterações não gravadas nesta fase. Deseja descartar e carregar outra fase?")) {
      if ($("floor")) $("floor").value = state.floor;
      return;
    }
    setStatus(`A carregar Fase ${String(floor).padStart(3, "0")}…`);
    try {
      const result = await api(`/api/floor?id=${floor}`);
      loadMap(result.map, result.source, result.saved);
    } catch (e) {
      showToast(e.message, true);
      setStatus("Falha ao abrir a fase especificada.", false);
      if ($("floor")) $("floor").value = state.floor;
    }
  }

  // ─── CONTROLE DE FERRAMENTAS & CATEGORIAS ───
  function setTool(tool) {
    state.tool = tool;
    state.linkStart = null;
    state.boxDrag = null;

    document.querySelectorAll(".tool-cell").forEach(btn => {
      btn.classList.toggle("active", btn.dataset.tool === tool);
    });

    if (canvas) {
      if (tool === "select") canvas.style.cursor = "default";
      else if (tool === "wall" || tool === "boxwall") canvas.style.cursor = "crosshair";
      else if (tool === "erase") canvas.style.cursor = "not-allowed";
      else canvas.style.cursor = "cell";
    }

    if (tool === "place" && state.piece) {
      const pLabel = $("place-label");
      if (pLabel) pLabel.textContent = `Inserir ${SHORT_NAMES[state.piece] || state.piece}`;
    }
  }

  function setCategory(category) {
    state.category = category;
    document.querySelectorAll(".asset-tab").forEach(tab => {
      tab.classList.toggle("active", tab.dataset.category === category);
    });

    const box = $("piece-list");
    if (!box) return;
    box.replaceChildren();

    const currentList = PIECE_CATEGORIES[category] || [];
    if ($("piece-count")) $("piece-count").textContent = String(currentList.length);

    currentList.forEach(key => {
      const card = document.createElement("button");
      card.className = "asset-card" + (key === state.piece ? " active" : "");
      card.dataset.kind = category;
      card.dataset.key = key;

      const isBoss = key.startsWith("boss/");
      const count = countPieceInstances(key, category);

      card.innerHTML = `
        <div class="asset-thumb">${GLYPHS[key] || "•"}</div>
        <div class="asset-meta">
          <strong>${SHORT_NAMES[key] || key}</strong>
          <small>${count > 0 ? `No mapa: ${count}` : 'Clique para usar'}</small>
        </div>
        ${isBoss ? '<span class="boss-badge">BOSS</span>' : ''}
      `;

      card.onclick = () => {
        state.piece = key;
        setTool("place");
        box.querySelectorAll(".asset-card").forEach(c => c.classList.toggle("active", c === card));
        setStatus(`Peça selecionada: ${NAMES[key] || key}. Clique na grelha para posicionar.`);
      };

      box.append(card);
    });
  }

  function countPieceInstances(key, category) {
    if (!state.map) return 0;
    if (category === "enemy" || category === "pickup") {
      return state.map.entity_spawns.filter(e => e.subtype === key).length;
    }
    if (category === "mechanism") {
      return state.map.mechanisms.filter(m => m.kind === key).length;
    }
    return 0;
  }

  // ─── VERIFICAÇÃO TÁTICA DE CONECTIVIDADE (ROTA EM TEMPO REAL) ───
  function checkRouteConnectivity() {
    if (!state.map) return;
    const m = state.map;
    const start = m.start;
    const portal = m.portal;

    // BFS na grelha
    const queue = [start];
    const visited = new Set();
    visited.add(`${start[0]},${start[1]}`);

    const wallSet = new Set(m.walls.map(w => `${w[0]},${w[1]}`));
    let reached = false;

    while (queue.length > 0) {
      const [cx, cy] = queue.shift();
      if (cx === portal[0] && cy === portal[1]) {
        reached = true;
        break;
      }

      const dirs = [[0, 1], [0, -1], [1, 0], [-1, 0]];
      for (const [dx, dy] of dirs) {
        const nx = cx + dx;
        const ny = cy + dy;
        const key = `${nx},${ny}`;

        if (nx > 0 && ny > 0 && nx < m.width - 1 && ny < m.height - 1) {
          if (!wallSet.has(key) && !visited.has(key)) {
            visited.add(key);
            queue.push([nx, ny]);
          }
        }
      }
    }

    const routeInd = $("route-indicator");
    const routeStatus = $("route-status");
    if (routeInd && routeStatus) {
      if (reached) {
        routeInd.className = "stat-pill route-pill";
        routeStatus.textContent = "✓ Rota Acessível";
        routeStatus.style.color = "var(--neon-teal)";
      } else {
        routeInd.className = "stat-pill route-pill";
        routeStatus.textContent = "⚠ Portal Inacessível";
        routeStatus.style.color = "var(--neon-red)";
      }
    }
  }

  // ─── MATEMÁTICA E COORDENADAS ───
  function arrEq(a, b) {
    return !!a && !!b && a[0] === b[0] && a[1] === b[1];
  }

  function walkable(p) {
    return p && p[0] > 0 && p[1] > 0 && p[0] < state.map.width - 1 && p[1] < state.map.height - 1;
  }

  function occupied(p, ignore = null) {
    if (!walkable(p)) return true;
    if (state.map.walls.some(w => arrEq(w, p))) return true;
    if (arrEq(state.map.start, p) && ignore !== "start") return true;
    if (arrEq(state.map.portal, p) && ignore !== "portal") return true;

    for (const e of state.map.entity_spawns) {
      if (arrEq(e.cell, p) && !(ignore?.group === "entity" && state.map.entity_spawns[ignore.index] === e)) return true;
    }
    for (const m of state.map.mechanisms) {
      if (arrEq(m.cell, p) && !(ignore?.group === "mechanism" && state.map.mechanisms[ignore.index] === m)) return true;
    }
    return false;
  }

  function keyAt(point) {
    if (!point || !state.map) return null;
    if (arrEq(state.map.start, point)) return { group: "start" };
    if (arrEq(state.map.portal, point)) return { group: "portal" };

    const mi = state.map.mechanisms.findIndex(o => arrEq(o.cell, point));
    if (mi >= 0) return { group: "mechanism", index: mi };

    const ei = state.map.entity_spawns.findIndex(o => arrEq(o.cell, point));
    if (ei >= 0) return { group: "entity", index: ei };

    if (state.map.walls.some(p => arrEq(p, point))) return { group: "wall", point };
    return null;
  }

  function selectedObject() {
    const s = state.selected;
    if (!s || !state.map) return null;
    if (s.group === "entity") return state.map.entity_spawns[s.index] || null;
    if (s.group === "mechanism") return state.map.mechanisms[s.index] || null;
    if (s.group === "start") return { kind: "start", cell: state.map.start };
    if (s.group === "portal") return { kind: "portal", cell: state.map.portal };
    return null;
  }

  function cellFromEvent(e) {
    const rect = canvas.getBoundingClientRect();
    const g = state.geom;
    if (!g) return null;

    const x = Math.floor((e.clientX - rect.left - g.ox) / g.cell);
    const y = Math.floor((e.clientY - rect.top - g.oy) / g.cell);

    if (x < 0 || y < 0 || x >= state.map.width || y >= state.map.height) {
      state.hoverCell = null;
      return null;
    }

    state.hoverCell = [x, y];
    
    // Atualizar HUD flutuante
    const coordEl = $("coordinates");
    const cellTypeEl = $("cell-type");
    if (coordEl) {
      coordEl.querySelector(".coord-val").textContent = `COL ${String(x).padStart(2, "0")} · LIN ${String(y).padStart(2, "0")}`;
    }
    if (cellTypeEl) {
      const hit = keyAt([x, y]);
      if (hit) {
        if (hit.group === "wall") cellTypeEl.textContent = "[PAREDE]";
        else if (hit.group === "start") cellTypeEl.textContent = "[INÍCIO JOGADOR]";
        else if (hit.group === "portal") cellTypeEl.textContent = "[PORTAL QUÂNTICO]";
        else if (hit.group === "entity") cellTypeEl.textContent = `[${SHORT_NAMES[state.map.entity_spawns[hit.index].subtype] || "AMEAÇA"}]`;
        else if (hit.group === "mechanism") cellTypeEl.textContent = `[${SHORT_NAMES[state.map.mechanisms[hit.index].kind] || "MECANISMO"}]`;
      } else {
        cellTypeEl.textContent = x === 0 || y === 0 || x === state.map.width - 1 || y === state.map.height - 1 ? "[BORDA]" : "[CHÃO VAZIO]";
      }
    }

    return [x, y];
  }

  // ─── APLICAÇÃO DE FERRAMENTAS ───
  function applyAt(point) {
    if (!point || !state.map) return;
    const t = state.tool;
    const m = state.map;

    // 1. Modo Selecionar
    if (t === "select") {
      const hit = keyAt(point);
      state.selected = hit && hit.group !== "wall" ? hit : null;
      drawInspector();
      render();
      if (hit?.group === "wall") {
        setStatus(`Parede em (${point[0]}, ${point[1]}). Use a Borracha [E] para remover.`);
      }
      return;
    }

    // 2. Modo Parede (com suporte a simetria horizontal)
    if (t === "wall") {
      const pointsToProcess = [point];
      if (state.mirrorH) {
        const mirrorX = m.width - 1 - point[0];
        if (mirrorX !== point[0]) pointsToProcess.push([mirrorX, point[1]]);
      }

      pointsToProcess.forEach(pt => {
        const key = pt.join(",");
        if (state.painted.has(key)) return;
        state.painted.add(key);

        if (walkable(pt) && !occupied(pt)) {
          if (!m.walls.some(w => arrEq(w, pt))) {
            m.walls.push(pt);
            markDirty();
          }
        }
      });
      render();
      return;
    }

    // 3. Modo Borracha
    if (t === "erase") {
      const pointsToProcess = [point];
      if (state.mirrorH) {
        const mirrorX = m.width - 1 - point[0];
        if (mirrorX !== point[0]) pointsToProcess.push([mirrorX, point[1]]);
      }

      pointsToProcess.forEach(pt => {
        const key = pt.join(",");
        if (state.painted.has(key)) return;
        state.painted.add(key);

        // Remove paredes
        m.walls = m.walls.filter(w => !arrEq(w, pt));

        // Remove entidades
        m.entity_spawns = m.entity_spawns.filter(e => !arrEq(e.cell, pt));

        // Remove mecanismos e fios
        const killedMechs = m.mechanisms.filter(o => arrEq(o.cell, pt));
        const killedIds = new Set(killedMechs.map(o => o.id));
        m.mechanisms = m.mechanisms.filter(o => !arrEq(o.cell, pt));
        m.mechanisms.forEach(mech => {
          mech.outputs = (mech.outputs || []).filter(id => !killedIds.has(id));
        });

        markDirty();
      });
      render();
      return;
    }

    // 4. Início ou Portal
    if (t === "start" || t === "portal") {
      if (occupied(point, t)) {
        showToast("Escolha uma casa livre desocupada.", true);
        return;
      }
      snapshot();
      m[t] = point;
      state.selected = { group: t };
      markDirty();
      render();
      setStatus(t === "start" ? "Posição de partida de Lia atualizada." : "Portal de saída reposicionado.");
      return;
    }

    // 5. Inserir Peça / Asset
    if (t === "place") {
      if (occupied(point)) {
        showToast("Esta casa já está ocupada.", true);
        return;
      }
      snapshot();

      if (state.category === "enemy" || state.category === "pickup") {
        m.entity_spawns.push({
          kind: state.category,
          subtype: state.piece,
          cell: point
        });
        state.selected = { group: "entity", index: m.entity_spawns.length - 1 };
      } else {
        let suffix = 1;
        let id;
        do {
          id = `${state.piece}_${suffix++}`;
        } while (m.mechanisms.some(mech => mech.id === id));

        const obj = {
          kind: state.piece,
          id,
          cell: point,
          outputs: []
        };

        if (obj.kind === "crate") obj.material = "wood";
        if (obj.kind === "pressure_plate") obj.required = "any";
        if (obj.kind === "gate") { obj.input_mode = "all"; obj.open = false; }
        if (obj.kind === "power_source") obj.active = true;

        m.mechanisms.push(obj);
        state.selected = { group: "mechanism", index: m.mechanisms.length - 1 };
      }

      markDirty();
      render();
      setStatus(`${SHORT_NAMES[state.piece] || state.piece} implantado em (${point[0]}, ${point[1]}).`);
      setCategory(state.category); // Atualiza contadores
      return;
    }

    // 6. Ligar Fios Elétricos
    if (t === "link") {
      const hit = keyAt(point);
      if (hit?.group !== "mechanism") {
        showToast("Clique num mecanismo (placa, gerador, portão ou relé) para conectar.", true);
        return;
      }

      const item = m.mechanisms[hit.index];
      if (!state.linkStart) {
        state.linkStart = item.id;
        state.selected = hit;
        setStatus(`Origem selecionada: [${item.id}]. Clique no mecanismo de destino.`);
        render();
        return;
      }

      if (state.linkStart === item.id) {
        state.linkStart = null;
        setStatus("Origem desmarcada. Selecione outro mecanismo.");
        render();
        return;
      }

      const source = m.mechanisms.find(o => o.id === state.linkStart);
      if (source) {
        snapshot();
        source.outputs = source.outputs || [];
        if (source.outputs.includes(item.id)) {
          source.outputs = source.outputs.filter(id => id !== item.id);
          setStatus(`Conexão removida entre [${source.id}] e [${item.id}].`);
        } else {
          source.outputs.push(item.id);
          setStatus(`Circuito elétrico ligado: [${source.id}] ➔ [${item.id}].`);
        }
        markDirty();
        state.linkStart = null;
        render();
      }
    }
  }

  // ─── FERRAMENTA SMART: BOX WALL (SALA COMPLETA) ───
  function applyBoxWall(start, end) {
    if (!start || !end || !state.map) return;
    snapshot();
    const minX = Math.max(1, Math.min(start[0], end[0]));
    const maxX = Math.min(state.map.width - 2, Math.max(start[0], end[0]));
    const minY = Math.max(1, Math.min(start[1], end[1]));
    const maxY = Math.min(state.map.height - 2, Math.max(start[1], end[1]));

    for (let x = minX; x <= maxX; x++) {
      for (let y = minY; y <= maxY; y++) {
        // Apenas contorno da caixa
        if (x === minX || x === maxX || y === minY || y === maxY) {
          const pt = [x, y];
          if (!occupied(pt) && !state.map.walls.some(w => arrEq(w, pt))) {
            state.map.walls.push(pt);
          }
        }
      }
    }
    markDirty();
    render();
    setStatus(`Sala retangular erguida entre (${minX},${minY}) e (${maxX},${maxY}).`);
  }

  // ─── FERRAMENTA SMART: FLOOD FILL (BALDE DE PREENCHIMENTO) ───
  function applyFloodFill(start) {
    if (!walkable(start) || !state.map) return;
    if (state.map.walls.some(w => arrEq(w, start))) return;

    snapshot();
    const m = state.map;
    const queue = [start];
    const visited = new Set();
    visited.add(`${start[0]},${start[1]}`);

    while (queue.length > 0) {
      const [cx, cy] = queue.shift();
      const pt = [cx, cy];

      if (!occupied(pt) && !m.walls.some(w => arrEq(w, pt))) {
        m.walls.push(pt);
      }

      const dirs = [[0, 1], [0, -1], [1, 0], [-1, 0]];
      for (const [dx, dy] of dirs) {
        const nx = cx + dx;
        const ny = cy + dy;
        const key = `${nx},${ny}`;

        if (nx > 0 && ny > 0 && nx < m.width - 1 && ny < m.height - 1) {
          if (!visited.has(key) && !m.walls.some(w => arrEq(w, [nx, ny]))) {
            visited.add(key);
            queue.push([nx, ny]);
          }
        }
      }
    }

    markDirty();
    render();
    setStatus("Área conectada preenchida com paredes.");
  }

  // ─── EVENTOS DE PONTEIRO / MOUSE NO CANVAS ───
  function onPointerDown(e) {
    // Botão do meio ou direito = Pan da câmera
    if (e.button === 1 || e.button === 2) {
      state.pointer = { pan: true, x: e.clientX, y: e.clientY, orig: { ...state.pan } };
      canvas.setPointerCapture(e.pointerId);
      e.preventDefault();
      return;
    }

    const p = cellFromEvent(e);
    if (!p) return;

    state.pointer = { cell: p, drag: false, x: e.clientX, y: e.clientY };

    if (state.tool === "boxwall") {
      state.boxDrag = { start: p, current: p };
      canvas.setPointerCapture(e.pointerId);
      return;
    }

    if (state.tool === "flood") {
      applyFloodFill(p);
      return;
    }

    if (state.tool === "wall" || state.tool === "erase") {
      snapshot();
      state.painting = true;
      state.painted.clear();
      applyAt(p);
      canvas.setPointerCapture(e.pointerId);
    } else if (state.tool === "select") {
      const hit = keyAt(p);
      if (hit && hit.group !== "wall") {
        state.selected = hit;
        state.pointer.dragTarget = hit;
        drawInspector();
        render();
        canvas.setPointerCapture(e.pointerId);
      } else {
        applyAt(p);
      }
    } else {
      applyAt(p);
    }
  }

  function onPointerMove(e) {
    if (!state.pointer) {
      cellFromEvent(e);
      render();
      return;
    }

    // Arrastando a tela (Pan)
    if (state.pointer.pan) {
      state.pan.x = state.pointer.orig.x + e.clientX - state.pointer.x;
      state.pan.y = state.pointer.orig.y + e.clientY - state.pointer.y;
      render();
      return;
    }

    const p = cellFromEvent(e);
    if (state.tool === "boxwall" && state.boxDrag && p) {
      state.boxDrag.current = p;
      render();
      return;
    }

    if (state.painting && p) {
      applyAt(p);
      return;
    }

    // Drag and Drop de entidade selecionada
    if (state.pointer.dragTarget && Math.hypot(e.clientX - state.pointer.x, e.clientY - state.pointer.y) > 6) {
      state.pointer.drag = true;
    }
    render();
  }

  function onPointerUp(e) {
    if (state.tool === "boxwall" && state.boxDrag) {
      applyBoxWall(state.boxDrag.start, state.boxDrag.current);
      state.boxDrag = null;
    }

    if (state.painting) {
      state.painting = false;
      state.painted.clear();
    }

    if (state.pointer?.drag) {
      const p = cellFromEvent(e);
      if (p && canMoveSelected(p)) {
        moveSelected(p);
      }
    }

    state.pointer = null;
    render();
  }

  function canMoveSelected(p) {
    if (!state.selected || !walkable(p)) return false;
    return !occupied(p, state.selected);
  }

  function moveSelected(p) {
    const s = state.selected;
    if (!s || !canMoveSelected(p)) return;

    snapshot();
    if (s.group === "start") state.map.start = p;
    else if (s.group === "portal") state.map.portal = p;
    else if (s.group === "entity") state.map.entity_spawns[s.index].cell = p;
    else if (s.group === "mechanism") state.map.mechanisms[s.index].cell = p;

    markDirty();
    render();
    setStatus(`Objeto reposicionado para (${p[0]}, ${p[1]}).`);
  }

  function removeSelected() {
    const s = state.selected;
    if (!s || s.group === "start" || s.group === "portal") return;

    snapshot();
    if (s.group === "entity") {
      state.map.entity_spawns.splice(s.index, 1);
    } else if (s.group === "mechanism") {
      const killId = state.map.mechanisms[s.index]?.id;
      state.map.mechanisms.splice(s.index, 1);
      state.map.mechanisms.forEach(m => {
        m.outputs = (m.outputs || []).filter(id => id !== killId);
      });
    }

    state.selected = null;
    markDirty();
    render();
    drawInspector();
    setCategory(state.category);
    setStatus("Objeto removido do tabuleiro.");
  }

  // ─── RENDERIZADOR HOLOGRÁFICO SCI-FI (CANVAS) ───
  function render() {
    if (!state.map || !ctx) return;

    const ratio = window.devicePixelRatio || 1;
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    if (w < 1 || h < 1) return;

    if (canvas.width !== Math.round(w * ratio) || canvas.height !== Math.round(h * ratio)) {
      canvas.width = Math.round(w * ratio);
      canvas.height = Math.round(h * ratio);
    }

    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    ctx.clearRect(0, 0, w, h);

    const m = state.map;
    const baseCell = Math.floor(Math.min((w - 50) / m.width, (h - 50) / m.height));
    const cell = Math.max(16, baseCell * state.zoom);
    const ox = (w - m.width * cell) / 2 + state.pan.x;
    const oy = (h - m.height * cell) / 2 + state.pan.y;

    state.geom = { cell, ox, oy, w, h };

    // Sincronizar HUD labels
    if ($("zoom-label")) $("zoom-label").textContent = `${Math.round(state.zoom * 100)}%`;
    if ($("map-size")) $("map-size").textContent = `${m.width} × ${m.height}`;
    if ($("size-button-label")) $("size-button-label").textContent = `${m.width} × ${m.height} Casas`;
    if ($("stage-title")) $("stage-title").textContent = m.name || `Fase ${String(state.floor).padStart(3, "0")}`;

    const totalPieces = m.entity_spawns.length + m.mechanisms.length;
    if ($("object-total")) $("object-total").textContent = String(totalPieces + 2);
    if ($("list-total")) $("list-total").textContent = String(totalPieces + 2);

    // 1. Grid e Células
    for (let y = 0; y < m.height; y++) {
      for (let x = 0; x < m.width; x++) {
        const isWall = m.walls.some(p => arrEq(p, [x, y]));
        drawCyberCell(x, y, ox, oy, cell, isWall);
      }
    }

    // 2. Fios de Mecanismos com Pulso de Energia
    m.mechanisms.forEach(source => {
      (source.outputs || []).forEach(targetId => {
        const target = m.mechanisms.find(t => t.id === targetId);
        if (target) {
          drawLaserWire(source.cell, target.cell, ox, oy, cell);
        }
      });
    });

    // 3. Mecanismos
    m.mechanisms.forEach((mech, i) => {
      const isSel = state.selected?.group === "mechanism" && state.selected.index === i;
      drawMechanismPiece(mech, ox, oy, cell, isSel);
    });

    // 4. Entidades (Inimigos, Recolhas)
    m.entity_spawns.forEach((ent, i) => {
      const isSel = state.selected?.group === "entity" && state.selected.index === i;
      drawEntityPiece(ent, ox, oy, cell, isSel);
    });

    // 5. Início do Jogador (Lia Orb) & Portal Quântico
    drawStartBeacon(m.start, ox, oy, cell, state.selected?.group === "start");
    drawQuantumPortal(m.portal, ox, oy, cell, state.selected?.group === "portal");

    // 6. Ghost Preview sob o Cursor
    if (state.hoverCell && !state.pointer?.drag) {
      drawGhostPreview(state.hoverCell, ox, oy, cell);
    }

    // 7. Preview da Ferramenta BoxWall
    if (state.boxDrag) {
      drawBoxWallPreview(state.boxDrag.start, state.boxDrag.current, ox, oy, cell);
    }

    // 8. Linha de Simetria Visual (se ativada)
    if (state.mirrorH) {
      drawSymmetryAxis(ox, oy, cell, m.width, m.height);
    }

    // 9. Atualizar Minimap
    renderMinimap();

    // 10. Atualizar Outliner
    drawOutliner();
  }

  // Desenho de Célula Futurista
  function drawCyberCell(x, y, ox, oy, s, isWall) {
    const px = ox + x * s;
    const py = oy + y * s;
    const isEdge = x === 0 || y === 0 || x === state.map.width - 1 || y === state.map.height - 1;

    if (isEdge) {
      // Borda Indestrutível
      ctx.fillStyle = "#070b14";
      ctx.fillRect(px, py, s, s);

      // Padrão de aviso laser
      ctx.strokeStyle = "rgba(48, 70, 110, 0.4)";
      ctx.lineWidth = 1;
      ctx.strokeRect(px + 0.5, py + 0.5, s - 1, s - 1);

      ctx.fillStyle = "rgba(0, 245, 212, 0.05)";
      ctx.fillRect(px + 2, py + 2, s - 4, s - 4);
      return;
    }

    // Chão Tático
    const alt = (x + y) % 2 === 0;
    ctx.fillStyle = alt ? "#0d1424" : "#090f1d";
    ctx.fillRect(px, py, s, s);

    // Grelha Sci-Fi
    if (state.showGrid) {
      ctx.strokeStyle = "rgba(34, 50, 78, 0.6)";
      ctx.lineWidth = 0.8;
      ctx.strokeRect(px + 0.5, py + 0.5, s - 1, s - 1);

      // Pontos milimétricos nas junções
      if (s > 24) {
        ctx.fillStyle = "rgba(0, 245, 212, 0.2)";
        ctx.fillRect(px, py, 1.5, 1.5);
      }
    }

    // Parede Volumétrica 3D
    if (isWall) {
      const pad = Math.max(2, s * 0.08);
      const wSize = s - pad * 2;
      
      // Sombra inferior
      ctx.fillStyle = "rgba(0, 0, 0, 0.6)";
      ctx.fillRect(px + pad + 2, py + pad + 3, wSize, wSize);

      // Corpo da Parede
      const grad = ctx.createLinearGradient(px, py, px + s, py + s);
      grad.addColorStop(0, "#4a5d78");
      grad.addColorStop(0.3, "#2a374d");
      grad.addColorStop(1, "#182130");

      ctx.fillStyle = grad;
      roundRect(ctx, px + pad, py + pad, wSize, wSize, Math.max(3, s * 0.12));
      ctx.fill();

      // Top Highlight Laser
      ctx.strokeStyle = "rgba(141, 162, 192, 0.6)";
      ctx.lineWidth = 1;
      ctx.stroke();

      // Linha de luz interna neon
      if (s > 26) {
        ctx.strokeStyle = "rgba(0, 245, 212, 0.4)";
        ctx.beginPath();
        ctx.moveTo(px + pad + 4, py + pad + 3);
        ctx.lineTo(px + s - pad - 4, py + pad + 3);
        ctx.stroke();
      }
    }
  }

  // Início do Jogador: Lia (Orb Ciano Pulsante)
  function drawStartBeacon(pt, ox, oy, s, isSelected) {
    const cx = ox + (pt[0] + 0.5) * s;
    const cy = oy + (pt[1] + 0.5) * s;
    const r = s * 0.32;

    ctx.save();
    // Halo Glow
    ctx.shadowColor = "#00f5d4";
    ctx.shadowBlur = s * 0.3;

    // Núcleo Gradiente
    const grad = ctx.createRadialGradient(cx - r * 0.3, cy - r * 0.3, 1, cx, cy, r);
    grad.addColorStop(0, "#e0fffb");
    grad.addColorStop(0.3, "#00f5d4");
    grad.addColorStop(1, "#005f73");

    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fill();

    // Borda Brilhante
    ctx.shadowBlur = 0;
    ctx.strokeStyle = "#ffffff";
    ctx.lineWidth = Math.max(1.5, s * 0.05);
    ctx.stroke();

    // Olhos / Scanner de Lia
    ctx.fillStyle = "#03141f";
    ctx.beginPath();
    ctx.arc(cx - r * 0.28, cy - r * 0.1, r * 0.18, 0, Math.PI * 2);
    ctx.arc(cx + r * 0.28, cy - r * 0.1, r * 0.18, 0, Math.PI * 2);
    ctx.fill();

    // Destaque de Seleção
    if (isSelected) {
      drawSelectionRing(cx, cy, s * 0.45);
    }
    ctx.restore();
  }

  // Portal Quântico de Saída (Losango Violeta com Partículas)
  function drawQuantumPortal(pt, ox, oy, s, isSelected) {
    const cx = ox + (pt[0] + 0.5) * s;
    const cy = oy + (pt[1] + 0.5) * s;
    const r = s * 0.35;

    ctx.save();
    ctx.shadowColor = "#c77dff";
    ctx.shadowBlur = s * 0.35;

    // Losango Externo
    ctx.strokeStyle = "#c77dff";
    ctx.lineWidth = Math.max(2, s * 0.06);
    ctx.beginPath();
    ctx.moveTo(cx, cy - r);
    ctx.lineTo(cx + r, cy);
    ctx.lineTo(cx, cy + r);
    ctx.lineTo(cx - r, cy);
    ctx.closePath();
    ctx.stroke();

    // Núcleo Interno Giratório
    const innerR = r * 0.55;
    const angle = (state.particlePhase || 0) * 0.02;
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(angle);

    ctx.fillStyle = "rgba(199, 125, 255, 0.4)";
    ctx.beginPath();
    ctx.moveTo(0, -innerR);
    ctx.lineTo(innerR, 0);
    ctx.lineTo(0, innerR);
    ctx.lineTo(-innerR, 0);
    ctx.closePath();
    ctx.fill();

    ctx.strokeStyle = "#ffffff";
    ctx.lineWidth = 1.2;
    ctx.stroke();
    ctx.restore();

    if (isSelected) {
      drawSelectionRing(cx, cy, s * 0.46);
    }
    ctx.restore();
  }

  // Desenho de Inimigos e Recolhas
  function drawEntityPiece(ent, ox, oy, s, isSelected) {
    const [cx, cy] = [ox + (ent.cell[0] + 0.5) * s, oy + (ent.cell[1] + 0.5) * s];
    const r = s * 0.3;
    const isEnemy = ent.kind === "enemy";
    const type = ent.subtype;
    const isBoss = type.startsWith("boss/");

    ctx.save();

    if (isEnemy) {
      const color = isBoss ? "#ffd166" : "#ff3366";
      ctx.shadowColor = color;
      ctx.shadowBlur = s * 0.2;

      // Forma do Inimigo
      if (type === "rusher" || type === "mirror" || type === "boss/knight") {
        // Losango Agressivo
        ctx.fillStyle = isBoss ? "#553a1a" : "#441220";
        ctx.strokeStyle = color;
        ctx.lineWidth = Math.max(1.8, s * 0.05);
        ctx.beginPath();
        ctx.moveTo(cx, cy - r);
        ctx.lineTo(cx + r, cy);
        ctx.lineTo(cx, cy + r);
        ctx.lineTo(cx - r, cy);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
      } else if (type === "warden" || type === "boss/rook" || type === "boss/king") {
        // Quadrado Fortificado
        ctx.fillStyle = isBoss ? "#553a1a" : "#441220";
        ctx.strokeStyle = color;
        ctx.lineWidth = Math.max(1.8, s * 0.05);
        roundRect(ctx, cx - r * 0.85, cy - r * 0.85, r * 1.7, r * 1.7, 4);
        ctx.fill();
        ctx.stroke();
      } else {
        // Esfera Tática / Hunter / Sentry
        ctx.fillStyle = isBoss ? "#553a1a" : "#441220";
        ctx.strokeStyle = color;
        ctx.lineWidth = Math.max(1.8, s * 0.05);
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
      }

      // Scanner Ocular
      ctx.fillStyle = "#ffffff";
      ctx.beginPath();
      ctx.ellipse(cx, cy - s * 0.02, s * 0.12, s * 0.08, 0, 0, Math.PI * 2);
      ctx.fill();

      // Pupila Laser (Olhando sutilmente para o cursor)
      let lookX = cx;
      let lookY = cy - s * 0.02;
      if (state.hoverCell) {
        const hx = ox + (state.hoverCell[0] + 0.5) * s;
        const hy = oy + (state.hoverCell[1] + 0.5) * s;
        const angle = Math.atan2(hy - cy, hx - cx);
        lookX += Math.cos(angle) * (s * 0.035);
        lookY += Math.sin(angle) * (s * 0.02);
      }

      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.arc(lookX, lookY, s * 0.045, 0, Math.PI * 2);
      ctx.fill();

      // Ícone ou Coroa de Boss
      if (isBoss) {
        ctx.fillStyle = "#ffd166";
        ctx.font = `900 ${Math.max(10, s * 0.32)}px sans-serif`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(GLYPHS[type] || "♚", cx, cy + r * 1.1);
      }
    } else {
      // Recolha (Pickup)
      const color = type === "coin" || type === "heart" ? "#ffd166" : "#00f5d4";
      ctx.shadowColor = color;
      ctx.shadowBlur = s * 0.2;

      ctx.fillStyle = type === "heart" ? "#441220" : type === "coin" ? "#3a2e10" : "#0f3238";
      ctx.strokeStyle = color;
      ctx.lineWidth = Math.max(1.6, s * 0.05);

      if (type === "coin") {
        ctx.beginPath();
        ctx.ellipse(cx, cy, r * 0.8, r, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
      } else if (type === "heart") {
        drawHeartShape(ctx, cx, cy, r * 0.85);
        ctx.fill();
        ctx.stroke();
      } else {
        roundRect(ctx, cx - r * 0.85, cy - r * 0.85, r * 1.7, r * 1.7, 4);
        ctx.fill();
        ctx.stroke();
      }

      ctx.fillStyle = color;
      ctx.font = `900 ${Math.max(9, s * 0.36)}px var(--font-mono)`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(GLYPHS[type] || "★", cx, cy + 1);
    }

    if (isSelected) {
      drawSelectionRing(cx, cy, s * 0.44);
    }
    ctx.restore();
  }

  // Desenho de Mecanismos e Circuitos
  function drawMechanismPiece(mech, ox, oy, s, isSelected) {
    const [cx, cy] = [ox + (mech.cell[0] + 0.5) * s, oy + (mech.cell[1] + 0.5) * s];
    const r = s * 0.32;
    const type = mech.kind;
    const color = type === "gate" ? "#ff9e00" : type === "power_source" ? "#ffd166" : type === "circuit_relay" ? "#c77dff" : "#00f5d4";

    ctx.save();
    ctx.shadowColor = color;
    ctx.shadowBlur = s * 0.15;

    ctx.fillStyle = type === "crate" ? "#38291a" : "#0c1d29";
    ctx.strokeStyle = color;
    ctx.lineWidth = Math.max(1.8, s * 0.05);

    if (type === "crate") {
      roundRect(ctx, cx - r * 0.82, cy - r * 0.82, r * 1.64, r * 1.64, 4);
      ctx.fill();
      ctx.stroke();

      // Cruz metálica
      ctx.strokeStyle = "#b58451";
      ctx.lineWidth = 1.4;
      ctx.beginPath();
      ctx.moveTo(cx - r * 0.5, cy - r * 0.5);
      ctx.lineTo(cx + r * 0.5, cy + r * 0.5);
      ctx.moveTo(cx + r * 0.5, cy - r * 0.5);
      ctx.lineTo(cx - r * 0.5, cy + r * 0.5);
      ctx.stroke();
    } else {
      roundRect(ctx, cx - r * 0.88, cy - r * 0.88, r * 1.76, r * 1.76, 5);
      ctx.fill();
      ctx.stroke();

      if (type === "gate") {
        ctx.lineWidth = 2;
        ctx.strokeStyle = color;
        for (let i = -1; i <= 1; i++) {
          ctx.beginPath();
          ctx.moveTo(cx + i * r * 0.4, cy - r * 0.6);
          ctx.lineTo(cx + i * r * 0.4, cy + r * 0.6);
          ctx.stroke();
        }
      } else if (type === "pressure_plate") {
        ctx.beginPath();
        ctx.arc(cx, cy, r * 0.45, 0, Math.PI * 2);
        ctx.stroke();
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(cx, cy, r * 0.2, 0, Math.PI * 2);
        ctx.fill();
      } else {
        ctx.fillStyle = color;
        ctx.font = `900 ${Math.max(10, s * 0.4)}px var(--font-mono)`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(GLYPHS[type] || "⚙", cx, cy + 1);
      }
    }

    if (isSelected) {
      drawSelectionRing(cx, cy, s * 0.46);
    }
    ctx.restore();
  }

  // Fio Laser com Pulso de Energia
  function drawLaserWire(a, b, ox, oy, s) {
    const ax = ox + (a[0] + 0.5) * s;
    const ay = oy + (a[1] + 0.5) * s;
    const bx = ox + (b[0] + 0.5) * s;
    const by = oy + (b[1] + 0.5) * s;

    ctx.save();
    // Linha de Fio
    ctx.strokeStyle = "rgba(0, 245, 212, 0.5)";
    ctx.lineWidth = Math.max(1.4, s * 0.035);
    ctx.setLineDash([s * 0.12, s * 0.08]);
    ctx.lineDashOffset = -(state.particlePhase * 0.5);

    ctx.shadowColor = "#00f5d4";
    ctx.shadowBlur = 6;
    ctx.beginPath();
    ctx.moveTo(ax, ay);
    ctx.lineTo(bx, by);
    ctx.stroke();

    // Partícula viajante
    const t = (state.particlePhase % 100) / 100;
    const px = ax + (bx - ax) * t;
    const py = ay + (by - ay) * t;

    ctx.fillStyle = "#ffffff";
    ctx.beginPath();
    ctx.arc(px, py, Math.max(2, s * 0.05), 0, Math.PI * 2);
    ctx.fill();

    ctx.restore();
  }

  // Ghost Preview sob o Cursor
  function drawGhostPreview(pt, ox, oy, s) {
    if (state.tool === "select") return;
    const px = ox + pt[0] * s;
    const py = oy + pt[1] * s;

    ctx.save();
    ctx.fillStyle = "rgba(0, 245, 212, 0.15)";
    ctx.strokeStyle = "rgba(0, 245, 212, 0.8)";
    ctx.lineWidth = 1.5;
    ctx.fillRect(px, py, s, s);
    ctx.strokeRect(px + 0.5, py + 0.5, s - 1, s - 1);

    if (state.tool === "place" && state.piece) {
      ctx.fillStyle = "rgba(255, 255, 255, 0.7)";
      ctx.font = `900 ${Math.max(10, s * 0.4)}px sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(GLYPHS[state.piece] || "✦", px + s / 2, py + s / 2);
    }
    ctx.restore();
  }

  // Preview de Caixa de Paredes (BoxWall)
  function drawBoxWallPreview(start, curr, ox, oy, s) {
    const minX = Math.min(start[0], curr[0]);
    const maxX = Math.max(start[0], curr[0]);
    const minY = Math.min(start[1], curr[1]);
    const maxY = Math.max(start[1], curr[1]);

    const px = ox + minX * s;
    const py = oy + minY * s;
    const pw = (maxX - minX + 1) * s;
    const ph = (maxY - minY + 1) * s;

    ctx.save();
    ctx.strokeStyle = "rgba(0, 245, 212, 0.9)";
    ctx.lineWidth = 2;
    ctx.setLineDash([4, 4]);
    ctx.fillStyle = "rgba(0, 245, 212, 0.08)";
    ctx.fillRect(px, py, pw, ph);
    ctx.strokeRect(px + 0.5, py + 0.5, pw - 1, ph - 1);
    ctx.restore();
  }

  // Linha do Eixo de Simetria
  function drawSymmetryAxis(ox, oy, s, w, h) {
    const midX = ox + (w / 2) * s;
    ctx.save();
    ctx.strokeStyle = "rgba(255, 51, 102, 0.6)";
    ctx.lineWidth = 1.5;
    ctx.setLineDash([6, 4]);
    ctx.beginPath();
    ctx.moveTo(midX, oy);
    ctx.lineTo(midX, oy + h * s);
    ctx.stroke();

    ctx.fillStyle = "rgba(255, 51, 102, 0.8)";
    ctx.font = "9px var(--font-mono)";
    ctx.fillText("EIXO SIMETRIA", midX + 6, oy + 16);
    ctx.restore();
  }

  function drawSelectionRing(cx, cy, radius) {
    ctx.strokeStyle = "#ffffff";
    ctx.lineWidth = 2;
    ctx.setLineDash([4, 4]);
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.stroke();
  }

  function roundRect(c, x, y, w, h, r) {
    c.beginPath();
    c.roundRect(x, y, w, h, r);
  }

  function drawHeartShape(c, x, y, r) {
    c.beginPath();
    c.moveTo(x, y + r * 0.8);
    c.bezierCurveTo(x - r * 1.4, y - r * 0.1, x - r * 0.8, y - r * 1.1, x, y - r * 0.48);
    c.bezierCurveTo(x + r * 0.8, y - r * 1.1, x + r * 1.4, y - r * 0.1, x, y + r * 0.8);
  }

  // ─── RADAR TÁTICO / MINIMAP ───
  function renderMinimap() {
    if (!miniCtx || !state.map) return;
    const mw = miniCanvas.width;
    const mh = miniCanvas.height;
    miniCtx.clearRect(0, 0, mw, mh);

    const m = state.map;
    const cellW = mw / m.width;
    const cellH = mh / m.height;

    // Fundo
    miniCtx.fillStyle = "#070c18";
    miniCtx.fillRect(0, 0, mw, mh);

    // Paredes
    miniCtx.fillStyle = "#3a4a63";
    m.walls.forEach(w => {
      miniCtx.fillRect(w[0] * cellW, w[1] * cellH, Math.max(1, cellW), Math.max(1, cellH));
    });

    // Início (Verde/Ciano)
    miniCtx.fillStyle = "#00f5d4";
    miniCtx.fillRect(m.start[0] * cellW, m.start[1] * cellH, Math.max(2, cellW * 1.2), Math.max(2, cellH * 1.2));

    // Portal (Magenta)
    miniCtx.fillStyle = "#c77dff";
    miniCtx.fillRect(m.portal[0] * cellW, m.portal[1] * cellH, Math.max(2, cellW * 1.2), Math.max(2, cellH * 1.2));

    // Inimigos (Vermelho)
    miniCtx.fillStyle = "#ff3366";
    m.entity_spawns.filter(e => e.kind === "enemy").forEach(e => {
      miniCtx.fillRect(e.cell[0] * cellW, e.cell[1] * cellH, cellW, cellH);
    });

    // Recolhas (Ouro)
    miniCtx.fillStyle = "#ffd166";
    m.entity_spawns.filter(e => e.kind === "pickup").forEach(e => {
      miniCtx.fillRect(e.cell[0] * cellW, e.cell[1] * cellH, cellW, cellH);
    });

    // Caixa de visualização da câmara atual
    if (state.geom) {
      const g = state.geom;
      const camX = (-state.pan.x / (m.width * g.cell)) * mw;
      const camY = (-state.pan.y / (m.height * g.cell)) * mh;
      const camW = (g.w / (m.width * g.cell)) * mw;
      const camH = (g.h / (m.height * g.cell)) * mh;

      miniCtx.strokeStyle = "rgba(0, 245, 212, 0.7)";
      miniCtx.lineWidth = 1;
      miniCtx.strokeRect(camX, camY, camW, camH);
    }
  }

  // ─── INSPETOR & HIERARQUIA (OUTLINER) ───
  function drawInspector() {
    const selected = selectedObject();
    const card = $("selection-card");
    const details = $("selection-details");
    const removeBtn = $("remove-selected");

    if (removeBtn) {
      removeBtn.disabled = !selected || selected.kind === "start" || selected.kind === "portal";
    }

    if (!details || !card) return;
    details.replaceChildren();

    if (!selected) {
      if ($("inspector-title")) $("inspector-title").textContent = "Parâmetros da Fase";
      card.className = "entity-card-empty";
      card.innerHTML = `
        <div class="card-crosshair">＋</div>
        <div class="card-empty-texts">
          <strong>Nenhum objeto selecionado</strong>
          <small>Clique em qualquer peça, parede ou mecanismo no mapa para inspecionar.</small>
        </div>
      `;
      return;
    }

    const type = selected.subtype || selected.kind || "Objeto";
    const titleName = NAMES[type] || NAMES[selected.kind] || type;

    if ($("inspector-title")) $("inspector-title").textContent = titleName;

    card.className = "entity-card-active";
    card.innerHTML = `
      <div class="active-entity-icon">${GLYPHS[type] || "✦"}</div>
      <div class="card-empty-texts">
        <strong style="color:var(--text-pure); font-size:12px;">${titleName}</strong>
        <small style="color:var(--neon-teal); font-family:var(--font-mono);">Posição: [X: ${selected.cell[0]} | Y: ${selected.cell[1]}]</small>
      </div>
    `;

    // Propriedades específicas de mecanismos
    if (state.selected?.group === "mechanism") {
      const mech = selected;

      // ID do Mecanismo
      const idLabel = document.createElement("label");
      idLabel.className = "form-field";
      idLabel.innerHTML = `<span class="field-label">Identificador de Circuito (ID)</span>`;
      const idInput = document.createElement("input");
      idInput.value = mech.id || "";
      idInput.maxLength = 32;
      idInput.onchange = () => {
        const val = idInput.value.trim();
        if (!val) {
          showToast("O ID do mecanismo não pode ficar vazio.", true);
          idInput.value = mech.id;
          return;
        }
        if (state.map.mechanisms.some((o, i) => i !== state.selected.index && o.id === val)) {
          showToast("Já existe um mecanismo com este identificador.", true);
          idInput.value = mech.id;
          return;
        }
        snapshot();
        mech.id = val;
        markDirty();
        render();
      };
      idLabel.append(idInput);
      details.append(idLabel);

      // Conexões de Fios
      const connBox = document.createElement("div");
      connBox.className = "form-field";
      connBox.innerHTML = `<span class="field-label">Destinos Conectados</span>`;

      const tray = document.createElement("div");
      tray.className = "chips-tray";

      if (mech.outputs && mech.outputs.length > 0) {
        mech.outputs.forEach(targetId => {
          const chip = document.createElement("span");
          chip.className = "wire-chip";
          chip.innerHTML = `${targetId} <span class="wire-chip-del" title="Desconectar">✕</span>`;
          chip.querySelector(".wire-chip-del").onclick = () => {
            snapshot();
            mech.outputs = mech.outputs.filter(id => id !== targetId);
            markDirty();
            render();
            drawInspector();
          };
          tray.append(chip);
        });
      } else {
        const emptyMsg = document.createElement("span");
        emptyMsg.style.cssText = "font-size:10px; color:var(--text-dim);";
        emptyMsg.textContent = "Sem ligações ativas. Utilize a ferramenta Ligar Fios [L] para conectar a outro mecanismo.";
        tray.append(emptyMsg);
      }

      connBox.append(tray);
      details.append(connBox);
    }
  }

  function drawOutliner() {
    const list = $("object-list");
    if (!list || !state.map) return;
    list.replaceChildren();

    const m = state.map;
    const filterText = ($("outliner-search")?.value || "").toLowerCase();

    const rows = [
      { group: "start", label: "Início do Jogador (Lia)", icon: "●", cell: m.start },
      { group: "portal", label: "Portal Quântico", icon: "✦", cell: m.portal },
      ...m.entity_spawns.map((e, index) => ({
        group: "entity", index, label: NAMES[e.subtype] || e.subtype, icon: GLYPHS[e.subtype] || "•", cell: e.cell, kind: e.kind
      })),
      ...m.mechanisms.map((mech, index) => ({
        group: "mechanism", index, label: `${NAMES[mech.kind] || mech.kind} (${mech.id})`, icon: GLYPHS[mech.kind] || "⚙", cell: mech.cell, kind: "mechanism"
      }))
    ];

    rows.forEach(row => {
      if (filterText && !row.label.toLowerCase().includes(filterText)) return;

      const item = document.createElement("div");
      const isSelected = state.selected?.group === row.group && state.selected?.index === row.index;
      item.className = "outliner-row" + (isSelected ? " selected" : "");

      item.innerHTML = `
        <span class="outliner-icon">${row.icon}</span>
        <span class="outliner-name">${row.label}</span>
        <span class="outliner-pos">[${row.cell[0]}, ${row.cell[1]}]</span>
      `;

      item.onclick = () => {
        state.selected = { group: row.group, index: row.index };
        centerCameraOn(row.cell);
        drawInspector();
        render();
      };

      list.append(item);
    });
  }

  function centerCameraOn(point) {
    const g = state.geom;
    if (!g) return;
    state.pan.x = (g.w / 2) - ((point[0] + 0.5) * g.cell);
    state.pan.y = (g.h / 2) - ((point[1] + 0.5) * g.cell);
    render();
  }

  // ─── VALIDAÇÃO E SALVAMENTO ───
  async function validateMap() {
    syncFields();
    setStatus("A validar matriz tática…");
    try {
      const res = await api("/api/validate", { map: state.map });
      showToast("Validação concluída: mapa íntegro e transitável!", false, "✓");
      setStatus("Fase verificada com sucesso!");
    } catch (e) {
      showToast(e.message, true, "⚠");
      setStatus("Existem inconformidades no mapa que devem ser corrigidas.", false);
    }
  }

  async function saveMap() {
    syncFields();
    setStatus("A gravar fase no catálogo do jogo…");
    try {
      const res = await api("/api/save", { map: state.map });
      setSaved("Gravado no jogo com sucesso");
      state.source = "mapa da Oficina";
      if ($("stage-source")) $("stage-source").textContent = "ORIGEM: SALVO NO JOGO";
      showToast(res.backup ? `${res.message} (Versão prévia em backup)` : res.message, false, "💾");
      setStatus(res.message);
    } catch (e) {
      showToast(e.message, true, "✕");
      setStatus("Não foi possível gravar. Corrija os erros.", false);
    }
  }

  // ─── REDIMENSIONAR MAPA ───
  function resizeMap(newW, newH) {
    newW = Math.max(9, Math.min(160, Math.floor(newW)));
    newH = Math.max(9, Math.min(160, Math.floor(newH)));
    if (!state.map) return;

    snapshot();
    state.map.width = newW;
    state.map.height = newH;

    // Podar elementos fora dos novos limites
    state.map.walls = state.map.walls.filter(w => w[0] > 0 && w[1] > 0 && w[0] < newW - 1 && w[1] < newH - 1);
    state.map.entity_spawns = state.map.entity_spawns.filter(e => e.cell[0] > 0 && e.cell[1] > 0 && e.cell[0] < newW - 1 && e.cell[1] < newH - 1);

    const killed = new Set(
      state.map.mechanisms.filter(m => m.cell[0] <= 0 || m.cell[1] <= 0 || m.cell[0] >= newW - 1 || m.cell[1] >= newH - 1).map(m => m.id)
    );
    state.map.mechanisms = state.map.mechanisms.filter(m => !killed.has(m.id));
    state.map.mechanisms.forEach(m => {
      m.outputs = (m.outputs || []).filter(id => !killed.has(id));
    });

    const clamp = (p) => [Math.max(1, Math.min(newW - 2, p[0])), Math.max(1, Math.min(newH - 2, p[1]))];
    state.map.start = clamp(state.map.start);
    state.map.portal = clamp(state.map.portal);

    if (arrEq(state.map.start, state.map.portal)) {
      state.map.portal = [Math.max(1, Math.min(newW - 2, state.map.start[0] + 1)), state.map.start[1]];
    }

    state.zoom = 1.0;
    state.pan = { x: 0, y: 0 };
    markDirty();
    $("resize-dialog").close();
    render();
    setStatus(`Tabuleiro reconfigurado para ${newW} × ${newH} casas.`);
  }

  // ─── LOOP DE ANIMAÇÃO SCI-FI ───
  function startRenderLoop() {
    function frame() {
      state.particlePhase = (state.particlePhase + 1) % 10000;
      // Re-renderiza sutilmente para partículas e pulso
      render();
      state.animFrame = requestAnimationFrame(frame);
    }
    state.animFrame = requestAnimationFrame(frame);
  }

  // ─── BINDINGS DE EVENTOS E INICIALIZAÇÃO ───
  function bindEvents() {
    // Ferramentas
    document.querySelectorAll(".tool-cell").forEach(btn => {
      btn.addEventListener("click", () => setTool(btn.dataset.tool));
    });

    // Abas de Assets
    document.querySelectorAll(".asset-tab").forEach(tab => {
      tab.addEventListener("click", () => setCategory(tab.dataset.category));
    });

    // Stepper de Fases
    if ($("prev-floor-btn")) $("prev-floor-btn").onclick = () => loadFloor(Math.max(1, state.floor - 1));
    if ($("next-floor-btn")) $("next-floor-btn").onclick = () => loadFloor(Math.min(200, state.floor + 1));
    if ($("floor")) $("floor").onchange = (e) => loadFloor(Number(e.target.value));

    // Ações Topbar
    if ($("new-btn")) $("new-btn").onclick = () => {
      if (state.dirty && !confirm("Descartar modificações e criar um novo mapa limpo?")) return;
      const w = 19, h = 15;
      const cleanMap = {
        format: "ctmmap", version: 1, floor: state.floor,
        id: `external_floor_${String(state.floor).padStart(3, "0")}`,
        name: `Fase ${String(state.floor).padStart(3, "0")}`,
        hint: "", objective: "escape", width: w, height: h,
        start: [1, 1], portal: [w - 2, h - 2], walls: [],
        authoritative_spawns: true, entity_spawns: [], mechanisms: []
      };
      loadMap(cleanMap, "mapa novo limpo", false);
    };

    if ($("import-btn")) $("import-btn").onclick = () => $("file-input").click();
    if ($("file-input")) $("file-input").onchange = async (e) => {
      const file = e.target.files?.[0];
      if (!file) return;
      try {
        const json = JSON.parse(await file.text());
        const res = await api("/api/open-json", { map: json });
        loadMap(res.map, `ficheiro ${file.name}`, false);
        showToast("Mapa importado com sucesso!", false, "✓");
      } catch (err) {
        showToast(err.message || "Ficheiro inválido.", true);
      } finally {
        e.target.value = "";
      }
    };

    if ($("blueprint-btn")) $("blueprint-btn").onclick = async () => {
      if (state.dirty && !confirm("Substituir o mapa atual pelo blueprint Godot original?")) return;
      try {
        const res = await api("/api/blueprint", { floor: state.floor });
        loadMap(res.map, "blueprint original", false);
        showToast("Blueprint Godot importado!", false, "✓");
      } catch (err) {
        showToast(err.message, true);
      }
    };

    if ($("disable-btn")) $("disable-btn").onclick = async () => {
      if (!confirm(`Desligar o mapa autoral da fase ${String(state.floor).padStart(3, "0")}? O ficheiro será arquivado como cópia recuperável.`)) return;
      try {
        const res = await api("/api/disable", { floor: state.floor });
        showToast(res.message, false, "✓");
        loadFloor(state.floor);
      } catch (err) {
        showToast(err.message, true);
      }
    };

    if ($("undo-btn")) $("undo-btn").onclick = undo;
    if ($("redo-btn")) $("redo-btn").onclick = redo;

    if ($("mirror-btn")) $("mirror-btn").onclick = () => {
      state.mirrorH = !state.mirrorH;
      $("mirror-btn").classList.toggle("active", state.mirrorH);
      showToast(state.mirrorH ? "Modo de Simetria Horizontal ATIVO" : "Modo de Simetria DESATIVADO", false, "M");
      render();
    };

    if ($("validate-btn")) $("validate-btn").onclick = validateMap;
    if ($("save-btn")) $("save-btn").onclick = saveMap;
    if ($("remove-selected")) $("remove-selected").onclick = removeSelected;

    // Controles de Visualização
    if ($("zoom-in")) $("zoom-in").onclick = () => { state.zoom = Math.min(2.5, state.zoom * 1.15); render(); };
    if ($("zoom-out")) $("zoom-out").onclick = () => { state.zoom = Math.max(0.4, state.zoom / 1.15); render(); };
    if ($("fit-btn")) $("fit-btn").onclick = () => { state.zoom = 1.0; state.pan = { x: 0, y: 0 }; render(); };
    if ($("grid-toggle-btn")) $("grid-toggle-btn").onclick = () => {
      state.showGrid = !state.showGrid;
      $("grid-toggle-btn").classList.toggle("active", state.showGrid);
      render();
    };

    if ($("minimap-toggle")) $("minimap-toggle").onclick = () => {
      const panel = $("minimap-panel");
      if (panel) panel.classList.toggle("collapsed");
    };

    // Modal de Redimensionamento
    const dlg = $("resize-dialog");
    if ($("resize-open")) $("resize-open").onclick = () => dlg.showModal();
    if ($("resize-btn")) $("resize-btn").onclick = () => dlg.showModal();
    if ($("dialog-cancel-btn")) $("dialog-cancel-btn").onclick = () => dlg.close();
    if ($("resize-form")) $("resize-form").onsubmit = (e) => {
      e.preventDefault();
      resizeMap(Number($("width-input").value), Number($("height-input").value));
    };

    document.querySelectorAll(".preset-btn").forEach(btn => {
      btn.onclick = () => {
        $("width-input").value = btn.dataset.w;
        $("height-input").value = btn.dataset.h;
        document.querySelectorAll(".preset-btn").forEach(b => b.classList.toggle("active", b === btn));
      };
    });

    // Inputs de Missão
    ["map-name", "map-hint", "objective", "authoritative"].forEach(id => {
      const el = $(id);
      if (el) el.addEventListener("input", () => { syncFields(); markDirty(); });
    });

    if ($("outliner-search")) {
      $("outliner-search").addEventListener("input", drawOutliner);
    }

    // Canvas Listeners
    canvas.addEventListener("pointerdown", onPointerDown);
    canvas.addEventListener("pointermove", onPointerMove);
    canvas.addEventListener("pointerup", onPointerUp);
    canvas.addEventListener("pointercancel", onPointerUp);
    canvas.addEventListener("contextmenu", e => e.preventDefault());

    canvas.addEventListener("wheel", e => {
      e.preventDefault();
      const factor = e.deltaY < 0 ? 1.1 : 1 / 1.1;
      state.zoom = Math.max(0.4, Math.min(2.5, state.zoom * factor));
      render();
    }, { passive: false });

    // Atalhos Globais de Teclado
    window.addEventListener("keydown", e => {
      if (e.target.matches("input, textarea, select")) return;

      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "z") {
        e.preventDefault();
        undo();
      } else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "y") {
        e.preventDefault();
        redo();
      } else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "s") {
        e.preventDefault();
        saveMap();
      } else if (e.key === "Delete" || e.key === "Backspace") {
        removeSelected();
      } else if (!e.ctrlKey && !e.metaKey) {
        const k = e.key.toLowerCase();
        if (k === "v") setTool("select");
        else if (k === "w") setTool("wall");
        else if (k === "b") setTool("boxwall");
        else if (k === "g") setTool("flood");
        else if (k === "e") setTool("erase");
        else if (k === "s") setTool("start");
        else if (k === "p") setTool("portal");
        else if (k === "l") setTool("link");
        else if (k === "m") {
          state.mirrorH = !state.mirrorH;
          if ($("mirror-btn")) $("mirror-btn").classList.toggle("active", state.mirrorH);
          showToast(state.mirrorH ? "Simetria ATIVADA" : "Simetria DESATIVADA", false, "M");
          render();
        } else if (k === "f") {
          state.zoom = 1.0; state.pan = { x: 0, y: 0 }; render();
        }
      }
    });

    window.addEventListener("resize", render);
  }

  // ─── INICIALIZAÇÃO DO SISTEMA ───
  async function boot() {
    const sel = $("floor");
    if (sel) {
      for (let i = 1; i <= 200; i++) {
        const opt = document.createElement("option");
        opt.value = i;
        opt.textContent = String(i).padStart(3, "0");
        sel.append(opt);
      }
    }

    bindEvents();
    startRenderLoop();

    try {
      await api("/api/status");
      await loadFloor(1);
    } catch (e) {
      setStatus("Falha de conexão com o servidor local.", false);
      showToast(e.message, true);
    }
  }

  boot();
})();
