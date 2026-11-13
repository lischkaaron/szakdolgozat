'use strict';

/** async route handler burkoló, hogy a dobott hibák a hibakezelőhöz kerüljenek. */
function asyncHandler(handler) {
  return function wrapped(req, res, next) {
    Promise.resolve(handler(req, res, next)).catch(next);
  };
}

module.exports = { asyncHandler };
