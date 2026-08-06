const fs = require("fs");
let s = fs.readFileSync("firestore.rules", "utf8");
// Strip // comments carefully (not inside strings)
let out = "";
let i = 0;
let inStr = false;
let sc = "";
while (i < s.length) {
  const c = s[i];
  if (inStr) {
    out += c;
    if (c === "\\" && i + 1 < s.length) {
      out += s[++i];
    } else if (c === sc) inStr = false;
    i++;
    continue;
  }
  if (c === '"' || c === "'") {
    inStr = true;
    sc = c;
    out += c;
    i++;
    continue;
  }
  if (c === "/" && s[i + 1] === "/") {
    while (i < s.length && s[i] !== "\n") i++;
    continue;
  }
  if (c === "/" && s[i + 1] === "*") {
    i += 2;
    while (i < s.length && !(s[i] === "*" && s[i + 1] === "/")) i++;
    i += 2;
    continue;
  }
  out += c;
  i++;
}
out = out
  .split("\n")
  .map((l) => l.replace(/[ \t]+$/g, ""))
  .filter((l) => l.trim().length)
  .join("\n");
fs.writeFileSync("firestore.rules.stripped.tmp", out);
console.log("stripped bytes", Buffer.byteLength(out), "lines", out.split("\n").length);
