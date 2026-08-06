const fs = require("fs");
const src = fs.readFileSync("firestore.rules", "utf8");

function findBlockBrace(matchPos) {
  let i = matchPos;
  while (i < src.length) {
    if (src[i] === "{") {
      const close = src.indexOf("}", i);
      if (close < 0) return -1;
      const inner = src.slice(i + 1, close);
      if (/^[A-Za-z0-9_=*]+$/.test(inner)) {
        i = close + 1;
        continue;
      }
      return i;
    }
    i++;
  }
  return -1;
}

function findEnd(bracePos) {
  let depth = 0,
    inStr = false,
    sc = "";
  for (let i = bracePos; i < src.length; i++) {
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
      if (depth === 0) return i;
    }
  }
  return -1;
}

function readBlock(matchPos) {
  const brace = findBlockBrace(matchPos);
  const end = findEnd(brace);
  return src.slice(matchPos, end + 1);
}

// Only top-level matches: lines that start with exactly 4 spaces + match
const matches = [];
const lines = src.split("\n");
let offset = 0;
for (const line of lines) {
  if (/^    match /.test(line)) {
    matches.push(offset);
  }
  offset += line.length + 1;
}
console.log("top-level match count", matches.length);

const keep = Number(process.argv[2] || "30");
const catchAllPos = matches.find((pos) =>
  src.slice(pos, pos + 60).includes("{document=**}")
);
const keepPos = matches.filter((p) => p !== catchAllPos).slice(0, keep);
const preamble = src.slice(0, matches[0]);
const kept = keepPos.map(readBlock);
const catchBlock = readBlock(catchAllPos);
const out = preamble + kept.join("\n\n") + "\n\n" + catchBlock + "\n  }\n}\n";
fs.writeFileSync("firestore.rules.partial.tmp", out);
console.log("keep", keep, "bytes", Buffer.byteLength(out), "lines", out.split("\n").length);
// sanity: compile check via counting braces
let d = 0;
for (const c of out) {
  if (c === "{") d++;
  else if (c === "}") d--;
}
console.log("brace balance", d);
