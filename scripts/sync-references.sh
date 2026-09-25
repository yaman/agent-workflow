#!/usr/bin/env bash
# Regenerate the per-skill copies of the shared reference files from the single
# source in references/. The copies exist because a skill must be self-contained
# on disk for `npx skills` and for a plain directory install; this script keeps
# them from drifting. Run after editing references/*.md.
set -euo pipefail
cd "$(dirname "$0")/.."

# Shared files, and the skills that must carry each.
CONFIG_SKILLS="story-atdd-workflow story-writing-council data-science-council product-verification-council wisdom-council"
TOOLMAP_SKILLS="architecture-rules story-atdd-workflow story-writing-council data-science-council product-verification-council wisdom-council"

for s in $CONFIG_SKILLS; do
  cp references/configuration.md "skills/$s/references/configuration.md"
done
for s in $TOOLMAP_SKILLS; do
  cp references/tool-mapping.md "skills/$s/references/tool-mapping.md"
done

echo "synced configuration.md to: $CONFIG_SKILLS"
echo "synced tool-mapping.md to:  $TOOLMAP_SKILLS"
