# Source and native provenance

Original project source is authored for Lofrano Tecnologia, copyright 2026. Solver, verifier, adapters, native test bridge, synthetic fixtures and gate scripts are original project code. No private client code or external solver implementation is incorporated. Z3 is an independently linked test dependency, not a source of elimination code.

## Qualified tool family supplied for this project

The native qualification inputs identify Debian Linux amd64 with:

* Debian trixie-slim base digest `sha256:7378260c0a098d27ac206225db5e7d92b8c7c84ea7afccc86eeb513756bbd392`.
* `ghc=9.6.6-4`, base 4.18.2.1.
* `cabal-install=3.10.3.0-1+b1`.
* `libghc-aeson-dev=2.1.2.1-6+b1`, Scientific 0.3.7.0, containers 0.6.7, bytestring 0.11.5.3, and the installed compiled transitive closure constrained in `cabal.project.freeze`.
* `libz3-dev=4.13.3-1`; qualified `libz3.so.4` SHA-256 `7accc397d4ac387468b09489bdaff9d82bfac4ca6a7e339b8fbb2167edf9c1c0`.
* CLI native runtime family: libc6 `2.41-12+deb13u4` including libm, libgmp10 `2:6.3.0+dfsg-3`, libffi8 `3.4.8-2`, libnuma1 `2.0.19-1`.

These identify qualification inputs, not test results for this source tree. There is no invented Hackage index-state/date, source archive hash or installed-content fingerprint here. The freeze text is the supplied qualified compiled-package closure. Its generated `index-state: HEAD` does not select an index because repositories are disabled.

## Reproducible evidence procedure

Networkable Docker preparation records signed apt metadata and the actual downloaded `.deb` archive hashes before installation, the installed version manifest, compiled GHC library hashes, package DB, Z3 content check and component notices. Top-level tool versions are exact; signed repository transitive artifacts are recorded from the actual preparation, not guessed. Preparation failure is not permission to relax these constraints.

Offline `scripts/offline.sh` checks those immutable image records and the source freeze, records source hashes, runs gates, inspects the source archive, compares every packaged file and the complete inventory, and hashes final source/binary artifacts. Generated data goes to `/work/artifacts`; original source stays in `/work/project`. It creates a fresh second Cabal store for source-artifact installation, and an independent consumer directory without `-i` source paths. Runtime dependency paths and hashes come from actual `ldd` output, with an explicit rejection of Z3 linkage.

CI prints the actual runner image, architecture, source SHA, native command logs and container exit code. It uses no cross-job cache or extra workflow action. No native result, installation result or source integrity result is claimed in advance of these gates. An unfinished outer job is INCOMPLETE, not evidence of a negative test. Container lifecycle identity belongs to Docker; the project does not signal numeric process IDs.

## Official primary sources

* GHC: https://www.haskell.org/ghc/
* Cabal: https://cabal.readthedocs.io/
* Aeson: https://hackage.haskell.org/package/aeson
* Z3: https://github.com/Z3Prover/z3
* Docker Debian image source: https://github.com/docker-library/debian
* Debian signed archive: https://www.debian.org/distrib/packages

## Português

A origem do código original e a família nativa estão identificadas acima. Os hashes de pacotes, bibliotecas instaladas, manifesto e avisos de licença são coletados dos artefatos reais durante a preparação; as etapas offline apenas os conferem. O arquivo-fonte e o binário recebem hashes após os testes. Não se inventa um snapshot Hackage: o projeto usa o conjunto global compilado do Debian. Um comando documentado é uma entrada executável para verificação, não uma alegação de execução concluída.
