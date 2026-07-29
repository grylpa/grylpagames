# Font licenses

Every bundled font and its license, verified from each font's embedded name-table
metadata and the matching upstream license file.

| Font file | License | License file here |
|-----------|---------|-------------------|
| OpenSans-SemiBold.ttf | SIL OFL 1.1 (Open Sans Project Authors, 2020) | OpenSans-OFL.txt |
| NotoSansSymbols-Regular.ttf | SIL OFL 1.1 (Noto Project / Google) | NotoSansSymbols-OFL.txt |
| NotoSansSymbols2-Regular.ttf | SIL OFL 1.1 (Noto Project / Google) | NotoSansSymbols2-OFL.txt |
| NotoSansMono.ttf | SIL OFL 1.1 (Noto Project / Google, 2022) | NotoSansMono-OFL.txt |
| JetBrainsMono.ttf | SIL OFL 1.1 (JetBrains, 2020) | JetBrainsMono-OFL.txt |
| Stormfaze.otf | CC0 1.0 (public domain, per embedded metadata) | Stormfaze-LICENSE.txt |
| Exo2.ttf | SIL OFL 1.1 (The Exo 2 Project Authors, 2013) | Exo2-OFL.txt |
| Orbitron.ttf | SIL OFL 1.1 (The Orbitron Project Authors, 2018) | Orbitron-OFL.txt |
| Baloo2.ttf | SIL OFL 1.1 (The Baloo 2 Project Authors, 2019) | Baloo2-OFL.txt |
| SpaceGrotesk.ttf | SIL OFL 1.1 (The Space Grotesk Project Authors, 2020) | SpaceGrotesk-OFL.txt |

`Stormfaze.otf`, `Exo2.ttf`, `Orbitron.ttf`, `Baloo2.ttf` and `SpaceGrotesk.ttf`
are the selectable GAME FONTS — the player picks one in Settings (About → Game
font) and it becomes the theme's default font. See `MainGlobals.GAME_FONTS`. The
last four are variable fonts, used at weight 600 via a `FontVariation`.

`JetBrainsMono.ttf` is the monospace font used by Typit (reference/typed text and
the keys comparison) for its clear look-alike disambiguation. `NotoSansMono.ttf`
is also bundled as an alternative.

Orbitron carries a Reserved Font Name, so a *modified* copy could not keep the
name "Orbitron". We ship it unmodified, which the OFL allows.

All licenses (OFL 1.1 and CC0) permit use, embedding and redistribution in an
application, including commercially. OFL requires the license text to ship
alongside the fonts (done) and forbids selling the fonts on their own.
