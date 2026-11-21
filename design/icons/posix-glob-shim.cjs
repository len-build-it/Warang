// Design-time shim for building the icon font on Windows.
// fantasticon joins its glob pattern with path.join, which yields
// backslashes on Windows that glob reads as escapes, so no SVG is found.
// Preloading this file makes that join use forward slashes.
const path = require('path');
if (path.sep === '\\') {
  const join = path.join;
  path.join = (...parts) => join(...parts).replace(/\\/g, '/');
}
