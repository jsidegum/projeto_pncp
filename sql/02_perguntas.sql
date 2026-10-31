-- 02_perguntas.sql : respostas das 6 perguntas da Controladoria
-- Regras: percentual = SOMA / SOMA (nunca media de percentuais)
--         economia so conta itens comparaveis (comparavel = 1)
--         NULLIF evita divisao por zero (ex.: Credenciamento nao tem item comparavel)

-- ---------------------------------------------------------------------
-- P1. Economia global: valor (R$) e percentual economizado
-- ---------------------------------------------------------------------
SELECT SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado   ELSE 0 END)               AS estimado_comparavel,
       SUM(CASE WHEN comparavel = 1 THEN valor_total_homologado ELSE 0 END)               AS homologado_comparavel,
       SUM(economia_valor)                                                               AS economia_rs,
       ROUND(100.0 * SUM(economia_valor)
             / NULLIF(SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct,
       SUM(valor_total_homologado)                                                       AS volume_homologado,
       COUNT(*)                                                                          AS itens,
       SUM(comparavel)                                                                   AS itens_comparaveis
FROM fato_item_contratado;

-- ---------------------------------------------------------------------
-- P2. Concentracao: 10 maiores fornecedores por volume e % do total
-- ---------------------------------------------------------------------
SELECT f.ni_fornecedor,
       f.nome_fornecedor,
       SUM(t.valor_total_homologado)                                                        AS volume,
       ROUND(100.0 * SUM(t.valor_total_homologado)
             / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)           AS pct_do_total
FROM fato_item_contratado t
JOIN dim_fornecedor f ON f.sk_fornecedor = t.sk_fornecedor
GROUP BY f.ni_fornecedor, f.nome_fornecedor
ORDER BY volume DESC
LIMIT 10;

-- P2 (complemento): quanto os 10 maiores somam juntos (concentracao Top 10 %)
SELECT ROUND(100.0 * SUM(volume) / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS concentracao_top10_pct
FROM (SELECT SUM(valor_total_homologado) AS volume
      FROM fato_item_contratado
      GROUP BY sk_fornecedor
      ORDER BY volume DESC
      LIMIT 10) AS top10;

-- ---------------------------------------------------------------------
-- P3. Modalidades: quem economiza mais (desagio) e quem concentra mais volume
-- ---------------------------------------------------------------------
SELECT m.nome_modalidade,
       COUNT(*)                                                                             AS itens,
       SUM(t.valor_total_homologado)                                                        AS volume,
       ROUND(100.0 * SUM(t.valor_total_homologado)
             / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)           AS pct_do_volume,
       ROUND(100.0 * SUM(t.economia_valor)
             / NULLIF(SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado t
JOIN dim_modalidade m ON m.sk_modalidade = t.sk_modalidade
GROUP BY m.nome_modalidade
ORDER BY volume DESC;

-- ---------------------------------------------------------------------
-- P4. Ciclo: media de dias entre publicacao e homologacao, por orgao (nome padronizado)
--     So orgaos com 5 ou mais itens com ciclo (COUNT(dias_ciclo) ignora os vazios)
-- ---------------------------------------------------------------------
SELECT o.nome_orgao,
       COUNT(DISTINCT o.cnpj_orgao)        AS unidades_compradoras,
       COUNT(t.dias_ciclo)                 AS itens_com_ciclo,
       ROUND(AVG(t.dias_ciclo), 1)         AS ciclo_medio_dias,
       MAX(t.dias_ciclo)                   AS ciclo_maximo_dias
FROM fato_item_contratado t
JOIN dim_orgao o ON o.sk_orgao = t.sk_orgao
GROUP BY o.nome_orgao
HAVING COUNT(t.dias_ciclo) >= 5
ORDER BY ciclo_medio_dias DESC;

-- ---------------------------------------------------------------------
-- P5. Regional: despesa e desagio por UF e por regiao
-- ---------------------------------------------------------------------
-- por UF
SELECT l.uf_sigla,
       l.regiao,
       SUM(t.valor_total_homologado)                                                        AS volume,
       ROUND(100.0 * SUM(t.economia_valor)
             / NULLIF(SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado t
JOIN dim_localidade l ON l.sk_localidade = t.sk_localidade
GROUP BY l.uf_sigla, l.regiao
ORDER BY volume DESC;

-- por regiao
SELECT l.regiao,
       SUM(t.valor_total_homologado)                                                        AS volume,
       ROUND(100.0 * SUM(t.valor_total_homologado)
             / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)           AS pct_do_volume,
       ROUND(100.0 * SUM(t.economia_valor)
             / NULLIF(SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado t
JOIN dim_localidade l ON l.sk_localidade = t.sk_localidade
GROUP BY l.regiao
ORDER BY volume DESC;

-- ---------------------------------------------------------------------
-- P6. Perfil do gasto: Bens x Servicos x Obras e engenharia (coluna da propria fato, sem JOIN)
-- ---------------------------------------------------------------------
SELECT perfil_gasto,
       COUNT(*)                                                                             AS itens,
       SUM(valor_total_homologado)                                                          AS volume,
       ROUND(100.0 * SUM(valor_total_homologado)
             / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)           AS pct_do_volume,
       ROUND(SUM(valor_total_homologado) / COUNT(*), 2)                                     AS ticket_medio
FROM fato_item_contratado
GROUP BY perfil_gasto
ORDER BY volume DESC;
