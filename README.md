# Atendimento Odontológico Inteligente — WhatsApp + n8n + Supabase + IA
Workflow desenvolvido em **n8n** para automatizar o atendimento de uma clínica odontológica pelo WhatsApp, integrando **Evolution API, Supabase, Redis e agentes de IA**.
O fluxo identifica quem está enviando a mensagem, consulta o cadastro no banco e direciona a conversa para o agente correspondente: **dentista, paciente cadastrado ou novo paciente**.
---

## Arquitetura
```text
WhatsApp
   │
   ▼
Evolution API
   │
   ▼
n8n Webhook
   │
   ├── ignora mensagens fromMe
   │
   ├── normaliza telefone e mensagem
   │
   ▼
Switch
   │
   ├── Dentista
   │      └── Busca dentista → Agente dentistas
   │
   └── Paciente
          │
          └── Busca cliente
                 │
                 ├── Encontrado
                 │      └── Agente pacientes
                 │
                 └── Não encontrado
                        └── Agente de cadastro
```
Os agentes utilizam **Redis Chat Memory** para manter o contexto da conversa e **Supabase Tools** para consultar e alterar os dados da clínica.
---

## Funcionalidades
### 🦷 Atendimento para dentistas
O número do WhatsApp é comparado com os profissionais configurados no nó `Switch`.
Depois da identificação, o workflow consulta o cadastro do dentista no Supabase e encaminha a mensagem para o **Agente dentistas**.

O agente pode:
- consultar a agenda do próprio dentista;
- consultar a agenda de hoje, amanhã, uma data específica ou uma semana;
- identificar o paciente de uma consulta;
- buscar pacientes pelo nome;
- agendar consultas;
- cancelar consultas;
- realizar remarcações através do fluxo de cancelamento + novo agendamento.

O agente não possui acesso à agenda de outros dentistas.

### 👤 Atendimento para pacientes cadastrados
O paciente é identificado pelo número de telefone.
Para pacientes encontrados no Supabase, o **Agente pacientes** pode:
- listar os dentistas disponíveis;
- consultar horários ocupados de um dentista;
- apresentar horários disponíveis;
- agendar uma consulta;
- consultar consultas futuras;
- cancelar uma consulta;
- iniciar uma remarcação através do cancelamento e novo agendamento.

O agente utiliza o telefone do WhatsApp para identificar o paciente e não solicita novamente dados que já estão disponíveis no fluxo.

### 📝 Cadastro de novos pacientes
Quando o telefone não é encontrado na tabela `pacientes`, a conversa é encaminhada para o **Agente de cadastro**.
O agente coleta:
- nome completo;
- convênio ou atendimento particular;
- endereço.

O telefone é obtido diretamente da mensagem do WhatsApp.
Antes de gravar os dados, o agente apresenta um resumo e solicita confirmação.
Somente após a confirmação a ferramenta `cadastrar_paciente` grava o registro no Supabase.
Após o cadastro confirmado, o agente informa que o cadastro foi concluído e pergunta se o paciente deseja agendar uma consulta. O agendamento ocorre a partir da próxima mensagem.
---

## Fluxo de entrada
O workflow utiliza um Webhook POST:
```text
whatsapp-in
```

A mensagem recebida pela Evolution API passa por estas etapas:
1. Verificação de `fromMe`.
2. Extração do número em `remoteJid`.
3. Extração do texto em `conversation`.
4. Roteamento pelo telefone.
5. Identificação de dentista ou paciente.
6. Execução do agente correspondente.
7. Envio da resposta de volta pelo WhatsApp através da Evolution API.

O número utilizado pelo fluxo é extraído de:
```text
body.data.key.remoteJid
```
---

## Agentes de IA
O workflow possui três agentes especializados.

