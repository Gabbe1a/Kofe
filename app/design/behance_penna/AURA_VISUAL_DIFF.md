# Aura visual-diff review — implementation pass

## Implemented from Source 1

- Catalog follows the source order: selected venue, profile action, search,
  horizontal categories, a 2-column product grid and floating cart summary.
- Product cards reserve their upper ~65% for the item image; title wraps to two
  lines and price remains anchored at the lower edge.
- Catalogue media now sits inside a 5 px white card reveal, matching the
  reference's near-edge image scale; title and price keep their 10 px reading
  inset independently of the larger photo.
- PDP is image-first with a 24 px lower configuration sheet, size controls,
  modifiers and a fixed quantity/price CTA.
- Cart uses compact product rows, circular quantity controls, recommendation
  rail, receiving/payment rows and an anchored total.
- Light and dark palettes share the same composition. The chosen theme is
  persisted locally and exposed in Profile → Theme.
- First launch now has a distinct welcome CTA; existing saved installations
  skip it and retain their current city/venue flow.
- Active orders are separated from history: a persistent compact card above
  the bottom navigation opens a live order screen. Its vertical tracker uses a
  visible «Сейчас» label, larger current stage, completed checkmarks and muted
  future stages; `issued` removes the live card and returns the order to history.
- Cart product rows now follow the borderless Source 1 composition, with a
  plain centered title and circular controls. Profile groups and checkout
  surfaces no longer receive an automatic outline.
- Dark profile colours are contextual rather than static: graphite surfaces,
  off-white text and muted secondary copy preserve the source hierarchy.
- Profile identity and navigation now live directly on the page canvas instead
  of nested white cards. The single 20 px page inset controls alignment, while
  spacing and hairline dividers retain grouping and free horizontal space.
- Cart fulfillment/payment rows now use that same page-canvas composition.
  Recommendation tiles also lose their outer white shell, allowing wider media
  and labels without reducing the established 20 px page inset.
- The venues screen is one continuous vertical scroll: the map, heading and
  address list move together. Address rows are transparent and separated by
  hairlines; the embedded map is a scroll-friendly preview and its fullscreen
  action retains interactive map navigation.
- Venue controls, selected markers, order-state badges and cart switches now
  resolve through the contextual graphite palette. Yandex MapKit enables its
  night rendering in dark mode, avoiding white map and black-on-black states.
- Profile data fields sit directly on the page canvas; notification inbox
  navigation and the persisted notification toggle are separate actions.
- Pickup venue selection validates the full persisted configuration against
  the target venue menu before retaining the cart and updating its prices.
- The category rail owns the full viewport width and can scroll beneath both
  page edges, while its resting first chip and the product grid retain the
  20 px content inset.
- Order history uses short server-issued numbers. Repeating an order restores
  every available line, quantity, size and modifier into one cart instead of
  opening an arbitrary product card.

## Intentional differences

- «Кофе» uses its own name, Russian copy, product media and Object Storage
  URLs. No logo, photograph or textual asset from the Behance source is reused.
- The source does not cover city, venue, auth, profile and order flows. These
  screens use the same typography, compact surfaces and tokens while retaining
  their established application behaviour.
- No visual device run was performed in this pass because Flutter/Dart commands
  are intentionally excluded. Manual review remains required at 375×812,
  390×844 and a narrow Android viewport.
- The new active-order bar and tracker were reviewed structurally for wrapping
  and flexible width, but still require the same manual device pass for final
  height and keyboard/safe-area confirmation.
