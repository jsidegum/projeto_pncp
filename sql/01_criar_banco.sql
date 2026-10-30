-- 01_criar_banco.sql : Star Schema (1 fato + 4 dimensoes) do projeto PNCP / Controladoria
-- O banco em si e recriado por src/banco.py (recriar_banco). Este script so cria as tabelas.
-- Atencao: o executor separa os comandos por ponto e virgula, entao nao use ponto e virgula nos comentarios.

-- =====================================================================
-- DIMENSOES: chave substituta (sk_) = PK / chave natural = UNIQUE NOT NULL
-- =====================================================================
CREATE TABLE dim_orgao (
    sk_orgao     INTEGER      PRIMARY KEY,
    cnpj_orgao   VARCHAR(14)  NOT NULL UNIQUE,
    nome_orgao   VARCHAR(300) NOT NULL,
    poder        VARCHAR(30)  NOT NULL
);

CREATE TABLE dim_fornecedor (
    sk_fornecedor   INTEGER      PRIMARY KEY,
    ni_fornecedor   VARCHAR(30)  NOT NULL UNIQUE,
    nome_fornecedor VARCHAR(300),
    tipo_pessoa     VARCHAR(5),
    porte           VARCHAR(60)
);

CREATE TABLE dim_modalidade (
    sk_modalidade   INTEGER      PRIMARY KEY,
    modalidade_id   INTEGER      NOT NULL UNIQUE,
    nome_modalidade VARCHAR(60)  NOT NULL
);

CREATE TABLE dim_localidade (
    sk_localidade INTEGER      PRIMARY KEY,
    uf_sigla      VARCHAR(2)   NOT NULL UNIQUE,
    uf_nome       VARCHAR(60)  NOT NULL,
    regiao        VARCHAR(20)  NOT NULL
);

-- Linha de excecao "Nao informado" (sk = -1): garante que nenhuma FK da fato fique solta.
-- A chave natural e um valor que nao existe nas demais linhas.
INSERT INTO dim_orgao        VALUES (-1, '-1', 'NÃO INFORMADO', 'Não informado');
INSERT INTO dim_fornecedor   VALUES (-1, '-1', 'NÃO INFORMADO', NULL, NULL);
INSERT INTO dim_modalidade   VALUES (-1, -1, 'Não informado');
INSERT INTO dim_localidade   VALUES (-1, '-1', 'NÃO INFORMADO', 'Não informado');

-- =====================================================================
-- FATO: grao = 1 linha por item de contratacao (numero_controle_pncp + numero_item)
-- =====================================================================
CREATE TABLE fato_item_contratado (
    sk_fato                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero_controle_pncp      VARCHAR(60)    NOT NULL,
    numero_item               INTEGER        NOT NULL,
    sk_orgao                  INTEGER        NOT NULL REFERENCES dim_orgao (sk_orgao),
    sk_fornecedor             INTEGER        NOT NULL REFERENCES dim_fornecedor (sk_fornecedor),
    sk_modalidade             INTEGER        NOT NULL REFERENCES dim_modalidade (sk_modalidade),
    sk_localidade             INTEGER        NOT NULL REFERENCES dim_localidade (sk_localidade),
    data_publicacao           DATE           NOT NULL,
    data_homologacao          DATE,
    descricao_item            TEXT,
    perfil_gasto              VARCHAR(30)    NOT NULL,
    quantidade                DECIMAL(18,4)  NOT NULL,
    valor_unitario_estimado   DECIMAL(18,4)  NOT NULL,
    valor_total_estimado      DECIMAL(18,2)  NOT NULL,
    valor_unitario_homologado DECIMAL(18,4)  NOT NULL,
    valor_total_homologado    DECIMAL(18,2)  NOT NULL,
    comparavel                SMALLINT       NOT NULL,
    economia_valor            DECIMAL(18,2),
    dias_ciclo                INTEGER,
    CONSTRAINT uq_fato_item UNIQUE (numero_controle_pncp, numero_item),
    CONSTRAINT ck_quantidade_positiva CHECK (quantidade > 0),
    CONSTRAINT ck_valores_nao_negativos CHECK (valor_unitario_estimado >= 0 AND valor_total_estimado >= 0
                                               AND valor_unitario_homologado >= 0 AND valor_total_homologado >= 0),
    CONSTRAINT ck_comparavel CHECK (comparavel IN (0, 1)),
    CONSTRAINT ck_perfil CHECK (perfil_gasto IN ('Bens', 'Serviços', 'Obras e engenharia')),
    CONSTRAINT ck_ciclo_nao_negativo CHECK (dias_ciclo IS NULL OR dias_ciclo >= 0)
);

-- Indices nas FKs (acelera os JOINs das perguntas)
CREATE INDEX ix_fato_orgao      ON fato_item_contratado (sk_orgao);
CREATE INDEX ix_fato_fornecedor ON fato_item_contratado (sk_fornecedor);
CREATE INDEX ix_fato_modalidade ON fato_item_contratado (sk_modalidade);
CREATE INDEX ix_fato_localidade ON fato_item_contratado (sk_localidade);
