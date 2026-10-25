# Design direction

Nichosi is a quiet, local-first database workspace with an original visual identity. The approved table workspace is the baseline for future database screens. A user-provided reference informed its broad layout and information density; do not copy another product's branding, icons, or distinctive visual details.

## Table workspace

- Use a compact top bar for row search, database and schema breadcrumbs, and a small set of contextual actions.
- Keep a narrow app navigation rail beside a database-object tree. The object tree shows the active connection, database, schema, and tables.
- Give the data grid most of the available space. Keep row actions at the left, column names and types in the header, and pagination and row counts in a quiet footer.
- Prefer clear, practical labels and familiar line icons. Use Lucide or Tabler icons and check the package license before redistributing bundled assets.
- Use restrained borders, subtle hover states, and rounded controls. Avoid decorative glow, strong gradients, and oversized hero sections inside data-workspace screens.

## Color and type

- Use neutral graphite surfaces as the default dark theme. Avoid a green cast across backgrounds and panels.
- Reserve a soft grass-green accent, around `#83c96f`, for focus, active navigation, and a small number of primary actions. Keep the accent distinct from the neutral surfaces.
- Use readable system typography. Table content should remain compact enough for scanning while labels and controls stay comfortably legible; avoid tiny metadata text.
- Preserve visible keyboard focus, sufficient contrast, and clear disabled states. Do not communicate state by color alone.

## Product behavior

- Keep the connections screen focused on saved connections. When none exist, show the first-connection guidance; when connections exist, show their database type, size, last connection, and an unavailable state where metadata cannot be provided.
- Visual prototypes must be explicitly labeled. Do not imply that database features work until they are connected to the API.
- Do not use third-party screenshots, logos, product names, or distinctive layouts as design targets. Use any user-provided reference only for high-level layout guidance unless the user explicitly asks otherwise.
