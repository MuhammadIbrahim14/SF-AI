// console.log("SkillForge portfolio app.js loaded");
// main().catch((error) => {
//   console.error("Portfolio load failed:", error);

//   const app = document.getElementById("app");
//   if (app) {
//     app.innerHTML = `
//       <main style="padding:40px;font-family:Arial">
//         <h1>Portfolio failed to load</h1>
//         <p>${error.message || error}</p>
//       </main>
//     `;
//   }
// });

// import { initializeApp } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js";
// import {
//   doc,
//   getDoc,
//   getFirestore,
// } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-firestore.js";
// import { firebaseConfig } from "./config.js";

// const app = initializeApp(firebaseConfig);
// const db = getFirestore(app);
// const root = document.querySelector("#app");

// function resolveSlug() {
//   const params = new URLSearchParams(window.location.search);
//   const querySlug = params.get("slug")?.trim();
//   if (querySlug) return cleanSlug(querySlug);

//   const hash = window.location.hash.replace(/^#\/?/, "").trim();
//   if (hash.startsWith("p/")) return cleanSlug(hash.slice(2));
//   if (hash && hash !== "p") return cleanSlug(hash);

//   const parts = window.location.pathname
//     .split("/")
//     .map((part) => part.trim())
//     .filter(Boolean);
//   if (parts[0] === "p") return cleanSlug(parts[1] || "");
//   return cleanSlug(parts[0] || "");
// }

// function cleanSlug(value = "") {
//   return decodeURIComponent(value).trim().replace(/^\/+|\/+$/g, "");
// }

// const slug = resolveSlug();
// console.log("[SkillForge Portfolio] resolved slug:", slug || "(missing)");

// function escapeHtml(value = "") {
//   return String(value)
//     .replaceAll("&", "&amp;")
//     .replaceAll("<", "&lt;")
//     .replaceAll(">", "&gt;")
//     .replaceAll('"', "&quot;");
// }

// function list(value) {
//   if (Array.isArray(value)) {
//     return value.map((item) => String(item || "").trim()).filter(Boolean);
//   }
//   if (typeof value === "string") {
//     return value
//       .split(/[\n,]/)
//       .map((item) => item.trim())
//       .filter(Boolean);
//   }
//   return [];
// }

// function firstText(...values) {
//   for (const value of values) {
//     const text = String(value || "").trim();
//     if (text) return text;
//   }
//   return "";
// }

// function section(title, items = []) {
//   const normalized = list(items);
//   if (!normalized.length) return "";
//   return `
//     <article class="section">
//       <h2>${escapeHtml(title)}</h2>
//       <div class="chips">
//         ${normalized
//       .map((item) => `<span class="chip">${escapeHtml(item)}</span>`)
//       .join("")}
//       </div>
//     </article>
//   `;
// }

// function renderMessage(title, message) {
//   root.innerHTML = `
//     <section class="card">
//       <p class="eyebrow">SkillForge Portfolio</p>
//       <h1>${escapeHtml(title)}</h1>
//       <p>${escapeHtml(message)}</p>
//     </section>
//   `;
// }

// async function loadProfile() {
//   if (!slug) {
//     renderMessage(
//       "Portfolio slug is missing",
//       "Open a link like /p/your-slug."
//     );
//     return;
//   }

//   const docPath = `publicProfiles/${slug}`;
//   console.log("[SkillForge Portfolio] Firestore doc path:", docPath);
//   const snapshot = await getDoc(doc(db, "publicProfiles", slug));
//   console.log("[SkillForge Portfolio] doc exists:", snapshot.exists());

//   if (!snapshot.exists()) {
//     renderMessage("Portfolio not found", "No public profile exists for this slug.");
//     return;
//   }

//   const profile = snapshot.data() || {};
//   const visible = profile.publicVisible === true || profile.isPublic === true;
//   console.log("[SkillForge Portfolio] visibility:", visible);

//   if (!visible) {
//     renderMessage(
//       "This portfolio is private or not published",
//       "The owner has not made this SkillForge portfolio public yet."
//     );
//     return;
//   }

//   const avatar = firstText(profile.avatarUrl, profile.photoUrl);
//   const displayName = firstText(profile.displayName, profile.name, "SkillForge Member");
//   const headline = firstText(profile.headline, profile.title, "Verified SkillForge portfolio");
//   const bio = firstText(profile.bio, profile.about, "No public bio added yet.");

