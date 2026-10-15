# DevPurge interface direction

Reference: the hierarchy of a desktop storage inspector: volume summary above a
compact, selectable file inventory, with an explicit review step. This is a new
interface; no previous visual design has been approved.

Warm limestone surfaces, graphite text, and restrained pine-green actions. Dark
mode uses charcoal surfaces with pale green actions. Statuses always include text.
Use Avenir Next (sans-serif fallback) for headings/body and Menlo (monospace
fallback) for sizes and paths. No external font downloads.

Spacing: 4, 8, 12, 16, 24, 32, 48 pixels. Radii: 6px controls, 12px panels.
One main action per stage: Scan storage, Review selection, Confirm cleanup.
Keep free disk space, scanned storage and selection sizes clearly distinguished.

Use native controls, visible keyboard focus, readable contrast, labeled checkboxes,
and a focused modal review. Empty, scanning, error and partial-success states must
be explicit. Respect reduced motion; transitions should explain status changes.
For a browser implementation, collapse columns gracefully at 320px and support
light/dark preference. A native implementation follows system appearance.
