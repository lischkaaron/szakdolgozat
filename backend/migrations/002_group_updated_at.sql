-- =============================================================================
--  Motoros Konvoj - csoportok: módosítás követése és tagkeresés gyorsítása
--
--  A csoportok szerkeszthetők (név, leírás), ezért érdemes tárolni, mikor
--  módosultak utoljára. A group_members táblára pedig a csoport -> tagok
--  irányú lekérdezésekhez kerül index (a PK csak (group_id, user_id) elejére
--  optimalizál, ezért itt külön index kell a group_id önálló szűréséhez).
-- =============================================================================

ALTER TABLE groups
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DROP TRIGGER IF EXISTS groups_set_updated_at ON groups;
CREATE TRIGGER groups_set_updated_at
  BEFORE UPDATE ON groups
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS group_members_group_idx ON group_members (group_id);
