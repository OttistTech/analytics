from pymongo import MongoClient
from decimal import Decimal

# Configuração do MongoDB
MONGO_URI = 'mongodb+srv://ottistechindespensa:8xHl12le5hASngqq@cluster0.1weg8.mongodb.net/'
mongo_client = MongoClient(MONGO_URI)
db = mongo_client['prediction']
collection = db['daily_consumption']

# Dados a serem inseridos
user_id = 71  # Substitua pelo valor real do user_id
previsao = "Sugar and similar, confectionery and water-based sweet desserts"
products = [
    {
        "product_id": 15,
        "ean_code": "7891000451304",
        "name": "Chocolate em pó",
        "image_url": "https://firebasestorage.googleapis.com/v0/b/indespensa-ottistech.appspot.com/o/products%2Fphoto%201731373338629.jpg?alt=media&token=0d72c362-3d6e-4250-9971-523bc75653db",
        "food_name": "Chocolate em pó",
        "category_name": "Doces",
        "description": "Chocolate perfeito para receitas doces",
        "brand_name": "Nestlé",
        "amount": float(200.00) if isinstance(200.00, Decimal) else 200.00,
        "unit": "g",
        "type": None  # Substitua pelo tipo real, se houver
    }
]

# Inserção no MongoDB
documento = {
    "user": user_id,
    "result": previsao,
    "products": products
}

# Realiza o insert e retorna o ID do documento inserido
inserted_id = collection.insert_one(documento).inserted_id
print(f"Documento inserido com ID: {inserted_id}")

# Fechando a conexão MongoDB
mongo_client.close()
