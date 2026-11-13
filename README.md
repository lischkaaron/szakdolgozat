# Motoros konvojokat támogató, valós idejű navigációs mobilalkalmazás, AI alapú útvonal elemzéssel

Real-time navigation mobile application for motorcycle convoys with AI-based route analysis

## Szakdolgozat Alapadatok

| Megnevezés | Adatok |
| :--- | :---|
| **Szakdolgozó neve** | Lischka Áron |
| **EHA / Neptun kód** | SSPWFB |
| **Szak** | üzemmérnök-informatikus BProf |
| **Tagozat** | nappali |
| **A dolgozat típusa** | Szakdolgozat |
| **Témavezető** | Dr. Jánki Zoltán Richárd |

## Fejlesztői indítás

A projekt két részből áll:

- `lib/` – Flutter mobilalkalmazás (`moto_konvoj`)
- `backend/` – Node.js + Express + PostgreSQL/PostGIS REST API

### 1. Backend

```powershell
cd backend
Copy-Item .env.example .env      # JWT_SECRET átírása ajánlott
docker compose up -d             # PostGIS adatbázis + Adminer
npm install
npm run migrate                  # táblák létrehozása
npm run seed                     # tesztfelhasználók + demó csoport (opcionális)
npm run dev                      # http://localhost:3000
```

Részletek, végpontlista és curl példák: [`backend/README.md`](backend/README.md)

### 2. Flutter alkalmazás

```powershell
flutter pub get
flutter run          # Android emulátor: 10.0.2.2 (alapértelmezett)
```

- **Android emulátor:** `http://10.0.2.2:3000/api` (ez az alapértelmezés)
- **Fizikai telefon USB-n (ajánlott):** `adb reverse tcp:3000 tcp:3000`, majd
  a login képernyő alján a **Szerver:** gomb → `http://localhost:3000/api`
- **Fizikai telefon Wi-Fi-n:** `--dart-define=API_BASE_URL=http://<számítógép-LAN-IP>:3000/api`
- **iOS szimulátor / asztali:** `--dart-define=API_BASE_URL=http://localhost:3000/api`

A szerver címe futásidőben is átállítható (nem kell újrafordítani): a bejelentkező
képernyő alján a **Szerver: …** gombra koppintva megadható a backend címe, ami a
SharedPreferences-be mentődik és azonnal érvénybe lép.

Az alkalmazás indításkor a bejelentkező/regisztráló képernyőt mutatja; a belépés után
jelenik meg a korábbi háromfülű felület (Tervezés / Közösség / Profil).

### Közösség: barátok és csoportok

A **Közösség** fül két részre oszlik, és mindkettő a backend valós adataival dolgozik:

- **Barátok:** keresés név vagy e-mail alapján, barátkérés küldése, bejövő kérések
  elfogadása/elutasítása, saját kérés visszavonása, barát eltávolítása.
- **Csoportok:** csoport létrehozása, átnevezése és leírásának szerkesztése, törlése,
  tagok hozzáadása (csak barátból) és eltávolítása, illetve kilépés a csoportból.

A listák lehúzással frissíthetők, a módosítások azonnal a PostgreSQL adatbázisba
kerülnek (`/api/friends`, `/api/groups` végpontok). A csoport tulajdonosa az, aki
létrehozta; ő szerkesztheti és törölheti a csoportot, valamint tagokat kezelhet.

### Túratervezés: mentés, indítás és meghívás

A **Tervezés** fülön kiválasztott útvonalhoz a „RÉSZTVEVŐK MEGHÍVÁSA” kártyán a
backendről betöltött barátok és csoportok közül lehet választani (a kiválasztott
elemek sárgán jelennek meg). A **TÚRA MENTÉSE** `draft`, a **TÚRA INDÍTÁSA**
`active` státusszal menti a túrát a `POST /api/tours` végponton, a kiválasztott
barátokat (`inviteUserIds`) és csoportokat (`inviteGroupIds`) pedig meghívja.
A meghívottak `invited` állapotba kerülnek, és a
`PATCH /api/tours/:id/members/me` végponton fogadhatják el vagy utasíthatják el
a meghívást; a vezető a `PATCH /api/tours/:id` végponttal léptetheti a túra
státuszát (`draft` → `planned` → `active` → `finished`).

### Kész tesztfelhasználók (fejlesztői adatbázis)

| E-mail | Jelszó | Megjegyzés |
| :--- | :--- | :--- |
| `alice@example.com` | `titkosJelszo123` | Yamaha MT-07, barátja Bob |
| `bob@example.com` | `titkosJelszo123` | Honda CB500X, barátja Alice |

Új fiók a regisztrációs képernyőn is létrehozható. Ha a fiókok nem léteznek
(pl. üres adatbázis), a `cd backend; npm run seed` paranccsal hozhatók létre
(a szkript a barátságot és egy demó csoportot is beállít).

### Tesztek

```powershell
flutter analyze
flutter test

# Élő backend elleni füstteszt (a backend fusson közben):
dart run tool/api_smoke_test.dart
```

