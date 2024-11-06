# Configurações de importação e conexão permanecem as mesmas
from pymongo import MongoClient
import psycopg2
from googletrans import Translator
import pickle
import pandas as pd
import os
from decimal import Decimal

# Função para obter a previsão para um usuário
def obter_previsao_para_usuario(model, registro):
    return (label_encoder.inverse_transform((model.predict(registro)))).tolist()

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

translator = Translator()
caminho_arquivo = './melhor_modelo.pkl'
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
    "dbname": "dbindespensa_fv24",
    "user": "indespensa",
    "host": "dpg-csl2vqa3esus73fvltng-a.virginia-postgres.render.com",
    "password": "vq3oH4u3kTMHFjW5ug6kl1bR5NCQh7k0",
    "port": "5432"
}
POSTGRES_URI = f"postgresql://{conn_params['user']}:{conn_params['password']}@{conn_params['host']}:{conn_params['port']}/{conn_params['dbname']}"
sql_conn = psycopg2.connect(POSTGRES_URI)
sql_cursor = sql_conn.cursor()

# Coletando todos os usuários 
sql_cursor.execute("SELECT user_id FROM users")
usuarios_inputs = sql_cursor.fetchall()
usuarios_ids = [usuario[0] for usuario in usuarios_inputs]

# Variável de controle para verificar se encontrou pelo menos um `purchase_history`
achou_purchase_history = False

# Loop para cada usuário
for user_id in usuarios_ids:
    sql_cursor.execute(f"SELECT population_group FROM users WHERE user_id = {user_id}")
    populational_group_result = sql_cursor.fetchone()
    populational_group = populational_group_result[0] if populational_group_result else None

    if populational_group:

        # Consulta para obter `purchase_history`
        sql_cursor.execute(f"SELECT get_most_consumed_food({user_id})")
        purchase_history_result = sql_cursor.fetchone()
        purchase_history = purchase_history_result[0] if purchase_history_result else None

        if not purchase_history:
            print(f"Usuário {user_id} não possui histórico de consumo. Pulando para o próximo usuário.")
            continue

        # Se encontrou um usuário com `purchase_history`, define a flag como True
        achou_purchase_history = True

        # Carregando preprocessador e label encoder
        preprocessador = pickle.load(open('./preprocessador.pkl', 'rb'))
        label_encoder = pickle.load(open('./label_encoder.pkl', 'rb'))

        # Criando DataFrame de entrada
        df_input = pd.DataFrame({
            'Country': ['France'],
            'PopulationGroup': [populational_group],
            'ConsumptionCategory': [purchase_history],
            'GramsPerDays': [2703],
            'Days': [7],
            'GramsOneDay': [303.3]
        }, index=[0])

        registro = preprocessador.transform(df_input)
        previsao = obter_previsao_para_usuario(model, registro)

        print(previsao[0])
        # Recuperando produtos com base na previsão
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
            products_list = [
                {
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
                for product in products
            ]
            salvar_previsao_no_mongo(user_id, previsao, products_list)
        else:
            print(f"Nenhum produto encontrado para a previsão: {previsao[0]}")
    else:
        print(f"Usuário {user_id} sem grupo populacional. Pulando.")

# Se não encontrou nenhum `purchase_history` ao final, encerra com uma mensagem
if not achou_purchase_history:
    print("Nenhum usuário possui histórico de consumo. Encerrando o programa.")

# Fechando conexões
sql_cursor.close()
sql_conn.close()
mongo_client.close()
