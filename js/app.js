/* KonvojNav – működés: navigáció, gyorsgombok, szimulált helyzetfrissítés */

var ICONS = {
  exit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" ' +
    'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
    '<path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3"/><path d="M10 8l-4 4 4 4"/>' +
    '<path d="M6 12h9"/></svg>',
  tour: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" ' +
    'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
    '<path d="M9 4 3 6.5v13L9 17l6 2.5 6-2.5v-13L15 7z"/><path d="M9 4v13M15 7v13"/></svg>',
  plan: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" ' +
    'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
    '<path d="M12 5v14M5 12h14"/></svg>',
  community: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" ' +
    'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
    '<circle cx="9" cy="8" r="3"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/>' +
    '<path d="M17 6.5a3 3 0 0 1 0 5.6"/><path d="M18 20c0-2.2-.9-4.2-2.3-5.6"/></svg>',
  chevron: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" ' +
    'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
    '<path d="m6 9 6 6 6-6"/></svg>',
  close: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" ' +
    'stroke-linecap="round" aria-hidden="true"><path d="M6 6 18 18M18 6 6 18"/></svg>'
};

(function () {
  var screenEl = document.getElementById('screen');
  var tabbarEl = document.getElementById('tabbar');
  var toastEl = document.getElementById('toast');

  var TABS = [
    { key: 'tour', label: 'Túra', icon: ICONS.tour },
    { key: 'plan', label: 'Tervezés', icon: ICONS.plan },
    { key: 'community', label: 'Közösség', icon: ICONS.community }
  ];

  var state = {
    screen: 'login',
    tour: DATA.tour,
    groups: DATA.groups.map(function (g) {
      return { name: g.name, members: g.members, tag: g.tag, joined: g.joined };
    })
  };

  var gpsTimer = null;
  var toastTimer = null;

  /* ---------- megjelenítés ---------- */

  function render() {
    stopGPS();

    var html;
    if (state.screen === 'login') html = Screens.login();
    else if (state.screen === 'plan') html = Screens.plan();
    else if (state.screen === 'community') html = Screens.community(state.groups, DATA.friends);
    else html = Screens.tour(state.tour);

    screenEl.innerHTML = html;
    screenEl.classList.toggle('screen--auth', state.screen === 'login');
    screenEl.classList.toggle('screen--tour', state.screen === 'tour');

    tabbarEl.hidden = state.screen === 'login';
    tabbarEl.innerHTML = TABS.map(function (t) {
      var active = t.key === state.screen ? ' is-active' : '';
      return '<button class="tabbar__item' + active + '" data-action="go" data-tab="' + t.key + '">' +
        t.icon + '<span>' + t.label + '</span></button>';
    }).join('');

    var scroller = screenEl.querySelector('.scroll');
    if (scroller) scroller.scrollTop = 0;

    if (state.screen === 'tour') startGPS();
  }

  function toast(text, danger) {
    toastEl.textContent = text;
    /* a túra képernyőn a térkép alján gombok vannak, ezért ott felül jelenik meg */
    toastEl.className = 'toast is-visible' + (danger ? ' toast--danger' : '') +
      (state.screen === 'tour' ? ' toast--top' : '');
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(function () { toastEl.className = 'toast'; }, 2400);
  }

  /* ---------- szimulált helyzetkövetés (a valós appban GPS + Socket.io) ---------- */

  function pointAt(t) {
    var pts = DATA.routePoints, segs = [], total = 0, i, dx, dy, len;
    for (i = 0; i < pts.length - 1; i++) {
      dx = pts[i + 1][0] - pts[i][0];
      dy = pts[i + 1][1] - pts[i][1];
      len = Math.sqrt(dx * dx + dy * dy);
      segs.push(len);
      total += len;
    }
    var target = Math.max(0, Math.min(1, t)) * total;
    for (i = 0; i < segs.length; i++) {
      if (target <= segs[i]) {
        var f = target / segs[i];
        return [
          pts[i][0] + (pts[i + 1][0] - pts[i][0]) * f,
          pts[i][1] + (pts[i + 1][1] - pts[i][1]) * f
        ];
      }
      target -= segs[i];
    }
    return [pts[pts.length - 1][0], pts[pts.length - 1][1]];
  }

  function startGPS() {
    var pinsEl = document.getElementById('mapPins');
    var chipsEl = document.getElementById('mapChips');
    if (!pinsEl || !chipsEl) return;

    var riders = DATA.riders.map(function (r) {
      var pin = document.createElement('div');
      pin.className = 'pin' + (r.me ? ' pin--me' : '');
      pin.style.background = r.color;
      pin.textContent = r.initials;
      pinsEl.appendChild(pin);

      var chip = document.createElement('div');
      chip.className = 'map-chip';
      chip.innerHTML = '<i style="background:' + r.color + '"></i><b>' +
        (r.me ? 'Te' : r.name.split(' ')[0]) + '</b><em>–</em>';
      chipsEl.appendChild(chip);

      return { rider: r, pin: pin, dist: chip.querySelector('em'), t: r.t, pos: null };
    });

    function place(p, instant) {
      var pt = pointAt(p.t);
      if (instant) p.pin.style.transition = 'none';
      p.pin.style.left = (pt[0] / DATA.mapSize.w * 100) + '%';
      p.pin.style.top = (pt[1] / DATA.mapSize.h * 100) + '%';
      p.pos = pt;
      if (instant) {
        void p.pin.offsetWidth;
        p.pin.style.transition = '';
      }
    }

    function meters(p) {
      var dx = p.pos[0] - riders[0].pos[0];
      var dy = p.pos[1] - riders[0].pos[1];
      return Math.round(Math.sqrt(dx * dx + dy * dy) * 3.5);
    }

    function label(m) {
      return m < 1000 ? m + ' m' : (m / 1000).toFixed(1).replace('.', ',') + ' km';
    }

    function tick() {
      riders.forEach(function (p) {
        if (p.t >= 0.995) {
          p.t = 0.02;
          place(p, true);
        } else {
          place(p, false);
        }
      });
      riders.forEach(function (p, i) {
        p.dist.textContent = i === 0 ? '– ' + p.rider.note : label(meters(p));
      });
    }

    riders.forEach(function (p) { place(p, true); });
    tick();

    gpsTimer = window.setInterval(function () {
      riders.forEach(function (p) { p.t += 0.006; });
      tick();
    }, 900);
  }

  function stopGPS() {
    if (gpsTimer) {
      window.clearInterval(gpsTimer);
      gpsTimer = null;
    }
  }

  /* ---------- túra részletei (fenti sáv → kinyíló kártya) ---------- */

  function setDetails(open) {
    var sheet = document.getElementById('detailSheet');
    var bar = document.getElementById('routeBar');
    if (!sheet) return;
    sheet.hidden = !open;
    if (bar) {
      bar.classList.toggle('is-open', open);
      bar.setAttribute('aria-expanded', open ? 'true' : 'false');
    }
  }

  /* ---------- túra létrehozása ---------- */

  function fmtWhen(value) {
    if (!value) return 'nincs megadva';
    var d = new Date(value);
    if (isNaN(d.getTime())) return value;
    var p = function (n) { return (n < 10 ? '0' : '') + n; };
    return d.getFullYear() + '.' + p(d.getMonth() + 1) + '.' + p(d.getDate()) +
      '. · ' + p(d.getHours()) + ':' + p(d.getMinutes());
  }

  function createTour() {
    var fromEl = document.getElementById('from');
    var toEl = document.getElementById('to');
    var whenEl = document.getElementById('when');
    var from = fromEl ? fromEl.value.trim() : '';
    var to = toEl ? toEl.value.trim() : '';

    if (!from || !to) {
      toast('Add meg a kiindulást és a célt!', true);
      return;
    }

    var km = 60 + ((from.length * 37 + to.length * 53) % 200);
    var mins = Math.round(km / 65 * 60);

    state.tour = {
      name: from + ' – ' + to,
      when: fmtWhen(whenEl ? whenEl.value : ''),
      distance: km + ' km',
      duration: Math.floor(mins / 60) + ' ó ' + (mins % 60) + ' p',
      next: to,
      route: from + ' → ' + to
    };

    state.screen = 'tour';
    render();
    toast('Túra létrehozva: ' + from + ' → ' + to);
  }

  /* ---------- események ---------- */

  document.addEventListener('click', function (e) {
    var el = e.target.closest ? e.target.closest('[data-action]') : null;
    if (!el) return;

    var action = el.getAttribute('data-action');

    if (action === 'login') {
      state.screen = 'tour';
      render();
      toast('Üdv újra, ' + DATA.user.name + '!');
    } else if (action === 'forgot') {
      toast('Jelszó-emlékeztető elküldve e-mailben.');
    } else if (action === 'logout') {
      state.screen = 'login';
      render();
    } else if (action === 'go') {
      state.screen = el.getAttribute('data-tab');
      render();
    } else if (action === 'quick') {
      toast('Üzenet a konvojnak: „' + el.getAttribute('data-msg') + '”');
      flash(el);
    } else if (action === 'sos') {
      toast('Vészjelzés elküldve a konvojnak!', true);
      flash(el);
    } else if (action === 'create-tour') {
      createTour();
    } else if (action === 'toggle-details') {
      var sheet = document.getElementById('detailSheet');
      setDetails(sheet ? sheet.hidden : false);
    } else if (action === 'close-details') {
      setDetails(false);
    } else if (action === 'join') {
      var name = el.getAttribute('data-name');
      state.groups.forEach(function (g) {
        if (g.name === name) { g.joined = true; g.members += 1; }
      });
      render();
      toast('Csatlakoztál: ' + name);
    } else if (action === 'invite') {
      toast('Meghívó elküldve: ' + el.getAttribute('data-name'));
    }
  });

  function flash(el) {
    el.classList.add('is-pressed');
    window.setTimeout(function () { el.classList.remove('is-pressed'); }, 320);
  }

  /* Esc zárja a részletek kártyát */
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') setDetails(false);
  });

  /* élő előnézet a tervező képernyőn */
  document.addEventListener('input', function (e) {
    if (e.target.id !== 'from' && e.target.id !== 'to') return;
    var from = document.getElementById('from');
    var to = document.getElementById('to');
    var pvFrom = document.getElementById('pv-from');
    var pvTo = document.getElementById('pv-to');
    if (pvFrom && from) pvFrom.textContent = from.value.trim() || 'Honnan?';
    if (pvTo && to) pvTo.textContent = to.value.trim() || 'Hova?';
  });

  render();
})();

