# Contract Net Protocol em JaCaMo/Jason

Este projeto implementa e avalia o **Contract Net Protocol (CNP)** em um Sistema Multiagente usando **JaCaMo/Jason**. O trabalho parte do enunciado de `tp-cnp.pdf`, cujo objetivo e implementar um SMA com `n` agentes **initiators**, `m` agentes **participants** e `i` contratos executados em paralelo por cada initiator, analisando como a abordagem baseada em agentes se comporta conforme a complexidade do sistema aumenta.

## 1. Estrutura dos agentes

A organizacao principal esta em:

```text
main.jcm
src/agt/initiator.asl
src/agt/participant.asl
script/stress_test.py
```

### `main.jcm`

O arquivo `main.jcm` define a sociedade multiagente executada pelo JaCaMo:

```jcm
mas main {
    agent gerente : initiator.asl {
        instances: 1
        beliefs: num_servicos(1)
    }
    agent operario : participant.asl {
        instances: 5
    }
}
```

Nele sao definidos:

- `gerente`: agente baseado em `initiator.asl`, responsavel por iniciar os leiloes CNP.
- `operario`: agente baseado em `participant.asl`, responsavel por receber chamadas de proposta e responder com um preco.
- `instances`: quantidade de agentes criados para cada tipo.
- `beliefs: num_servicos(i)`: crenca inicial usada pelo initiator para saber quantos servicos deve contratar em paralelo.

Durante os testes automatizados, o script Python reescreve esse arquivo para variar `n`, `m` e `i`.

### `initiator.asl`

O `initiator` representa o gerente do CNP. Ele e o agente que abre os leiloes, recebe propostas e escolhe o melhor participante.

Fluxo principal:

1. Ao iniciar, le a crenca `num_servicos(I)`.
2. Cria uma lista de servicos possiveis.
3. Para cada servico, dispara uma intencao paralela com `!!iniciar_leilao(NomeServico)`.
4. Em cada leilao:
   - registra o tempo inicial;
   - envia um `cfp(Servico)` por `.broadcast`;
   - espera 3 segundos pelas propostas;
   - chama `!escolher_vencedor(Servico)`.
5. Na escolha do vencedor:
   - usa `.findall` para buscar todas as propostas recebidas na base de crencas;
   - mede o tempo gasto nessa busca como gargalo BDI;
   - seleciona o menor preco com `.min`;
   - envia `accept_proposal` ao vencedor;
   - envia `reject_proposal` aos perdedores;
   - calcula o tempo total do leilao;
   - imprime uma linha `METRICA_CNP` para o script Python coletar.

A linha de metrica segue o formato:

```text
METRICA_CNP;Servico;RespostasRecebidas;TempoBDI;TempoTotal
```

### `participant.asl`

O `participant` representa o operario do CNP. Ele responde a chamadas de proposta feitas pelos initiators.

Fluxo principal:

1. Recebe uma mensagem `cfp(Servico)` enviada por algum initiator.
2. Calcula um preco aleatorio entre 50 e 150.
3. Envia ao initiator uma proposta no formato `propose(Servico, Preco)`.

Na implementacao atual, todos os participants usam a mesma estrategia simples de preco aleatorio. Isso foi suficiente para o objetivo do trabalho, porque o foco da avaliacao nao e otimizar o preco, mas observar o comportamento da infraestrutura quando muitos agentes e contratos estao ativos.

## 2. Script Python de testes

O arquivo `script/stress_test.py` automatiza as baterias de teste. Ele executa o projeto varias vezes, mudando os parametros do SMA e coletando metricas impressas pelos agentes.

O script faz quatro tarefas principais:

1. Define as configuracoes de teste nas baterias.
2. Reescreve o `main.jcm` com os valores de `n`, `m` e `i`.
3. Executa o JaCaMo com:

```bash
./gradlew --no-daemon --console=plain
```

4. Le a saida do processo e captura as linhas `METRICA_CNP`.

O resultado e salvo em `resultados_academicos.csv` com as colunas:

```text
Bateria,
n_Gerentes,
m_Operarios,
i_Servicos,
Leiloes_Esperados,
Leiloes_Fechados,
Sucesso_CNP(%),
Volume_Msgs_FIPA,
Drop_Msgs_FIPA,
Gargalo_BDI(ms),
Throughput_Total(ms)
```

