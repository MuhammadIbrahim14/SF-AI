const fs = require("fs");
const src = fs.readFileSync("firestore.rules", "utf8");
const names = [
  "adminProfileHasRole",
  "isAdmin",
  "isActiveUser",
  "signedIn",
  "hasRole",
  "isSuperAdmin",
  "userDoc",
  "adminDoc",
];
for (const name of names) {
  const re = new RegExp("function\\s+" + name + "\\s*\\([\\s\\S]*?\\n  \\}\\n");
  const m = src.match(re);
  console.log("==== " + name + " ====");
  console.log(m ? m[0] : "NOT FOUND");
}
// call counts for key helpers
for (const name of ["isAdmin", "isActiveUser", "signedIn", "hasRole", "adminProfileHasRole", "get(", "exists("]) {
  const re = name.endsWith("(") ? /get\(/g : new RegExp("\\b" + name + "\\s*\\(", "g");
  const n = (src.match(name === "get(" ? /(?<![\w])get\(/g : name === "exists(" ? /(?<![\w])exists\(/g : new RegExp("\\b" + name.replace("(", "") + "\\s*\\(", "g")) || []).length;
}
["isAdmin","isActiveUser","signedIn","hasRole","adminProfileHasRole","isSuperAdmin"].forEach((name) => {
  const n = (src.match(new RegExp("\\b" + name + "\\s*\\(", "g")) || []).length;
  console.log("calls", name, n);
});
