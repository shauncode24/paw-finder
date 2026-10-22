# 0003: Search, filters and distance run on the phone

**Status:** accepted

## Context
Firestore needs a composite index for most queries that combine filters and sorting, and every document read counts against the free quota.

## Decision
`ListingsService` keeps **one live listener** on active listings (newest 500). `PetFilters.matches`, distance and sorting are computed on the phone from that list.

## Consequences
- No Firestore indexes to create, and browsing costs almost no extra reads.
- Search can be as flexible as we like (every word across name, breed, temperament, story...).
- The feed is capped at 500 listings; beyond that the oldest drop out. At that scale, move to server-side queries with geohashes and indexes.
- Other lists follow the same idea: foster directory (300), reviews per lister (100), journey updates (100).
