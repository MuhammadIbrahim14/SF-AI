const fs = require("fs");
let src = fs.readFileSync("firestore.rules", "utf8").replace(/\r\n/g, "\n");
// remove // line comments
src = src.replace(/^\s*\/\/.*$/gm, "");
// remove /* */ comments
src = src.replace(/\/\*[\s\S]*?\*\//g, "");
// trim trailing spaces, drop empty lines
src = src
  .split("\n")
  .map((l) => l.replace(/[ \t]+$/g, ""))
  .filter((l) => l.trim().length > 0)
  .join("\n");
fs.writeFileSync("firestore.rules.min.tmp", src, "utf8");
console.log("bytes", Buffer.byteLength(src), "lines", src.split("\n").length);
