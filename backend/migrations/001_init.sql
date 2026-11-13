-- =============================================================================
--  Motoros Konvoj - kezdő adatbázis séma
--  PostgreSQL 16 + PostGIS 3.4
--
--  Futtatás:  npm run migrate
--  (a migrációs futóprogram a schema_migrations táblában tartja nyilván,
--   melyik fájl futott már le, ezért újrafuttatás nem okoz duplikációt)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS postgis;   -- földrajzi adatokhoz (positions.geom)
CREATE EXTENSION IF NOT EXISTS citext;    -- kis/nagybetűtől független e-mail cím
CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- gen_random_uuid()

-- -----------------------------------------------------------------------------
--  Segédfüggvény: updated_at automatikus frissítése
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
--  users - felhasználók (regisztráció / bejelentkezés / profil)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         citext NOT NULL UNIQUE,
  password_hash text   NOT NULL,
  display_name  text   NOT NULL,
  motorcycle    text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT users_display_name_not_blank CHECK (length(btrim(display_name)) > 0)
);

DROP TRIGGER IF EXISTS users_set_updated_at ON users;
CREATE TRIGGER users_set_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
--  friend_requests - barátkérések (pending / accepted / declined)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS friend_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  addressee_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status        text NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  responded_at  timestamptz,
  CONSTRAINT friend_requests_not_self CHECK (requester_id <> addressee_id)
);

-- Egy felhasználó-pár között egyszerre csak egy függő kérés lehet.
CREATE UNIQUE INDEX IF NOT EXISTS friend_requests_pending_uniq
  ON friend_requests (requester_id, addressee_id)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS friend_requests_addressee_idx
  ON friend_requests (addressee_id, status);

-- -----------------------------------------------------------------------------
--  friends - jóváhagyott barátságok (szimmetrikusan, két sorban tárolva)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS friends (
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, friend_id),
  CONSTRAINT friends_not_self CHECK (user_id <> friend_id)
);

-- -----------------------------------------------------------------------------
--  groups / group_members - motoros csapatok
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS groups (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  description text,
  owner_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT groups_name_not_blank CHECK (length(btrim(name)) > 0)
);

CREATE TABLE IF NOT EXISTS group_members (
  group_id  uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role      text NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

CREATE INDEX IF NOT EXISTS group_members_user_idx ON group_members (user_id);

-- -----------------------------------------------------------------------------
--  tours / tour_members - közös túrák (tervezés, meghívás, aktív túra)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tours (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title            text NOT NULL,
  origin_name      text NOT NULL,
  origin_lat       double precision,
  origin_lng       double precision,
  destination_name text NOT NULL,
  destination_lat  double precision,
  destination_lng  double precision,
  distance_m       integer,
  duration_s       integer,
  route_geometry   geometry(LineString, 4326),
  status           text NOT NULL DEFAULT 'draft'
                   CHECK (status IN ('draft', 'planned', 'active', 'finished')),
  scheduled_at     timestamptz,
  created_by       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS tours_set_updated_at ON tours;
CREATE TRIGGER tours_set_updated_at
  BEFORE UPDATE ON tours
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS tour_members (
  tour_id   uuid NOT NULL REFERENCES tours(id) ON DELETE CASCADE,
  user_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role      text NOT NULL DEFAULT 'member' CHECK (role IN ('leader', 'member')),
  status    text NOT NULL DEFAULT 'invited'
            CHECK (status IN ('invited', 'accepted', 'declined')),
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tour_id, user_id)
);

CREATE INDEX IF NOT EXISTS tour_members_user_idx ON tour_members (user_id, status);

-- -----------------------------------------------------------------------------
--  tour_signals - a gyorsgombok által küldött jelzések (lassítás, SOS, ...)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tour_signals (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tour_id    uuid NOT NULL REFERENCES tours(id) ON DELETE CASCADE,
  sender_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type       text NOT NULL
             CHECK (type IN ('slow_down', 'speed_up', 'rest', 'sos')),
  message    text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS tour_signals_tour_idx
  ON tour_signals (tour_id, created_at DESC);

-- -----------------------------------------------------------------------------
--  positions - valós idejű helyzet (a PostGIS geom mező automatikusan töltődik)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS positions (
  id          bigserial PRIMARY KEY,
  tour_id     uuid NOT NULL REFERENCES tours(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lat         double precision NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng         double precision NOT NULL CHECK (lng BETWEEN -180 AND 180),
  speed_mps   real,
  heading     real,
  geom        geography(Point, 4326),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION set_position_geom()
RETURNS trigger AS $$
BEGIN
  NEW.geom := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326)::geography;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS positions_set_geom ON positions;
CREATE TRIGGER positions_set_geom
  BEFORE INSERT OR UPDATE OF lat, lng ON positions
  FOR EACH ROW EXECUTE FUNCTION set_position_geom();

CREATE INDEX IF NOT EXISTS positions_tour_time_idx
  ON positions (tour_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS positions_geom_idx
  ON positions USING gist (geom);

-- -----------------------------------------------------------------------------
--  recommendations - AI által javasolt megállók egy túrához
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS recommendations (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tour_id        uuid NOT NULL REFERENCES tours(id) ON DELETE CASCADE,
  category       text NOT NULL
                 CHECK (category IN ('sight', 'food', 'lodging', 'fuel')),
  name           text NOT NULL,
  description    text,
  lat            double precision,
  lng            double precision,
  detour_m       integer,
  rating         numeric(2, 1) CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5)),
  source         text NOT NULL DEFAULT 'ai' CHECK (source IN ('ai', 'manual')),
  added_to_route boolean NOT NULL DEFAULT false,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS recommendations_tour_idx ON recommendations (tour_id);