//   root.innerHTML = `
//     <section class="card hero">
//       ${avatar
//       ? `<img class="avatar" src="${escapeHtml(avatar)}" alt="" />`
//       : `<div class="avatar"></div>`
//     }
//       <div>
//         <p class="eyebrow">${escapeHtml(profile.roleType || "SkillForge")}</p>
//         <h1>${escapeHtml(displayName)}</h1>
//         <p>${escapeHtml(headline)}</p>
//         ${profile.hireButtonEnabled
//       ? `<a class="cta" href="mailto:">Hire / Contact</a>`
//       : ""
//     }
//       </div>
//     </section>
//     <section class="card" style="margin-top: 18px">
//       <h2>About</h2>
//       <p>${escapeHtml(bio)}</p>
//     </section>
//     <section class="grid">
//       ${section("Verified Skills", profile.verifiedSkills)}
//       ${section("Skills", profile.skills)}
//       ${section("Projects", profile.projects)}
//       ${section("Services", profile.services)}
//       ${section("Courses Created", profile.coursesCreated)}
//       ${section("Certificates", profile.certificates)}
//       ${section("Social Links", profile.socialLinks)}
//     </section>
//   `;
// }

// loadProfile().catch((error) => {
//   console.error("[SkillForge Portfolio] load failed:", error);
//   renderMessage(
//     "Unable to load portfolio",
//     "Please check Firebase config, Firestore rules, and the portfolio slug."
//   );
// });



console.log("SkillForge portfolio app.js loaded");

const appRoot = document.getElementById("app");

