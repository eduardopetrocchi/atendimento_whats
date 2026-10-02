# Atendimento Odontológico Inteligente (WhatsApp + n8n + Supabase + IA)
Workflow modular desenvolvido em **n8n** para automação de atendimento em clínicas odontológicas via **WhatsApp** (Evolution API). Utiliza agentes de Inteligência Artificial com memória conversacional via **Redis** e persistência de dados em **Supabase**.
---
## 📌 Funcionalidades
O fluxo opera por meio de triagem inteligente e roteia as mensagens para três assistentes especializados:

1. **Assistente Interna para Dentistas**:
* Consulta a agenda do dia, semana ou datas específicas.
* Agendamento de consultas para pacientes já cadastrados.
* Cancelamento e remarcação de horários.
* Reconhecimento automático do profissional pelo número de WhatsApp.

2. **Atendimento a Pacientes Cadastrados**:
* Reconhecimento automático do cadastro pelo número de telefone.
* Listagem dos profissionais da clínica.
* Consulta de disponibilidade em tempo real.
* Marcação e cancelamento de consultas.
* Consulta de agendamentos futuros.

3. **Onboarding / Cadastro de Novos Pacientes**:
* Fluxo interativo para captação de novos contatos.
* Coleta guiada de nome completo, convênio/particular e endereço.
* Confirmação dos dados antes da gravação no banco de dados.
---

## 🛠️ Tecnologias Utilizadas
* **Orquestração:** [n8n](https://n8n.io/)
* **WhatsApp API:** [Evolution API](https://github.com/EvolutionAPI/evolution-api)
* **Banco de Dados:** [Supabase](https://supabase.com/) (PostgreSQL)
* **Memória de Sessão:** [Redis](https://redis.io/)
* **Modelos de Linguagem (LLMs):**
* Groq (`qwen/qwen3.8-27b`)
* Google Gemini
---

## 🗄️ Estrutura do Banco de Dados (Supabase)
Para o funcionamento correto das tools integradas ao n8n, certifique-se de configurar as seguintes tabelas e views no seu Supabase:
### 1. `pacientes`
Armazena as informações cadastrais dos clientes.
* `id` (serial / uuid, PK)
* `nome` (text)
* `sobrenome` (text)
* `telefone` (text)
* `convenio` (text)
* `endereco` (text)

### 2. `dentistas`
Controle de acesso interno dos profissionais.
* `id` (serial / uuid, PK)
* `nome` (text)
* `telefone` (text)

### 3. `dentistas_publico` (View ou Tabela)
Exibição pública utilizada pela IA durante o agendamento de pacientes.
* `id`
* `nome`

### 4. `consultas`
Tabela principal de agendamentos.
* `id` (serial / uuid, PK)
* `cliente_id` (FK para `pacientes.id`)
* `dentista_id` (FK para `dentistas.id`)
* `data_hora` (timestamp com timezone)
* `status` (text: `'agendada'`, `'cancelada'`, etc.)

### 5. `agenda` e `consultas_detalhe` (Views auxiliares)
Views relacionando `consultas`, `pacientes` e `dentistas` com campos legíveis para a IA:
* `consulta_id`
* `data_hora`
* `dentista_id` / `dentista`
* `paciente_id` / `paciente`
* `telefone`
* `convenio`
* `status`
---

## 🚀 Como Configurar
1. **Importação no n8n**:
* Copie o JSON do arquivo e importe em uma nova automação no seu n8n.

2. **Configuração de Credenciais**:
Conecte suas credenciais nos nós correspondentes:
* **Supabase API**: URL do projeto e Service Role/Anon Key.
* **Evolution API**: Endpoint da API e API Key.
* **Redis**: Host, porta e senha da sua instância Redis.
* **Groq API / Google Gemini API**: Chaves de API para os modelos de chat.

3. **Configuração do Nó Switch (Dentistas)**:
* Abra o nó `Switch`.
* Substitua os números fictícios (`5548999990001`, `5548999990002`) pelos telefones reais com DDI e DDD dos profissionais autorizados.
* Ajuste os nomes das saídas conforme os dentistas cadastrados.

4. **Webhook na Evolution API**:
* Aponte os eventos de mensagens recebidas (`MESSAGES_UPSERT`) da sua instância da Evolution API para a URL do nó **Webhook** do n8n.

5. **Personalização**:
* Altere o nome fictício (`Clínica OdontoExemplo`) e horários de funcionamento dentro dos `System Messages` dos nós de Agente para atender às regras de negócio da sua clínica.
