# SkillForge Public Portfolio Hosting

The static portfolio app lives in `portfolio_web/` and reads only:

```text
publicProfiles/{slug}
```

It does not require login, Cloud Functions, or paid hosting.

## Configure

1. Copy `portfolio_web/config.example.js` to `portfolio_web/config.js`.
2. Add your Firebase web config.
3. Do not add private service account keys.

## Netlify Setup

1. Push the project to GitHub.
2. Go to the Netlify dashboard.
3. Add a new project.
4. Import the existing SkillForge repository from GitHub.
5. Set the base directory to `portfolio_web`.
6. Build command: leave empty.
7. Publish directory: `.` when the base directory is `portfolio_web`.
8. Deploy.
9. Copy the Netlify site URL.
10. In SkillForge Admin > Release Center Config, set:

```text
portfolioBaseUrl=https://your-site.netlify.app
```

11. Enable public portfolio links and save.
12. Publish a portfolio from Portfolio Builder.
13. Open:

```text
https://your-site.netlify.app/p/{slug}
```

`portfolio_web/netlify.toml` includes redirects so `/p/{slug}` opens the same
static app and loads the Firestore profile by slug.

## Cloudflare Pages

1. Push the repository to GitHub.
2. Create a Pages project.
3. Build command: none.
4. Output directory: `portfolio_web`.
5. Add a Pages redirect equivalent for `/p/* -> /index.html`.
6. Open `https://your-site.pages.dev/p/{slug}`.

## Firebase Hosting

Use a separate hosting target if preferred:

```bash
firebase target:apply hosting portfolio-public skillforge-portfolio
firebase deploy --only hosting:portfolio-public --project skillforge-ai-4f2da
```

Set the public directory to:

```text
portfolio_web
```

## Firestore Rules

Public reads must be limited to:

```text
publicProfiles/{slug} where publicVisible == true
```

Never query private collections such as `users`, `attempts`, `wallets`,
`studentAiTutorThreads`, or private LMS progress from the public app.

## Custom Domain

Netlify does not deploy one site per portfolio. One deployed `portfolio_web`
site serves all `publicProfiles/{slug}` documents. New public profiles appear
as soon as Firestore contains a visible public profile document.

After deployment, set `portfolioBaseUrl` in the SkillForge admin config. The
main app will not generate fake public links when this value is missing.
