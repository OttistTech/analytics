# O código a seguir tem o objetivo de prever o consumo do usuário com a inteligência artificial e retornar do SQL 
# para o MongoDB uma lista de produtos aleatórios que sejam da categoria que o usuário tem maior propensão de consumo.

from pymongo import MongoClient
import psycopg2
from googletrans import Translator
import pickle
import pandas as pd
import os
from decimal import Decimal

# Função para obter a previsão para um usuário
def obter_previsao_para_usuario(model, population, purchase_hystory, country):
    features_df = pd.DataFrame({
        'país': [country],
        'population': [population],
        'purchase_specief': [purchase_hystory],
        'col_5': [2123], # Nas variáveis como: país, coluna 5 e ect, adicionamos os valores mais comuns/que mais se repetem nesses campos (segundo nossa análise exploratória) pois, com a pouca informação do banco, não conseguimos preencher esses requisitos.
        'col_6': [7],
        'col_7': [303.3]
    })
    return (label_encoder.inverse_transform((model.predict(features_df)))).tolist()

# Função para salvar a previsão no MongoDB
def salvar_previsao_no_mongo(user_id, previsao, products):
    documento = {
        "user": user_id,
        "result": previsao,
        "products": products
    }
    collection.insert_one(documento)
    print(f"Previsão para o usuário {user_id} armazenada com sucesso.")

# Função para limpar a coleção no MongoDB
def limpar_collection():
    collection.delete_many({})
    print("Coleção limpa com sucesso.")

# Usamos um tradutor, pois em nosso banco recebemos as informações em português. No entanto, o modelo foi treinado em inglês. Logo, foi preciso converter as palavras para inglês.
translator = Translator()

# Consumindo o modelo treinado
caminho_arquivo = './melhor_modelo.pkl'

# Checando se o pickle foi gerado e possui algo nele
if os.path.exists(caminho_arquivo):
    model = pickle.load(open(caminho_arquivo, 'rb'))
else:
    print("Arquivo não encontrado:", caminho_arquivo)

# Configurações do MongoDB
MONGO_URI = 'mongodb+srv://ottistechindespensa:8xHl12le5hASngqq@cluster0.1weg8.mongodb.net/'
mongo_client = MongoClient(MONGO_URI)
db = mongo_client['prediction']
collection = db['daily_consumption']

# Limpar a coleção antes de adicionar novos dados
limpar_collection()

# Configurações do PostgreSQL
conn_params = {
    "dbname": "dbindespensa_h41l",
    "user": "indepensa",
    "host": "dpg-cs65g2aj1k6c73a03ut0-a.virginia-postgres.render.com",
    "password": "BYseHxX3YMee36e1m5JisHJgqS77qER2",
    "port": "5432"
}

# Transformando em uma URI por praticidade
POSTGRES_URI = f"postgresql://{conn_params['user']}:{conn_params['password']}@{conn_params['host']}:{conn_params['port']}/{conn_params['dbname']}"
sql_conn = psycopg2.connect(POSTGRES_URI)
sql_cursor = sql_conn.cursor()

# Coletando todos os usuários 
sql_cursor.execute("SELECT user_id FROM users")
usuarios_inputs = sql_cursor.fetchall()
usuarios_ids = [usuario[0] for usuario in usuarios_inputs]

# Para cada usuário, procuro o grupo populacional no banco sql e guardo em uma variável.
for user_id in usuarios_ids:
    sql_cursor.execute(f"SELECT grupo_populacional FROM users WHERE user_id = {user_id}")
    populational_group_result = sql_cursor.fetchone()
    populational_group = populational_group_result[0] if populational_group_result else None
    
    # O mesmo para tipo de comida mais consumida
    sql_cursor.execute(f"SELECT get_most_consumed_food({user_id})")
    purchase_history_result = sql_cursor.fetchone()
    purchase_history = purchase_history_result[0] if purchase_history_result else None

    if purchase_history:
        purchase_history_text = translator.translate(purchase_history, src='pt', dest='en')
        purchase_history_en = purchase_history_text.text

        # Consumindo preprocessador e label enconders treinados
        preprocessador = pickle.load(open('./preprocessador.pkl', 'rb'))
        label_encoder = pickle.load(open('./label_encoder.pkl', 'rb'))

        # Criando um DataFrame com os dados antes de passar ao preprocessador
        df_input = pd.DataFrame({
            'populational_group': [populational_group],
            'purchase_history': [purchase_history_en],
            'country': ['France']
        })

        # Aplicando o preprocessador no DataFrame
        populational_group_coded = preprocessador.fit_transform(df_input[['populational_group']])
        purchase_history_en_coded = preprocessador.fit_transform(df_input[['purchase_history']])
        country = preprocessador.fit_transform(df_input[['country']])

        # Convertendo a previsão usando o modelo
        previsao = obter_previsao_para_usuario(model, populational_group_coded[0], purchase_history_en_coded[0], country[0])

        # Recuperando produtos
        sql_cursor.execute(f"""
        SELECT 
            p.product_id, 
            p.ean_code, 
            p.name, 
            p.image_url, 
            f.food_name, 
            c.category_name,
            p.description, 
            b.brand_name, 
            p.amount, 
            p.unit,
            p.type 
        FROM get_random_products_by_category('{previsao[0]}') p
        JOIN categories c ON p.category_id = c.category_id  
        JOIN brand b ON p.brand_id = b.brand_id  
        JOIN foods f ON p.food_id = f.food_id
    """)

        products = sql_cursor.fetchall()

        if products:
            # Convertendo Decimal para float e organizando em uma lista de dicionários
            products_list = []
            for product in products:
                product_dict = {
                    "product_id": product[0],
                    "ean_code": product[1],
                    "name": product[2],
                    "image_url": product[3],
                    "food_name": product[4],
                    "category_name": product[5],
                    "description": product[6],
                    "brand_name": product[7],
                    "amount": float(product[8]) if isinstance(product[8], Decimal) else product[8],
                    "unit": product[9],
                    "type": product[10]
                }
                products_list.append(product_dict)

            # Salvando a previsão no MongoDB
            salvar_previsao_no_mongo(user_id, previsao, products_list)
            print(f"Previsão para usuário {user_id}: {previsao} \n Produtos: {products_list}")
        else:
            print(f"Nenhum produto encontrado para a previsão: {previsao[0]}")

# Fechando conexões
sql_cursor.close()
sql_conn.close()
mongo_client.close()