# Rational Halfspace Witnesses

Versão de desenvolvimento **0.1.0**, da [Lofrano Tecnologia](https://lofranotecnologia.com.br). Biblioteca Haskell original e CLI JSON sem interface gráfica para pequenos sistemas `A*x <= b`. A aritmética é exata. Uma resposta conclusiva contém um ponto racional verificado ou um certificado de inviabilidade com multiplicadores não negativos. Esgotar recursos produz **UNKNOWN_BUDGET**, nunca uma afirmação de inviabilidade.

[English](README.md) · [Contrato preciso / contrato da API](docs/contract.md) · [Projeto](docs/design.md)

## Instalação, testes e demonstração

A família nativa qualificada usa GHC 9.6.6, Cabal 3.10.3.0 e o conjunto compilado do Debian com Aeson 2.1.2.1. Z3 4.13.3 é necessário **somente para compilar/executar os testes**. Consulte a [proveniência](docs/provenance.md). A aplicação não precisa de compilador em execução nem de downloads do Hackage.

Com esse conjunto instalado, crie uma configuração privada do Cabal sem repositórios. Apenas `--offline` não impede a inicialização de metadados na configuração padrão nova.

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

Saída humana da demonstração sintética:

```text
Synthetic / Sintético — development 0.1.0
FEASIBLE / VIÁVEL: x = 1/2
INFEASIBLE / INVIÁVEL: multipliers / multiplicadores = [1, 1]
UNKNOWN_BUDGET / ORÇAMENTO ESGOTADO: PairLimit
Assertions passed / Asserções aprovadas.
```

A demonstração confere os resultados exatos antes de imprimir. A opção JSON emite um único objeto completo com os três resultados.

## Exemplo da CLI

```sh
printf '%s\n' '{"variables":1,"a":[[{"n":-1,"d":1}],[{"n":1,"d":1}]],"b":[{"n":-1,"d":2},{"n":2,"d":3}]}' | ./dist/rational-halfspace-witnesses solve
```

Resposta de exemplo; a ordem das chaves não faz parte do contrato:

```json
{"complete":true,"point":[{"d":2,"n":1}],"schema":"rational-halfspace-witnesses/1","status":"FEASIBLE"}
```

A entrada vem somente de stdin. Não há opção de caminho, comando, endpoint ou rede. Campos desconhecidos são rejeitados. O Aeson interpreta JSON e mantém o primeiro valor de uma chave repetida. Números integrais podem usar expoentes se passarem pela conversão limitada. As respostas usam pares exatos de numerador e denominador, sem arredondamento decimal. Nas respostas JSON, `"complete":true` indica apenas que o registro de protocolo foi construído por completo antes da saída, e não que houve veredito matemático conclusivo; o consumidor deve inspecionar `"status"` (`FEASIBLE`, `INFEASIBLE`, `UNKNOWN_BUDGET`, `INVALID_INPUT`, `INTERNAL_ERROR`) e o código de saída.

## Exemplo da biblioteca

```haskell
import RationalHalfspace

example :: Result
example = solve defaultBudget
  (Input 1 [[Fraction 1 1], [Fraction (-1) 1]]
           [Fraction 1 3, Fraction (-1) 2])
-- Infeasible [1 % 1, 1 % 1]
```

`solve :: Budget -> Input -> Result` valida as frações originais, elimina variáveis em ordem crescente, reconstrói o ponto ou propaga o certificado e executa um verificador separado sobre a matriz original. `verifyPoint` e `verifyCertificate` retornam `Either Failure Bool`: falha de orçamento não demonstra validade nem invalidade.

## Limites e decisões de projeto

* Até 8 variáveis, 32 desigualdades e 65.536 bytes em stdin.
* Módulo do numerador original até 1.000.000; denominador de 1 a 1.000.000.
* Até 4.096 posições de linhas de eliminação vivas, incluindo histórico e preparação; até 200.000 pares positivo/negativo reservados; 4.096 bits por componente racional normalizado.
* Temporários inteiros verificados têm limite explícito de 8.193 bits. A resposta, incluindo a quebra de linha, tem no máximo 65.536 bytes.
* Orçamentos personalizados só reduzem os tetos. Linhas e pares podem ser zero; bits devem ser positivos. Contabilização conservadora pode esgotar recursos mesmo quando outro algoritmo concluiria.
* Não há desigualdades estritas, variáveis inteiras, otimização, termos não lineares nem fórmulas quantificadas. Entradas válidas podem não receber resposta conclusiva.
* Não há telemetria, modelos, subprocessos ou Z3 na aplicação. Dados previamente alocados pelo chamador da API tipada não estão dentro de uma barreira de memória contra código hostil.

Fourier–Motzkin foi escolhido por sua simplicidade auditável. A normalização sempre positiva preserva a orientação das desigualdades; a redução de duplicatas exatas conserva um certificado determinístico. O crescimento de linhas continua sendo uma limitação importante. Não há alegação de desempenho, certificação ou prontidão para produção.

## Verificações isoladas de pacote

O workflow prepara artefatos Debian assinados e usa um contêiner offline novo, UID/GID 1000, sem montagens ou capabilities, com no-new-privileges, 1 GiB, duas CPUs e 256 PIDs. Confere impressões digitais e o freeze inalterado, executa testes nativos e demonstrações, gera o arquivo-fonte, compara inventário completo e hashes, instala a partir desse arquivo e compila um consumidor independente da biblioteca instalada fora do checkout e do pacote extraído. Outra imagem mínima testa a CLI instalada sem GHC, compilador C, Z3 ou checkout. São verificações executáveis, não afirmações de execução aprovada.

```sh
docker build --platform linux/amd64 --target prepared -t rhw-prepared .
docker create --name rhw-local-gates --network none --user 1000:1000 --cap-drop ALL --security-opt no-new-privileges --pids-limit 256 --memory 1g --cpus 2 rhw-prepared
docker start --attach rhw-local-gates
docker inspect --format '{{.State.ExitCode}}' rhw-local-gates
```

Saída não zero, oráculo ausente, dependência com falha ou execução interrompida não aprovam a verificação. Uma execução bloqueada/interrompida é **INCOMPLETE**, nunca um resultado matemático negativo. Não há sinalização por PID numérico. Assume-se sistema de arquivos Linux local, cooperativo, controlado e sem mutação hostil concorrente. Stdout não é atômico: exija objeto completo terminado por quebra de linha e o código de saída documentado.

## Licença e contato

MIT, copyright 2026 Lofrano Tecnologia, somente para o código original. Dependências e artefatos nativos mantêm suas licenças; veja [THIRD_PARTY.md](THIRD_PARTY.md). Contato geral: [site oficial](https://lofranotecnologia.com.br). Segurança: [relato privado de vulnerabilidade no GitHub](https://github.com/martinlofranodeoliveira/rational-halfspace-witnesses/security/advisories/new).