### O que o script mede

- **Leiloes esperados**: quantidade teorica de CNPs que deveriam acontecer, calculada por `n * i`.
- **Leiloes fechados**: quantidade de leiloes que chegaram a imprimir `METRICA_CNP`.
- **Sucesso CNP (%)**: porcentagem de leiloes concluidos em relacao aos esperados.
- **Volume de mensagens FIPA**: estimativa do volume gerado pelos leiloes concluidos. Para cada leilao, o script considera:

```text
1 CFP + m Proposes + 1 Accept + (m - 1) Rejects
```

Isso equivale a:

```text
2m + 1 mensagens por leilao
```

No texto teorico do planejamento, foi considerada a ideia de `2 + 2m` mensagens por leilao. Na implementacao atual do script, entretanto, o calculo usado e `1 + m + 1 + (m - 1)`, isto e, `2m + 1`.

- **Drop de mensagens FIPA**: diferenca entre o numero de participants esperados e o numero de propostas recebidas:

```text
mensagens_perdidas = m - respostas_recebidas
```

- **Gargalo BDI**: tempo gasto pelo initiator para executar `.findall` e varrer a base de crencas em busca das propostas recebidas.
- **Throughput total**: tempo entre o inicio do leilao e o fechamento do contrato.

O script importa `psutil`, mas a versao atual nao grava uso de CPU nem memoria RAM no CSV. Portanto, as metricas efetivamente medidas hoje sao as de mensagens, sucesso dos leiloes, gargalo BDI e tempo total.

## 3. Relacao com o enunciado do trabalho

O `tp-cnp.pdf` pede a implementacao de um SMA em Jason com:

- `n` initiators, com `1 < n < 200`;
- `m` participants, com `1 < m < 50`;
- cada initiator contratando `i` servicos ao mesmo tempo, com `0 < i < 10`;
- execucao de `i` CNPs em paralelo;
- definicao das metricas de analise como parte do trabalho;
- avaliacao das variacoes de `n`, `m` e `i`;
- avaliacao da abordagem de agentes e das ferramentas usadas.

Neste projeto, a solucao foi modelada de forma direta:

- O **initiator** e o gerente do contrato.
- O **participant** e o operario que responde com uma proposta.
- Cada servico representa uma instancia de CNP.
- O paralelismo de contratos e criado com o operador `!!`, que dispara varias intencoes simultaneas dentro do mesmo agente.
- A comunicacao e feita por mensagens FIPA/Jason, usando `cfp`, `propose`, `accept_proposal` e `reject_proposal`.

A escolha foi manter a logica de negocio simples para que o experimento medisse principalmente o comportamento do SMA. Em vez de criar estrategias complexas de preco, o participant responde com preco aleatorio. Assim, a variacao observada nos resultados vem principalmente da quantidade de agentes, mensagens, propostas e intencoes paralelas.

## 4. O que foi decidido medir

A avaliacao foi desenhada para verificar onde a teoria de Sistemas Multiagentes encontra limites praticos de execucao. Em teoria, agentes sao autonomos, racionais e capazes de negociar. Na pratica, essa negociacao depende de memoria, escalonamento de intencoes, processamento local e infraestrutura de comunicacao.

Por isso, foram escolhidas quatro dimensoes principais de analise.

### 4.1 Custo de comunicacao: overhead FIPA

O CNP e um protocolo baseado em troca formal de mensagens. Para cada contrato, o initiator envia uma chamada de proposta, os participants respondem, um vencedor e aceito e os demais sao rejeitados.

Essa comunicacao e importante porque, em sistemas orientados a eventos, a rede e a infraestrutura de mensagens tendem a ser um dos primeiros gargalos. O objetivo da metrica e observar se o JaCaMo consegue rotear muitas mensagens sem perder propostas ou deixar leiloes incompletos.

No script, isso aparece principalmente em:

- `Volume_Msgs_FIPA`;
- `Drop_Msgs_FIPA`;
- `Sucesso_CNP(%)`.

### 4.2 Gargalo do raciocinio BDI

Agentes BDI tomam decisoes usando crencas, desejos e intencoes. No projeto, as propostas recebidas ficam disponiveis como crencas do initiator. Quando chega a hora de escolher o vencedor, o agente executa:

