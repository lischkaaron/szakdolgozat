'use strict';

const express = require('express');
const { pool, query } = require('../db/pool');
const { asyncHandler } = require('../utils/asyncHandler');
const { HttpError } = require('../utils/httpError');
const {
  requireString,
  optionalString,
  requireUuid,
  optionalNumber,
  optionalDateTime,
  optionalUuidArray,
} = require('../utils/validate');
const { toTour, toTourMember } = require('../utils/serializers');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// Minden túra-végpont csak bejelentkezve hívható.
router.use(requireAuth);

const TOUR_COLUMNS = `t.id, t.title, t.origin_name, t.origin_lat, t.origin_lng,
  t.destination_name, t.destination_lat, t.destination_lng, t.distance_m, t.duration_s,
  t.status, t.scheduled_at, t.created_by, t.created_at, t.updated_at`;

const TOUR_STATUSES = ['draft', 'planned', 'active', 'finished'];
const MEMBER_RESPONSES = ['accepted', 'declined'];

// A státusz csak előre léphet (a tervezetből indulva az aktív túráig).
const ALLOWED_TRANSITIONS = {
  draft: ['planned'],
  planned: ['active'],
  active: ['finished'],
  finished: [],
};

/** Érvényes túra-státusz (a válaszban mindig ezek egyike szerepel). */
function requireTourStatus(value) {
  if (!TOUR_STATUSES.includes(value)) {
    throw HttpError.badRequest(
      `A "status" mező értéke a következők egyike legyen: ${TOUR_STATUSES.join(', ')}.`,
    );
  }

  return value;
}

/** Meghívott válasza: elfogadás vagy elutasítás. */
function requireMemberResponse(value) {
  if (!MEMBER_RESPONSES.includes(value)) {
    throw HttpError.badRequest('A "status" mező értéke "accepted" vagy "declined" legyen.');
  }

  return value;
}

/**
 * A bejelentkezett felhasználó tagságának betöltése.
 * Ha nem tag, 404-et adunk (nem áruljuk el, hogy létezik-e a túra).
 */
async function loadMembership(tourId, userId) {
  const result = await query(
    `SELECT tour_id, role, status FROM tour_members
     WHERE tour_id = $1 AND user_id = $2`,
    [tourId, userId],
  );

  if (result.rowCount === 0) {
    throw HttpError.notFound('A túra nem található, vagy nem vagy a résztvevője.');
  }

  return result.rows[0];
}

/** Egy túra résztvevői (a vezető elöl), a felhasználók adataival együtt. */
async function loadMembers(tourId, selfId = null) {
  const result = await query(
    `SELECT tm.user_id, tm.role, tm.status, tm.joined_at,
            u.display_name, u.email, u.motorcycle
     FROM tour_members tm
     JOIN users u ON u.id = tm.user_id
     WHERE tm.tour_id = $1
     ORDER BY (tm.role = 'leader') DESC, u.display_name`,
    [tourId],
  );

  return result.rows.map((row) => toTourMember(row, selfId));
}

/** A túra sora (tagság ellenőrzés nélkül). */
async function loadTourRow(tourId) {
  const result = await query(
    `SELECT ${TOUR_COLUMNS} FROM tours t WHERE t.id = $1`,
    [tourId],
  );

  if (result.rowCount === 0) {
    throw HttpError.notFound('A túra nem található.');
  }

  return result.rows[0];
}

/** Túra + résztvevők + a kérő szerepe és részvételi állapota. */
async function serializeTourForUser(tourId, userId) {
  await loadMembership(tourId, userId);

  const row = await loadTourRow(tourId);
  const members = await loadMembers(tourId, userId);

  return toTour(row, members, userId);
}

/**
 * GET /api/tours
 * A bejelentkezett felhasználó túrái (vezetőként vagy meghívottként),
 * a résztvevők listájával, a legújabb elöl.
 */
