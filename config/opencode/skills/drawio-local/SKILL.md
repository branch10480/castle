---
name: drawio-local
description: Create draw.io (diagrams.net) diagrams entirely locally without uploading to any server, and let users choose a visual theme. Use when users say “drawio/draw.io/diagrams.net”, ask to make draw.io files, or when a draw.io MCP tool is involved and confidentiality/offline requirements prohibit app.diagrams.net uploads.
---

# Drawio Local

## Overview

- Produce `.drawio` files as local outputs only.
- Never open or rely on any remote editor or upload service (including app.diagrams.net).
- Require a visual theme selection; if the user is unsure, generate local preview files for each theme.

## Workflow

1. Gather requirements: diagram type, nodes/edges, labels, and desired output path.
2. Ask for a visual theme (see `references/themes.md`).
   - Use Japanese names when presenting choices.
   - If the user is unsure, generate local preview `.drawio` files (one per theme) with a tiny 3-node sample so they can open and compare locally.
3. Build the `.drawio` XML using the selected theme styles.
4. Write the `.drawio` file to the requested local path and confirm how to open it (draw.io desktop app or any local diagrams.net-capable editor).
5. Do not use `mcp__drawio__open_drawio_*` tools or any web UI.

## XML Construction Rules

- Use draw.io XML (`mxfile` + `diagram` + `mxGraphModel`).
- For each node, set `style` to the theme's `nodeStyle` and provide `mxGeometry` with `x`, `y`, `width`, and `height`.
- For each edge, set `style` to the theme's `edgeStyle`, and set `source` and `target` to node ids.
- Keep ids stable and unique (e.g., `n1`, `n2`, `e1`).

Minimal template:

```xml
<mxfile host="app.diagrams.net" modified="2020-01-01T00:00:00.000Z" agent="drawio" version="20.0.0">
  <diagram name="Page-1">
    <mxGraphModel dx="1000" dy="1000" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="850" pageHeight="1100" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="n1" value="Start" style="{NODE_STYLE}" vertex="1" parent="1">
          <mxGeometry x="80" y="80" width="160" height="60" as="geometry" />
        </mxCell>
        <mxCell id="n2" value="Next" style="{NODE_STYLE}" vertex="1" parent="1">
          <mxGeometry x="320" y="80" width="160" height="60" as="geometry" />
        </mxCell>
        <mxCell id="e1" value="" style="{EDGE_STYLE}" edge="1" parent="1" source="n1" target="n2">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

Replace `{NODE_STYLE}` and `{EDGE_STYLE}` with values from `references/themes.md`.

## Resources

- Theme catalog and style tokens: `references/themes.md`
