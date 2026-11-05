# Rational Halfspace Witnesses

Development version **0.1.0**, by [Lofrano Tecnologia](https://lofranotecnologia.com.br). An original Haskell library and headless JSON CLI for small systems `A*x <= b`. Arithmetic is exact. A successful answer contains either a checked rational point or a checked nonnegative Farkas-style certificate. Resource exhaustion is explicitly **UNKNOWN_BUDGET**, not infeasibility.

[Português brasileiro](README.pt-BR.md) · [Precise contract](docs/contract.md) · [Design](docs/design.md)

## Install, test, demo

The qualified native package family is GHC 9.6.6, Cabal 3.10.3.0 and Debian's compiled Aeson 2.1.2.1 closure. Z3 4.13.3 is needed **only to compile/run tests**. See [provenance](docs/provenance.md). No Hackage download or runtime compiler is required by the application.

On an environment with that installed closure, create a private no-repository Cabal configuration first. `--offline` alone is insufficient with Cabal's default fresh configuration.

```sh
export CABAL_DIR="$PWD/build/cabal"
mkdir -p "$CABAL_DIR"
printf 'active-repositories: :none\n' > "$CABAL_DIR/config"
cabal build all --offline --jobs=1
cabal test all --offline
cabal run exe:rational-halfspace-witnesses --offline -- demo --assert
cabal run exe:rational-halfspace-witnesses --offline -- demo --assert --json
mkdir -p dist
cabal v2-install exe:rational-halfspace-witnesses --offline --jobs=1 --installdir="$PWD/dist"
./dist/rational-halfspace-witnesses demo --assert
```

Human-readable synthetic demo output:

```text
Synthetic / Sintético — development 0.1.0
FEASIBLE / VIÁVEL: x = 1/2
INFEASIBLE / INVIÁVEL: multipliers / multiplicadores = [1, 1]
UNKNOWN_BUDGET / ORÇAMENTO ESGOTADO: PairLimit
Assertions passed / Asserções aprovadas.
```

The demo checks its exact expected results before printing. The JSON option emits a single complete demo object containing all three results.

## CLI example

```sh
printf '%s\n' '{"variables":1,"a":[[{"n":-1,"d":1}],[{"n":1,"d":1}]],"b":[{"n":-1,"d":2},{"n":2,"d":3}]}' | ./dist/rational-halfspace-witnesses solve
```

Example response (object-key order is not a consumer contract):

```json
{"complete":true,"point":[{"d":2,"n":1}],"schema":"rational-halfspace-witnesses/1","status":"FEASIBLE"}
```

Only stdin is accepted; there is no path, command, endpoint or network option. JSON unknown fields are rejected. Aeson parses JSON; duplicate object keys use its first-value semantics. Integral JSON numbers can use exponent notation if their value passes the bounded integer conversion. Results always use exact integer numerator/denominator pairs. In JSON responses, `"complete":true` marks a complete protocol record rather than a conclusive mathematical verdict; consumers must inspect `"status"` (`FEASIBLE`, `INFEASIBLE`, `UNKNOWN_BUDGET`, `INVALID_INPUT`, `INTERNAL_ERROR`) along with the exit code.

## Library example

```haskell
import RationalHalfspace

example :: Result
example = solve defaultBudget
  (Input 1 [[Fraction 1 1], [Fraction (-1) 1]]
           [Fraction 1 3, Fraction (-1) 2])
-- Infeasible [1 % 1, 1 % 1]
```

`solve :: Budget -> Input -> Result` validates the original fractions, eliminates variables in ascending order, reconstructs a point or propagates a certificate, then invokes a separate direct verifier over the original matrix. `verifyPoint` and `verifyCertificate` return `Either Failure Bool`; a verifier budget error is not a proof of validity or invalidity.

## Bounds and limitations

* At most 8 variables, 32 inequalities and 65,536 stdin bytes.
* Raw numerator magnitude at most 1,000,000; denominator from 1 through 1,000,000.
* At most 4,096 live elimination-row slots, including history and staging; at most 200,000 reserved positive/negative pairs; 4,096 bits per normalized rational component.
* Checked integer temporaries have an explicit maximum of 8,193 bits. Output, including newline, is at most 65,536 bytes.
* Custom budgets can only reduce ceilings. Zero row/pair capacity is allowed; bits must be positive. Conservative staging and intermediate arithmetic can exhaust even when a different algorithm could finish.
* No strict inequalities, integer constraints, optimization, nonlinear terms or quantified formulas. Not every admitted input receives a conclusive verdict.
* No telemetry, model dependency, subprocess or runtime Z3 linkage. Direct typed callers' preallocated data is outside the memory-sandbox boundary.

Fourier–Motzkin is deliberately simple and auditable, but row growth is substantial. Positive normalization and exact duplicate reduction help without changing inequality orientation. There is no performance, certification or production-readiness claim.

## Isolated package gates

The workflow prepares signed Debian artifacts, then runs a fresh offline container with UID/GID 1000, no mounts, no capabilities, no-new-privileges, 1 GiB RAM, two CPUs and 256 PIDs. It checks package/content fingerprints and the unchanged freeze, runs native tests and both demos, builds a source archive, compares its complete file inventory and hashes, installs from that archive, and compiles an independent installed-library consumer outside both checkout and extracted package. A separate minimal runtime image tests the installed CLI without GHC, C compiler, Z3 or checkout. These are executable gates, not a statement that any particular run passed.

```sh
docker build --platform linux/amd64 --target prepared -t rhw-prepared .
docker create --name rhw-local-gates --network none --user 1000:1000 --cap-drop ALL --security-opt no-new-privileges --pids-limit 256 --memory 1g --cpus 2 rhw-prepared
docker start --attach rhw-local-gates
docker inspect --format '{{.State.ExitCode}}' rhw-local-gates
```

A nonzero exit, missing oracle, dependency failure or unfinished outer job fails the gate. An interrupted/stalled execution is **INCOMPLETE**, never a mathematical negative. No numeric process signaling is implemented. The filesystem assumption is an owned cooperative local Linux filesystem with no concurrent hostile mutation. Stdout is not atomic: require a complete newline-terminated object and the documented exit status.

## License and contact

MIT, copyright 2026 Lofrano Tecnologia, applies to original project source only. Dependencies and native artifacts retain their own licenses; see [THIRD_PARTY.md](THIRD_PARTY.md). General contact: [official homepage](https://lofranotecnologia.com.br). Security reports: [GitHub private vulnerability reporting](https://github.com/martinlofranodeoliveira/rational-halfspace-witnesses/security/advisories/new).
