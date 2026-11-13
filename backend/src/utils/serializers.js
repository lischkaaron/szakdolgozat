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

module.exports = {
  toPublicUser,
  toFriend,
  toFriendRequest,
  toGroup,
  toGroupMember,
};
