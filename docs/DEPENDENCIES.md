# Bundled dependency provenance

RotaAssist release ZIPs are standalone: `embeds.xml` loads the copies under
`RotaAssist/Libs`, so users do not need to install Ace3 or a minimap library as
separate addons. `scripts/verify_package.py` follows the TOC and nested XML
includes and rejects a package when any referenced library file is absent,
mis-cased, or modified relative to `SHA256SUMS.txt`.

## LibDBIcon

The `1.1.1-rc.1` local candidate uses LibDBIcon-1.0 minor 43 from the WowAce
SVN mirror commit:

- repository: `https://github.com/wowace-clone/LibDBIcon-1.0`
- commit: `cf61a961979ad54910a402aedf0b9bb45200959f`
- file: `LibDBIcon-1.0/LibDBIcon-1.0.lua`
- vendored file SHA-256: `3b6a6201188f7953aaef51708efc7f610d6ccb2edb976d32dfc98beae0e91851`

The previous local minor-34 copy registered callbacks that read WoW's removed
global `this` value. Static inspection showed those handlers would dereference
`this` during minimap hover, click, drag, and mouse events. Minor 43 takes the
frame and button from callback parameters (`self`, `button`) and passed the
offline ordered-load smoke test. This is evidence for fixing the interaction
path; it is not a claim of in-client verification.

LibDataBroker-1.1 matches upstream commit
`1a63ede0248c11aa1ee415187c1f9c9489ce3e02`; the bundled Lua file SHA-256 is
`d79b3eada649684543bbbc3c511c2515e16d644f198fa991a201ee64d045b0f2`.

## Source checkout limitation

`addon/Libs/` is intentionally ignored by `.gitignore` and is populated by the
maintainer's dependency/bootstrap process. A plain source checkout may therefore
lack required embedded files. In that state the local packager fails its source
TOC/XML dependency check and does not create a ZIP. The distributable ZIP under
`dist/1.1.1-rc.1/` contains the complete libraries and their license files.

The current `.pkgmeta` still describes external retrieval for hosted packaging,
but it uses moving `latest` references and is not the reproducibility mechanism
for this local candidate. The authoritative integrity record for the delivered
candidate is its internal `SHA256SUMS.txt` plus the adjacent ZIP `.sha256` file.
