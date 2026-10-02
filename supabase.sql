-- ============================================================
-- SUPABASE - ATENDIMENTO ODONTOLÓGICO INTELIGENTE
-- Projeto: atendimento_whats
--
-- Estrutura utilizada pelo workflow:
-- - pacientes
-- - dentistas
-- - consultas
-- - agenda
-- - dentistas_publico
-- - consultas_detalhe
--
-- O workflow do n8n utiliza:
--   pacientes          -> identificação, busca e cadastro
--   dentistas          -> identificação interna dos profissionais
--   consultas          -> criação, disponibilidade e cancelamento
--   agenda             -> agenda do dentista com dados do paciente
--   dentistas_publico  -> lista de dentistas para pacientes
--   consultas_detalhe  -> consultas futuras do paciente
--
-- Execute as seções na ordem apresentada.
-- ============================================================


-- ============================================================
-- 1. TABELA pacientes
-- ============================================================
-- O workflow pressupõe que esta tabela já exista.
-- A definição abaixo pode ser usada em uma instalação nova.

create table if not exists pacientes (
  id bigint generated always as identity primary key,
  nome text not null,
  sobrenome text not null,
  telefone text not null,
  convenio text,
  endereco text
);


-- ============================================================
-- 2. POPULAÇÃO INICIAL DE pacientes
-- ============================================================

insert into pacientes (nome, sobrenome, telefone, convenio, endereco)
values
  (
    'Ana',
    'Silva',
    '+55 (11) 98765-4321',
    'Unimed',
    'Rua das Flores, 123, Apto 45 - São Paulo, SP'
  ),
  (
    'Bruno',
    'Oliveira',
    '+55 (21) 91234-5678',
    null,
    'Av. Atlântica, 400 - Rio de Janeiro, RJ'
  ),
  (
    'Claudia',
    'Menezes',
    '+55 (31) 99876-1122',
    'Bradesco Saúde',
    'Rua da Bahia, 850 - Belo Horizonte, MG'
  ),
  (
    'Diego',
    'Ferreira',
    '+55 (41) 97654-3344',
    null,
    'Rua XV de Novembro, 1500 - Curitiba, PR'
  ),
  (
    'Elena',
    'Ramos',
    '+55 (48) 98888-7766',
    'Amil',
    'Rodovia SC-401, Km 5 - Florianópolis, SC'
  );


-- ============================================================
-- 3. TABELA dentistas
-- ============================================================
-- O telefone é utilizado pelo workflow para identificar
-- o dentista que está conversando pelo WhatsApp.

create table if not exists dentistas (
  id bigint generated always as identity primary key,
  nome text not null,
  telefone text not null
);


-- ============================================================
-- 4. DENTISTAS DE EXEMPLO
-- ============================================================
-- Os números abaixo correspondem aos números fictícios
-- configurados no nó "Switch" do workflow.
--
-- Substitua pelos dados reais da clínica.

insert into dentistas (nome, telefone)
values
  ('Dra. Dentista 1', '5548999990001'),
  ('Dr. Dentista 2', '5548999990002');


-- ============================================================
-- 5. TABELA consultas
-- ============================================================

create table if not exists consultas (
  id bigint generated always as identity primary key,
  cliente_id bigint references pacientes(id),
  data_hora timestamptz not null,
  duracao_min int default 30,
  status text default 'agendada',
  observacoes text,
  created_at timestamptz default now()
);


-- Adiciona o dentista responsável pela consulta.
alter table consultas
  add column if not exists dentista_id bigint references dentistas(id);


-- ============================================================
-- 6. ÍNDICE DE CONFLITO DE HORÁRIOS
-- ============================================================
-- Garante que um dentista não tenha duas consultas
-- "agendada" exatamente no mesmo horário.
--
-- A regra considera o dentista porque a agenda é separada
-- por profissional.

drop index if exists consultas_slot_unico;

create unique index consultas_slot_unico
  on consultas (dentista_id, data_hora)
  where status = 'agendada';


-- ============================================================
-- 7. VIEW agenda
-- ============================================================
-- Utilizada pelo agente interno dos dentistas.
--
-- O workflow consulta esta view para:
-- - visualizar a agenda;
-- - identificar o paciente;
-- - consultar telefone e convênio;
-- - filtrar por dentista, status e intervalo de datas.

create or replace view agenda as
select
  c.id as consulta_id,
  c.dentista_id,
  c.data_hora,
  c.status,
  p.id as paciente_id,
  p.nome || ' ' || p.sobrenome as paciente,
  p.telefone,
  p.convenio
from consultas c
join pacientes p
  on p.id = c.cliente_id;


-- ============================================================
-- 8. VIEW dentistas_publico
-- ============================================================
-- Utilizada pelo agente de pacientes.
--
-- O workflow precisa apenas do ID e do nome dos dentistas
-- para permitir que o paciente escolha o profissional.

create or replace view dentistas_publico as
select
  id,
  nome
from dentistas;


-- ============================================================
-- 9. VIEW consultas_detalhe
-- ============================================================
-- Utilizada pelo agente de pacientes para consultar
-- agendamentos futuros do paciente, exibindo também
-- o nome do dentista.

create or replace view consultas_detalhe as
select
  c.id as consulta_id,
  c.cliente_id,
  c.dentista_id,
  c.data_hora,
  c.duracao_min,
  c.status,
  c.observacoes,
  c.created_at,
  d.nome as dentista,
  p.nome || ' ' || p.sobrenome as paciente,
  p.telefone,
  p.convenio
from consultas c
join pacientes p
  on p.id = c.cliente_id
join dentistas d
  on d.id = c.dentista_id;


-- ============================================================
-- 10. CONSULTAS DE VERIFICAÇÃO
-- ============================================================
-- Execute opcionalmente para conferir a estrutura criada.

-- select * from pacientes;
-- select * from dentistas;
-- select * from consultas;
-- select * from agenda;
-- select * from dentistas_publico;
-- select * from consultas_detalhe;


-- ============================================================
-- OBSERVAÇÕES
-- ============================================================
--
-- 1. O workflow utiliza "status = 'agendada'" para considerar
--    um horário ocupado.
--
-- 2. O cancelamento não remove a consulta:
--    o workflow altera o status para "cancelada".
--
-- 3. O índice parcial libera novamente o horário quando a
--    consulta deixa de ter status "agendada".
--
-- 4. O workflow trabalha com consultas de 30 minutos e horários
--    em intervalos de 30 minutos. Essa regra está no prompt dos
--    agentes e não é uma restrição de banco.
--
-- 5. A proteção contra horários no passado também está no fluxo
--    de atendimento e não como constraint SQL.
--
-- 6. O índice impede conflito no mesmo "dentista_id + data_hora".
--    Ele não implementa detecção de sobreposição de intervalos.
--
-- 7. Os telefones de exemplo dos dentistas são fictícios e devem
--    ser substituídos no ambiente real.