router.get('/', asyncHandler(async (req, res) => {
  const tours = await query(
    `SELECT ${TOUR_COLUMNS}
     FROM tours t
     JOIN tour_members tm ON tm.tour_id = t.id AND tm.user_id = $1
     ORDER BY t.created_at DESC`,
    [req.user.id],
  );

  if (tours.rowCount === 0) {
    res.json({ tours: [] });
    return;
  }

  const ids = tours.rows.map((row) => row.id);
  const members = await query(
    `SELECT tm.tour_id, tm.user_id, tm.role, tm.status, tm.joined_at,
            u.display_name, u.email, u.motorcycle
     FROM tour_members tm
     JOIN users u ON u.id = tm.user_id
     WHERE tm.tour_id = ANY($1::uuid[])
     ORDER BY (tm.role = 'leader') DESC, u.display_name`,
    [ids],
  );

  const membersByTour = new Map(ids.map((id) => [id, []]));
  for (const row of members.rows) {
    membersByTour.get(row.tour_id)?.push(toTourMember(row, req.user.id));
  }

  res.json({
    tours: tours.rows.map((row) => toTour(row, membersByTour.get(row.id), req.user.id)),
  });
}));

/**
 * POST /api/tours
 * Body: {
 *   title?, originName, originLat?, originLng?,
 *   destinationName, destinationLat?, destinationLng?,
 *   distanceM?, durationS?, scheduledAt?,
 *   status? ('draft' | 'planned' | 'active'),
 *   inviteUserIds?: uuid[], inviteGroupIds?: uuid[]
 * }
 * A létrehozó vezető lesz (elfogadott részvétellel); a meghívott barátok és a
 * csoportok tagjai `invited` állapotba kerülnek. 201 -> { tour }
 */
router.post('/', asyncHandler(async (req, res) => {
  const body = req.body || {};

  const originName = requireString(body.originName, 'originName', { max: 120 });
  const destinationName = requireString(body.destinationName, 'destinationName', { max: 120 });
  const title = optionalString(body.title, 'title', { max: 255 })
    ?? `${originName} ➔ ${destinationName}`;
  const status = body.status === undefined ? 'planned' : requireTourStatus(body.status);
  const originLat = optionalNumber(body.originLat, 'originLat', { min: -90, max: 90 });
  const originLng = optionalNumber(body.originLng, 'originLng', { min: -180, max: 180 });
  const destinationLat = optionalNumber(body.destinationLat, 'destinationLat', { min: -90, max: 90 });
  const destinationLng = optionalNumber(body.destinationLng, 'destinationLng', { min: -180, max: 180 });
  const distanceM = optionalNumber(body.distanceM, 'distanceM', { min: 0, integer: true });
  const durationS = optionalNumber(body.durationS, 'durationS', { min: 0, integer: true });
  const scheduledAt = optionalDateTime(body.scheduledAt, 'scheduledAt');
  const inviteUserIds = optionalUuidArray(body.inviteUserIds, 'inviteUserIds');
  const inviteGroupIds = optionalUuidArray(body.inviteGroupIds, 'inviteGroupIds');

  // Csak barát hívható meg közvetlenül.
  if (inviteUserIds.length > 0) {
    const friends = await query(
      'SELECT friend_id FROM friends WHERE user_id = $1 AND friend_id = ANY($2::uuid[])',
      [req.user.id, inviteUserIds],
    );

    if (friends.rowCount !== inviteUserIds.length) {
      throw HttpError.badRequest('Csak a barátaidat hívhatod meg a túrára.');
    }
  }

  // Csoportot csak a saját csoportjaiból lehet meghívni; a tagok lesznek meghívva.
  const groupMemberIds = new Set();

  if (inviteGroupIds.length > 0) {
    const groups = await query(
      `SELECT g.id
       FROM groups g
       JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = $1
       WHERE g.id = ANY($2::uuid[])`,
      [req.user.id, inviteGroupIds],
    );

    if (groups.rowCount !== inviteGroupIds.length) {
      throw HttpError.badRequest('Csak olyan csoportot hívhatsz meg, amelynek tagja vagy.');
    }

    const members = await query(
      'SELECT DISTINCT user_id FROM group_members WHERE group_id = ANY($1::uuid[])',
      [inviteGroupIds],
    );

    for (const row of members.rows) {
      groupMemberIds.add(row.user_id);
    }
  }

  const inviteeIds = [...new Set([...inviteUserIds, ...groupMemberIds])]
    .filter((id) => id !== req.user.id);

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const inserted = await client.query(
      `INSERT INTO tours (title, origin_name, origin_lat, origin_lng,
                          destination_name, destination_lat, destination_lng,
                          distance_m, duration_s, status, scheduled_at, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
       RETURNING id`,
      [
        title,
        originName,
        originLat,
        originLng,
        destinationName,
        destinationLat,
        destinationLng,
        distanceM,
        durationS,
        status,
        scheduledAt,
        req.user.id,
      ],
    );

    const tourId = inserted.rows[0].id;

    await client.query(
      `INSERT INTO tour_members (tour_id, user_id, role, status)
       VALUES ($1, $2, 'leader', 'accepted')`,
      [tourId, req.user.id],
    );

    if (inviteeIds.length > 0) {
      await client.query(
        `INSERT INTO tour_members (tour_id, user_id, role, status)
         SELECT $1, invited.user_id, 'member', 'invited'
         FROM unnest($2::uuid[]) AS invited(user_id)
         ON CONFLICT (tour_id, user_id) DO NOTHING`,
        [tourId, inviteeIds],
      );
    }

    await client.query('COMMIT');

    res.status(201).json({ tour: await serializeTourForUser(tourId, req.user.id) });
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}));

