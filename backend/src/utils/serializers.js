'use strict';

/** users tábla sora -> API válasz (jelszó hash nélkül). */
function toPublicUser(row) {
  if (!row) return null;

  return {
    id: row.id,
    email: row.email,
    displayName: row.display_name,
    motorcycle: row.motorcycle ?? null,
    createdAt: row.created_at ?? null,
  };
}

/** friends lista sora -> API válasz. */
function toFriend(row) {
  return {
    id: row.id,
    displayName: row.display_name,
    email: row.email ?? null,
    motorcycle: row.motorcycle ?? null,
    friendsSince: row.friends_since ?? null,
  };
}

/** friend_requests sora -> API válasz. */
function toFriendRequest(row) {
  return {
    id: row.id,
    status: row.status,
    direction: row.direction ?? null,
    createdAt: row.created_at,
    respondedAt: row.responded_at ?? null,
    requester: { id: row.requester_id, displayName: row.requester_name },
    addressee: { id: row.addressee_id, displayName: row.addressee_name },
  };
}

/** group_members + users JOIN sora -> API válasz. */
function toGroupMember(row, selfId = null) {
  return {
    userId: row.user_id,
    displayName: row.display_name,
    email: row.email ?? null,
    motorcycle: row.motorcycle ?? null,
    role: row.role,
    joinedAt: row.joined_at ?? null,
    isSelf: selfId !== null && row.user_id === selfId,
  };
}

/**
 * groups tábla sora -> API válasz.
 * A tagok listáját külön adjuk át (a listázó végpont egyben tölti be őket).
 */
function toGroup(row, members = []) {
  return {
    id: row.id,
    name: row.name,
    description: row.description ?? null,
    ownerId: row.owner_id,
    createdAt: row.created_at ?? null,
    updatedAt: row.updated_at ?? null,
    memberCount: row.member_count ?? members.length,
    myRole: row.my_role ?? null,
    members,
  };
}

/**
 * tour_members + users JOIN sora -> API válasz.
 * A szerep `leader` / `member`, a részvétel `invited` / `accepted` / `declined`.
 */
function toTourMember(row, selfId = null) {
  return {
    userId: row.user_id,
    displayName: row.display_name,
    email: row.email ?? null,
    motorcycle: row.motorcycle ?? null,
    role: row.role,
    status: row.status,
    joinedAt: row.joined_at ?? null,
    isSelf: selfId !== null && row.user_id === selfId,
  };
}

/**
 * tours tábla sora -> API válasz.
 * A tagokat külön adjuk át; a kérő szerepét/állapotát belőlük számoljuk.
 */
function toTour(row, members = [], selfId = null) {
  const selfMember = selfId === null
    ? undefined
    : members.find((member) => member.userId === selfId);

  return {
    id: row.id,
    title: row.title,
    originName: row.origin_name,
    originLat: row.origin_lat ?? null,
    originLng: row.origin_lng ?? null,
    destinationName: row.destination_name,
    destinationLat: row.destination_lat ?? null,
    destinationLng: row.destination_lng ?? null,
    distanceM: row.distance_m ?? null,
    durationS: row.duration_s ?? null,
    status: row.status,
    scheduledAt: row.scheduled_at ?? null,
    createdBy: row.created_by,
    createdAt: row.created_at ?? null,
    updatedAt: row.updated_at ?? null,
    memberCount: members.length,
    myRole: selfMember?.role ?? null,
    myStatus: selfMember?.status ?? null,
    members,
  };
}

module.exports = {
  toPublicUser,
  toFriend,
  toFriendRequest,
  toGroup,
  toGroupMember,
  toTour,
  toTourMember,
};
