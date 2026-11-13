# Motoros Konvoj – Backend

Node.js + Express + PostgreSQL/PostGIS REST API a szakdolgozat mobilalkalmazásához.
Ez az **M1 mérföldkő** backend alapja: adatbázis séma, regisztráció/bejelentkezés (JWT),
profilkezelés és barátkezelés.

## Követelmények

- Node.js 20 vagy újabb (a fejlesztés Node 24-gyel történt)
- Docker Desktop (WSL2 backend) a PostGIS adatbázishoz

## Indítás (fejlesztői környezet)

```powershell
cd backend

# 1) Környezeti változók
Copy-Item .env.example .env
#   -> nyisd meg a .env fájlt és írd át a JWT_SECRET értékét

# 2) Adatbázis indítása (PostGIS + Adminer)
docker compose up -d

# 3) Függőségek
npm install

# 4) Táblák létrehozása
npm run migrate

# 5) Szerver indítása (fejlesztői, automatikus újratöltéssel)
npm run dev
```

Ellenőrzés: <http://localhost:3000/health> → `{"status":"ok","db":"up", ...}`

- API dokumentáció (Swagger UI): <http://localhost:3000/api/docs>
- OpenAPI leírás: <http://localhost:3000/openapi.yaml>
- Adminer (adatbázis böngésző): <http://localhost:8081>
  – Rendszer: PostgreSQL, Szerver: `db`, Felhasználó: `moto`, Jelszó: `moto_dev_pw`, Adatbázis: `moto_konvoj`

Leállítás: `Ctrl+C` a szervernél, majd `docker compose down` (az adatok megmaradnak a
`moto_pgdata` volume-ban; teljes törléshez `docker compose down -v`).

## Végpontok

| Metódus | Útvonal | Auth | Leírás |
| --- | --- | --- | --- |
| GET | `/health` | – | API + adatbázis állapot |
| POST | `/api/auth/register` | – | Regisztráció → `{ token, user }` |
| POST | `/api/auth/login` | – | Bejelentkezés → `{ token, user }` |
| GET | `/api/users/me` | Bearer | Saját profil |
| PATCH | `/api/users/me` | Bearer | Profil módosítása (`displayName`, `motorcycle`) |
| GET | `/api/users/search?q=` | Bearer | Felhasználó keresése (barátkéréshez) |
| GET | `/api/friends` | Bearer | Barátlista |
| GET | `/api/friends/requests` | Bearer | Függő (`pending`) és lezárt (`history`) kérések |
| POST | `/api/friends/requests` | Bearer | Barátkérés küldése (`{email}` vagy `{userId}`) |
| POST | `/api/friends/requests/:id/accept` | Bearer | Kérés elfogadása (csak a címzett) |
| POST | `/api/friends/requests/:id/decline` | Bearer | Kérés elutasítása |
| DELETE | `/api/friends/requests/:id` | Bearer | Saját függő barátkérés visszavonása |
| DELETE | `/api/friends/:userId` | Bearer | Barátság megszüntetése |
| GET | `/api/groups` | Bearer | Saját csoportok (tagokkal) |
| POST | `/api/groups` | Bearer | Új csoport (`{name, description?}`) |
| GET | `/api/groups/:id` | Bearer | Csoport részletei (csak tag) |
| PATCH | `/api/groups/:id` | Bearer | Név/leírás módosítása (csak tulajdonos) |
| DELETE | `/api/groups/:id` | Bearer | Csoport törlése (csak tulajdonos) |
| POST | `/api/groups/:id/members` | Bearer | Tag hozzáadása barátból (csak tulajdonos) |
| DELETE | `/api/groups/:id/members/:userId` | Bearer | Tag eltávolítása / kilépés |

Hibák egységes formátumban: `{ "error": { "message": "..." } }`.

## Kézi tesztelés (PowerShell)

> PowerShellben a `curl` a `Invoke-WebRequest` aliasa, ezért használj `curl.exe`-t,
> vagy az alábbi `Invoke-RestMethod` példákat.

```powershell
$base = 'http://localhost:3000'

# 1) Regisztráció
$alice = Invoke-RestMethod -Method Post -Uri "$base/api/auth/register" -ContentType 'application/json' `
  -Body '{"email":"alice@example.com","password":"titkosJelszo123","displayName":"Alice","motorcycle":"Yamaha MT-07"}'

