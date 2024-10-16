import json
from pymongo import MongoClient
from datetime import datetime
import psycopg2
import boto3

# Configurações da IA
ENDPOINT_NAME = 'nome-do-seu-endpoint'
runtime = boto3.client('runtime.sagemaker')

# Configurações do MongoDB
MONGO_URI = 'mongodb+srv://<user>:<password>@cluster0.mongodb.net/test?retryWrites=true&w=majority'
mongo_client = MongoClient(MONGO_URI)
db = mongo_client['predicoes']
collection = db['consumo_diario']

# Configurações do PostgreSQL
POSTGRES_URI = "dbname='seu_banco' user='seu_usuario' password='sua_senha' host='localhost'"
sql_conn = psycopg2.connect(POSTGRES_URI)
sql_cursor = sql_conn.cursor()

# Função para buscar previsões de consumo para um usuário
def obter_previsao_para_usuario(user_id, age, purchase_history):
    payload = {
        "user_id": user_id,
        "age": age,
        "purchase_history": purchase_history
    }
    
    # Fazendo requisição para o endpoint da IA
    response = runtime.invoke_endpoint(EndpointName=ENDPOINT_NAME,
                                    ContentType='application/json',
                                    Body=json.dumps(payload))
    
    # Recebendo a previsão da IA
    result = json.loads(response['Body'].read().decode())
    
    return result

# Função para salvar a previsão no MongoDB
def salvar_previsao_no_mongo(user_id, previsao):
    # Cria o documento a ser salvo
    documento = {
        "user_id": user_id,
        "previsao": previsao,
        "data": datetime.now()
    }
    
    # Inserindo no MongoDB
    collection.insert_one(documento)
    print(f"Previsão para o usuário {user_id} armazenada com sucesso.")

# Função para buscar usuários do banco de dados SQL
def buscar_usuarios_do_sql():
    sql_cursor.execute("SELECT user_id, age, purchase_history FROM usuarios")
    return sql_cursor.fetchall()

# Buscando usuários e suas previsões
usuarios = buscar_usuarios_do_sql()

# Executando para todos os usuários
for usuario in usuarios:
    user_id = usuario[0]
    age = usuario[1]
    purchase_history = usuario[2]
    
    previsao = obter_previsao_para_usuario(user_id, age, purchase_history)
    salvar_previsao_no_mongo(user_id, previsao)

# Fechando conexões
sql_cursor.close()
sql_conn.close()
mongo_client.close()