/* KonvojNav – minta adatok (a mockup minden adata innen származik) */

var DATA = {
  user: { name: 'Lischka Áron', initials: 'LÁ' },

  /* Az éppen futó túra */
  tour: {
    name: 'Bükki kanyarok',
    when: '2026.10.12. · 08:30',
    distance: '182 km',
    duration: '4 ó 20 p',
    next: 'Szilvásvárad · 34 km',
    route: 'Eger → Szilvásvárad → Répáshuta → Lillafüred'
  },

  /* Konvoj résztvevői – t = hol tart az útvonalon (0..1) */
  riders: [
    { name: 'Te', initials: 'LÁ', color: '#f26a1b', me: true, t: 0.70, note: 'Első motor' },
    { name: 'Kovács Péter', initials: 'KP', color: '#1d7afc', t: 0.56, note: 'Oszlop 2.' },
    { name: 'Tóth Réka', initials: 'TR', color: '#12a150', t: 0.42, note: 'Oszlop 3.' },
    { name: 'Nagy Bence', initials: 'NB', color: '#8b5cf6', t: 0.28, note: 'Záró motor' }
  ],

  /* Közösség */
  groups: [
    { name: 'Bükki Motorosok', members: 24, joined: true, tag: 'BM' },
    { name: 'Észak-magyarországi túrázók', members: 86, joined: false, tag: 'ÉT' },
    { name: 'Hétvégi kanyarok', members: 12, joined: false, tag: 'HK' }
  ],

  friends: [
    { name: 'Kovács Péter', initials: 'KP', status: 'online', color: '#1d7afc' },
    { name: 'Tóth Réka', initials: 'TR', status: 'online', color: '#12a150' },
    { name: 'Nagy Bence', initials: 'NB', status: '2 órája volt aktív', color: '#8b5cf6' },
    { name: 'Szabó Gábor', initials: 'SG', status: 'offline', color: '#94a3b8' }
  ],

  /* Túratervezéshez használható települések */
  places: [
    'Eger', 'Szilvásvárad', 'Répáshuta', 'Lillafüred', 'Miskolc', 'Tokaj',
    'Hortobágy', 'Debrecen', 'Balatonfüred', 'Budapest', 'Pécs', 'Sopron'
  ],

  /* Az útvonal pontjai a stilizált (álló, teljes képernyős) térképen
     – a "GPS" animáció ezen fut végig. A sáv felső/alsó részét a
     felület (útvonalsáv, gyorsgombok) takarja, ezért középen fut. */
  mapSize: { w: 360, h: 720 },
  routePoints: [
    [38, 500], [96, 473], [74, 429], [132, 403], [196, 415], [236, 379],
    [190, 343], [248, 308], [318, 294], [286, 253], [216, 222], [262, 175], [326, 142]
  ]
};
