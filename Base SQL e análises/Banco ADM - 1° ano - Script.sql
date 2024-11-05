--1 Tabela: tag
CREATE TABLE tag (
    id INT PRIMARY KEY NOT NULL DEFAULT 0, -- Chave primária com valor padrão
    description VARCHAR(20) NOT NULL -- Descrição da tag não pode ser nula
	
);
--2 Tabela: cep
CREATE TABLE cep (
	cep_id int primary key not null
    cep VARCHAR(8) PRIMARY KEY NOT NULL -- CEP deve ser único e não nulo
);
--3 Tabela: categories
CREATE TABLE categories (
    category_id int PRIMARY KEY, -- Chave primária da tabela categories
    category_name VARCHAR(255) NOT NULL UNIQUE -- Nome da categoria não pode ser nulo e deve ser único
);
-- 4 Tabela: address
CREATE TABLE address (
    address_id INTEGER PRIMARY KEY NOT NULL DEFAULT 0,
	cep_id varchar(255) references cep(cep_id),
    street VARCHAR(255),
    extra TEXT,
    city VARCHAR(255),
    state VARCHAR(255),
    UNIQUE (address_id)
);
--5 Tabela: ingredient
CREATE TABLE ingredient (
    ingredient_id INTEGER PRIMARY KEY NOT NULL DEFAULT 0,
    name VARCHAR(255) NOT NULL, -- Adicionado NOT NULL
    UNIQUE (ingredient_id)
);
--6 Tabela: user
CREATE TABLE user (
    customer_id INTEGER PRIMARY KEY NOT NULL DEFAULT 0,
    name VARCHAR(255) NOT NULL, -- Adicionado NOT NULL
    plan VARCHAR(255),
    type VARCHAR(255),
    desactivated_at DATE,
    password VARCHAR(255) NOT NULL, -- adicionado NOT NULL
    payment_method VARCHAR(100),
    business_type VARCHAR(150),
    email_login VARCHAR(255),
    register_date DATE NOT NULL, -- adicionando NOT NULL
    food_restriction VARCHAR(100),
    address_id INTEGER REFERENCES address(address_id)
    CHECK (
        (type = 'ADM') OR 
        (enterprise_type IS NOT NULL OR birthdate IS NOT NULL)
    )
   );