function setHtml(html) {
  if (appRoot) appRoot.innerHTML = html;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function getSlug() {
  const params = new URLSearchParams(window.location.search);
  const querySlug = params.get("slug");
  if (querySlug && querySlug.trim()) return querySlug.trim();

  const parts = window.location.pathname.split("/").filter(Boolean);

  if (parts[0] === "p" && parts[1]) return decodeURIComponent(parts[1]);
  if (parts[0] && parts[0] !== "p") return decodeURIComponent(parts[0]);

  return "";
}

function normalizeList(value) {
  if (!value) return [];

  if (Array.isArray(value)) {
    return value
      .map((item) => {
        if (typeof item === "string") return item;
        if (item?.name) return item.name;
        if (item?.title) return item.title;
        if (item?.skillName) return item.skillName;
        return "";
      })
      .filter(Boolean);
  }

  if (typeof value === "string") {
    return value
      .split(",")
      .map((x) => x.trim())
      .filter(Boolean);
  }

  return [];
}

function normalizeCards(value) {
  if (!Array.isArray(value)) return [];

  return value.map((item) => {
    if (typeof item === "string") {
      return { title: item, description: "" };
    }

    return {
      title: item?.title || item?.name || item?.serviceTitle || item?.courseTitle || "Untitled",
      description: item?.description || item?.summary || item?.bio || "",
      link: item?.link || item?.url || "",
    };
  });
}

function renderList(title, items) {
  if (!items.length) return "";

  return `
    <section class="section">
      <h2>${escapeHtml(title)}</h2>
      <div class="skill-grid">
        ${items.map((item) => `<span class="skill-pill">${escapeHtml(item)}</span>`).join("")}
      </div>
    </section>
  `;
}

function renderCards(title, items) {
  if (!items.length) return "";

  return `
    <section class="section">
      <h2>${escapeHtml(title)}</h2>
      <div class="card-grid">
        ${items
          .map(
            (item) => `
              <article class="info-card">
                <h3>${escapeHtml(item.title)}</h3>
                ${item.description ? `<p>${escapeHtml(item.description)}</p>` : ""}
                ${item.link ? `<a href="${escapeHtml(item.link)}" target="_blank" rel="noopener">Open</a>` : ""}
              </article>
            `
          )
          .join("")}
      </div>
    </section>
  `;
}

function renderProfile(data, slug) {
  const displayName = data.displayName || data.name || "SkillForge Creator";
  const headline = data.headline || data.title || "Verified SkillForge Portfolio";
  const bio = data.bio || data.about || "This creator has published a public SkillForge portfolio.";
  const roleType = data.roleType || data.role || "Portfolio";
  const avatarUrl = data.avatarUrl || data.photoUrl || "";
  const location = data.location || "";

  const verifiedSkills = normalizeList(data.verifiedSkills);
  const skills = normalizeList(data.skills);
  const projects = normalizeCards(data.projects);
  const services = normalizeCards(data.services);
  const courses = normalizeCards(data.coursesCreated || data.courses);
  const certificates = normalizeCards(data.certificates);

  setHtml(`
    <main class="portfolio-page">
      <section class="hero">
        <div class="hero-bg"></div>
        <div class="hero-content">
          <div class="avatar">
            ${
              avatarUrl
                ? `<img src="${escapeHtml(avatarUrl)}" alt="${escapeHtml(displayName)}" />`
                : `<span>${escapeHtml(displayName.charAt(0).toUpperCase())}</span>`
            }
          </div>

          <div>
            <p class="eyebrow">SkillForge AI Public Portfolio</p>
            <h1>${escapeHtml(displayName)}</h1>
            <p class="headline">${escapeHtml(headline)}</p>

            <div class="hero-meta">
              <span>${escapeHtml(roleType)}</span>
              ${location ? `<span>${escapeHtml(location)}</span>` : ""}
              <span>/p/${escapeHtml(slug)}</span>
            </div>

            <div class="hero-actions">
              <a href="#work" class="primary-btn">View Work</a>
              <a href="#contact" class="secondary-btn">Contact / Hire</a>
            </div>
          </div>
        </div>
      </section>

      <section class="section">
        <h2>About</h2>
        <p class="about-text">${escapeHtml(bio)}</p>
      </section>

      ${renderList("Verified Skills", verifiedSkills.length ? verifiedSkills : skills)}
      ${verifiedSkills.length ? renderList("Skills", skills.filter((x) => !verifiedSkills.includes(x))) : ""}

      <div id="work"></div>
      ${renderCards("Projects", projects)}
      ${renderCards("Services", services)}
      ${renderCards("Courses", courses)}
      ${renderCards("Certificates", certificates)}

      <section id="contact" class="section contact-card">
        <h2>Contact / Hire</h2>
        <p>This public profile is powered by SkillForge AI. Use the SkillForge platform to connect safely.</p>
      </section>

      <footer class="footer">
        Powered by SkillForge AI
      </footer>
    </main>
  `);
}

async function main() {
  const slug = getSlug();

  console.log("Resolved slug:", slug);

  if (!slug) {
    setHtml(`
      <main class="state-page">
        <h1>Portfolio slug is missing</h1>
        <p>Open a portfolio link like:</p>
        <code>/p/your-slug</code>
      </main>
    `);
    return;
  }

  if (!window.firebaseConfig || !window.firebaseConfig.projectId) {
    setHtml(`
      <main class="state-page error">
        <h1>Portfolio website is not configured</h1>
        <p>config.js is missing or Firebase projectId is not set.</p>
      </main>
    `);
    return;
  }

  if (!window.firebase?.initializeApp || !window.firebase?.firestore) {
    setHtml(`
      <main class="state-page error">
        <h1>Firebase SDK failed to load</h1>
        <p>Check your internet connection or Firebase CDN scripts.</p>
      </main>
    `);
    return;
  }

  firebase.initializeApp(window.firebaseConfig);
  const db = firebase.firestore();

  const path = `publicProfiles/${slug}`;
  console.log("Reading Firestore path:", path);

  const snap = await db.collection("publicProfiles").doc(slug).get();

  console.log("Doc exists:", snap.exists);

  if (!snap.exists) {
    setHtml(`
      <main class="state-page">
        <h1>Portfolio not found</h1>
        <p>No public profile exists for slug:</p>
        <code>${escapeHtml(slug)}</code>
      </main>
    `);
    return;
  }

  const data = snap.data() || {};
  console.log("Profile data:", data);

  const isPublic = data.publicVisible === true || data.isPublic === true;

  console.log("Visibility:", {
    publicVisible: data.publicVisible,
    isPublic: data.isPublic,
    resolved: isPublic,
  });

  if (!isPublic) {
    setHtml(`
      <main class="state-page">
        <h1>This portfolio is private</h1>
        <p>The owner has not published this portfolio yet.</p>
      </main>
    `);
    return;
  }

  renderProfile(data, slug);
}

main().catch((error) => {
  console.error("Portfolio load failed:", error);

  setHtml(`
    <main class="state-page error">
      <h1>Portfolio failed to load</h1>
      <p>${escapeHtml(error.message || error)}</p>
      <p>Check Firestore rules, config.js, and publicProfiles visibility fields.</p>
    </main>
  `);
});