| Agente | Função | Modelo | Memória |
|---|---|---|---|
| `Agente dentistas` | Atendimento interno aos dentistas | Google Gemini | Redis |
| `Agente pacientes` | Atendimento aos pacientes cadastrados | Groq / Qwen | Redis |
| `Agente de cadastro` | Cadastro de novos pacientes | Groq / Qwen | Redis |

### Agente dentistas

Modelo configurado:

```text
Google Gemini
```

Memória:

```text
Redis Chat Memory (dentistas)
```

Ferramentas:

- `ver_agenda_dentista`
- `buscar_paciente`
- `agendar_consulta_dentista`
- `cancelar_consulta_dentista`

### Agente pacientes

Modelo configurado:

```text
qwen/qwen3.8-27b
```

via Groq.

Memória:

```text
Redis Chat Memory (pacientes)
```

Ferramentas:

- `listar_dentistas`
- `minhas_consultas`
- `verificar_disponibilidade_dentista`
- `agendar_consulta_paciente`
- `cancelar_consulta_paciente`

### Agente de cadastro

Modelo configurado:

```text
qwen/qwen3.8-27b
```

via Groq.

Memória:

```text
Redis Chat Memory (cadastro)
```

Ferramenta:

- `cadastrar_paciente`

---

## Memória conversacional

Cada agente possui uma memória Redis independente.

A chave da sessão é baseada no telefone do usuário:

```text
telefone
```

Isso permite manter o contexto de uma conversa entre diferentes mensagens recebidas pelo WhatsApp.

---

# Supabase

O Supabase funciona como banco de dados operacional do atendimento.

O workflow utiliza as seguintes estruturas:

```text
pacientes
dentistas
consultas

agenda
dentistas_publico
consultas_detalhe
```

As três primeiras são tabelas. As três últimas são views utilizadas para facilitar as consultas dos agentes.

O arquivo [`supabase.sql`](supabase.sql) contém o script de configuração.

---

## Tabela `pacientes`

Armazena os dados cadastrais dos pacientes.

| Campo | Tipo | Uso |
|---|---|---|
| `id` | bigint | Identificador |
| `nome` | text | Primeiro nome |
| `sobrenome` | text | Sobrenome |
| `telefone` | text | Identificação pelo WhatsApp |
| `convenio` | text | Convênio ou informação equivalente |
| `endereco` | text | Endereço |

O workflow utiliza o `telefone` para verificar se a pessoa já possui cadastro.

Também utiliza `nome` e `sobrenome` para localizar pacientes durante o agendamento realizado por um dentista.

---

## Tabela `dentistas`

Armazena os profissionais autorizados a utilizar o atendimento interno.

| Campo | Tipo | Uso |
|---|---|---|
| `id` | bigint | Identificador |
| `nome` | text | Nome do dentista |
| `telefone` | text | Número usado para identificação |

O telefone também é utilizado no nó `Switch` para definir se a mensagem deve seguir para o fluxo de dentistas.

### Atenção

O workflow contém atualmente números fictícios no `Switch`:

```text
5548999990001
5548999990002
```

Eles devem ser substituídos pelos números reais da clínica.

---

## Tabela `consultas`

Armazena os agendamentos.

| Campo | Tipo | Uso |
|---|---|---|
| `id` | bigint | Identificador |
| `cliente_id` | bigint | Referência para `pacientes.id` |
| `dentista_id` | bigint | Referência para `dentistas.id` |
| `data_hora` | timestamptz | Data e horário |
| `duracao_min` | int | Duração |
| `status` | text | Status da consulta |
| `observacoes` | text | Observações |
| `created_at` | timestamptz | Data de criação |

Os status utilizados pelo fluxo são:

```text
agendada
cancelada
```

O modelo de dados também permite:

```text
concluida
```

---

## Regra de conflito de horário

O banco possui um índice único parcial:

```sql
create unique index consultas_slot_unico
  on consultas (dentista_id, data_hora)
  where status = 'agendada';
```

A regra impede dois agendamentos `agendada` para o mesmo dentista no mesmo instante.

