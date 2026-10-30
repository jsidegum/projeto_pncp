"""
carregar.py  -  CARGA NO POSTGRESQL   (voce completa os trechos com ____)
=========================================================================
Passos:  1) recria o banco e as tabelas (banco.recriar_banco + sql/01_criar_banco.sql)
         2) carrega as 4 DIMENSOES   3) carrega a FATO (as dimensoes vem primeiro!)   4) confere as contagens
Usa so o que o kit ja traz: src/config.py e src/banco.py (recriar_banco, conectar, executar_script, inserir_em_lote, consultar).
O sql/01_criar_banco.sql e o SEU script (veja a secao 4.3 do enunciado): crie esse arquivo antes de rodar a carga.
Ele so cria as tabelas: o banco em si e recriado por banco.recriar_banco().
Dica: veja a carga em lote do 1_extrair.py do Desafio Transparencia (banco.inserir_em_lote).

COMO RODAR (depois do montar_tabelas):   python -m src.carregar
"""

import pandas as pd

from src import banco, config


def ler(nome, **opcoes):
    """PRONTA. Le um CSV de data/processed. Campo vazio vira NaN (que mais abaixo vira None = NULL no banco)."""
    return pd.read_csv(config.PASTA_PROCESSED / f"{nome}.csv", keep_default_na=False, na_values=[""], **opcoes)


def tuplas(tabela, colunas):
    """PRONTA. Transforma o DataFrame em uma lista de tuplas simples, que e o que o banco entende.
    Valor vazio (NaN) vira None, que o banco grava como NULL."""
    dados = tabela[colunas].astype(object)
    dados = dados.where(dados.notna(), None)
    return [tuple(linha) for linha in dados.itertuples(index=False, name=None)]


def inserir(con, tabela, colunas, dados):
    """Monta o INSERT INTO ... VALUES (%s, %s, ...) e envia todas as linhas de uma vez."""
    # Um %s para cada coluna. COMPLETE: monte uma lista com "%s" repetido len(colunas) vezes:  ["%s"] * len(colunas)
    marcadores = ", ".join(["%s"] * len(colunas))
    sql = f"INSERT INTO {tabela} ({', '.join(colunas)}) VALUES ({marcadores})"
    # COMPLETE: envie em lote com banco.inserir_em_lote(conexao, sql, linhas)
    try:
        banco.inserir_em_lote(con, sql, tuplas(dados, colunas))
    except Exception as erro:
        con.rollback()                       # desfaz o lote que falhou e avisa qual tabela quebrou
        raise RuntimeError(f"Falha ao carregar {tabela}: {erro}") from erro
    print(f"   {tabela}: {len(dados)} linhas")


def validar_fks(fato, dimensoes):
    """Validacao previa de integridade: toda FK da fato precisa existir na dimensao (antes de tocar no banco)."""
    for sk, dim in dimensoes.items():
        orfas = set(fato[sk].dropna()) - set(dim[sk].astype(int))
        if orfas or fato[sk].isna().any():
            raise ValueError(f"FK solta em {sk}: {sorted(orfas)[:5]} (ou valor vazio). Corrija antes de carregar.")


def main():
    # 1) Banco (o recriar_banco apaga e cria de novo) e tabelas
    banco.recriar_banco()
    con = banco.conectar()
    # COMPLETE: execute o arquivo SQL de criacao: banco.executar_script(conexao, caminho_do_arquivo)
    banco.executar_script(con, config.PASTA_SQL / "01_criar_banco.sql")

    # 2) Dimensoes PRIMEIRO: a fato tem chave estrangeira para elas, entao elas precisam existir antes.
    print("Carga:")
    dimensoes = {}
    for nome, colunas in [("dim_orgao", ["sk_orgao", "cnpj_orgao", "nome_orgao", "poder"]),
                          ("dim_fornecedor", ["sk_fornecedor", "ni_fornecedor", "nome_fornecedor", "tipo_pessoa", "porte"]),
                          ("dim_modalidade", ["sk_modalidade", "modalidade_id", "nome_modalidade"]),
                          ("dim_localidade", ["sk_localidade", "uf_sigla", "uf_nome", "regiao"])]:
        # dtype=str: o CNPJ nao pode perder o zero da esquerda ao ser lido
        dim = ler(nome, dtype=str)
        dimensoes["sk_" + nome.replace("dim_", "")] = dim
        inserir(con, nome, colunas, dim)

    # 3) Fato (depois das dimensoes)
    fato = ler("fato_item_contratado")
    # dias_ciclo vem como 48.0 (decimal) porque tem vazios; o banco quer inteiro. COMPLETE: converta para o tipo "Int64"
    fato["dias_ciclo"] = fato["dias_ciclo"].astype("Int64")
    colunas = ["numero_controle_pncp", "numero_item", "sk_orgao", "sk_fornecedor", "sk_modalidade", "sk_localidade",
               "data_publicacao", "data_homologacao", "descricao_item", "perfil_gasto", "quantidade",
               "valor_unitario_estimado", "valor_total_estimado", "valor_unitario_homologado", "valor_total_homologado",
               "comparavel", "economia_valor", "dias_ciclo"]
    # COMPLETE: o nome da tabela da fato
    validar_fks(fato, dimensoes)             # falha ANTES de inserir se houver FK solta
    inserir(con, "fato_item_contratado", colunas, fato)

    # 4) Conferencia: o que esta no banco tem que bater com a prova real (anexo 8 do enunciado)
    print("Conferencia:")
    # as dimensoes tem a linha de excecao "Nao informado" (sk = -1), que nao entra na contagem esperada
    for tabela, esperado in [("fato_item_contratado", 6126), ("dim_orgao", 363), ("dim_fornecedor", 2652),
                             ("dim_modalidade", 7), ("dim_localidade", 27)]:
        # COMPLETE: conte as linhas da tabela com SELECT COUNT(*)
        filtro = "TRUE" if tabela.startswith("fato") else f"sk_{tabela[4:]} > 0"
        n = banco.consultar(con, f"SELECT COUNT(*) FROM {tabela} WHERE {filtro}")[0][0]
        print(f"   {tabela}: {n} (esperado {esperado}) -> {'OK' if n == esperado else 'DIVERGENTE'}")
    con.close()


if __name__ == "__main__":
    main()
