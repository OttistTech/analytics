-- Tabelas e constraints de exemplo

DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS foods CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS recipes CASCADE;
DROP TABLE IF EXISTS recipe_ingredients CASCADE;
DROP TABLE IF EXISTS completed_recipes CASCADE;
DROP TABLE IF EXISTS list_items CASCADE;
DROP TABLE IF EXISTS pantry_items CASCADE;
DROP TABLE IF EXISTS enterprise_products CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS campaigns CASCADE;
DROP TABLE IF EXISTS brand CASCADE;
DROP TABLE IF EXISTS cep CASCADE;
DROP TABLE IF EXISTS tag CASCADE;

-- Tabela: users
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    birthdate DATE,
    enterprise_type VARCHAR(100),
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deactivated_at TIMESTAMP,
    is_premium BOOLEAN,
    population_group VARCHAR(20),
    CHECK (
        (type = 'ADM') OR 
        (enterprise_type IS NOT NULL OR birthdate IS NOT NULL)
    )
);

-- Tabela: cep
CREATE TABLE cep (
    cep_id VARCHAR(20) PRIMARY KEY,
    street VARCHAR(255) NOT NULL,
    city VARCHAR(255) NOT NULL,
    state VARCHAR(255) NOT NULL
);

-- Tabela: addresses
CREATE TABLE addresses (
    address_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id),
    cep_id VARCHAR(20) NOT NULL REFERENCES cep(cep_id),
    address_number INT,
    UNIQUE(user_id, cep_id, address_number)
);

-- Tabela: categories
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(255) NOT NULL UNIQUE
);

-- Tabela: foods
CREATE TABLE foods (
    food_id SERIAL PRIMARY KEY,
    food_name VARCHAR(255) NOT NULL UNIQUE
);

-- Tabela: brand
CREATE TABLE brand (
    brand_id SERIAL PRIMARY KEY,
    brand_name VARCHAR(255) NOT NULL UNIQUE
);

-- Tabela: tag
CREATE TABLE tag(
    tag_id SERIAL PRIMARY KEY,
    description VARCHAR(20) NOT NULL
);

-- Tabela: products
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    ean_code VARCHAR(50) UNIQUE,
    name VARCHAR(255) NOT NULL,
    image_url VARCHAR(255),
    food_id INT NOT NULL REFERENCES foods(food_id),
    category_id INT NOT NULL REFERENCES categories(category_id),
    description TEXT NOT NULL,
    brand_id INT NOT NULL REFERENCES brand(brand_id),
    amount DECIMAL(10, 2),
    unit VARCHAR(50),
    type VARCHAR(50)
);

-- Tabela: recipes
CREATE TABLE recipes (
    recipe_id SERIAL PRIMARY KEY,
    created_by INT NOT NULL REFERENCES users(user_id),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    level INT NOT NULL REFERENCES tag(tag_id),
    preparation_time INT NOT NULL,
    preparation_method INT NOT NULL,
    is_shared BOOLEAN,
    image_url VARCHAR(255)
);

-- Tabela: recipe_ingredients
CREATE TABLE recipe_ingredients (
    recipe_ingredient_id SERIAL PRIMARY KEY,
    recipe_id INT NOT NULL REFERENCES recipes(recipe_id),
    ingredient_food_id INT NOT NULL REFERENCES foods(food_id),
    amount DECIMAL(10, 2),
    unit VARCHAR(50),
    is_essential BOOLEAN
);

-- Tabela: completed_recipes
CREATE TABLE completed_recipes (
    completed_recipe_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id),
    recipe_id INT NOT NULL REFERENCES recipes(recipe_id),
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    num_stars INT CHECK (num_stars >= 1 AND num_stars <= 5),
    CONSTRAINT unique_user_recipe UNIQUE (user_id, recipe_id)
);

-- Tabela: list_items
CREATE TABLE list_items (
    list_item_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id),
    product_id INT NOT NULL REFERENCES products(product_id),
    amount INT NOT NULL,
    purchase_date DATE
);

-- Tabela: pantry_items
CREATE TABLE pantry_items (
    pantry_item_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id),
    product_id INT NOT NULL REFERENCES products(product_id),
    amount INT NOT NULL,
    validity_date DATE,
    purchase_date DATE,
    is_active BOOLEAN,
    was_opened BOOLEAN
);

-- Tabela: enterprise_products
CREATE TABLE enterprise_products (
    enterprise_product_id SERIAL PRIMARY KEY,
    recipe_id INT NOT NULL REFERENCES recipes(recipe_id),
    enterprise_user_id INT NOT NULL REFERENCES users(user_id),
    price DECIMAL(10, 2) NOT NULL,
    is_active BOOLEAN
);

-- Tabela: orders
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    consumer_name VARCHAR(255) NOT NULL,
    source VARCHAR(255) NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_closed BOOLEAN
);

-- Tabela: order_items
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    enterprise_product_id INT NOT NULL REFERENCES enterprise_products(enterprise_product_id),
    order_id INT NOT NULL REFERENCES orders(order_id),
    amount INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL
);

-- Tabela: campaigns
CREATE TABLE campaigns (
    campaign_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    image_url VARCHAR(255),
    description TEXT NOT NULL,
    enterprise_product_id INT REFERENCES enterprise_products(enterprise_product_id),
    product_price DECIMAL(10, 2) NOT NULL,
    start_date DATE,
    end_date DATE,
    campaign_url VARCHAR(255),
    cost DECIMAL(10, 2) NOT NULL
);