O workflow também consulta a agenda antes de criar uma nova consulta.

A duração padrão definida no banco é de:

```text
30 minutos
```

A regra de funcionamento utilizada pelos agentes é:

```text
Segunda a sexta
08:00 às 18:00
Horários de 30 em 30 minutos
```

Essas regras de funcionamento estão nos prompts dos agentes, não em constraints do banco.

---

# Views utilizadas pelo workflow

## `agenda`

Utilizada pelo `Agente dentistas`.

Relaciona:

```text
consultas
    ↓
pacientes
```

Disponibiliza:

- `consulta_id`
- `dentista_id`
- `data_hora`
- `status`
- `paciente_id`
- `paciente`
- `telefone`
- `convenio`

A ferramenta `ver_agenda_dentista` filtra essa view pelo dentista atual, pelo status `agendada` e por um intervalo de datas.

---

## `dentistas_publico`

Utilizada pelo `Agente pacientes`.

Disponibiliza somente:

```text
id
nome
```

É utilizada para apresentar os profissionais disponíveis e obter o `dentista_id` necessário para consultar horários e realizar agendamentos.

---

## `consultas_detalhe`

Utilizada pelo `Agente pacientes`.

Relaciona:

```text
consultas
    ↓
pacientes
    ↓
dentistas
```

Disponibiliza os dados necessários para consultar os agendamentos futuros do paciente, incluindo o dentista associado.

A ferramenta `minhas_consultas` filtra:

```text
cliente_id = paciente atual
status = agendada
data_hora >= momento atual
```

---

# Ferramentas dos agentes

## Ferramentas do dentista

### `ver_agenda_dentista`

Consulta a view `agenda`.

Recebe um intervalo:

```text
inicio
fim
```

em ISO 8601 com fuso `-03:00`.

---

### `buscar_paciente`

Busca pacientes na tabela `pacientes` utilizando uma palavra do nome ou sobrenome.

É utilizada para obter o `paciente_id` antes de um agendamento.

---

### `agendar_consulta_dentista`

Cria um registro em `consultas` com:

```text
dentista_id
cliente_id
data_hora
status = agendada
```

O agente deve consultar a agenda antes e solicitar confirmação do dentista antes de executar a ferramenta.

---

### `cancelar_consulta_dentista`

Altera o status da consulta para:

```text
cancelada
```

A consulta não é apagada do banco.

---

## Ferramentas do paciente

### `listar_dentistas`

Consulta:

```text
dentistas_publico
```

Retorna os dentistas disponíveis.

### `minhas_consultas`

Consulta:

```text
consultas_detalhe
```

Retorna as consultas futuras do paciente.

### `verificar_disponibilidade_dentista`

Consulta a tabela `consultas` para encontrar horários ocupados de um dentista em determinado intervalo.

### `agendar_consulta_paciente`

Cria uma consulta para o paciente identificado pelo fluxo.

### `cancelar_consulta_paciente`

Altera o status de uma consulta específica para:

```text
cancelada
```

O filtro também verifica o `cliente_id`, evitando que o agente cancele uma consulta pertencente a outro paciente.

---

# Regras de atendimento implementadas

O comportamento dos agentes inclui algumas regras importantes.

### Confirmação antes de alterações

Antes de agendar ou cancelar, o agente repete os dados relevantes e solicita confirmação.

A ferramenta só deve ser executada após a confirmação.

### Não inventar informações

Os agentes são instruídos a utilizar os resultados das ferramentas para:

- pacientes;
- dentistas;
- horários;
- consultas.

### Privacidade

No atendimento aos dentistas, o prompt limita os dados compartilhados sobre pacientes a:

- nome;
- telefone;
- convênio.

O endereço não deve ser informado pelo agente.

No atendimento aos pacientes, o agente só pode consultar e alterar consultas associadas ao próprio paciente.

### Limites do atendimento

Os agentes não fornecem:

