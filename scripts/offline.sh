#!/bin/sh
set -eu
umask 077
export HOME=/work
export LANG=C.UTF-8
export CABAL_DIR=/work/scratch/cabal
export PATH=/usr/bin:/bin
mkdir -p "$CABAL_DIR" /work/artifacts /work/scratch/source /work/scratch/consumer /work/scratch/install
cat > "$CABAL_DIR/config" <<'EOF'
active-repositories: :none
remote-repo-cache: /work/scratch/cabal/packages
store-dir: /work/scratch/cabal/store
logs-dir: /work/scratch/cabal/logs
EOF
cd /work/project
sha256sum --quiet -c /opt/qualification/content.sha256
sha256sum --quiet -c /opt/qualification/freeze.sha256
ghc-pkg dump --global --expand-pkgroot > /work/artifacts/package-db.actual
cmp /opt/qualification/package-db /work/artifacts/package-db.actual
dpkg-query -W -f='${binary:Package}\t${Version}\n' > /work/artifacts/packages.actual
cmp /opt/qualification/packages /work/artifacts/packages.actual
cp -R /opt/qualification /work/artifacts/qualification
printf 'ghc: '; ghc --numeric-version
printf 'cabal: '; cabal --numeric-version
find . -type f -print | LC_ALL=C sort > /work/artifacts/intended-files
while IFS= read -r file; do sha256sum "$file"; done < /work/artifacts/intended-files > /work/artifacts/source.sha256
cabal build all --offline --jobs=1
cabal test all --offline --jobs=1 --test-show-details=direct
cabal run exe:rational-halfspace-witnesses --offline -- demo --assert
cabal run exe:rational-halfspace-witnesses --offline -- demo --assert --json
cabal sdist --output-directory=/work/artifacts
archive=/work/artifacts/rational-halfspace-witnesses-0.1.0.tar.gz
tar -tzf "$archive" > /work/artifacts/archive-members
# Inspect before extracting even this locally generated archive.
if grep -E '(^/|(^|/)\.\.(/|$))' /work/artifacts/archive-members; then exit 1; fi
tar -xzf "$archive" -C /work/scratch/source
package=/work/scratch/source/rational-halfspace-witnesses-0.1.0
cd "$package"
find . -type f -print | LC_ALL=C sort > /work/artifacts/packaged-files
cmp /work/artifacts/intended-files /work/artifacts/packaged-files
sha256sum -c /work/artifacts/source.sha256
# Installation is from the extracted source artifact, never the checkout.
export CABAL_DIR=/work/scratch/install/cabal
mkdir -p "$CABAL_DIR"
cat > "$CABAL_DIR/config" <<'EOF'
active-repositories: :none
remote-repo-cache: /work/scratch/install/cabal/packages
store-dir: /work/scratch/install/cabal/store
logs-dir: /work/scratch/install/cabal/logs
EOF
cabal v2-install --lib lib:rational-halfspace-witnesses --offline --jobs=1 --package-env=/work/scratch/installed.env
cabal v2-install exe:rational-halfspace-witnesses --offline --jobs=1 --installdir=/work/scratch/installed-bin
cp test/Consumer.hs /work/scratch/consumer/Consumer.hs
cd /work/scratch/consumer
ghc -Wall -Werror -package-env /work/scratch/installed.env Consumer.hs -o consumer
./consumer
cli=/work/scratch/installed-bin/rational-halfspace-witnesses
printf '%s\n' '{"variables":1,"a":[[{"n":-1,"d":1}],[{"n":1,"d":1}]],"b":[{"n":-1,"d":1},{"n":2,"d":1}]}' | "$cli" > /work/artifacts/feasible.json
printf '%s\n' '{"variables":1,"a":[[{"n":1,"d":1}],[{"n":-1,"d":1}]],"b":[{"n":0,"d":1},{"n":-1,"d":1}]}' | "$cli" > /work/artifacts/infeasible.json
printf '%s\n' '{"variables":1,"a":[[{"n":1,"d":1}],[{"n":-1,"d":1}]],"b":[{"n":0,"d":1},{"n":-1,"d":1}],"budget":{"rows":4096,"pairs":0,"bits":4096}}' | "$cli" > /work/artifacts/exhausted.json
grep -F '"status":"FEASIBLE"' /work/artifacts/feasible.json
grep -F '"status":"INFEASIBLE"' /work/artifacts/infeasible.json
grep -F '"status":"UNKNOWN_BUDGET"' /work/artifacts/exhausted.json
"$cli" demo --assert
"$cli" demo --assert --json > /work/artifacts/demo.json
ldd "$cli" > /work/artifacts/runtime.ldd
if grep -i z3 /work/artifacts/runtime.ldd; then exit 1; fi
awk '$2 == "=>" {print $3} $1 ~ /^\// {print $1}' /work/artifacts/runtime.ldd | xargs sha256sum > /work/artifacts/runtime.sha256
cp -L "$cli" /work/artifacts/rational-halfspace-witnesses
sha256sum "$archive" /work/artifacts/rational-halfspace-witnesses > /work/artifacts/artifacts.sha256
printf 'COMPLETE: native tests, demo, exact source inventory, installed consumer and CLI gates\n'