$bob = Invoke-RestMethod -Method Post -Uri "$base/api/auth/register" -ContentType 'application/json' `
  -Body '{"email":"bob@example.com","password":"titkosJelszo123","displayName":"Bob"}'

# 2) Saját profil
$headers = @{ Authorization = "Bearer $($alice.token)" }
Invoke-RestMethod -Uri "$base/api/users/me" -Headers $headers

# 3) Barátkérés küldése Bobnak
Invoke-RestMethod -Method Post -Uri "$base/api/friends/requests" -Headers $headers `
  -ContentType 'application/json' -Body '{"email":"bob@example.com"}'

# 4) Bob elfogadja
$bobHeaders = @{ Authorization = "Bearer $($bob.token)" }
$pending = Invoke-RestMethod -Uri "$base/api/friends/requests" -Headers $bobHeaders
$requestId = $pending.pending[0].id
Invoke-RestMethod -Method Post -Uri "$base/api/friends/requests/$requestId/accept" -Headers $bobHeaders

# 5) Barátlisták
Invoke-RestMethod -Uri "$base/api/friends" -Headers $headers
Invoke-RestMethod -Uri "$base/api/friends" -Headers $bobHeaders

# 6) Csoport létrehozása, majd Bob hozzáadása (csak barátot lehet)
$group = Invoke-RestMethod -Method Post -Uri "$base/api/groups" -Headers $headers `
  -ContentType 'application/json' -Body (@{ name = 'Betyár Riders Klub'; description = 'Hétvégi túrák' } | ConvertTo-Json)

Invoke-RestMethod -Method Post -Uri "$base/api/groups/$($group.group.id)/members" -Headers $headers `
  -ContentType 'application/json' -Body (@{ userId = $bob.user.id } | ConvertTo-Json)

# 7) Bob csoportjai (tagként látja)
Invoke-RestMethod -Uri "$base/api/groups" -Headers $bobHeaders
```

Bash/macOS alatt ugyanez `curl`-lal:

```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"titkosJelszo123","displayName":"Alice"}'
```

## Projekt felépítés

```
backend/
  docker-compose.yml      PostGIS + Adminer
  migrations/001_init.sql  teljes kezdő séma
  migrations/002_group_updated_at.sql  csoportok updated_at + tag index
  openapi.yaml            API leírás (Swagger UI-hoz)
  src/
    index.js              belépési pont, graceful shutdown
    app.js                Express app (helmet, cors, json, hibakezelés)
    config.js             .env betöltés + alapértelmezések
    db/pool.js            pg kapcsolatpool
    db/migrate.js         SQL migráció futtató
    middleware/auth.js    JWT kiállítás és Bearer ellenőrzés
    middleware/error.js   404 + egységes hibaválasz
    routes/               health, auth, users, friends, groups
    utils/                validálás, hibák, JSON szerializálás
```

## Adatbázis séma (10 tábla)

`users`, `friend_requests`, `friends`, `groups`, `group_members`, `tours`,
`tour_members`, `tour_signals`, `positions`, `recommendations`.

- A `positions` tábla `geography(Point,4326)` mezőjét trigger tölti ki (`ST_MakePoint`),
  így később PostGIS lekérdezésekkel (távolság, körzet) lehet dolgozni.
- A `friends` tábla szimmetrikus: egy elfogadott barátság két sort kap.
- A `friend_requests` táblán részleges egyedi index védi a duplikált függő kéréseket.

## Biztonsági megjegyzések

- A jelszavakat bcrypt hash-sel tárolja (`BCRYPT_ROUNDS`, alapértelmezés 10).
- A JWT access token élettartama `JWT_EXPIRES_IN` (alap: 7 nap).
  **Következő lépés:** rövid életű access token + refresh token tábla.
- Éles üzemhez kötelező: erős `JWT_SECRET`, HTTPS, szűk `CORS_ORIGIN`, `NODE_ENV=production`.

## Következő lépések (a terv szerint)

1. `tours` / `tour_members` végpontok (túra létrehozása, meghívás, státusz).
2. `positions` POST + Socket.io szoba a valós idejű helyzethez.
3. `recommendations` végpont + OpenAI hívás szerveroldali proxyként (kulcs ne kerüljön az appba).
4. Automatizált tesztek (Jest + supertest) a jelenlegi végpontokra.
