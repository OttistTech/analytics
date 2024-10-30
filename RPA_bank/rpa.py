# Importações
import pandas as pd
import psycopg2
from psycopg2 import sql
from sqlalchemy import create_engine

# Função que extrai dados de uma tabela específica no banco de dados de origem e retorna um DataFrame.
def extract_data_from_table(table_name, conn_params):
    # Conexão SQLAlchemy
    conn_string = f"postgresql://{conn_params['user']}:{conn_params['password']}@{conn_params['host']}:{conn_params['port']}/{conn_params['dbname']}"
    
    try:
        # Criando o motor de conexão usando SQLAlchemy
        engine = create_engine(conn_string)
        # Selecionando todos os dados da tabela fornecida
        query = f"SELECT * FROM {table_name}"
        # Colocando a consulta num DF
        df = pd.read_sql(query, engine)
        return df
    except Exception as e:
        print(f"Erro ao extrair dados da tabela {table_name}: {e}")
        return None

# Função que obtém os nomes das colunas de uma tabela específica no banco de destino.
def get_columns_from_table(table_name, conn_params):
    """Obtem as colunas da tabela de destino."""
    conn = None
    try:
        # Conectando com o banco
        conn = psycopg2.connect(**conn_params)
        cur = conn.cursor()
        # Consultando os nomes das colunas da tabela usando a metadata do banco de dados
        query = f"SELECT column_name FROM information_schema.columns WHERE table_name = '{table_name}'"
        cur.execute(query)
        # Guardando resultados em uma lista
        columns = [row[0] for row in cur.fetchall()]
        return columns
    except Exception as e:
        print(f"Erro ao buscar colunas da tabela {table_name}: {e}")
        return []
    finally:
        # Fecha a conexão com o banco de dados
        if conn:
            cur.close()
            conn.close()

# Função que insere os dados extraídos no banco de destino, garantindo que os dados estejam compatíveis com as colunas de destino.
def insert_data_into_table(df, table_name, conn_params, target_columns):
    conn = None
    try:
        conn = psycopg2.connect(**conn_params)
        cur = conn.cursor()

        # Filtrando as colunas do DataFrame para corresponder às colunas da tabela de destino
        common_columns = [col for col in df.columns if col in target_columns]
        df_filtered = df[common_columns]
        
        # Lidando com valores nulos na coluna 'type', substituindo-os por um valor padrão
        if 'type' in df_filtered.columns:
            df_filtered.loc[df_filtered['type'].isnull(), 'type'] = 'default_type'

        # Cria uma query SQL para inserir os dados na tabela, com um mecanismo de "upsert"
        # Isso evita duplicatas
        insert_query = sql.SQL(
            "INSERT INTO {} ({}) VALUES ({}) "
            "ON CONFLICT (email) DO UPDATE SET {}"
        ).format(
            sql.Identifier(table_name),
            sql.SQL(', ').join(map(sql.Identifier, df.columns)),
            sql.SQL(', ').join(sql.Placeholder() * len(df.columns)),
            sql.SQL(', ').join(
                sql.SQL("{} = EXCLUDED.{}").format(sql.Identifier(col), sql.Identifier(col))
                for col in df.columns
            )
        )

        for _, row in df_filtered.iterrows():
            cur.execute(insert_query, tuple(row))

        # Confirma as alterações no banco de dados
        conn.commit()
        print(f"Dados inseridos com sucesso na tabela {table_name}")
    except Exception as e:
        print(f"Erro ao inserir dados na tabela {table_name}: {e}")
    finally:
        if conn:
            cur.close()
            conn.close()

# Função principal que transfere dados de várias tabelas de origem para tabelas de destino.
def transfer_data(tables_mapping, conn_params_extracao, conn_params_insercao):
    for origem_table, destino_table in tables_mapping.items():
        # Mostrando qual tabela está sendo transferida
        print(f"Transferindo dados da tabela {origem_table} para {destino_table}...")
        
        df = extract_data_from_table(origem_table, conn_params_extracao)
        if df is not None and not df.empty:
            target_columns = get_columns_from_table(destino_table, conn_params_insercao)
            if target_columns:
                insert_data_into_table(df, destino_table, conn_params_insercao, target_columns)
            else:
                print(f"Erro ao buscar colunas da tabela de destino {destino_table}")
        else:
            # Erro se não houver dados para transferir
            print(f"Não há dados para transferir na tabela {origem_table}")

# Parâmetros de conexão para o banco de origem
conn_params_extracao = {
    "dbname": "adm",
    "user": "indepensa",
    "host": "dpg-cs65g2aj1k6c73a03ut0-a.virginia-postgres.render.com",
    "password": "${{secrets.KEY_BANCO2}}",
    "port": "5432"
}

# Parâmetros de conexão para o banco de destino
conn_params_insercao = {
    "dbname": "dbindespensa_h41l",
    "user": "indepensa",
    "host": "dpg-cs65g2aj1k6c73a03ut0-a.virginia-postgres.render.com",
    "password": "${{secrets.KEY_BANCO2}}",
    "port": "5432"
}

# Mapeamento das tabelas de origem para as tabelas de destino
tabelas = {
    "adm": "users",  
    "tag": "tags",  
    "brand": "brand", 
    "products": "product",  
    "cep": "cep",
    "categories": "categories"
}

#Executando trânsferencia
transfer_data(tabelas, conn_params_extracao, conn_params_insercao)
