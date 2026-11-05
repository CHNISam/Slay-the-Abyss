# Public prototype asset provenance

This is a public, noncommercial browser design prototype. It does not grant third-party IP rights or certify production readiness. The repository LICENSE-SCOPE.md applies: imagery, fonts, character names and third-party IP are not relicensed by the source-code license.

## Retained project and user materials

- `traveler-battle.png`, `traveler-avatar.png`, `traveler-reference.png`: existing project AI-generated Traveler illustrations. The battle and avatar sources correspond to `art/characters/traveler-geo/portraits/battle133/source.png` and `avatar96/source.png`. These are not official HoYoverse artwork. Generated artwork does not establish ownership of the underlying character IP.
- `sta-cover.jpeg`: project cover supplied by the user for this prototype.
- `constellation-exact.png`: icon supplied by the user, copied byte-for-byte. SHA-256: `5780bc541d322b369b61f656908da59bdeee7f3ad83988edca8be23776720ecd`. The 2026-11-05 selection-screen correction uses its unchanged alpha silhouette as a warm-gold CSS mask (`#ffe0a2`), matching the user's full-screen reference rather than redrawing the shape.
- `menu-reference-background.png`, `menu-reference-logo.png`, `settings-reference-background.png`: generated from the user's supplied design references for this browser prototype. These are not extracted game assets.
- These project/user materials are retained under the user's explicit instruction to archive this prototype publicly. That instruction is not independent proof of third-party ownership or a blanket downstream license. Production use, redistribution and applicable fan-content rules still require review.

## Removed comparison assets and replacements

The private study contained 12 original Slay the Spire rasters: Ironclad/colorless card bases, common rarity frames/banner, the GOG-store logo and a colorless mana emblem. Original card components came from `https://maybelatergames.co.uk/spirespy/assets/cards/`; the logo came from GOG's store CDN. No public redistribution permission was established, so these rasters and the three embedded card-base copies are excluded from this public snapshot.

Twelve platform-preview rasters are also excluded: node icons 100114, 102002, 102025, 102028, 102033, 102034, 102044; deck 105046; geo 102005; and attack/skill/power type icons 102012, 102014, 102024. Their earlier mapping came from `data/presentation/ui_theme.json`; platform preview access does not itself grant redistribution permission.

The same-stem `.svg` files are newly authored simple geometry and text, not conversions, tracings or encoded copies of those rasters. File names remain stable for module compatibility. `excluded-private-assets.json` records the excluded raster SHA-256 values and the source revision for auditing without including the images.

Prior screenshots, the screenshot gallery and environment-specific verification script are not included. External reference pages remain links only. No full third-party screenshot is bundled as a UI component.

## Code-drawn graphics and font

Map and UI shapes in CSS/SVG are code-drawn reference studies. They are not verified original game assets or a claim of game-IP rights. Layout and game names may still refer to the studied games.

The embedded Kreon font in `sts-map-restore.css` is from Google Fonts, not extracted from a game. It remains under SIL Open Font License 1.1; the complete copyright and license notice is preserved in that file. Upstream notice: `https://github.com/google/fonts/blob/main/ofl/kreon/OFL.txt`.

No changes to the repository's license or public asset policy are made by this snapshot.

## 2026-11-05 update

Upstream private source: 63d9364ce60bb79ffc720c23902bfa58d5e930ab. All newly introduced original rarity PNGs, red-orb PNG, and raster-embedding Geo SVGs remain excluded. Public geo-card-zhongli-* and geo-cost-icon-priority.svg are deliberately simple geometric substitutes, not conversions or tracings. Original power illustrations remain external reference links only; sampled flat background colors do not reproduce their artwork.

Two embedded OFL font subsets are included with complete notices in FONT-LICENSES.txt: system Noto Sans Mono CJK SC Regular (NotoSansCJK-Regular.ttc index7) and Noto Serif CJK SC Bold (NotoSerifCJK-Bold.ttc index2), subset names Prototype Card Sans and Prototype Card Type. Fonts originate from Noto, not a game package; browser rendering and type-serif version are not pixel-identical to the game. Upstream license: https://github.com/notofonts/noto-cjk/blob/main/Sans/LICENSE .

### Unified power placeholder correction
All four power portraits use the same dark blue-purple #252536, sampled from pixel(70,140) in the500×380 Inflame image: https://github.com/nkhoit/spire-archive/blob/4e6b0e040ccd00eb04fb1ab7fb0b298c222d2f29/public/images/sts1/cards/inflame.png . Only the background left of the fire blade is referenced; no source illustration pixels or smoke/fire artwork are bundled. This replaces the previous per-card background sampling to follow the user's consistency requirement, without claiming the original game has a universal power color.

## Approved-design adoption update

The 2026-11-05 adoption update incorporates the result screen and current-page-only run state from private source `7e40d2d361fff6b9c89d9f409db29a9d8ac44352`. The prior public source `84da1d3b2ac889fe9a9fa9cb48779ba255be99ea` and its safe geometric substitutes remain the public visual base. No new third-party raster is added.

`victory-easter-egg.png` is excluded: it derives from the existing HoYoverse / ufotable concept-trailer frame and public redistribution rights have not been established. Its SHA-256 is added to `excluded-private-assets.json`. The public interaction opens a source/boundary notice instead of the picture; it does not hotlink the image. The approved private artwork and design are not modified by this publication substitute.
