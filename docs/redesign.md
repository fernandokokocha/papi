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
it. Steps 27–35 in particular are shared.

While the rebuild is in progress the version and candidate request specs are
red. Every red example is a content assertion for something not yet rebuilt, so
that list doubles as the check that nothing was dropped. It reaches zero at
step 35.

## Steps

### Endpoint card — unchanged

1. ~~Card shell + header row (verb badge, path)~~ — done
2. ~~Section bands~~ — done
3. ~~Response row — status code + description~~ — done
4. ~~Schema block — monospace lines, indentation~~ — done
5. ~~Params, Query and Auth sections~~ — done
6. ~~Syntax colours~~

### Endpoint card — changed

7. ~~Line tints — added / removed / type_changed~~
8. Two-column alignment and the changed-card treatment

### Whole-card states

9. Endpoint added
10. Endpoint removed

### Affordances

11. Expand / collapse
12. History link
13. Copy cURL

### Entity cards

14. unchanged
15. changed
16. added
17. removed

### Auth cards

18. unchanged
19. changed
20. added
21. removed

### Page level

22. Version identity — project, name, date, proposed/merged by
23. Comparison control — "Compared with" select + Current
24. Release notes
25. Version navigation — ← →, View candidate
26. Actions — Export OpenAPI, Import OpenAPI, New candidate

### Sidebar

27. Shell + collapse toggle
28. Endpoint list — verb badges, paths, path grouping, truncation
29. Entities and Auth sections
30. Scroll-spy active state

### Comment layer

31. Count badges — sidebar and card
32. Line note badges + hover cards
33. Card-level threads
34. Reply and resolve
35. Comment / Display toolbar

### Shell

36. Page background, content width, vertical rhythm
37. Topbar identity — logo, user, log out
38. Sticky behaviour
