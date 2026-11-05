# Contract / Contrato — development 0.1.0

This document defines the supported subset, not general linear-programming or JSON standards compliance. Os termos e nomes de construtores abaixo também são o contrato da API em português.

## Typed input / Entrada tipada

`Input n a b` denotes `a*x <= b`, with original row and column order retained. `Fraction numerator denominator` is a raw pair, validated **before** reduction. Thus `Fraction 2000000 2` is invalid even though it reduces to an allowed integer. Denominators must be positive, not merely nonzero.

`0 <= n <= 8`; `0 <= length a == length b <= 32`; every row has exactly `n` entries. Empty matrices and zero-dimensional systems are meaningful. Absolute raw numerators are at most 1,000,000, denominators 1 through 1,000,000. GHC `Integer` and `Ratio Integer` perform integer arithmetic and rational reduction.

`Budget rows pairs bits` must satisfy `0 <= rows <= 4096`, `0 <= pairs <= 200000`, `1 <= bits <= 4096`. The default uses all ceilings. Zero row/pair budgets support explicit forced-exhaustion tests and are also valid public budgets. Overlong or cyclic list spines for rows, bounds, points and certificates are rejected by bounded prefix checks (`take 33`, `take 9`); general caller allocations and hostile Haskell values such as bottom or unbounded thunks inside elements are outside this contract.

Validation failures are `InvalidInput VariableCount`, `InequalityCount`, `DimensionMismatch`, `InvalidNumerator`, `InvalidDenominator`, or `InvalidBudget`. Validation order is budget, variable count, inequality count, dimensions, then fractions in row order followed by right-hand sides; each fraction checks denominator before numerator.

Em português: as dimensões e os limites valem para os pares originais, antes da simplificação. Denominador negativo ou zero é inválido. Listas de linhas, limites, coordenadas ou pesos que excedam o prefixo limitado são rejeitadas, mas valores parciais (`bottom`) ou código hostil do chamador não são isolados.

## Library results / Resultados da biblioteca

`solve :: Budget -> Input -> Result`

* `Feasible point`: exactly `n` coordinates, with direct independent verification of every original inequality.
* `Infeasible weights`: exactly one nonnegative rational per original inequality. Independent verification establishes `weights*A = 0` and `weights*b < 0`. Removed rows still have their original positions.
* `UnknownBudget reason`: `RowLimit`, `PairLimit`, `BitLimit` or `OutputLimit`. No partial point or certificate accompanies it. It says nothing about mathematical feasibility.
* `InvalidInput reason`: invalid input, not infeasibility.
* `CalculationError`: an internal invariant or verification disagreement; never a mathematical verdict.

`verifyPoint` and `verifyCertificate` have type `Budget -> Input -> [Rational] -> Either Failure Bool`. They validate budget/input, check component bounds, and evaluate the original rows. Wrong evidence arity returns `Right False`. Negative certificate entries return `Right False`. Arithmetic exhaustion is `Left (BudgetExceeded BitLimit)`, invalid input is `Left (BadInput reason)`. They do not import elimination code. Arithmetic primitives are shared, matrix evaluation is not. Their `rows` and `pairs` fields validate the budget shape but do not limit verification, which performs no elimination.

Em português: `Right True` é verificação positiva; `Right False` rejeita a evidência. `Left` não equivale a rejeição matemática. `UNKNOWN_BUDGET` nunca publica evidência parcial. `CalculationError` exige investigação.

## Elimination and resources / Eliminação e recursos

Variables are eliminated in ascending index order. At each stage rows are ordered lexicographically by normalized `(coefficients, rhs)`. A nonconstant row is divided by the absolute value of its first nonzero coefficient. Its entire certificate is divided by that same **positive** value. Exact duplicate normalized rows retain the first encountered certificate. No sign-flipping or approximate comparison occurs.

Positive/negative pairs combine using `(-negativeCoefficient)*positiveRow + positiveCoefficient*negativeRow`. Zero-coefficient rows are carried forward. A constant row with negative rhs immediately proposes a certificate; nonnegative constant rows are discarded. All proposals still require independent verification.

Back-substitution walks the saved stages in reverse. It chooses zero when permitted, otherwise the positive lower endpoint or negative upper endpoint. Unconstrained variables become zero. Output is deterministic for the same input representation and budget; equivalent row permutations need not yield the same evidence.

The row budget counts all retained stage/history slots plus the table under construction and **two temporary row slots before each insertion**, including duplicate and constant candidates. The original bounded matrix is retained for verification, not counted as an elimination history. Logical slots are conservatively counted even where immutable row objects share storage. No original unnormalized elimination-row list is retained. A one-row nonempty input can therefore require two slots. Saved stages are not discarded early. This is not an optimal row-space algorithm.

Each stage reserves its entire `positiveCount*negativeCount` pair batch before candidate allocation/work. A batch exceeding the cumulative pair limit returns UNKNOWN even if an early candidate might have proved infeasibility. Pair candidate lists are consumed lazily; no full Cartesian row collection is built.

