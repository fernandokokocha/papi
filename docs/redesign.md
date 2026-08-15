# Redesign

The app was built for function and looks it. This is a skin, not a rework: the
information on each page is there because it was needed, and the general
structure of the views is not expected to change.

## How

Page by page, rebuilt from an empty template rather than restyled in place.
Elements come back one at a time, each redesigned until it is satisfying, and
what is settled stays — later elements adapt to it, not the reverse. Where a
later element genuinely breaks a settled one, that is said out loud rather than
quietly restyled.

No design system up front. Each element brings the classes it needs; a
treatment earns a name once it appears a second time. `/design-preview` is
rebuilt at the end, from what actually landed.

One commit per settled step, so `git log` is the record of what is done.

The version page goes first. Its guts live in `versions/_endpoints_and_entities`,
which `candidates/show` also renders, so most of the candidate page comes with
it. Steps 25–33 in particular are shared.

While the rebuild is in progress the version and candidate request specs are
red. Every red example is a content assertion for something not yet rebuilt, so
that list doubles as the check that nothing was dropped. It reaches zero at
step 33.

## Steps

### Endpoint card — unchanged

1. ~~Card shell + header row (verb badge, path)~~ — done
2. Section bands — NOTE / INPUT / RESPONSES
3. Response row — status code + description
4. Schema block — monospace lines, indentation, syntax colours

### Endpoint card — changed

5. Line tints — added / removed / type_changed
6. Two-column alignment and the changed-card treatment

### Whole-card states

7. Endpoint added
8. Endpoint removed

### Affordances

9. Expand / collapse
10. History link
11. Copy cURL

### Entity cards

12. unchanged
13. changed
14. added
15. removed

### Auth cards

16. unchanged
17. changed
18. added
19. removed

### Page level

20. Version identity — project, name, date, proposed/merged by
21. Comparison control — "Compared with" select + Current
22. Release notes
23. Version navigation — ← →, View candidate
24. Actions — Export OpenAPI, Import OpenAPI, New candidate

### Sidebar

25. Shell + collapse toggle
26. Endpoint list — verb badges, paths, path grouping, truncation
27. Entities and Auth sections
28. Scroll-spy active state

### Comment layer

29. Count badges — sidebar and card
30. Line note badges + hover cards
31. Card-level threads
32. Reply and resolve
33. Comment / Display toolbar

### Shell

34. Page background, content width, vertical rhythm
35. Topbar identity — logo, user, log out
36. Sticky behaviour

## Settled

**1 · Card shell.** Two panels per card, one per version, 8px apart on the page
background — the gap is what makes it read as two versions rather than one
split card. Each panel carries its own sticky header, so a path whose param was
renamed still shows both spellings. Header is a grey strip with a hairline
rule, not a fill: the element that repeats forty times is not the loudest thing
on screen.

Verb chips are tinted rather than filled, at 12px in a 52px shared width so the
paths line up down the page — `DELETE` sets that width, and every other verb is
padded up to it. PATCH took amber and PUT took violet, diverging from Swagger
UI's palette, because Swagger's PUT-orange and PATCH-teal are indistinguishable
at low saturation. Path is 13px mono, with a real space before it so selecting
the header copies `GET /attachments`.

The card cannot use `overflow-hidden` for its rounded corners — an
`overflow-hidden` ancestor kills `position: sticky` in its descendants, so the
header rounds its own top corners instead.

Colour in the header encodes identity (the verb), where GitHub's file header
spends its only colour on change. That is a deliberate exception: the verb is
the main scanning key in an API doc in a way a filename never is.

Deferred from this step: how much the card should contrast with the page waits
for step 34, when there is real content inside it to judge against.
