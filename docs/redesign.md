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
it. Steps 26–34 in particular are shared.

While the rebuild is in progress the version and candidate request specs are
red. Every red example is a content assertion for something not yet rebuilt, so
that list doubles as the check that nothing was dropped. It reaches zero at
step 34.

## Steps

### Endpoint card — unchanged

1. ~~Card shell + header row (verb badge, path)~~ — done
2. ~~Section bands~~ — done
3. ~~Response row — status code + description~~ — done
4. Schema block — monospace lines, indentation, syntax colours
5. ~~Params, Query and Auth sections~~ — done

### Endpoint card — changed

6. Line tints — added / removed / type_changed
7. Two-column alignment and the changed-card treatment

### Whole-card states

8. Endpoint added
9. Endpoint removed

### Affordances

10. Expand / collapse
11. History link
12. Copy cURL

### Entity cards

13. unchanged
14. changed
15. added
16. removed

### Auth cards

17. unchanged
18. changed
19. added
20. removed

### Page level

21. Version identity — project, name, date, proposed/merged by
22. Comparison control — "Compared with" select + Current
23. Release notes
24. Version navigation — ← →, View candidate
25. Actions — Export OpenAPI, Import OpenAPI, New candidate

### Sidebar

26. Shell + collapse toggle
27. Endpoint list — verb badges, paths, path grouping, truncation
28. Entities and Auth sections
29. Scroll-spy active state

### Comment layer

30. Count badges — sidebar and card
31. Line note badges + hover cards
32. Card-level threads
33. Reply and resolve
34. Comment / Display toolbar

### Shell

35. Page background, content width, vertical rhythm
36. Topbar identity — logo, user, log out
37. Sticky behaviour