--7 Tabela: pantry
CREATE TABLE pantry (
    pantry_id INTEGER PRIMARY KEY NOT NULL DEFAULT 0,
    customer_id INTEGER NOT NULL REFERENCES customer(customer_id),
    UNIQUE (pantry_id)
);
-- 8 Tabela: product
CREATE TABLE product (
    product_id INTEGER PRIMARY KEY NOT NULL DEFAULT 0,
    description TEXT,
    barcode BIGINT UNIQUE,
    brand VARCHAR(100),
    name VARCHAR(255) NOT NULL, -- adicionado NOT NULL 
    type VARCHAR(100),
    weight_volume DECIMAL CHECK (weight_volume >= 0), -- dando check para o volume não ser negativo
    UNIQUE (product_id),
	category_id int references categories(category_id)
);
-- 9 Tabela: recipe
CREATE TABLE recipe (
    recipe_id INTEGER PRIMARY KEY NOT NULL DEFAULT 0,
    picture INTEGER,
    level VARCHAR(255),
    instructions TEXT,
    author VARCHAR(255),
    name VARCHAR(255) NOT NULL, -- Adicionado NOT NULL
    time TIME NOT NULL, -- Adicionado NOT NULL
    description TEXT,
    shared INTEGER CHECK (shared >= 0), -- check para nao ser maior que 0
    customer INTEGER REFERENCES customer(customer_id),
    UNIQUE (recipe_id)
);
-- 10 Tabela: finished_recipes
CREATE TABLE finished_recipes (
    finishedRecipes_id INTEGER PRIMARY KEY NOT NULL DEFAULT 0,
    date DATE NOT NULL, -- Adicionado NOT NULL
    rating INTEGER CHECK (rating BETWEEN 0 AND 5), -- check para a quantia ser de 0 a 5
    customer INTEGER REFERENCES customer(customer_id),
    recipe_id INTEGER REFERENCES recipe(recipe_id),
    UNIQUE (finishedRecipes_id)
);
-- 11 Tabela: "order"
CREATE TABLE purchase (
    purchase_id INTEGER PRIMARY KEY NOT NULL DEFAULT 0,
    date DATE NOT NULL, -- Adicionado NOT NULL 
    finished BOOLEAN NOT NULL DEFAULT FALSE, -- Adicionado NOT NULL e valor padrao false
    total INTEGER CHECK (total >= 0), -- check para o total ser maior que 0
    client_name VARCHAR(255),
    customer_id INTEGER REFERENCES customer(customer_id),
    UNIQUE (purchase_id)
);
-- 12 Tabela: business_order
CREATE TABLE business_order (
    businessOrder_id INTEGER PRIMARY KEY NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT TRUE, -- adicionado o NOT NULL e condição padrão true
    price INT CHECK (price >= 0), -- check para o preço nao ser negativo
    company_user_id INTEGER REFERENCES customer(customer_id),
    recipe_id INTEGER REFERENCES recipe(recipe_id),
    UNIQUE (businessOrder_id)
);
-- 13 Tabela: product_pantry
CREATE TABLE product_pantry (
    product_pantry_id INTEGER PRIMARY KEY NOT NULL DEFAULT 0,
    product_id INTEGER REFERENCES product(product_id),
    buy_date DATE,
    quantity DECIMAL CHECK (quantity >= 0), -- check para a quantidade não ser negativa
    active INTEGER CHECK (active IN (0, 1)), -- check para ser 1 ou 0 (sim ou não)
    expiring_date DATE,
    pantry_id INTEGER REFERENCES pantry(pantry_id),
    UNIQUE (product_pantry_id)
);
-- 14 Tabela: recipe_ingredient
CREATE TABLE recipe_ingredient (
    recipe_ingredient_id INTEGER PRIMARY KEY NOT NULL DEFAULT 0,
    quantity INTEGER CHECK (quantity > 0), -- check para a quantidade ser maior que 0
    unities INTEGER CHECK (unities >= 0), -- check para a unities ser maior que 0
    essential BOOLEAN NOT NULL DEFAULT FALSE, -- adicionado para não ser nulo e um valor padrão falso
    recipe_id INTEGER REFERENCES recipe(recipe_id),
    ingredient_id INTEGER REFERENCES ingredient(ingredient_id),
    UNIQUE (recipe_ingredient_id)
);
-- 15 Tabela: shopping_list_item
CREATE TABLE shopping_list_item (
    shoppingListItem_id INTEGER PRIMARY KEY NOT NULL DEFAULT 0,
    quantity DECIMAL CHECK (quantity >= 0), -- check para quantia não ser negativa
    bought_date DATE,
    customer_id INTEGER REFERENCES customer(customer_id),
    product_id INTEGER REFERENCES product(product_id),
    UNIQUE (shoppingListItem_id)
);
--16 Tabela: procut_list_item
CREATE TABLE product_list_item (
    recipe_id INT NOT NULL,
    ingredient_id INT NOT NULL,
    quantity DECIMAL(5,2) DEFAULT 1.0 CHECK (quantity > 0), --check para a quantia não ser negativa
    product_list_item_id INTEGER PRIMARY KEY NOT NULL DEFAULT 0, --adicionando o not null para que a pk não seja nula e deixando 0 como valor padrão
    recipe_idFK INTEGER REFERENCES recipe(recipe_id),
    ingredient_idFK INTEGER REFERENCES ingredient(ingredient_id)
);
--17 Tabela: recipe_tag
CREATE TABLE recipe_tag(
	recipe_id int references recipe(recipe_id),
	recipe_tag_id int primary key, 
	quantity int
);
--Regras de Negócio:

--Essencialidade dos Ingredientes:
--O campo essential só pode ser definido como TRUE se o ingrediente for realmente essencial para a receita. Essa validação deve ser feita consultando a combinação de recipe_id e ingredient_id.

--Classificação de Usuários:
--Se o plano do usuário for Business, o tipo também deve ser definido como Business. Para planos Premium e Gratuito, o tipo deve ser Cliente.

--Campo 'Shared':
--O valor do campo shared deve ser restrito a 0 (não) ou 1 (sim).


--Quantidade de Ingredientes:
--O campo quantity deve ser um número inteiro e não pode ser negativo.
--Atividade do Usuário:



-- 1. Constraint para plano e tipo
ALTER TABLE customer
ADD CONSTRAINT check_plan_type CHECK (
    (plan IN ('Premium', 'Gratuito') AND type = 'Cliente') OR
    (plan = 'Business' AND type = 'Business') OR (plan= 'ADM' AND type = 'Business')
);

-- 2. Constraint para 'shared'
ALTER TABLE recipe
ADD CONSTRAINT check_shared CHECK (shared IN (0, 1));

-- 3. Constraint para 'quantity'
ALTER TABLE recipe_ingredient
ADD CONSTRAINT check_quantity CHECK (quantity >= 0 AND quantity = FLOOR(quantity));