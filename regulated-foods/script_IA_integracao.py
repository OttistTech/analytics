import json
from pymongo import MongoClient
import psycopg2
from googletrans import Translator
import pickle
import pandas as pd
import os
import pickle
from sklearn.preprocessing import LabelEncoder
import pickle

def obter_previsao_para_usuario(model, population, purchase_hystory, country):
    features_df = pd.DataFrame({
        'país': [country],
        'population': [population],
        'purchase_specief': [purchase_hystory],
        'col_5': [2123],
        'col_6': [7],
        'col_7': [303.3]
    })
    return (label_encoder.inverse_transform((model.predict(features_df)))).tolist()

# Função para salvar a previsão no MongoDB
def salvar_previsao_no_mongo(user_id, previsao):
    # Cria o documento a ser salvo
    documento = {
        "usuário": user_id,
        "resultado": previsao
    }
    collection.insert_one(documento)
    print(f"Previsão para o usuário {user_id} armazenada com sucesso.")

# Função para limpar a coleção no MongoDB
def limpar_collection():
    collection.delete_many({})
    print("Coleção limpa com sucesso.")

# Instanciando o tradutor
translator = Translator()

# Substitua o caminho abaixo pelo seu caminho absoluto
caminho_arquivo = './melhor_modelo.pkl'

# Verificando se o arquivo existe
if os.path.exists(caminho_arquivo):
    model = pickle.load(open(caminho_arquivo, 'rb'))
else:
    print("Arquivo não encontrado:", caminho_arquivo)


# Configurações do MongoDB
MONGO_URI = 'mongodb+srv://ottistechindespensa:8xHl12le5hASngqq@cluster0.1weg8.mongodb.net/'
mongo_client = MongoClient(MONGO_URI)
db = mongo_client['predicoes']
collection = db['consumo_diario']

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

POSTGRES_URI = f"postgresql://{conn_params['user']}:{conn_params['password']}@{conn_params['host']}:{conn_params['port']}/{conn_params['dbname']}"
sql_conn = psycopg2.connect(POSTGRES_URI)
sql_cursor = sql_conn.cursor()

sql_cursor.execute("SELECT user_id FROM users")
usuarios_inputs = sql_cursor.fetchall()
usuarios_ids = [usuario[0] for usuario in usuarios_inputs]

for user_id in usuarios_ids:
    sql_cursor.execute(f"SELECT grupo_populacional FROM users WHERE user_id = {user_id}")
    populational_group_result = sql_cursor.fetchone()
    populational_group = populational_group_result[0] if populational_group_result else None

    sql_cursor.execute(f"SELECT get_most_consumed_food({user_id})")
    purchase_history_result = sql_cursor.fetchone()
    purchase_history = purchase_history_result[0] if purchase_history_result else None

    if purchase_history:
        purchase_history_text = translator.translate(purchase_history, src='pt', dest='en')
        purchase_history_en = purchase_history_text.text

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
        
        # Salvando a previsão no MongoDB
        salvar_previsao_no_mongo(user_id, previsao)
        print(f"Previsão para usuário {user_id}: {previsao}")

# Fechando conexões
sql_cursor.close()
sql_conn.close()
mongo_client.close()
