# SkillForge Public Portfolio Web

Static public portfolio viewer for `publicProfiles/{slug}`.

## Run locally

1. Copy `config.example.js` to `config.js`.
2. Add your Firebase web config in `config.js`.
3. Serve this folder with any static server.

Example:

```bash
npx serve .
```

Open:

```text
http://localhost:3000/#/p/your-slug
```

The app reads only `publicProfiles/{slug}` and displays the profile only when
`publicVisible == true`.