Every normalized rational operand and result has numerator magnitude and positive denominator strictly below `2^bits`. Before multiplication/addition, both operands are checked. Cross-products are at most `2*bits` bits; an unreduced addition numerator is at most `2*bits+1` bits. These temporary bounds are checked before `%` normalization. At the ceiling, the maximum is 8,193 bits. Every intermediate rational operation must fit the normalized component budget; cancellation in a later operation does not rescue an earlier exhaustion. Rational comparisons use bounded checked operands, so their cross-products are bounded too. Verification and reconstruction use the same arithmetic bounds. Exhaustion anywhere is UNKNOWN, never INFEASIBLE.

Em português: o limite de linhas inclui histórico e preparação, não apenas a etapa ativa. Reservam-se dois espaços temporários por inserção. Pares são reservados por etapa antes de trabalhar. Temporários inteiros têm limite provado antes da normalização; o algoritmo pode retornar desconhecido de forma conservadora.

## JSON CLI / CLI JSON

Invocation: no arguments, or `solve`. One complete JSON document from stdin, at most 65,536 bytes. The adapter retains at most 65,537 bytes including one-byte oversize lookahead before Aeson is invoked. No input-file adapter exists.

Required keys: `variables`, `a`, `b`. Optional key: `budget`. A rational is exactly `{"n":integer,"d":integer}`. Budget, when present, requires exactly `rows`, `pairs`, `bits`. Unknown keys at all these levels are invalid. Arrays are limited before element conversion. Missing fields, null, booleans, nonintegral numbers and out-of-range schema integers are invalid JSON input for this interface. Integral exponent-form numbers are allowed by the maintained Scientific bounded-Int conversion; giant exponents are not expanded to unbounded input Integers. Duplicate keys use Aeson's **first-value** semantics; duplicate detection is not provided. No decimal or string rational representation is accepted.

All result objects contain `schema: "rational-halfspace-witnesses/1"`, `complete: true`, and `status`. Note that `complete: true` is a protocol framing marker indicating that the JSON response record was completely constructed before output, **not** that the mathematical verdict was conclusive; consumers must always inspect `status` to distinguish `FEASIBLE`, `INFEASIBLE`, `UNKNOWN_BUDGET`, `INVALID_INPUT` and `INTERNAL_ERROR`. Additional fields:

| Status | Fields | Exit |
| --- | --- | --- |
| FEASIBLE | `point`: rational array | 0 |
| INFEASIBLE | `certificate`: rational array | 0 |
| UNKNOWN_BUDGET | `reason`: budget constructor name | 0 |
| INVALID_INPUT | `reason`: input constructor name | 2 |
| INTERNAL_ERROR | none | 70 |

The adapter additionally uses `InvalidJSON`, `InputTooLarge`, `InvalidArguments`. It emits no parser internals or input echoes. I/O failure exits 74 (even if diagnostic `stderr` also fails) and may leave no output or truncated output. Stalls/interruption are INCOMPLETE under the outer owner, not JSON mathematical statuses. Unsupported arguments do not trigger any external effect beyond diagnostic output.

Each encoded result, including its final LF byte, is at most 65,536 bytes. Encoding overflow replaces the proposed evidence with `UNKNOWN_BUDGET/OutputLimit`. `solve` makes this check too, before returning evidence. Public `Result` constructors and `renderResult` permit caller-created values; the encoder itself does not certify them. Only `solve` promises checked evidence.

Consumers must require exactly one complete newline-terminated JSON object, `complete: true`, correct schema, valid fields and the corresponding exit code. Ignore object key order; do not accept a prefix, a truncated stream, or exit 74 as evidence. Stdout is not atomic and no durability claim is made.

Em português: stdin e stdout têm limite de 65.536 bytes por documento de resultado. O byte adicional serve apenas para detectar excesso na entrada. Chaves repetidas usam o primeiro valor, conforme a semântica do Aeson. O campo `complete: true` indica apenas que o registro JSON de protocolo está completo, e não que houve veredito matemático conclusivo; o consumidor deve sempre inspecionar `status` (`FEASIBLE`, `INFEASIBLE`, `UNKNOWN_BUDGET`, `INVALID_INPUT`, `INTERNAL_ERROR`). Exija documento completo, quebra de linha, esquema e código de saída correto; uma saída parcial ou saída 74 não é resultado.

## Demo and environment / Demonstração e ambiente

`demo --assert` emits bilingual human output only after checking all three exact synthetic expected results. `demo --assert --json` emits one LF-terminated object with schema `rational-halfspace-witnesses-demo/1`, `complete: true`, and `results` in feasible, infeasible, exhausted order. It is bounded by 65,536 bytes. No clock, randomness, real data or external service is used.

The supported filesystem is owned cooperative local Linux storage, stable during read/hash/package gates, without hostile concurrent mutation. No hostile-filesystem snapshot, atomic stdout publication, universal cleanup, RSS bound for arbitrary callers or real-time completion is claimed. Container enforcement limits are separate from mathematical budgets. No PID/PGID signaling or arbitrary executable capability exists.

Licença: MIT somente para o código original. Dependências, compilador, oráculo e imagem mantêm licenças próprias.
