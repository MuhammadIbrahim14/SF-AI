const fs = require("fs");
let s = fs.readFileSync("firestore.rules", "utf8");

function replaceFn(src, name, newBody) {
  const startRe = new RegExp("    function " + name + "\\s*\\(");
  const m = startRe.exec(src);
  if (!m) throw new Error("function not found: " + name);
  const start = m.index;
  const brace = src.indexOf("{", start);
  let depth = 0,
    inStr = false,
    sc = "",
    end = -1;
  for (let i = brace; i < src.length; i++) {
    const c = src[i];
    if (inStr) {
      if (c === "\\") {
        i++;
        continue;
      }
      if (c === sc) inStr = false;
      continue;
    }
    if (c === '"' || c === "'") {
      inStr = true;
      sc = c;
      continue;
    }
    if (c === "{") depth++;
    else if (c === "}") {
      depth--;
      if (depth === 0) {
        end = i;
        break;
      }
    }
  }
  return src.slice(0, start) + newBody.trimEnd() + src.slice(end + 1);
}

// Flatten isAdmin to one admin get OR one user get with combined role check
s = replaceFn(
  s,
  "isAdmin",
  `    function isAdmin() {
      return activeAdminProfileExists() || userHasAdminLikeRole();
    }

    function userHasAdminLikeRole() {
      return signedIn()
        && exists(userPath(request.auth.uid))
        && userIsActiveAdminLike(get(userPath(request.auth.uid)).data);
    }

    function userIsActiveAdminLike(data) {
      return !(data.get('status', 'active') in ['banned', 'suspended'])
        && (
          documentHasRole(data, 'admin')
          || documentHasRole(data, 'super_admin')
        );
    }`
);

// documentHasRole: aliases once
s = replaceFn(
  s,
  "documentHasRole",
  `    function documentHasRole(data, role) {
      return documentHasAnyRoleAlias(data, roleAliases(role));
    }

    function documentHasAnyRoleAlias(data, aliases) {
      return data.get('primaryRole', '') in aliases
        || data.get('role', '') in aliases
        || (
          data.get('roles', []) is list
          && data.get('roles', []).hasAny(aliases)
        );
    }`
);

fs.writeFileSync("firestore.rules", s);
console.log("bytes", Buffer.byteLength(s));