/**
 * GET /api/tours/:id
 * Túra részletei (résztvevőkkel). Csak a résztvevők láthatják.
 */
router.get('/:id', asyncHandler(async (req, res) => {
  const tourId = requireUuid(req.params.id, 'id');

  res.json({ tour: await serializeTourForUser(tourId, req.user.id) });
}));

/**
 * PATCH /api/tours/:id
 * Body: { title?, status?, scheduledAt? } - csak a túra vezetője módosíthat.
 * A státusz csak előre léphet: draft -> planned -> active -> finished.
 */
router.patch('/:id', asyncHandler(async (req, res) => {
  const tourId = requireUuid(req.params.id, 'id');
  const membership = await loadMembership(tourId, req.user.id);

  if (membership.role !== 'leader') {
    throw HttpError.forbidden('Csak a túra vezetője módosíthatja a túrát.');
  }

  const body = req.body || {};
  const current = await loadTourRow(tourId);

  const title = body.title === undefined
    ? current.title
    : requireString(body.title, 'title', { max: 255 });
  const status = body.status === undefined
    ? current.status
    : requireTourStatus(body.status);
  const scheduledAt = body.scheduledAt === undefined
    ? current.scheduled_at
    : optionalDateTime(body.scheduledAt, 'scheduledAt');

  if (status !== current.status && !ALLOWED_TRANSITIONS[current.status].includes(status)) {
    throw HttpError.badRequest(
      `A túra állapota nem módosítható erről: "${current.status}" -> "${status}".`,
    );
  }

  await query(
    'UPDATE tours SET title = $2, status = $3, scheduled_at = $4 WHERE id = $1',
    [tourId, title, status, scheduledAt],
  );

  res.json({ tour: await serializeTourForUser(tourId, req.user.id) });
}));

/**
 * DELETE /api/tours/:id
 * A túra (és a résztvevők) törlése. Csak a túra vezetője teheti meg.
 */
router.delete('/:id', asyncHandler(async (req, res) => {
  const tourId = requireUuid(req.params.id, 'id');
  const membership = await loadMembership(tourId, req.user.id);

  if (membership.role !== 'leader') {
    throw HttpError.forbidden('Csak a túra vezetője törölheti a túrát.');
  }

  await query('DELETE FROM tours WHERE id = $1', [tourId]);
  res.status(204).send();
}));

/**
 * POST /api/tours/:id/members
 * Body: { userId } vagy { groupId } - csak a vezető hívhat meg.
 * A barát `invited` állapotba kerül; csoportnál annak minden tagja.
 * 201 -> { tour }
 */
