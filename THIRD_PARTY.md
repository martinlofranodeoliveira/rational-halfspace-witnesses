# Third-party license boundary / Limites de licenças

The MIT license in LICENSE covers only original Rational Halfspace Witnesses source. It does not relicense the compiler, Cabal, Aeson, its dependencies, Z3, Debian packaging, system libraries or the base image. This source distribution does not vendor those components.

The qualified Debian package family supplies its exact notices in `/usr/share/doc/<package>/copyright` and shared license texts in `/usr/share/common-licenses`. Docker preparation copies all installed package copyright files and shared license texts into `/opt/qualification/notices`. Offline evidence copies them into its artifact directory; the minimal runtime image carries those notices in `/work/notices`. This deliberate superset preserves toolchain and test-dependency notices as well as runtime notices. Review the actual collected artifacts before redistributing binaries or images; a version label alone is not a notice audit.

Important boundaries:

* GHC and Aeson include BSD-style notices, with component-specific attribution.
* Cabal has its own BSD-style copyright/license text.
* Z3 upstream uses the MIT/Expat license. Debian Z3 packaging has distinct notices, including GPL terms for Debian packaging files; upstream and packaging are not interchangeable.
* Native runtime and compiler packages include licenses other than MIT. Preserve their complete actual notices and applicable redistribution obligations.

Official source links and exact qualified version identities are in [docs/provenance.md](docs/provenance.md). No dependency source text is represented as original project code.

Em português: MIT aplica-se somente ao código original deste repositório. Compilador, bibliotecas, Z3, empacotamento Debian e imagem mantêm seus próprios termos. A preparação coleta os avisos exatos dos pacotes instalados, inclusive textos compartilhados. Revise esses artefatos antes de redistribuir binários ou imagens; não rotule toda a árvore como MIT.