```asl
.findall(proposta(Preco, Agente), propose(Servico, Preco)[source(Agente)], ListaPropostas)
```

Esse ponto foi escolhido como medida do gargalo BDI porque ele forca o agente a consultar sua memoria logica. Quanto mais participants respondem, maior tende a ser a lista de propostas varrida pelo `.findall`.

A pergunta principal e se esse tempo cresce de forma aceitavel conforme `m` aumenta, ou se passa a degradar muito quando ha muitas propostas simultaneas.

### 4.3 Concorrencia de intencoes

O parametro `i` representa quantos servicos cada initiator tenta contratar ao mesmo tempo.

No codigo, isso e feito com:

```asl
!!iniciar_leilao(NomeServico)
```

O operador `!!` cria novas intencoes paralelas. Assim, um mesmo agente gerente pode estar acompanhando varios leiloes ao mesmo tempo. Essa decisao testa a capacidade do modelo BDI de lidar com varias linhas de raciocinio simultaneas.

A metrica observada aqui e o aumento do tempo total dos leiloes quando o numero de servicos paralelos cresce.

### 4.4 Throughput do sistema

O throughput e medido pelo tempo total do leilao, isto e, do inicio do `cfp` ate a escolha do vencedor e envio das mensagens de aceite/rejeicao.

Essa metrica mostra a eficiencia global do SMA para resolver problemas de alocacao de recursos. Em termos praticos, ela responde quanto tempo o sistema demora para transformar uma demanda de servico em um contrato fechado.

## 5. Baterias de teste

As baterias foram desenhadas para variar uma dimensao principal por vez. A ideia e isolar gargalos: processamento BDI, concorrencia de intencoes, comunicacao e sobrevivencia em carga maxima.

### Bateria 1: teste do cerebro

Objetivo: estressar `m`, a quantidade de participants.

Configuracoes:

```text
n=1, m=5,  i=1
n=1, m=15, i=1
n=1, m=30, i=1
n=1, m=50, i=1
```

Como ha apenas um initiator e um servico por vez, o foco fica no custo de processar uma quantidade crescente de propostas. Esta bateria observa principalmente o tempo do `.findall`.

### Bateria 2: teste de foco

Objetivo: estressar `i`, a quantidade de servicos paralelos por initiator.

Configuracoes:

```text
n=5, m=20, i=1
n=5, m=20, i=3
n=5, m=20, i=5
n=5, m=20, i=8
n=5, m=20, i=10
```

Aqui, a quantidade de gerentes e operarios fica fixa, enquanto o numero de contratos paralelos cresce. O objetivo e observar se a concorrencia de intencoes dentro dos agentes aumenta a latencia dos leiloes.

### Bateria 3: teste do mega-fone

Objetivo: estressar `n`, a quantidade de initiators.

Configuracoes:

```text
n=10,  m=10, i=2
n=50,  m=10, i=2
n=100, m=10, i=2
n=200, m=10, i=2
```

Nesta bateria, muitos gerentes fazem broadcasts quase ao mesmo tempo. O objetivo e avaliar a saturacao da infraestrutura de mensagens e observar possiveis perdas de propostas ou queda na taxa de sucesso dos leiloes.

### Bateria 4: teste de sobrevivencia

Objetivo: executar o cenario de maior carga.

Configuracao:

```text
n=200, m=50, i=10
```

Este teste combina muitos initiators, muitos participants e muitos servicos paralelos. A meta nao e demonstrar execucao ideal, mas observar ate onde a infraestrutura consegue ir antes de degradar, atrasar ou deixar leiloes sem conclusao dentro do tempo limite.

## Como executar

Para rodar a configuracao atual do `main.jcm`:

```bash
./gradlew
```

Para executar todas as baterias automatizadas:

```bash
python script/stress_test.py
```

Ao final, os resultados sao gravados em:

```text
resultados_academicos.csv
```

## Observacoes

- O script altera o `main.jcm` automaticamente a cada bateria.
- O timeout de cada configuracao e de 40 segundos.
- Como os precos sao aleatorios, os vencedores podem variar entre execucoes.
- A medicao de CPU e memoria foi prevista conceitualmente para o teste de sobrevivencia, mas ainda nao esta implementada no CSV atual.
