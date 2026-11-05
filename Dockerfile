FROM debian:trixie-slim@sha256:7378260c0a098d27ac206225db5e7d92b8c7c84ea7afccc86eeb513756bbd392 AS prepared
USER root
RUN mkdir -p /opt/qualification /work/project /work/scratch /work/artifacts && \
    apt-get update && \
    mkdir -p /opt/qualification/signed-apt-metadata && \
    find /var/lib/apt/lists -maxdepth 1 -type f ! -name lock -exec cp {} /opt/qualification/signed-apt-metadata/ \; && \
    apt-get --download-only --no-install-recommends -y install \
      ghc=9.6.6-4 cabal-install=3.10.3.0-1+b1 \
      libghc-aeson-dev=2.1.2.1-6+b1 libz3-dev=4.13.3-1 build-essential && \
    sha256sum /var/cache/apt/archives/*.deb > /opt/qualification/debian-archives.sha256 && \
    apt-get --no-download --no-install-recommends -y install \
      ghc=9.6.6-4 cabal-install=3.10.3.0-1+b1 \
      libghc-aeson-dev=2.1.2.1-6+b1 libz3-dev=4.13.3-1 build-essential
RUN test "$(ghc --numeric-version)" = 9.6.6 && \
    test "$(cabal --numeric-version)" = 3.10.3.0 && \
    echo '7accc397d4ac387468b09489bdaff9d82bfac4ca6a7e339b8fbb2167edf9c1c0  /usr/lib/x86_64-linux-gnu/libz3.so.4' | sha256sum -c - && \
    ghc-pkg dump --global --expand-pkgroot > /opt/qualification/package-db && \
    dpkg-query -W -f='${binary:Package}\t${Version}\n' > /opt/qualification/packages && \
    find /usr/lib/ghc /usr/lib/haskell-packages -type f -exec sha256sum '{}' + > /opt/qualification/content.sha256 && \
    sha256sum /usr/bin/cabal /usr/lib/x86_64-linux-gnu/libz3.so.4 >> /opt/qualification/content.sha256 && \
    mkdir -p /opt/qualification/notices && \
    for notice in /usr/share/doc/*/copyright; do \
      name=$(basename "$(dirname "$notice")"); \
      mkdir -p "/opt/qualification/notices/$name"; \
      cp -L "$notice" "/opt/qualification/notices/$name/copyright"; \
    done && \
    cp -R /usr/share/common-licenses /opt/qualification/notices/common-licenses
COPY --chown=1000:1000 .dockerignore .editorconfig .gitignore Dockerfile Setup.hs rational-halfspace-witnesses.cabal cabal.project cabal.project.freeze LICENSE README.md README.pt-BR.md THIRD_PARTY.md CHANGELOG.md CONTRIBUTING.md SECURITY.md /work/project/
COPY --chown=1000:1000 .github/ /work/project/.github/
COPY --chown=1000:1000 src/ /work/project/src/
COPY --chown=1000:1000 app/ /work/project/app/
COPY --chown=1000:1000 test/ /work/project/test/
COPY --chown=1000:1000 docs/ /work/project/docs/
COPY --chown=1000:1000 scripts/ /work/project/scripts/
RUN sha256sum /work/project/cabal.project.freeze > /opt/qualification/freeze.sha256 && \
    chown -R 1000:1000 /work
WORKDIR /work
USER 1000:1000
ENV HOME=/work LANG=C.UTF-8 PATH=/usr/bin:/bin
CMD ["sh", "/work/project/scripts/offline.sh"]

FROM debian:trixie-slim@sha256:7378260c0a098d27ac206225db5e7d92b8c7c84ea7afccc86eeb513756bbd392 AS runtime
USER root
RUN apt-get update && apt-get --no-install-recommends -y install \
      libc6=2.41-12+deb13u4 libgmp10=2:6.3.0+dfsg-3 \
      libffi8=3.4.8-2 libnuma1=2.0.19-1 && \
    mkdir -p /work/tmp /work/notices && chown -R 1000:1000 /work
COPY --chown=1000:1000 build/rational-halfspace-witnesses /work/rational-halfspace-witnesses
COPY --chown=1000:1000 build/qualification/notices /work/notices
WORKDIR /work
USER 1000:1000
ENV HOME=/work LANG=C.UTF-8 PATH=/usr/bin:/bin
ENTRYPOINT ["/work/rational-halfspace-witnesses"]
CMD ["demo", "--assert"]
