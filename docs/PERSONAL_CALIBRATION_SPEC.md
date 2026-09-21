# Personal Havoc calibration

Accept a local standard SimulationCraft character export, not arbitrary SimC
instructions. Normalize one level-90 Havoc actor, talents, race, full equipped
gear and supplied consumables. Preserve item modifiers, gems and enchants; reject
unsupported fields rather than silently omitting their effect. Remove character
name/server/region metadata. Never import another profile, APL, file or URL from
the supplied character text. Require all 16 combat slots; empty/partial gear is
outside this first version. Optional shirt/tabard are supported.

Validate the pinned engine and reference profile hashes. Take only APL lines
from the reference; never inherit its gear, talents or consumables. Evaluate the
reference plus a bounded family of own policies with identical character input,
scenario settings and reference envelope. Separate discovery and holdout seeds.
Freeze the selected candidate before holdout, then compare it with the reference
in every scenario using three times the sum of marginal standard errors.

Partition artifacts by the complete experiment identity. Validate raw output
character talents, race, level and every input gear modifier as well as engine,
game build, sample count, timing and scenario identity. Cached results are not
trusted without revalidation. Retain failed/lower-performing evidence. Partial
runs never become a completed report. Report the best tested candidate only;
never claim theoretical maximum, live battlefield equivalence, or runtime
qualification. Do not install a selected offline policy into the addon.

Provide a local launcher and a ZIP containing scripts, frozen own policy and
instructions. Locate installed pinned SimC/reference files, or accept explicit
paths; do not include a third-party executable in the kit. No new Python package
is required for execution. Validate with an upstream-derived public export and
real SimC, clearly separated from an actual user's capture.

Test-Lock scenario 3: additive parser, isolation, identity, holdout and generated
modifier preservation cases plus mutation checks.
