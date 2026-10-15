/* KonvojNav – a 4 képernyő felépítése (mindegyik sima HTML szöveget ad vissza) */

var Screens = {

  /* 1. Bejelentkezés */
  login: function () {
    return '' +
      '<div class="auth">' +
        '<div class="auth__logo">🏍️</div>' +
        '<h1 class="auth__title">KonvojNav</h1>' +
        '<p class="auth__sub">Motoros konvojok navigációja</p>' +

        '<label class="field"><span>E-mail</span>' +
          '<input type="email" id="email" value="aron@example.com" autocomplete="username">' +
        '</label>' +

        '<label class="field"><span>Jelszó</span>' +
          '<input type="password" id="password" value="jelszo123" autocomplete="current-password">' +
        '</label>' +

        '<button class="btn btn--primary" data-action="login">Bejelentkezés</button>' +
        '<button class="link" data-action="forgot">Elfelejtett jelszó?</button>' +
      '</div>';
  },

  /* 2. Túra – teljes képernyős térkép, fenti útvonalsáv, gyorsgombok a térképen */
  tour: function (tour) {
    return '' +
      /* a térkép kitölti az egész képernyőt */
      '<div class="map">' +
        mapSVG() +
        '<div class="map__pins" id="mapPins"></div>' +
      '</div>' +

      /* a térkép fölé úszó felület: útvonalsáv fent, gyorsgombok lent */
      '<div class="tour-ui">' +
        '<div class="tour-top">' +
          '<button class="routebar" id="routeBar" data-action="toggle-details" ' +
            'aria-expanded="false" aria-controls="detailSheet">' +
            '<i class="dot dot--from"></i>' +
            '<span class="routebar__text">' + shortRoute(tour) + '</span>' +
            '<span class="routebar__chev">' + ICONS.chevron + '</span>' +
          '</button>' +
          '<button class="icon-btn icon-btn--glass" data-action="logout" aria-label="Kilépés">' +
            ICONS.exit +
          '</button>' +
        '</div>' +

        '<div class="tour-bottom">' +
          '<div class="map__chips" id="mapChips"></div>' +
          '<div class="quick">' +
            quick('Lassítunk', '🐢', 'slow') +
            quick('Gyorsítsunk', '🐇', 'fast') +
            quick('Pihenőt kérünk', '☕', 'rest') +
            '<button class="quick__btn quick__btn--sos" data-action="sos" data-msg="Baj van">' +
              '<span class="quick__ico">🆘</span><span class="quick__label">Baj van</span>' +
            '</button>' +
          '</div>' +
        '</div>' +
      '</div>' +

      /* a részletek kártya – az útvonalsávra kattintva nyílik ki */
      '<div class="sheet" id="detailSheet" hidden>' +
        '<div class="sheet__backdrop" data-action="close-details"></div>' +
        '<div class="sheet__card" role="dialog" aria-label="Túra részletei">' +
          '<div class="sheet__head">' +
            '<div class="grow">' +
              '<h2 class="sheet__title">' + tour.name + '</h2>' +
              '<p class="sheet__sub">' + tour.when + '</p>' +
            '</div>' +
            '<button class="icon-btn" data-action="close-details" aria-label="Bezárás">' +
              ICONS.close +
            '</button>' +
          '</div>' +
          '<dl class="details">' +
            row('Útvonal', tour.route) +
            row('Következő megálló', tour.next) +
            row('Távolság', tour.distance) +
            row('Várható idő', tour.duration) +
            row('Résztvevők', DATA.riders.length + ' fő') +
          '</dl>' +
        '</div>' +
      '</div>';
  },

  /* 3. Túra tervezése – honnan, hova */
  plan: function () {
    var opts = DATA.places.map(function (p) { return '<option value="' + p + '">'; }).join('');
    return '' +
      '<header class="topbar">' +
        '<div class="grow"><h1 class="topbar__title">Túra tervezése</h1>' +
        '<p class="topbar__sub">Add meg az indulást és a célt</p></div>' +
      '</header>' +

      '<div class="scroll">' +
        '<section class="card">' +
          '<label class="field"><span>Honnan</span>' +
            '<input id="from" list="places" placeholder="pl. Eger"></label>' +
          '<label class="field"><span>Hova</span>' +
            '<input id="to" list="places" placeholder="pl. Lillafüred"></label>' +
          '<label class="field"><span>Indulás</span>' +
            '<input id="when" type="datetime-local" value="2026-10-12T08:30"></label>' +
          '<datalist id="places">' + opts + '</datalist>' +
          '<button class="btn btn--primary" data-action="create-tour">Túra létrehozása</button>' +
        '</section>' +

        '<section class="card">' +
          '<h2 class="card__title">Tervezett útvonal</h2>' +
          '<div class="route-view">' +
            '<div class="route-view__point"><i class="dot dot--from"></i><b id="pv-from">Honnan?</b></div>' +
            '<div class="route-view__line"></div>' +
            '<div class="route-view__point"><i class="dot dot--to"></i><b id="pv-to">Hova?</b></div>' +
          '</div>' +
        '</section>' +
      '</div>';
  },

  /* 4. Közösség – csoportok és barátok */
  community: function (groups, friends) {
    var groupItems = groups.map(function (g) {
      return '' +
        '<li class="row-item">' +
          '<span class="avatar avatar--square">' + g.tag + '</span>' +
          '<span class="grow"><b>' + g.name + '</b><em>' + g.members + ' tag</em></span>' +
          (g.joined
            ? '<span class="badge">Tag vagy</span>'
            : '<button class="btn btn--small" data-action="join" data-name="' + g.name + '">Csatlakozás</button>') +
        '</li>';
    }).join('');

    var friendItems = friends.map(function (f) {
      var online = f.status === 'online';
      return '' +
        '<li class="row-item">' +
          '<span class="avatar" style="background:' + f.color + '">' + f.initials + '</span>' +
          '<span class="grow"><b>' + f.name + '</b>' +
            '<em class="' + (online ? 'is-online' : '') + '">' + f.status + '</em></span>' +
          '<button class="btn btn--small btn--ghost" data-action="invite" data-name="' + f.name + '">Meghívás</button>' +
        '</li>';
    }).join('');

    return '' +
      '<header class="topbar">' +
        '<div class="grow"><h1 class="topbar__title">Közösség</h1>' +
        '<p class="topbar__sub">Csoportok és barátok</p></div>' +
        '<span class="avatar avatar--me" style="background:#f26a1b">' + DATA.user.initials + '</span>' +
      '</header>' +

      '<div class="scroll">' +
        '<section class="card">' +
          '<h2 class="card__title">Csoportok</h2>' +
          '<ul class="list">' + groupItems + '</ul>' +
        '</section>' +
        '<section class="card">' +
          '<h2 class="card__title">Barátok</h2>' +
          '<ul class="list">' + friendItems + '</ul>' +
        '</section>' +
      '</div>';
  }
};