router.post('/:id/members', asyncHandler(async (req, res) => {
  const tourId = requireUuid(req.params.id, 'id');
  const membership = await loadMembership(tourId, req.user.id);

  if (membership.role !== 'leader') {
    throw HttpError.forbidden('Csak a túra vezetője hívhat meg résztvevőt.');
  }

  const { userId, groupId } = req.body || {};
  let inviteeIds = [];

  if (userId !== undefined) {
    const targetId = requireUuid(userId, 'userId');

    if (targetId !== req.user.id) {
      const friendship = await query(
        'SELECT 1 FROM friends WHERE user_id = $1 AND friend_id = $2',
        [req.user.id, targetId],
      );

      if (friendship.rowCount === 0) {
        throw HttpError.badRequest('Csak a barátaidat hívhatod meg a túrára.');
      }

      inviteeIds = [targetId];
    }
  } else if (groupId !== undefined) {
    const targetGroupId = requireUuid(groupId, 'groupId');

    const groups = await query(
      'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
      [targetGroupId, req.user.id],
    );

    if (groups.rowCount === 0) {
      throw HttpError.badRequest('Csak olyan csoportot hívhatsz meg, amelynek tagja vagy.');
    }

    const members = await query(
      'SELECT user_id FROM group_members WHERE group_id = $1',
      [targetGroupId],
    );

    inviteeIds = members.rows
      .map((row) => row.user_id)
      .filter((id) => id !== req.user.id);
  } else {
    throw HttpError.badRequest(
      'Add meg a meghívott barát (userId) vagy csoport (groupId) azonosítóját.',
    );
  }

  if (inviteeIds.length === 0) {
    throw HttpError.badRequest('Nincs kit meghívni: a kiválasztott felhasználó már résztvevő.');
  }

  const inserted = await query(
    `INSERT INTO tour_members (tour_id, user_id, role, status)
     SELECT $1, invited.user_id, 'member', 'invited'
     FROM unnest($2::uuid[]) AS invited(user_id)
     ON CONFLICT (tour_id, user_id) DO NOTHING
     RETURNING user_id`,
    [tourId, inviteeIds],
  );

  if (inserted.rowCount === 0) {
    throw HttpError.conflict('A meghívottak már résztvevői a túrának.');
  }

  res.status(201).json({ tour: await serializeTourForUser(tourId, req.user.id) });
}));

/**
 * PATCH /api/tours/:id/members/me
 * Body: { status: 'accepted' | 'declined' } - a meghívott saját válasza.
 */
router.patch('/:id/members/me', asyncHandler(async (req, res) => {
  const tourId = requireUuid(req.params.id, 'id');
  const status = requireMemberResponse(req.body?.status);
  const membership = await loadMembership(tourId, req.user.id);

  if (membership.role === 'leader') {
    throw HttpError.badRequest('A túra vezetője nem módosíthatja a saját részvételét.');
  }

  await query(
    'UPDATE tour_members SET status = $3 WHERE tour_id = $1 AND user_id = $2',
    [tourId, req.user.id, status],
  );

  res.json({ tour: await serializeTourForUser(tourId, req.user.id) });
}));

/**
 * DELETE /api/tours/:id/members/:userId
 * A vezető eltávolíthat egy résztvevőt; mindenki más csak saját magát
 * (azaz lemondhatja a részvételt). A vezető nem léphet ki.
 */
router.delete('/:id/members/:userId', asyncHandler(async (req, res) => {
  const tourId = requireUuid(req.params.id, 'id');
  const targetId = requireUuid(req.params.userId, 'userId');
  const membership = await loadMembership(tourId, req.user.id);
  const isSelf = targetId === req.user.id;

  if (!isSelf && membership.role !== 'leader') {
    throw HttpError.forbidden('Csak a túra vezetője távolíthat el más résztvevőt.');
  }

  if (isSelf && membership.role === 'leader') {
    throw HttpError.badRequest(
      'A túra vezetője nem léphet ki. Töröld a túrát, ha nem indul útnak.',
    );
  }

  const removed = await query(
    'DELETE FROM tour_members WHERE tour_id = $1 AND user_id = $2 RETURNING user_id',
    [tourId, targetId],
  );

  if (removed.rowCount === 0) {
    throw HttpError.notFound('A felhasználó nem résztvevője a túrának.');
  }

  res.status(204).send();
}));

module.exports = router;
