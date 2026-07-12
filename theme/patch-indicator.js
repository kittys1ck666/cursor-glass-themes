/* Glass themes — tiny statusbar indicator (no extension required) */
(function () {
  "use strict";
  function patch() {
    var e1 = document.querySelector(".right-items");
    var e2 = document.querySelector(".right-items .__GLASS_THEME_INDICATOR_CLS");
    if (e1 && !e2) {
      var e = document.createElement("div");
      e.id = "cursor-glass-themes";
      e.title = "Cursor Glass Themes";
      e.className = "statusbar-item right __GLASS_THEME_INDICATOR_CLS";
      var a = document.createElement("a");
      a.tabIndex = -1;
      a.className = "statusbar-item-label";
      var span = document.createElement("span");
      span.className = "codicon codicon-paintcan";
      a.appendChild(span);
      e.appendChild(a);
      e1.appendChild(e);
    }
  }
  setInterval(patch, 5000);
  if (document.readyState === "complete") patch();
  else window.addEventListener("load", patch);
})();
