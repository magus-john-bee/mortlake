# Resolve the schema path for a config file.
#   1. If $schema is present in the file, use it (JSON/YAML convention).
#   2. Otherwise, check for <file_dir>/schemas/<stem>.schema.json.
# Prints the schema path to stdout (empty if none found).
_resolve-schema file:
    #!/usr/bin/env bash
    set -euo pipefail
    file="{{ file }}"
    schema=$(grep -oP '"\$schema"\s*[=:]\s*"\K[^"]*' "$file" 2>/dev/null | head -1 || true)
    if [ -n "$schema" ]; then
        echo "$schema"
        exit 0
    fi
    dir=$(dirname "$file")
    stem=$(basename "$file" | sed 's/\.[^.]*$//')
    fallback="$dir/schemas/$stem.schema.json"
    if [ -f "$fallback" ]; then
        echo "$fallback"
    fi

# Validate a single config file against its schema.
check-schema file:
    #!/usr/bin/env bash
    set -euo pipefail
    file="{{ file }}"
    [ ! -f "$file" ] && { echo "File not found: $file" >&2; exit 1; }
    schema=$(just --quiet _resolve-schema "$file")
    [ -z "$schema" ] && { echo "No schema found for $file" >&2; exit 1; }
    filetype="${file##*.}"
    args=(--schemafile "$schema")
    [[ "$filetype" != "json" ]] && args+=(--default-filetype "$filetype")
    check-jsonschema "${args[@]}" "$file"

# Validate all config files against their schemas.
validate-schemata:
    #!/usr/bin/env bash
    set -euo pipefail
    fail=0
    while IFS= read -r -d '' file; do
        schema=$(just --quiet _resolve-schema "$file")
        [ -z "$schema" ] && continue
        filetype="${file##*.}"
        args=(--schemafile "$schema")
        [[ "$filetype" != "json" ]] && args+=(--default-filetype "$filetype")
        echo "Checking $file ($schema)..."
        check-jsonschema "${args[@]}" "$file" || fail=1
    done < <(find modules -type f \( -name '*.json' -name '*.schema.json' -prune -o -name '*.json' -print \) -o \( -name '*.yaml' -o -name '*.yml' -o -name '*.toml' \) -print0 | sort -z)
    exit $fail

# ── Nix config evaluation ──────────────────────────────────

eval host:
    nix eval --json --show-trace .#nixosConfigurations.{{ host }}.config.system.build.toplevel.drvPath

dry host:
    nixos-rebuild dry-build --flake .#{{ host }} --show-trace

# ── Linting ────────────────────────────────────────────────

lint:
    #!/usr/bin/env bash
    set -euo pipefail
    fail=0
    echo "Running nix fmt..."
    nix fmt -- --fail-on-change || fail=1
    echo "Running statix check..."
    statix check . || fail=1
    echo "Running deadnix..."
    deadnix --fail . || fail=1
    echo "Validating schemas..."
    just validate-schemata || fail=1
    exit $fail

lint-fix:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Fixing with nix fmt..."
    nix fmt
    echo "Fixing with statix..."
    statix fix .
    echo "Fixing with deadnix..."
    deadnix --edit .
    echo "Lint fix complete"

# ── Agent skills ───────────────────────────────────────────

sync-feynman-skills:
    #!/usr/bin/env bash
    set -euo pipefail
    target="skills/feynman"
    rm -rf "$target"
    curl -fsSL https://feynman.is/install-skills | bash -s -- --dir "$PWD/$target"
    count=$(find "$target" -name 'SKILL.md' | wc -l)
    echo "Synced $count feynman skills to $target"

# ── Personal sites ─────────────────────────────────────────

build-resume variant="generalist":
    cd sites/dev-resume && python3 scripts/build-resume.py {{ variant }} && npx hugo --minify

resume-variants:
    cd sites/dev-resume && python3 scripts/build-resume.py
