# Design / Projeto

## Mathematical core

Each internal row stores its full original-width coefficient vector, rhs, and a dense nonnegative certificate vector over the original rows. Initially the certificate is a unit vector. Combining a positive and negative coefficient uses positive multipliers; dividing the resulting row by a positive scale divides the certificate too. Inductively every internal inequality is a nonnegative combination of original inequalities. A negative constant rhs therefore proposes a Farkas-style contradiction.

The implementation is original Haskell Fourier–Motzkin, not a Z3 wrapper. GHC owns arbitrary-precision arithmetic and Ratio normalization. Aeson owns JSON parsing; Scientific owns bounded conversion of JSON number values. There is no custom JSON or SMT-LIB parser.

## Independent verification boundary

`Verify` imports no solver representation or transformations. It evaluates each original inequality at a proposed point, or each original matrix column and rhs at a proposed certificate. Shared checked rational primitives avoid duplicating integer-bound policy; the primal/dual equations are independently assembled. A bug in either path can still exist, so tests include separately specified rational points/certificates, deliberate corruptions, and native Z3 comparisons. Agreement on bounded synthetic systems is evidence, not certification.

The Z3 C API bridge is compiled only into the test component. It uses real-sort numerals, multiplication, addition and non-strict comparisons; native UNKNOWN is a separate failing test outcome. Solver timeout and resource limit parameters bound its work in addition to the outer container. No helper is built at application runtime. The production executable has no Z3 dependency or subprocess API.

## Space accounting

Ascending elimination and immutable saved snapshots make reconstruction understandable. Retaining all snapshots trades space for simplicity. The accounting intentionally overestimates logical live rows: old snapshots, active rows, the next table and two staging slots are checked before a candidate is constructed. This avoids a misleading active-only ceiling. Exact duplicate reduction uses an ordered map and first-certificate retention; it is deterministic but does not implement dominance pruning.

Intermediate rational multiplication/addition can exceed the component limit before a later cancellation. Returning UNKNOWN immediately is deliberate. Likewise a pair batch is reserved in advance rather than trying to extract a contradiction opportunistically beyond the declared budget. Neither resource policy implies mathematical infeasibility.

The original matrix remains bounded by 32 by 8 independently of elimination-row accounting. Dense certificates have at most 32 entries; witnesses have at most 8. Encoded size is checked separately because 32 large rationals can exceed the wire ceiling despite satisfying component limits.

## Error and publication model

Pure calculation constructs a private candidate. Direct verification and encoded-length validation precede `solve` returning evidence. There is no mutable published solver state, hence budget errors cannot overwrite an earlier result through this API. CLI output is written only after those checks, but kernel I/O is not atomic; complete framing and exit status are necessary. Build artifacts are created in owned scratch directories and copied only after gates pass. Their logs and hashes identify a completed gate, not crash durability or an atomic hostile-filesystem snapshot.

## Native packaging

The public Docker preparation stage uses signed Debian package repositories and exact top-level qualified tool versions. It records actual archive hashes, repository metadata, installed versions, compiled Haskell content hashes and package DB. Offline gates compare these records rather than regenerating a freeze. A source distribution must have the same complete per-file content inventory as the source input. Library/executable installation is from its extracted artifact, using a fresh no-repository Cabal store. The independent consumer has no source include path. A separate runtime image checks the installed CLI without compilers or checkout.

No Hackage source closure or index snapshot is asserted. The supplied freeze pins the qualified Debian global closure; `index-state: HEAD` is inert with `active-repositories: :none`. Apt preparation can fail if exact versions are unavailable or the qualified native-library hash changes; it must not silently substitute another toolchain.

## Resumo em português

Cada linha carrega multiplicadores sobre as desigualdades originais. Combinação e normalização são sempre positivas; isso conserva a prova dual. A reconstrução usa os históricos em ordem inversa e o verificador confere diretamente a matriz original, sem importar o solver. O mapa ordenado remove duplicatas exatas, preservando o primeiro certificado.

O orçamento considera histórico, tabela em formação e temporários. O algoritmo pode desistir antes de cancelamentos futuros: desconhecido é uma resposta correta de orçamento, não uma conclusão matemática. A codificação tem seu próprio limite. O oráculo Z3 é nativo, separado, apenas de teste e com UNKNOWN distinto.

As verificações de pacote trabalham offline com configurações Cabal sem repositórios, comparam o conteúdo do arquivo-fonte e compilam um consumidor instalado fora do checkout. Não se afirma conformidade ampla, execução universal, publicação, ganho de desempenho ou uso em produção.
