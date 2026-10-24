// Bridge between the page and Swift. Swift calls sm.* through evaluateJavaScript; the page talks back
// with window.webkit.messageHandlers.studymate.postMessage({type, ...}).
(function () {
  const sm = {};
  function post(msg) {
    try { window.webkit.messageHandlers.studymate.postMessage(msg); } catch (e) {}
  }
  function typeset(root) {
    if (typeof renderMathInElement !== "function") return;
    renderMathInElement(root || document.body, {
      delimiters: [
        { left: "$$", right: "$$", display: true },
        { left: "\\[", right: "\\]", display: true },
        { left: "$", right: "$", display: false },
        { left: "\\(", right: "\\)", display: false }
      ],
      throwOnError: false,
      strict: "ignore"
    });
  }
  sm.setContent = function (html) {
    const root = document.getElementById("root");
    root.innerHTML = html;
    typeset(root);
    window.scrollTo(0, 0);
    post({ type: "rendered" });
  };
  sm.setAccent = function (hex) { document.documentElement.style.setProperty("--accent", hex); };
  sm.scrollToAnchor = function (id) {
    const el = document.getElementById(id);
    if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  // ---- lesson: step-by-step examples ----
  function stepButton(ex) {
    const steps = ex.querySelectorAll(".step");
    const shown = ex.querySelectorAll(".step.shown").length;
    const btn = ex.querySelector("button[data-action=step]");
    const all = ex.querySelector("button[data-action=all]");
    const done = ex.querySelector(".ex-done");
    if (!btn) return;
    if (steps.length === 0) { btn.hidden = true; if (all) all.hidden = true; return; }
    if (shown === 0) { btn.textContent = "풀이 보기"; btn.classList.add("primary"); btn.hidden = false; if (all) all.hidden = false; if (done) done.hidden = true; }
    else if (shown < steps.length) { btn.textContent = "다음 단계 (" + shown + "/" + steps.length + ")"; btn.classList.add("primary"); if (all) all.hidden = false; if (done) done.hidden = true; }
    else { btn.textContent = "접기"; btn.classList.remove("primary"); if (all) all.hidden = true; if (done) done.hidden = false; }
  }
  sm.initExamples = function () {
    document.querySelectorAll(".example").forEach(stepButton);
  };
  document.addEventListener("click", function (e) {
    const btn = e.target.closest("button[data-action]");
    if (btn) {
      const ex = btn.closest(".example");
      const action = btn.dataset.action;
      if (ex && action === "step") {
        const steps = ex.querySelectorAll(".step");
        const next = ex.querySelector(".step:not(.shown)");
        if (next) { next.classList.add("shown"); post({ type: "step", example: ex.id }); }
        else { steps.forEach(s => s.classList.remove("shown")); }
        stepButton(ex);
      } else if (ex && action === "all") {
        ex.querySelectorAll(".step").forEach(s => s.classList.add("shown"));
        post({ type: "step", example: ex.id, all: true });
        stepButton(ex);
      } else if (action) {
        post({ type: "action", action: action, id: btn.dataset.id || "" });
      }
      return;
    }
    const choice = e.target.closest(".choice");
    if (choice && !document.querySelector(".problem.locked")) {
      post({ type: "choice", letter: choice.dataset.letter });
    }
    const link = e.target.closest("a[href]");
    if (link) { e.preventDefault(); post({ type: "link", href: link.getAttribute("href") }); }
  });

  // ---- problem ----
  sm.setSelected = function (letter) {
    document.querySelectorAll(".choice").forEach(c => c.classList.toggle("selected", c.dataset.letter === letter));
  };
  sm.setLang = function (lang) {
    document.querySelectorAll(".q.en").forEach(q => q.hidden = lang !== "en");
    document.querySelectorAll(".q.ko").forEach(q => q.hidden = lang !== "ko");
    document.querySelectorAll(".choice .body").forEach(b => {
      const alt = b.dataset.ko;
      if (!alt) return;
      if (lang === "ko" && !b.dataset.en) b.dataset.en = b.innerHTML;
      b.innerHTML = lang === "ko" ? alt : (b.dataset.en || b.innerHTML);
      typeset(b);
    });
  };
  sm.showHint = function (n) {
    const h = document.getElementById("hint" + n);
    if (h) { h.classList.add("shown"); h.scrollIntoView({ behavior: "smooth", block: "nearest" }); }
  };
  sm.showResult = function (chosen, answer, elapsedText) {
    const p = document.querySelector(".problem");
    if (!p) return;
    p.classList.add("locked");
    document.querySelectorAll(".choice").forEach(c => {
      c.classList.remove("selected");
      if (c.dataset.letter === answer) c.classList.add("correct");
      else if (c.dataset.letter === chosen) c.classList.add("wrong");
    });
    const r = document.querySelector(".result");
    const ok = chosen === answer;
    r.classList.add("shown", ok ? "ok" : "bad");
    r.innerHTML = (ok ? "정답" : "오답 · 정답은 " + answer) + "<span class=meta>" + elapsedText + "</span>";
    const s = document.querySelector(".solution");
    if (s) s.classList.add("shown");
    r.scrollIntoView({ behavior: "smooth", block: "nearest" });
  };
  sm.unlock = function () {
    const p = document.querySelector(".problem");
    if (p) p.classList.remove("locked");
    document.querySelectorAll(".choice").forEach(c => c.classList.remove("correct", "wrong"));
  };

  window.sm = sm;
  window.addEventListener("load", function () { post({ type: "ready" }); });
})();
