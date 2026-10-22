# 0002: Photos are stored inside Firestore documents

**Status:** accepted

## Context
Pet photos, avatars, chat photos and journey photos have to be shared between phones. Cloud Storage needs the paid plan (ADR 0001).

## Decision
Store photos as **base64 text inside Firestore documents**, shrunk first (`ImageCompressor`): a 280px thumbnail in the listing, up to five 900px photos in `listings/{id}/photos`, 800px chat and journey photos, 160px avatars. Views use a private `pfphoto:` URL scheme resolved by `PhotoLoader`, or `Base64Photo` for text-embedded photos.

## Consequences
- Each document must stay under Firestore's 1 MB limit, so photos are small and limited to five per listing.
- Base64 adds about a third to the size; roughly 1,000 listings fit in the free 1 GiB.
- Switching to Cloud Storage later only touches `PhotoLoader`, `ImageCompressor` and the places that write photos; screens keep using URLs.
- Sensitive application attachments (ID, lease) are deliberately **not** uploaded.
