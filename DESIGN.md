# Media QC Inspector Design Notes

## Core principles

- Keep result badges consistent across the app.
- Keep reports plain text.
- Keep queue density high.
- Preserve the soft blue selected state.
- Favor clear production language over developer language.

## Shared values

- Card corner radius: 12
- Metric card corner radius: 8
- PASS color: green
- FAIL color: red
- ANALYZING color: blue
- METADATA FAILED color: orange
- Status text should remain neutral when the result badge is present.

## Components

- `ResultBadgeView` large style: used in the detail panel.
- `ResultBadgeView` compact style: used in the queue.
- Queue cards should remain compact and readable.
- Detail panel should emphasize the analysis result first.

## Typography

- Use bold, clear labels for outcomes.
- Keep metric labels small and secondary.
- Keep filenames prominent but secondary to the result badge.