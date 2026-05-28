# Firestore Composite-Index Audit

Last reviewed: 2026-05-28

## Why this matters

Firestore requires a composite index for any query that combines:

- Two or more `.where()` clauses on different fields with equality
- `.where()` on field A plus `.orderBy()` on field B
- `.where(..., arrayContains: ...)` plus `.orderBy()`
- Range filters with sorts on other fields

If the matching index is missing, the live query throws a
`failed-precondition: The query requires an index. You can create it
here:` error at runtime. We've hit this exact error twice during admin
panel development.

## Audit method

```bash
# Find every where/orderBy pattern in the codebase:
grep -nE '\.where\(|\.orderBy\(' lib/ -r --include='*.dart'
```

Cross-reference each combined query with `firestore.indexes.json`.

## Required indexes (mapped to source lines)

| Index | Used by |
|---|---|
| `posts(authorId ASC, createdAt DESC)` | `repositories.dart` line 25-28 — profile timeline |
| `events(isApproved ASC, date ASC)` | `repositories.dart` line 139-141 — public events feed |
| `notifications(userId ASC, createdAt DESC)` | `repositories.dart` line 189-192 + `real_providers.dart` notification stream |
| `trips(userId ASC, startDate DESC)` | `repositories.dart` line 263-265 — passport list |
| `chats(participants CONTAINS, lastMessageAt DESC)` | `repositories.dart` line 335-338 + `real_providers.dart` line 939 — chat list |
| `posts(isReported ASC, reportCount DESC)` | `admin_content_page.dart` (currently sorts in memory; kept for future re-enable) |
| `safeChecks(status ASC, expiresAt DESC)` | Dashboard need-help count (currently single-field with in-memory filter) |
| `reports(status ASC, createdAt DESC)` | `admin_reports_page.dart` (currently in-memory sort) |

## Queries that do NOT need a composite index

These look like they might but don't:

- `.where('name', '>=', q).where('name', '<', q+'z')` — same-field range, single-field auto-index
- `.where('field', isEqualTo: x).limit(N)` — single field, no orderBy
- `.where('participants', arrayContains: uid).get()` — single arrayContains, no orderBy
- `.collection('audit_log').orderBy('timestamp', desc).limit(50)` — single field
- `.where('uid', isNotEqualTo: x).limit(30)` — single field with inequality

## Triple-where queries (potential index gotcha)

`repositories.dart` line 235-238 does:
```dart
.collection('matches')
  .where('userA', isEqualTo: targetUid)
  .where('userB', isEqualTo: uid)
  .where('status', isEqualTo: 'pending')
  .get();
```

This is **3 equality filters with no orderBy**, which Firestore *can*
sometimes serve without a composite index when the matched docs are
sparse — but on a busy collection it may need one. If you see a
`failed-precondition` here in production, add:

```json
{
  "collectionGroup": "matches",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userA",  "order": "ASCENDING" },
    { "fieldPath": "userB",  "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" }
  ]
}
```

## How to deploy

Once the Firebase CLI account has IAM access to `flyconnect-ab4f2`
(currently blocked):

```bash
firebase deploy --only firestore:indexes
```

This deploys both rules and indexes in one command:

```bash
firebase deploy --only firestore
```

Index builds take 5–30 minutes per index on a populated collection.
Monitor progress in Firebase Console → Firestore → Indexes.

## Local validation via emulator

You can lint without deploying by running the emulator:

```bash
firebase emulators:start --only firestore
```

Then run a Flutter test that points at `localhost:8080`:

```dart
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
```

The emulator uses the indexes file the same way production does, so
missing indexes throw the same `failed-precondition` errors. Run the
app or a smoke test against the emulator before deploying.

A turnkey lint script (loops every known query and reports missing
indexes) is on the roadmap but not yet built.

## Process: when adding a new query

1. Write the query
2. Run `grep -nE '\.where\(|\.orderBy\(' lib/ -r --include='*.dart'`
   and check whether your new combination matches an existing index
3. If not, add a new entry to `firestore.indexes.json`
4. Update the table in this file
5. Test against the emulator before deploying
