/* Glass marble — theme colors from CSS vars (--a-marble-c1 … c5) */
(function () {
  "use strict";

  var DEBUG = false;
  function log() {
    if (!DEBUG || !console || !console.log) return;
    console.log.apply(console, ["[glass-marble]"].concat([].slice.call(arguments)));
  }
  log("loading");

  var HOST_ORDER = [
    "[data-component='root']",
    "[data-component='workspaces-container']",
    ".glass-agent-conversation-tiling",
    "[data-component='agent-panel']",
    ".part.auxiliarybar > .content",
    ".part.auxiliarybar",
    ".composer-bar.editor",
    ".part.auxiliarybar .composer-pane",
  ];

  var INPUT_MARKERS = ".agent-panel-followup-input, .composer-human-message-container";

  var VERT = "attribute vec2 a_pos;void main(){gl_Position=vec4(a_pos,0.,1.);}";
  var FRAG = [
    "precision mediump float;",
    "uniform vec2 u_win;uniform vec2 u_origin;uniform vec2 u_extent;uniform vec2 u_canvas;",
    "uniform float u_time;uniform float u_scroll;",
    "uniform vec3 u_c1,u_c2,u_c3,u_c4,u_c5;uniform float u_vignette,u_bright;",
    "float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}",
    "float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.-2.*f);",
    "float a=hash(i),b=hash(i+vec2(1.,0.)),c=hash(i+vec2(0.,1.)),d=hash(i+vec2(1.,1.));",
    "return mix(mix(a,b,u.x),mix(c,d,u.x),u.y);}",
    "float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<5;i++){v+=a*noise(p);p=p*2.03+vec2(17.1,9.7);a*=.5;}return v;}",
    "void main(){",
    "vec2 win=vec2(u_origin.x+gl_FragCoord.x*u_extent.x/u_canvas.x,",
    "u_origin.y+(u_canvas.y-gl_FragCoord.y)*u_extent.y/u_canvas.y);",
    "vec2 uv=win/u_win.y*2.6;uv.y-=u_scroll;float t=u_time*.05;",
    "vec2 q=vec2(fbm(uv+t),fbm(uv+vec2(5.2,1.3)-t*.6));",
    "vec2 r=vec2(fbm(uv+3.5*q+vec2(1.7,9.2)+t*.35),fbm(uv+3.5*q+vec2(8.3,2.8)-t*.2));",
    "float n=fbm(uv+3.5*r);float ridge=abs(2.*r.x-1.);float vein=pow(max(0.,1.-ridge),9.)*.45;",
    "float v=n*.8+vein;",
    "vec3 col=mix(u_c1,u_c2,smoothstep(0.,.35,v));col=mix(col,u_c3,smoothstep(.35,.58,v));",
    "col=mix(col,u_c4,smoothstep(.58,.8,v));col=mix(col,u_c5,smoothstep(.8,.97,v));",
    "vec2 p=win/u_win-.5;col*=1.-dot(p,p)*u_vignette;col*=u_bright;",
    "gl_FragColor=vec4(col,1.);}",
  ].join("");

  var globalRenderer = null;
  var panelRenderer = null;
  var panelHost = null;
  var panelTrackBar = null;
  var panelObservers = [];
  var scroll = 0;
  var targetScroll = 0;
  var t0 = performance.now();
  var last = 0;
  var frames = 0;
  var hudEl = null;
  var ideDiagAt = 0;
  var transparencyFixDone = false;
  var attachCheckTimer = null;
  var themeUniformCache = null;
  var themeUniformCacheAt = 0;

  var SHOW_HUD = false;

  function ensureHud() {
    if (!SHOW_HUD) return null;
    if (hudEl) return hudEl;
    hudEl = document.createElement("div");
    hudEl.id = "abyss-debug-hud";
    document.body.appendChild(hudEl);
    return hudEl;
  }

  function findAuxBar() {
    return (
      document.getElementById("workbench.parts.auxiliarybar") ||
      document.querySelector(".part.auxiliarybar")
    );
  }

  function hostDims(el, fallbackRect) {
    if (!el) return { w: 0, h: 0 };
    var w = el.clientWidth;
    var h = el.clientHeight;
    if ((w < 2 || h < 2) && fallbackRect) {
      w = Math.max(w, fallbackRect.width || 0);
      h = Math.max(h, fallbackRect.height || 0);
    }
    if ((w < 2 || h < 2) && el.getBoundingClientRect) {
      var r = el.getBoundingClientRect();
      w = Math.max(w, r.width || 0);
      h = Math.max(h, r.height || 0);
    }
    return { w: w, h: h };
  }

  function logIdeDiag(reason) {
    if (isGlassMode()) return;
    var now = performance.now();
    if (now - ideDiagAt < 2500) return;
    ideDiagAt = now;
    var bar = findAuxBar();
    if (!bar) {
      log("ide:", reason, "— auxiliary bar not in DOM");
      return;
    }
    var br = bar.getBoundingClientRect();
    var content = bar.querySelector(".content");
    var cd = hostDims(content, br);
    var host = findIdeHost();
    log(
      "ide:",
      reason,
      "bar=" + Math.round(br.width) + "x" + Math.round(br.height),
      "content=" + Math.round(cd.w) + "x" + Math.round(cd.h),
      "host=" + (host ? host.className.split(" ").slice(0, 3).join(".") : "none")
    );
  }

  function prefersReducedMotion() {
    try {
      return !!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches);
    } catch (e) {
      return false;
    }
  }

  function updateHud() {
    if (!document.body) return;
    var bar = findAuxBar();
    var content = bar && bar.querySelector(".content");
    var br = bar ? bar.getBoundingClientRect() : null;
    var cd = hostDims(content, br);
    var g = document.getElementById("abyss-global-bg");
    var lines = [
      "mode:" + (isGlassMode() ? "glass" : "ide"),
      "global:" + (globalRenderer ? "ok" : "no") + (g && g.style.display === "none" ? "(hidden)" : ""),
      "panel:" + (panelRenderer ? "ok" : "no"),
      "host:" + (panelHost ? panelHost.className.split(" ").slice(0, 2).join(".") : "none"),
      "auxbar:" + (bar ? Math.round(br.width) + "x" + Math.round(br.height) : "no"),
      "content:" + (content ? Math.round(cd.w) + "x" + Math.round(cd.h) : "no"),
      "gpu:" + (document.body.classList.contains("abyss-gpu") ? "yes" : "no"),
      "frames:" + frames,
    ];
    var hud = ensureHud();
    if (hud) hud.textContent = lines.join(" | ");
  }

  function parseTriplet(str) {
    var p = (str || "").split(",").map(function (s) { return parseFloat(s.trim()); });
    if (p.length !== 3 || p.some(isNaN)) return [0.01, 0.04, 0.09];
    return p;
  }

  function getThemePalette() {
    var now = performance.now();
    if (themeUniformCache && now - themeUniformCacheAt < 1000) return themeUniformCache;
    var st = getComputedStyle(document.documentElement);
    var keys = ["c1", "c2", "c3", "c4", "c5"];
    var colors = {};
    for (var i = 0; i < keys.length; i++) {
      colors[keys[i]] = parseTriplet(st.getPropertyValue("--a-marble-" + keys[i]));
    }
    themeUniformCache = {
      colors: colors,
      vignette: parseFloat(st.getPropertyValue("--a-marble-vignette")) || 0.45,
      bright: parseFloat(st.getPropertyValue("--a-marble-brightness")) || 0.9,
      cssGradient: buildCssFallback(colors),
    };
    themeUniformCacheAt = now;
    return themeUniformCache;
  }

  function buildCssFallback(colors) {
    function toRgb(t) {
      return "rgb(" + Math.round(t[0] * 255) + "," + Math.round(t[1] * 255) + "," + Math.round(t[2] * 255) + ")";
    }
    return (
      "radial-gradient(120% 80% at 20% 10%, " + toRgb(colors.c5) + " 0%, transparent 55%)," +
      "radial-gradient(100% 90% at 80% 80%, " + toRgb(colors.c3) + " 0%, transparent 50%)," +
      "linear-gradient(145deg, " + toRgb(colors.c1) + " 0%, " + toRgb(colors.c2) + " 45%, " + toRgb(colors.c4) + " 100%)"
    );
  }

  function applyCssFallback(el) {
    if (!el) return;
    var pal = getThemePalette();
    el.style.background = pal.cssGradient;
    el.style.backgroundSize = "cover";
  }

  function readThemeUniforms(gl, prog) {
    var pal = getThemePalette();
    var keys = ["c1", "c2", "c3", "c4", "c5"];
    for (var i = 0; i < keys.length; i++) {
      var v = pal.colors[keys[i]];
      var loc = gl.getUniformLocation(prog, "u_" + keys[i]);
      if (loc) gl.uniform3f(loc, v[0], v[1], v[2]);
    }
    var lv = gl.getUniformLocation(prog, "u_vignette");
    var lb = gl.getUniformLocation(prog, "u_bright");
    if (lv) gl.uniform1f(lv, pal.vignette);
    if (lb) gl.uniform1f(lb, pal.bright);
  }

  function compile(gl, type, src) {
    var sh = gl.createShader(type);
    gl.shaderSource(sh, src);
    gl.compileShader(sh);
    return gl.getShaderParameter(sh, gl.COMPILE_STATUS) ? sh : null;
  }

  function isGlassMode() {
    return document.body.getAttribute("data-cursor-glass-mode") === "true";
  }

  function winMetrics() {
    var dpr = Math.min(window.devicePixelRatio || 1, 1.25) * 0.65;
    return {
      w: Math.max(2, Math.floor(window.innerWidth * dpr)),
      h: Math.max(2, Math.floor(window.innerHeight * dpr)),
      dpr: dpr,
    };
  }

  function hostMetrics(el, canvas) {
    var rect = el.getBoundingClientRect();
    var m = winMetrics();
    var scale = canvas.width / Math.max(1, rect.width);
    return {
      originX: rect.left * scale,
      originY: rect.top * scale,
      extentX: rect.width * scale,
      extentY: rect.height * scale,
      winW: m.w,
      winH: m.h,
      bw: Math.max(2, Math.floor(rect.width * m.dpr)),
      bh: Math.max(2, Math.floor(rect.height * m.dpr)),
    };
  }

  function createRenderer(canvas, el) {
    var gl =
      canvas.getContext("webgl", { alpha: false, antialias: false, depth: false, stencil: false, powerPreference: "high-performance" }) ||
      canvas.getContext("experimental-webgl");
    if (!gl) return null;

    var vs = compile(gl, gl.VERTEX_SHADER, VERT);
    var fs = compile(gl, gl.FRAGMENT_SHADER, FRAG);
    if (!vs || !fs) return null;

    var prog = gl.createProgram();
    gl.attachShader(prog, vs);
    gl.attachShader(prog, fs);
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) return null;
    gl.useProgram(prog);

    var buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    var loc = gl.getAttribLocation(prog, "a_pos");
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

    readThemeUniforms(gl, prog);

    return {
      gl: gl,
      prog: prog,
      canvas: canvas,
      el: el,
      uWin: gl.getUniformLocation(prog, "u_win"),
      uOrigin: gl.getUniformLocation(prog, "u_origin"),
      uExtent: gl.getUniformLocation(prog, "u_extent"),
      uCanvas: gl.getUniformLocation(prog, "u_canvas"),
      uTime: gl.getUniformLocation(prog, "u_time"),
      uScroll: gl.getUniformLocation(prog, "u_scroll"),
      draw: function (t, sc) {
        readThemeUniforms(this.gl, this.prog);
        var hm = hostMetrics(this.el, this.canvas);
        if (this.canvas.width !== hm.bw || this.canvas.height !== hm.bh) {
          this.canvas.width = hm.bw;
          this.canvas.height = hm.bh;
          this.gl.viewport(0, 0, hm.bw, hm.bh);
        }
        this.gl.uniform2f(this.uWin, hm.winW, hm.winH);
        this.gl.uniform2f(this.uOrigin, hm.originX, hm.originY);
        this.gl.uniform2f(this.uExtent, hm.extentX, hm.extentY);
        this.gl.uniform2f(this.uCanvas, this.canvas.width, this.canvas.height);
        this.gl.uniform1f(this.uTime, t);
        this.gl.uniform1f(this.uScroll, sc);
        this.gl.drawArrays(this.gl.TRIANGLES, 0, 3);
      },
    };
  }

  function findIdeHost() {
    var bar = findAuxBar();
    if (!bar) return null;
    var br = bar.getBoundingClientRect();
    if (br.width < 40 || br.height < 40) return null;
    var content = bar.querySelector(".content");
    if (!content) return null;

    /* Mount inside .content only — canvas on .auxiliarybar sits behind .content (z-index) */
    var candidates = [
      content.querySelector(".composer-bar.editor"),
      content.querySelector(".embedded-aux-bar-editor-container"),
      content.querySelector("[data-component='agent-panel']"),
      content,
    ];
    for (var i = 0; i < candidates.length; i++) {
      var el = candidates[i];
      if (!el) continue;
      var d = hostDims(el, br);
      if (d.w >= 40 && d.h >= 40) return el;
    }
    return null;
  }

  function sealAuxBarVars(bar) {
    if (!bar || bar.dataset.abyssSealed) return;
    bar.dataset.abyssSealed = "1";
    bar.style.setProperty("--composer-pane-background", "transparent", "important");
    bar.style.setProperty("--glass-chat-surface-background", "transparent", "important");
    bar.style.setProperty("--cursor-bg-chrome", "transparent", "important");
    bar.style.setProperty("--vscode-editor-background", "transparent", "important");
    bar.style.setProperty("--vscode-sideBar-background", "transparent", "important");
    bar.style.setProperty("background", "transparent", "important");
    bar.style.setProperty("background-color", "transparent", "important");
  }

  function isIdeAuxContent(el) {
    return !!(el && el.closest && el.closest(".part.auxiliarybar"));
  }

  function hostScore(el) {
    if (!el || el.clientWidth < 40 || el.clientHeight < 40) return -1;
    var area = el.clientWidth * el.clientHeight;
    if (isGlassMode() && el.getAttribute("data-component") === "root") return 5e9 + area;
    if (isGlassMode() && el.getAttribute("data-component") === "agent-panel") return 4.5e9 + area;
    if (!isGlassMode() && isIdeAuxContent(el)) return 4.9e9 + area;
    if (!isGlassMode() && el.classList && el.classList.contains("part") && el.classList.contains("auxiliarybar")) {
      return 4e9 + area;
    }
    if (isGlassMode()) {
      var hasInput = el.querySelector(INPUT_MARKERS) ? 1 : 0;
      return hasInput * 1e9 + area;
    }
    return -1;
  }

  function findPanelHost() {
    if (!isGlassMode()) return findIdeHost();
    var best = null;
    var bestScore = -1;
    for (var i = 0; i < HOST_ORDER.length; i++) {
      document.querySelectorAll(HOST_ORDER[i]).forEach(function (el) {
        var s = hostScore(el);
        if (s > bestScore) {
          bestScore = s;
          best = el;
        }
      });
    }
    return best;
  }

  /* Shells only — do not use * here; STEP rules in ide-agent.css must survive */
  var TRANSPARENCY_FIX_CSS = [
    "body:not([data-cursor-glass-mode=true]) .monaco-workbench .part.auxiliarybar,",
    "body:not([data-cursor-glass-mode=true]) .monaco-workbench .part.auxiliarybar > .content,",
    "body:not([data-cursor-glass-mode=true]) .monaco-workbench .part.auxiliarybar .composer-bar.editor,",
    "body:not([data-cursor-glass-mode=true]) .monaco-workbench .part.auxiliarybar .composer-bar.editor .conversations,",
    "body:not([data-cursor-glass-mode=true]) .monaco-workbench .part.auxiliarybar .composer-human-ai-pair-container,",
    "body:not([data-cursor-glass-mode=true]) .monaco-workbench .part.auxiliarybar .monaco-editor .monaco-editor-background {",
    "background: transparent !important;",
    "background-color: transparent !important;",
    "--composer-pane-background: transparent !important;",
    "--vscode-editor-background: transparent !important;",
    "--vscode-sideBar-background: transparent !important;",
    "}",
    "body:not([data-cursor-glass-mode=true]) .monaco-workbench .part.auxiliarybar .agent-panel-followup-input--conversation-overlay::before,",
    "body:not([data-cursor-glass-mode=true]) .monaco-workbench .part.auxiliarybar .agent-panel-followup-input--conversation-overlay::after {",
    "display: none !important;",
    "}",
  ].join("\n");

  function injectTransparencyFix() {
    if (transparencyFixDone && document.getElementById("abyss-transparency-fix")) return;
    if (document.getElementById("abyss-transparency-fix")) {
      transparencyFixDone = true;
      return;
    }
    var style = document.createElement("style");
    style.id = "abyss-transparency-fix";
    style.textContent = TRANSPARENCY_FIX_CSS;
    document.head.appendChild(style);
    transparencyFixDone = true;
  }

  function relocateTransparencyFix() {
    var el = document.getElementById("abyss-transparency-fix");
    if (!el) {
      transparencyFixDone = false;
      injectTransparencyFix();
      el = document.getElementById("abyss-transparency-fix");
    }
    if (el && el.parentNode) el.parentNode.appendChild(el);
  }

  function scheduleAttachCheck() {
    if (attachCheckTimer) return;
    attachCheckTimer = setTimeout(function () {
      attachCheckTimer = null;
      if (!globalRenderer) attachGlobal();
      if (!panelRenderer) tryAttachPanel();
    }, 500);
  }

  function detachPanel() {
    for (var i = 0; i < panelObservers.length; i++) {
      try { panelObservers[i].disconnect(); } catch (e) {}
    }
    panelObservers = [];
    if (panelHost) {
      delete panelHost.dataset.abyssHost;
      var bg = panelHost.querySelector(".abyss-panel-bg");
      if (bg && bg.parentNode) bg.parentNode.removeChild(bg);
    }
    panelHost = null;
    panelRenderer = null;
    panelTrackBar = null;
  }

  function attachGlobal() {
    if (globalRenderer || document.getElementById("abyss-global-bg")) return globalRenderer;

    var wrap = document.createElement("div");
    wrap.id = "abyss-global-bg";
    var canvas = document.createElement("canvas");
    wrap.appendChild(canvas);
    document.body.appendChild(wrap);

    var fakeHost = {
      getBoundingClientRect: function () {
        return { left: 0, top: 0, width: window.innerWidth, height: window.innerHeight };
      },
    };

    globalRenderer = createRenderer(canvas, fakeHost);
    if (!globalRenderer) {
      applyCssFallback(wrap);
      log("global: webgl unavailable — CSS fallback");
      globalRenderer = { canvas: canvas, el: fakeHost, draw: function () {}, cssFallback: true };
    } else if (!globalRenderer._logged) {
      globalRenderer._logged = true;
      log("ready");
    }
    return globalRenderer;
  }

  function attachPanel(el, trackEl) {
    if (!el || el.dataset.abyssHost) return false;
    var d = hostDims(el, trackEl && trackEl.getBoundingClientRect());
    if (d.w < 40 || d.h < 40) return false;

    var metricsEl = trackEl || el;
    el.dataset.abyssHost = "1";
    panelHost = el;
    panelTrackBar = trackEl || (el.classList && el.classList.contains("auxiliarybar") ? el : findAuxBar());

    var wrap = document.createElement("div");
    wrap.className = "abyss-panel-bg";
    var canvas = document.createElement("canvas");
    wrap.appendChild(canvas);
    el.insertBefore(wrap, el.firstChild);

    panelRenderer = createRenderer(canvas, metricsEl);
    if (!panelRenderer) {
      applyCssFallback(wrap);
      panelRenderer = { canvas: canvas, el: metricsEl, draw: function () {}, cssFallback: true };
      log("panel: webgl failed — CSS fallback on", el.className.split(" ").slice(0, 3).join("."));
    }

    if (isGlassMode()) {
      var global = document.getElementById("abyss-global-bg");
      if (global) global.style.display = "none";
    }

    try {
      var ro1 = new ResizeObserver(function () {
        if (panelRenderer && panelRenderer.draw && !panelRenderer.cssFallback) {
          panelRenderer.draw((performance.now() - t0) / 1000, scroll);
        }
      });
      ro1.observe(metricsEl);
      panelObservers.push(ro1);
      if (panelTrackBar && panelTrackBar !== metricsEl) {
        var ro2 = new ResizeObserver(function () {
          if (panelRenderer && panelRenderer.draw && !panelRenderer.cssFallback) {
            panelRenderer.draw((performance.now() - t0) / 1000, scroll);
          }
        });
        ro2.observe(panelTrackBar);
        panelObservers.push(ro2);
      }
    } catch (e) {}

    log("panel:", el.className.split(" ").slice(0, 3).join(" "), Math.round(d.w) + "x" + Math.round(d.h));
    return true;
  }

  function syncGlobalVisibility() {
    var global = document.getElementById("abyss-global-bg");
    if (!global) return;
    /* IDE: hide global when panel marble is attached — avoid dual WebGL cost */
    if (!isGlassMode()) {
      global.style.display = panelRenderer ? "none" : "";
      return;
    }
    global.style.display = panelRenderer ? "none" : "";
  }

  function tryAttachPanel() {
    if (!isGlassMode()) {
      var bar = findAuxBar();
      if (!bar) {
        logIdeDiag("waiting");
        syncGlobalVisibility();
        return false;
      }
      var br = bar.getBoundingClientRect();
      if (br.width < 40 || br.height < 40) {
        logIdeDiag("too small");
        syncGlobalVisibility();
        return false;
      }
      if (panelRenderer && panelTrackBar === bar) {
        syncGlobalVisibility();
        return true;
      }
      injectTransparencyFix();
      sealAuxBarVars(bar);
      detachPanel();
      var host = findIdeHost();
      var ok = host ? attachPanel(host, bar) : false;
      if (!ok) logIdeDiag("attach failed");
      if (ok) sealAuxBarVars(bar);
      if (bar.classList) bar.classList.add("abyss-ide-agent-ready");
      syncGlobalVisibility();
      return ok;
    }

    var el = findPanelHost();
    if (!el) {
      syncGlobalVisibility();
      return false;
    }
    if (panelHost && panelHost === el && panelRenderer) return true;
    if (panelHost && hostScore(el) <= hostScore(panelHost)) return true;
    detachPanel();
    var okGlass = attachPanel(el);
    syncGlobalVisibility();
    return okGlass;
  }

  function syncThemeModeAttr() {
    var mode = (getComputedStyle(document.documentElement).getPropertyValue("--a-theme-mode") || "").trim();
    if (mode === "light" || mode === "dark") {
      document.documentElement.setAttribute("data-a-theme-mode", mode);
    }
  }

  function boot() {
    syncThemeModeAttr();
    injectTransparencyFix();
    attachGlobal();
    tryAttachPanel();

    if (!globalRenderer && !panelRenderer) return;

    var reduced = prefersReducedMotion();
    if (reduced) {
      var tStatic = 0;
      if (panelRenderer && !panelRenderer.cssFallback) panelRenderer.draw(tStatic, scroll);
      if (globalRenderer && !globalRenderer.cssFallback && !panelRenderer) {
        globalRenderer.draw(tStatic, scroll);
      }
      document.body.classList.add("abyss-gpu");
      updateHud();
      log("reduced-motion: static frame only");
      return;
    }

    if (!boot.looping) {
      boot.looping = true;
      function frame(now) {
        requestAnimationFrame(frame);
        if (document.hidden) return;

        if (!globalRenderer) attachGlobal();
        if (!panelRenderer) tryAttachPanel();

        if (!globalRenderer && !panelRenderer) return;
        if (now - last < 33) return;
        last = now;
        scroll += (targetScroll - scroll) * 0.07;
        var t = (now - t0) / 1000;

        if (panelRenderer && !panelRenderer.cssFallback) panelRenderer.draw(t, scroll);
        /* IDE with panel: panel only. Otherwise draw global. */
        if (globalRenderer && !globalRenderer.cssFallback && !panelRenderer) {
          globalRenderer.draw(t, scroll);
        }

        if (++frames === 2) {
          document.body.classList.add("abyss-gpu");
          updateHud();
        }
        if (frames % 30 === 0) updateHud();
      }
      requestAnimationFrame(frame);
    }
  }

  document.addEventListener("scroll", function (e) {
    if (e.target && e.target.scrollTop != null) targetScroll = e.target.scrollTop * 0.0011;
  }, true);

  function tryBoot() {
    if (document.body) boot();
  }

  if (document.readyState === "complete") tryBoot();
  else window.addEventListener("load", tryBoot);
  setTimeout(tryBoot, 300);
  setTimeout(tryBoot, 1500);
  setTimeout(tryBoot, 4000);
  setTimeout(updateHud, 800);
  setTimeout(updateHud, 3000);
  setTimeout(relocateTransparencyFix, 2500);
  setTimeout(relocateTransparencyFix, 8000);

  var n = 0;
  var poll = setInterval(function () {
    if (!globalRenderer) attachGlobal();
    if (!panelRenderer) tryAttachPanel();
    if (globalRenderer && panelRenderer) {
      clearInterval(poll);
      return;
    }
    if (++n > 40) clearInterval(poll);
  }, 1000);

  try {
    new MutationObserver(function () {
      if (globalRenderer && panelRenderer) return;
      scheduleAttachCheck();
    }).observe(document.documentElement, { childList: true, subtree: true });
  } catch (e) {}
})();
