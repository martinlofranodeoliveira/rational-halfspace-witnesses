# Contributing

Use synthetic data only. Keep changes small enough to review the mathematical invariants, budgets and wire contract together. Original contributions must be compatible with the MIT license; do not submit private client code or copied implementation code.

1. Use the native family in docs/provenance.md and a private no-repository Cabal configuration as shown in README.md.
2. Run `cabal build all --offline --jobs=1`, `cabal test all --offline` and `cabal run exe:rational-halfspace-witnesses --offline -- demo --assert`.
3. Exercise the no-mount Docker gate and source-artifact consumer through the workflow or the documented container entrypoint. Source-tree tests alone are insufficient for package acceptance.
4. Add regressions with independently specified expected mathematics. Assert exact typed failures for budget/input cases. A crash, timeout, missing oracle, oracle UNKNOWN or dependency failure is not a passing negative test.
5. Update both READMEs, the bilingual contract and changelog when observable behavior changes. Keep Z3 restricted to the test component. Never add runtime command, endpoint, network, tracking or credential capabilities.

Do not regenerate the freeze during ordinary offline tests. A dependency/toolchain change needs deliberate native qualification, actual compiled-package evidence, exact artifact notices and fresh outside-checkout consumption. Do not infer compatibility from matching version strings alone.

Use repository issues for ordinary bugs with small synthetic reproductions. For vulnerabilities, use the private reporting link in SECURITY.md. General contact is the official organization homepage, not an invented personal address.

Português: contribuições devem ser originais, com dados sintéticos, testes matemáticos independentes e falhas tipadas exatas. Atualize a documentação bilíngue e mantenha Z3 somente nos testes. Mudanças na família nativa exigem nova qualificação real, não atualização silenciosa de locks.