- orientação médica;
- diagnóstico;
- valores de consulta.

Pedidos fora do escopo ou situações de urgência devem ser encaminhados para atendimento humano.

---

# Configuração

## 1. Supabase

Execute:

```text
supabase.sql
```

no SQL Editor do Supabase.

O script cria:

```text
pacientes
dentistas
consultas
agenda
dentistas_publico
consultas_detalhe
```

e insere dados de exemplo.

---

## 2. Redis

Configure uma instância Redis acessível pelo n8n.

O workflow possui três memórias:

```text
Redis Chat Memory (dentistas)
Redis Chat Memory (pacientes)
Redis Chat Memory (cadastro)
```

---

## 3. Evolution API

Configure a instância do WhatsApp na Evolution API.

O webhook utilizado pelo n8n é:

```text
POST /webhook/whatsapp-in
```

A URL completa depende do endereço da sua instalação do n8n.

Configure o evento de recebimento de mensagens para enviar os dados ao webhook.

---

## 4. Credenciais do n8n

O workflow utiliza credenciais para:

- Supabase;
- Redis;
- Groq;
- Google Gemini;
- Evolution API.

As credenciais não estão incluídas neste repositório.

Configure-as novamente ao importar o workflow em outra instalação do n8n.

---

## 5. Importar o workflow

No n8n:

1. Abra o editor.
2. Selecione a opção de importar workflow.
3. Importe:

```text
Atendimento Odontológico Inteligente - WhatsApp + Supabase.json
```

4. Reconfigure as credenciais.
5. Atualize os números fictícios do nó `Switch`.
6. Configure o webhook da Evolution API.
7. Execute testes com pacientes e dentistas cadastrados.

---

# Dados de exemplo

O `supabase.sql` inclui cinco pacientes de exemplo:

```text
Ana Silva
Bruno Oliveira
Claudia Menezes
Diego Ferreira
Elena Ramos
```

Também inclui dois dentistas fictícios correspondentes aos números configurados no `Switch`.

Os dados servem apenas para testes do workflow.

---

# Estrutura do repositório

```text
atendimento_whats/
│
├── README.md
├── supabase.sql
│
└── Atendimento Odontológico Inteligente - WhatsApp + Supabase.json
```

---

# Fluxo resumido

```text
                    ┌──────────────────┐
                    │     WhatsApp     │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Evolution API   │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │   n8n Webhook    │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │ Identifica número│
                    └────────┬─────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
          Dentista                       Paciente
              │                             │
              ▼                             ▼
      ┌──────────────┐             ┌────────────────┐
      │Agente        │             │Busca paciente  │
      │dentistas     │             └───────┬────────┘
      └──────┬───────┘                     │
             │                     ┌───────┴────────┐
             │                     │                │
             │                  Existe?          Novo
             │                     │                │
             │                     ▼                ▼
             │             ┌──────────────┐  ┌──────────────┐
             │             │Agente        │  │Agente de     │
             │             │pacientes     │  │cadastro      │
             │             └──────┬───────┘  └──────┬───────┘
             │                    │                 │
             └────────────────────┴─────────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ Evolution API   │
                         │ → WhatsApp      │
                         └─────────────────┘
```

---

## Tecnologias

- **n8n** — orquestração do workflow
- **Evolution API** — integração com WhatsApp
- **Supabase / PostgreSQL** — persistência dos dados
- **Redis** — memória conversacional
- **Google Gemini** — modelo utilizado pelo agente de dentistas
- **Groq + Qwen** — modelos utilizados pelos agentes de pacientes e cadastro
- **LangChain / n8n AI Agent** — estrutura dos agentes e ferramentas

---

## Arquivos

- `Atendimento Odontológico Inteligente - WhatsApp + Supabase.json` — workflow exportado do n8n.
- `supabase.sql` — criação das tabelas, views, índice e dados de exemplo.
- `README.md` — documentação do projeto.
