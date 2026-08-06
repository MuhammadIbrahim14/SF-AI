const fs = require("fs");
const bak = fs.readFileSync("firestore.rules.with-comments.bak", "utf8");
const cur = fs.readFileSync("firestore.rules", "utf8");

const firstMatch = bak.search(/\n    match /);
const rest = bak.slice(firstMatch);

// Find function declarations in rest (between/among matches)
const fnRe = /\n    function [A-Za-z_][A-Za-z0-9_]*\s*\(/g;
const missing = [];
let m;
while ((m = fnRe.exec(rest))) {
  const fnStart = firstMatch + m.index + 1;
  const name = rest.slice(m.index).match(/function\s+([A-Za-z_][A-Za-z0-9_]*)/)[1];
  const brace = bak.indexOf("{", fnStart);
  let depth = 0,
    inStr = false,
    sc = "",
    end = -1;
  for (let i = brace; i < bak.length; i++) {
    const c = bak[i];
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
  const block = bak.slice(fnStart, end + 1);
  const existsInCur = new RegExp("function\\s+" + name + "\\s*\\(").test(cur);
  missing.push({ name, existsInCur, block });
}

console.log(
  "mid-file functions:",
  missing.map((x) => x.name + (x.existsInCur ? " (present)" : " MISSING"))
);

const toInsert = missing.filter((x) => !x.existsInCur).map((x) => x.block);
if (!toInsert.length) {
  console.log("nothing to insert");
  process.exit(0);
}

const curFirst = cur.search(/\n    match /);
const next =
  cur.slice(0, curFirst + 1) +
  toInsert.join("\n\n") +
  "\n\n" +
  cur.slice(curFirst + 1);
fs.writeFileSync("firestore.rules", next);
console.log("inserted", toInsert.length, "functions; new bytes", Buffer.byteLength(next));
