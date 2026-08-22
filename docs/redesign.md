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
it. Steps 28–40 in particular are shared.

While the rebuild is in progress the version and candidate request specs are
red. Every red example is a content assertion for something not yet rebuilt, so
that list doubles as the check that nothing was dropped. It reaches zero at
step 50, once two examples asserting Import OpenAPI on the version page are
deleted — that page no longer carries it.

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
8. ~~Two-column alignment and the changed-card treatment~~

### Whole-card states

9. ~~Endpoint added~~
10. ~~Endpoint removed~~
11. ~~Response added / removed inside a changed card~~

### Affordances

12. ~~Expand / collapse~~
13. ~~History link~~
14. ~~Copy cURL~~

### Entity cards

15. ~~unchanged~~
16. ~~changed~~
17. ~~added~~
18. ~~removed~~

### Auth cards

19. ~~unchanged~~
20. ~~changed~~
21. ~~added~~
22. ~~removed~~

### Page level

23. ~~Version identity — project, name, date, proposed/merged by~~
24. ~~Comparison control — "Compared with" select + Current~~
25. ~~Release notes~~
26. ~~Version navigation — ← →, View candidate~~
27. ~~Actions — Export OpenAPI, Import OpenAPI, New candidate~~

### Sidebar

28. ~~Shell + collapse toggle~~
29. ~~Endpoint list — verb badges, paths, path grouping, truncation~~
30. ~~Entities and Auth sections~~
31. ~~Scroll-spy active state~~

### Comment layer

32. ~~Count badges — sidebar and card~~
33. ~~Line note badges + hover cards~~
34. ~~Card-level threads~~
35. ~~Region threads~~
36. ~~Line threads~~
37. ~~Outdated line threads — the snapshot drifted, so there is no line to sit on~~
38. ~~Reply and resolve~~
39. ~~Comment / Display toolbar — and with it the whole act of writing a
    comment~~
40. Whether the version and candidate views unify — a decided candidate is
    still commentable, and the version page shows no comments at all

### Shell

41. ~~Page geometry — full-bleed shell, sidebar column, diff pane~~
42. Topbar identity — logo, user, log out
43. ~~Sticky behaviour — the page scrolls, the rail pins, the sidebar holds its own scroll~~

### History page

44. Milestone cards — the version-page card, compared against `milestone.before`
45. Milestone header — version, kind, since, date, author, candidate
46. Page header — project, endpoint or entity identity, count, empty state

### Candidate page

47. Identity — project, name, state chip, proposed / decided by
48. Approvals — count, approvers, the approve toggle
49. Comparison rail and actions — Edit, Reject, Merge; View version when merged
50. Conversation — candidate-level threads and the compose form

### Minor pages

51. Projects list — project rows, latest version, entry points
52. Project history — the Table / Activity toggle
53. Auth — log in, forgot password, reset password
54. Small forms — new project, import OpenAPI

### Last

55. Candidate form — the schema editor
56. `/design-preview`, rebuilt from what landed