/* --- kisebb építőelemek --- */

function row(label, value) {
  return '<div><dt>' + label + '</dt><dd>' + value + '</dd></div>';
}

function quick(label, ico, key) {
  return '<button class="quick__btn" data-action="quick" data-msg="' + label + '" data-key="' + key + '">' +
    '<span class="quick__ico">' + ico + '</span><span class="quick__label">' + label + '</span></button>';
}

/* Az útvonalsávban csak az első és az utolsó település látszik: "Eger → Lillafüred" */
function shortRoute(tour) {
  var parts = tour.route.split('→').map(function (p) { return p.trim(); });
  if (parts.length < 2) return tour.route;
  return parts[0] + ' → ' + parts[parts.length - 1];
}

/* Stilizált "térkép" – nem valódi térkép, csak a felület bemutatásához */
function mapSVG() {
  var s = DATA.mapSize;
  var points = DATA.routePoints;
  var pts = points.map(function (p) { return p[0] + ',' + p[1]; }).join(' ');
  var start = points[0];
  var end = points[points.length - 1];
  return '<svg class="map__svg" viewBox="0 0 ' + s.w + ' ' + s.h + '" preserveAspectRatio="none">' +
    '<rect width="' + s.w + '" height="' + s.h + '" fill="#e9f0e7"/>' +

    /* erdők és tavak */
    '<path d="M0 0h164q30 92-14 164T0 330z" fill="#dcecd6"/>' +
    '<path d="M360 0v204q-96-6-136-92T214 0z" fill="#dcecd6"/>' +
    '<path d="M0 720h156q-16-90-94-122T0 488z" fill="#dcecd6"/>' +
    '<path d="M360 720V566q-86 20-122 96l-12 58z" fill="#cfe3f2"/>' +

    /* utak */
    '<g stroke="#e2e7ec" stroke-width="14" stroke-linecap="round" fill="none">' +
      '<path d="M-10 452 370 408"/>' +
      '<path d="M-10 196 370 246"/>' +
      '<path d="M72 730 128 -10"/>' +
      '<path d="M296 730 252 -10"/>' +
      '<path d="M-10 596 214 -10"/>' +
    '</g>' +

    /* tervezett útvonal (indulás zöld, cél piros) */
    '<polyline points="' + pts + '" fill="none" stroke="#f9d0b4" stroke-width="10" ' +
      'stroke-linecap="round" stroke-linejoin="round"/>' +
    '<polyline points="' + pts + '" fill="none" stroke="#f26a1b" stroke-width="4.5" ' +
      'stroke-linecap="round" stroke-linejoin="round"/>' +
    '<circle cx="' + start[0] + '" cy="' + start[1] + '" r="11" fill="#fff"/>' +
    '<circle cx="' + start[0] + '" cy="' + start[1] + '" r="7" fill="#12a150"/>' +
    '<circle cx="' + end[0] + '" cy="' + end[1] + '" r="11" fill="#fff"/>' +
    '<circle cx="' + end[0] + '" cy="' + end[1] + '" r="7" fill="#e02b3c"/>' +
  '</svg>';
}


