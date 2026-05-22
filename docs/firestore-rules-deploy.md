# Deploying `firestore.rules`

The committed `firestore.rules` enforces server-side security
(role-based access, field-level write whitelisting). It must be
deployed to production for the rules to take effect.

## Prerequisites

1. **Firebase CLI** installed and authenticated:
   ```bash
   npm install -g firebase-tools
   firebase login
   ```
2. **IAM access** on the `flyconnect-ab4f2` project. The deploying
   account needs at least `Firebase Rules Admin` role
   (or `Editor` / `Owner` on the project).

## Files in the repo

- `firebase.json` — points `firestore.rules` at the production source
- `.firebaserc` — default project: `flyconnect-ab4f2`
- `firestore.rules` — the rules themselves
- `firestore.indexes.json` — composite indexes (deploy together)

## Deploy command

```bash
firebase deploy --only firestore:rules
```

To deploy rules + indexes together:

```bash
firebase deploy --only firestore
```

## Troubleshooting

### 403 "Caller does not have required permission to use project"

The signed-in CLI account lacks IAM on the project. Ask the project
owner (whoever has Owner/Editor on `flyconnect-ab4f2`) to:

1. Open https://console.firebase.google.com/project/flyconnect-ab4f2/settings/iam
2. Click **Add member**
3. Add your email with role **Firebase Rules Admin** (least privilege)
   or **Editor** (broader)
4. Retry the deploy

### "firebase use must be run from a Firebase project directory"

You're not in the repo root. `cd` to `C:\Projects\Fly Connect 2`.

### Need to test rules before deploying?

```bash
firebase emulators:start --only firestore
```

Spins up a local emulator on port 8080 with the rules applied. Useful
for iterating on rule changes without hitting production.
