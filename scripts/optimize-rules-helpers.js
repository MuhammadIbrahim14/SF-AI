const fs = require("fs");
const path = "firestore.rules";
let src = fs.readFileSync(path, "utf8");
const backup = path + ".bak-pre-sizefix";
if (!fs.existsSync(backup)) fs.writeFileSync(backup, src);

function replaceFn(src, name, newBody) {
  // Match "    function name(...) { ... }" with brace balancing from function keyword
  const startRe = new RegExp("    function " + name + "\\s*\\(");
  const m = startRe.exec(src);
  if (!m) throw new Error("function not found: " + name);
  const start = m.index;
  const brace = src.indexOf("{", start);
  let depth = 0;
  let inStr = false;
  let sc = "";
  let end = -1;
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
  if (end < 0) throw new Error("end not found: " + name);
  return src.slice(0, start) + newBody.trimEnd() + src.slice(end + 1);
}

src = replaceFn(
  src,
  "hasBoundHiringCandidateAccess",
  `    function hasBoundHiringCandidateAccess(candidateId) {
      return hasRole('company')
        && exists(hiringAccessDocPath(candidateId))
        && hiringAccessBoundToCompany(
          get(hiringAccessDocPath(candidateId)).data,
          candidateId
        );
    }

    function hiringAccessBoundToCompany(data, candidateId) {
      return data.companyId == request.auth.uid
        && data.candidateId == candidateId;
    }`
);

src = replaceFn(
  src,
  "hiringAccessWriteValid",
  `    function hiringAccessWriteValid() {
      return request.resource.data.companyId is string
        && request.resource.data.candidateId is string
        && request.resource.data.applicationId is string
        && request.resource.data.jobId is string
        && request.resource.data.module == 'company_hiring'
        && exists(applicationPath(request.resource.data.applicationId))
        && applicationMatchesHiringAccess(
          get(applicationPath(request.resource.data.applicationId)).data
        );
    }

    function applicationMatchesHiringAccess(app) {
      return app.companyId == request.resource.data.companyId
        && app.applicantId == request.resource.data.candidateId
        && app.jobId == request.resource.data.jobId;
    }`
);

src = replaceFn(
  src,
  "hasRole",
  `    function hasRole(role) {
      return signedIn()
        && exists(userPath(request.auth.uid))
        && userIsActiveWithRole(get(userPath(request.auth.uid)).data, role);
    }

    function userIsActiveWithRole(data, role) {
      return !(data.get('status', 'active') in ['banned', 'suspended'])
        && documentHasRole(data, role);
    }`
);

src = replaceFn(
  src,
  "adminProfileHasRole",
  `    function adminProfileHasRole(role) {
      return signedIn()
        && exists(adminPath(request.auth.uid))
        && adminDataHasRole(get(adminPath(request.auth.uid)).data, role);
    }

    function adminDataHasRole(data, role) {
      return !(data.get('status', 'active') in ['banned', 'suspended'])
        && (
          documentHasRole(data, role)
          || data.get('primaryRole', '') in roleAliases(role)
          || data.get('accessLevel', '') in roleAliases(role)
          || data.get('role', '') in roleAliases(role)
          || data.get('permissionLevel', '') in roleAliases(role)
          || (role == 'admin' && data.get('admin', false) == true)
          || (
            role in ['superAdmin', 'super_admin', 'superadmin']
            && (
              data.get('isSuperAdmin', false) == true
              || data.get('superAdmin', false) == true
              || data.get('super_admin', false) == true
              || data.get('superadmin', false) == true
            )
          )
        );
    }`
);

src = replaceFn(
  src,
  "isAdmin",
  `    function isAdmin() {
      // activeAdminProfileExists already covers adminProfileHasRole(*) success cases
      return activeAdminProfileExists()
        || hasRole('admin')
        || hasRole('super_admin');
    }`
);

fs.writeFileSync(path, src);
console.log("updated", path, "bytes", Buffer.byteLength(src));
