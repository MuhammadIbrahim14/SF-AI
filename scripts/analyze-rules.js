const fs = require("fs");
const src = fs.readFileSync("firestore.rules", "utf8");
const re = /function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)\s*\{/g;
const starts = [];
let m;
while ((m = re.exec(src))) {
  starts.push({ name: m[1], start: m.index });
}
function findEnd(s, openIdx) {
  let depth = 0;
  let inStr = false;
  let sc = "";
  for (let i = openIdx; i < s.length; i++) {
    const c = s[i];
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
      if (depth === 0) return i;
    }
  }
  return -1;
}
const funcs = [];
for (const st of starts) {
  const brace = src.indexOf("{", st.start);
  const end = findEnd(src, brace);
  const body = src.slice(st.start, end + 1);
  funcs.push({
    name: st.name,
    bytes: Buffer.byteLength(body),
    lines: body.split(/\n/).length,
  });
}
funcs.sort((a, b) => b.bytes - a.bytes);
console.log("TOP FUNCTIONS");
funcs.slice(0, 25).forEach((f) => console.log(f.bytes, f.lines, f.name));
const has = [];
const hr = /keys\(\)\.(hasOnly|hasAll)\(\[([\s\S]*?)\]\)/g;
let h;
while ((h = hr.exec(src))) {
  has.push({
    kind: h[1],
    bytes: h[2].length,
    preview: h[2].replace(/\s+/g, " ").slice(0, 100),
  });
}
has.sort((a, b) => b.bytes - a.bytes);
console.log("TOP hasOnly/hasAll");
has.slice(0, 15).forEach((x) => console.log(x.bytes, x.kind, x.preview));
console.log("total hasOnly/hasAll", has.length);
