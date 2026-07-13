# Aura visual-diff review — implementation pass

## Implemented from Source 1

- Catalog follows the source order: selected venue, profile action, search,
  horizontal categories, a 2-column product grid and floating cart summary.
- Product cards reserve their upper ~65% for the item image; title wraps to two
  lines and price remains anchored at the lower edge.
- PDP is image-first with a 24 px lower configuration sheet, size controls,
  modifiers and a fixed quantity/price CTA.
- Cart uses compact product rows, circular quantity controls, recommendation
  rail, receiving/payment rows and an anchored total.
- Light and dark palettes share the same composition. The chosen theme is
  persisted locally and exposed in Profile → Theme.
- First launch now has a distinct welcome CTA; existing saved installations
  skip it and retain their current city/venue flow.

## Intentional differences

- «Кофе Мама» uses its own name, Russian copy, product media and Object Storage
  URLs. No logo, photograph or textual asset from the Behance source is reused.
- The source does not cover city, venue, auth, profile and order flows. These
  screens use the same typography, compact surfaces and tokens while retaining
  their established application behaviour.
- No visual device run was performed in this pass because Flutter/Dart commands
  are intentionally excluded. Manual review remains required at 375×812,
  390×844 and a narrow Android viewport.
