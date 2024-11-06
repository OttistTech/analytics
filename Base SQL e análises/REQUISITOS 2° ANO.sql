-- Requisitos 2° ano para Modelagem

-- 1° requisito

-- Procedure para atualizar o plano de um usuário
CREATE OR REPLACE PROCEDURE atualizar_status_premium(
    p_user_id INT
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_is_premium BOOLEAN;
BEGIN
    -- Verificar se o usuário existe e obter o status atual de is_premium
    SELECT is_premium INTO v_is_premium
    FROM users
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuário com ID % não existe.', p_user_id;
    END IF;

    -- Atualizar o campo is_premium para o valor oposto ao atual
    UPDATE users
    SET is_premium = NOT v_is_premium
    WHERE user_id = p_user_id;

    -- Mensagem de confirmação
    RAISE NOTICE 'Status premium do usuário com ID % atualizado para %.', p_user_id, NOT v_is_premium;

END;
$$;

--Procedure para apagar desativar a conta do usuário
CREATE OR REPLACE PROCEDURE desativar_conta_usuario(
    p_user_id INT
) 
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verificar se o usuário existe
    IF NOT EXISTS (
        SELECT 1 
        FROM users 
        WHERE user_id = p_user_id
    ) THEN
        RAISE EXCEPTION 'Usuário com ID % não existe.', p_user_id;
    END IF;

    -- Atualizar o campo deactivated_at com a data e hora atuais
    UPDATE users
    SET deactivated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id;

    -- Mensagem de confirmação
    RAISE NOTICE 'Conta do usuário com ID % foi desativada em %.', p_user_id, CURRENT_TIMESTAMP;

END;
$$;


-- Procedure para atualizar quantia de um produto na despensa
CREATE OR REPLACE PROCEDURE atualizar_quantidade_despensa(
    user_id BIGINT,
    p_produto_id INT,
    p_quantidade INT,
    p_operacao VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_quantidade_atual INT;
    v_nova_quantidade INT;
BEGIN
    -- Verificar se o produto está na despensa do usuário
    SELECT amount INTO v_quantidade_atual
    FROM pantry_items
    WHERE user_id = user_id AND product_id = p_produto_id;

    IF v_quantidade_atual IS NULL THEN
        RAISE EXCEPTION 'Produto com ID % não está na despensa do usuário com ID %.', p_produto_id, user_id;
    END IF;

    -- Determinar a nova quantidade com base na operação
    IF p_operacao = 'mais' THEN
        v_nova_quantidade := v_quantidade_atual + p_quantidade;
    ELSIF p_operacao = 'menos' THEN
        v_nova_quantidade := v_quantidade_atual - p_quantidade;
    ELSE
        RAISE EXCEPTION 'Operação inválida. Use "mais" para adicionar ou "menos" para subtrair.';
    END IF;

    -- Se a nova quantidade for menor ou igual a zero, remover o produto da despensa
    IF v_nova_quantidade <= 0 THEN
        DELETE FROM pantry_items
        WHERE user_id = user_id AND product_id = p_produto_id;
    ELSE
        -- Atualizar quantidade do produto na despensa
        UPDATE pantry_items
        SET amount = v_nova_quantidade
        WHERE user_id = user_id AND product_id = p_produto_id;
    END IF;
END;
$$;


-- 2° requisito


--Log de produtos que foram inseridos, alterados e retirados da tabela
CREATE TABLE pantry_item_logs (
    log_id SERIAL PRIMARY KEY,
    pantry_item_id INT NOT NULL,
    user_id INT NOT NULL,
    action VARCHAR(50) NOT NULL,
    amount INT,
    log_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 
CREATE OR REPLACE FUNCTION log_pantry_item_update_update_insert()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO pantry_item_logs (
        pantry_item_id, 
        user_id, 
        action, 
        amount 
    )
    VALUES (
        NEW.pantry_item_id, 
        NEW.user_id, 
        TG_OP, 
        NEW.amount 
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_pantry_item_delete()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO pantry_item_logs (
        pantry_item_id, 
        user_id, 
        action, 
        amount 
    )
    VALUES (
        OLD.pantry_item_id, 
        OLD.user_id, 
        TG_OP, 
        OLD.amount 
    );
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER pantry_item_trigger_update_insert
AFTER INSERT OR UPDATE ON pantry_items
FOR EACH ROW
EXECUTE FUNCTION log_pantry_item_update_update_insert();

CREATE TRIGGER pantry_item_trigger_del
BEFORE DELETE ON pantry_items
FOR EACH ROW
EXECUTE FUNCTION log_pantry_item_delete();

--Log de assinatura
CREATE TABLE IF NOT EXISTS subscription_plan_change_logs (
    log_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    old_plan TEXT NOT NULL,
    new_plan TEXT NOT NULL,
    changed_by_user_id INT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION log_premium_change()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO subscription_plan_change_logs(
        user_id, 
        old_plan, 
        new_plan, 
        changed_by_user_id,
        changed_at
    )
    VALUES (
        NEW.user_id, 
        OLD.is_premium::TEXT,
        NEW.is_premium::TEXT,
	NEW.user_id,
        CURRENT_TIMESTAMP
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER premium_change_trigger
AFTER UPDATE OF is_premium ON users
FOR EACH ROW
WHEN (OLD.is_premium IS DISTINCT FROM NEW.is_premium)
EXECUTE FUNCTION log_premium_change();

-- Log de pedidos
CREATE TABLE order_logs (
    log_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    user_id INT NOT NULL,
    action VARCHAR(50) NOT NULL,
    old_status BOOLEAN,
    new_status BOOLEAN,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by_user_id INT
);

CREATE OR REPLACE FUNCTION log_order_change_update_insert()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO order_logs (
        order_id,
        user_id,
        action,
        old_status,
        new_status,
        changed_at,
        changed_by_user_id
    )
    VALUES (
        NEW.order_id,
        NEW.user_id,
        TG_OP,
        OLD.is_closed,
        NEW.is_closed,
        CURRENT_TIMESTAMP,
        NEW.user_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_order_change_delete()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO order_logs (
        order_id,
        user_id,
        action,
        old_status,
        new_status,
        changed_at,
        changed_by_user_id
    )
    VALUES (
        OLD.order_id,
        OLD.user_id,
        TG_OP,
        OLD.is_closed,
        OLD.is_closed,
        CURRENT_TIMESTAMP,
        NEW.user_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_change_trigger_update_insert
AFTER INSERT OR UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION log_order_change_update_insert();

CREATE TRIGGER order_change_trigger_delete
BEFORE DELETE ON orders
FOR EACH ROW
EXECUTE FUNCTION log_order_change_delete();

-- 3° requisito
--Cumprido! Normalização em outro documento.

-- Extras 

-- Extra 01

-- Log nome e senha usuário
CREATE TABLE user_changes_log (
    log_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    old_name VARCHAR(255),
    new_name VARCHAR(255),
    old_password VARCHAR(255),
    new_password VARCHAR(255),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION log_user_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.name IS DISTINCT FROM OLD.name) OR (NEW.password IS DISTINCT FROM OLD.password) THEN
        INSERT INTO user_changes_log (email, old_name, new_name, old_password, new_password)
        VALUES (OLD.email, OLD.name, NEW.name, OLD.password, NEW.password);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_changes_trigger
AFTER UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION log_user_changes();

-- Log itens da lista
CREATE TABLE list_items_log (
    log_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    product_id INT NOT NULL,
    removed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION log_list_item_removal()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO list_items_log (email, product_id)
    SELECT u.email, OLD.product_id
    FROM users u
    WHERE u.user_id = OLD.user_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER list_items_removal_trigger
BEFORE DELETE ON list_items
FOR EACH ROW
EXECUTE FUNCTION log_list_item_removal();

--Log endereços

CREATE TABLE address_changes_log (
    log_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    old_cep_id VARCHAR(20),
    new_cep_id VARCHAR(20),
    old_address_number INT,
    new_address_number INT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION log_address_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.cep_id IS DISTINCT FROM OLD.cep_id) OR (NEW.address_number IS DISTINCT FROM OLD.address_number) THEN
        INSERT INTO address_changes_log (email, old_cep_id, new_cep_id, old_address_number, new_address_number)
        SELECT u.email, OLD.cep_id, NEW.cep_id, OLD.address_number, NEW.address_number
        FROM users u
        WHERE u.user_id = OLD.user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER address_changes_trigger
AFTER UPDATE ON addresses
FOR EACH ROW
EXECUTE FUNCTION log_address_changes();

--Extra 02

-- Função para checar se um produto específico está válido ou não (true = validade em dia, false = validade passou).
CREATE OR REPLACE FUNCTION checar_validade_produto(p_produto_id INT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verifica se o produto está dentro da validade
    RETURN EXISTS (
        SELECT 1
        FROM pantry_items
        WHERE product_id = p_produto_id
          AND validity_date > CURRENT_DATE
          AND is_active = TRUE
    );
END;
$$;

-- Função checando quantia de dias em que produto passou da validade
CREATE OR REPLACE FUNCTION contar_produtos_fora_validade(p_user_id INT)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    quantidade INTEGER;
BEGIN
    -- Conta o número de produtos cuja data de validade é anterior à data atual
    SELECT COUNT(*)
    INTO quantidade
    FROM pantry_items
    WHERE user_id = p_user_id
      AND validity_date < CURRENT_DATE
      AND is_active = TRUE;

    -- Retorna a quantidade encontrada
    RETURN quantidade;
END;
$$;


-- Função para buscar receitas com base nos produtos da sua despensa
CREATE OR REPLACE FUNCTION buscar_receitas_com_despensa(p_user_id INT)
RETURNS TABLE(
    recipe_id INT,
    recipe_title VARCHAR(255),
    missing_ingredients INT
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.recipe_id,
        r.title AS recipe_title,
        COUNT(ri.recipe_ingredient_id) AS missing_ingredients
    FROM 
        recipes r
    JOIN 
        recipe_ingredients ri ON r.recipe_id = ri.recipe_id
    LEFT JOIN 
        pantry_items pi ON pi.user_id = p_user_id 
                        AND pi.product_id = (
                            SELECT product_id 
                            FROM products 
                            WHERE food_id = ri.ingredient_food_id
                            LIMIT 1
                        )
    WHERE 
        pi.product_id IS NULL -- Ingredientes que faltam
        OR pi.amount < ri.amount -- Ingredientes que estão abaixo da quantidade necessária
    GROUP BY 
        r.recipe_id, r.title
    ORDER BY 
        missing_ingredients ASC; -- Ordenar por receitas com menos ingredientes faltando
END;
$$;

--Função para procurar receitas baseada num filtro (essa função pode receber uma lista)
CREATE OR REPLACE FUNCTION procurar_receitas_por_ingredientes(
    p_ingredientes_nome VARCHAR(255)[] DEFAULT NULL, -- Lista de nomes dos ingredientes
    p_ingredientes_id INT[] DEFAULT NULL -- Lista de IDs dos ingredientes
)
RETURNS TABLE(
    recipe_id INT,
    title VARCHAR(255),
    description TEXT
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT r.recipe_id, r.title, r.description
    FROM recipes r
    JOIN recipe_ingredients ri ON r.recipe_id = ri.recipe_id
    JOIN foods f ON ri.ingredient_food_id = f.food_id
    WHERE 
        (
            (p_ingredientes_nome IS NULL OR f.food_name = ANY(p_ingredientes_nome)) OR
            (p_ingredientes_id IS NULL OR ri.ingredient_food_id = ANY(p_ingredientes_id))
        )
    GROUP BY r.recipe_id
    HAVING 
        (p_ingredientes_nome IS NULL OR COUNT(DISTINCT f.food_name) = array_length(p_ingredientes_nome, 1)) AND
        (p_ingredientes_id IS NULL OR COUNT(DISTINCT ri.ingredient_food_id) = array_length(p_ingredientes_id, 1));
END;
$$;

--Função para consertar o tipo de campo de birthdate
CREATE OR REPLACE FUNCTION ajustar_birthdate()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Ajusta o campo birthdate para manter apenas a data, sem a parte de tempo
    NEW.birthdate := DATE(NEW.birthdate);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_ajustar_birthdate
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION ajustar_birthdate();

--Procedure para limpar produtos vencidos da despensa
CREATE OR REPLACE PROCEDURE limpar_produtos_vencidos(p_user_id INT)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Deletar produtos vencidos da despensa
    DELETE FROM pantry_items
    WHERE user_id = p_user_id
      AND validity_date < CURRENT_DATE
      AND is_active = TRUE;

    RAISE NOTICE 'Produtos vencidos removidos com sucesso para o usuário %.', p_user_id;
END;
$$;

-- Função para achar receitas com filtros
CREATE OR REPLACE FUNCTION find_recipes(
    p_level VARCHAR(20) DEFAULT NULL,
    p_max_preparation_time INT DEFAULT NULL,
    p_preparation_method TEXT DEFAULT NULL
)
RETURNS TABLE(
    recipe_id INT,
    title VARCHAR,
    description TEXT,
    level VARCHAR,
    preparation_time INT,
    preparation_method TEXT,
    is_shared BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.recipe_id::INT,
        r.title,
        r.description,
        r.level,
        r.preparation_time,
        r.preparation_method,
        r.is_shared
    FROM
        recipes r
    WHERE
        (p_level IS NULL OR r.level = p_level) AND
        (p_max_preparation_time IS NULL OR r.preparation_time <= p_max_preparation_time) AND
        (p_preparation_method IS NULL OR r.preparation_method ILIKE '%' || p_preparation_method || '%');
END;
$$ LANGUAGE plpgsql;

-- Atribuindo grupo populacional
CREATE OR REPLACE FUNCTION atribuir_grupo_populacional() 
RETURNS TRIGGER AS $$
DECLARE
    idade INT;
BEGIN
    -- Calcula a idade baseado no birthdate
    IF NEW.birthdate IS NOT NULL THEN
        idade := DATE_PART('year', AGE(NEW.birthdate));
        
        -- Atribui o grupo populacional com base na idade
        IF idade <= 2 THEN
            NEW.population_group := 'Infants';
        ELSIF idade BETWEEN 3 AND 5 THEN
            NEW.population_group := 'Toddlers';
        ELSIF idade BETWEEN 6 AND 12 THEN
            NEW.population_group := 'Other children';
        ELSIF idade BETWEEN 13 AND 17 THEN
            NEW.population_group := 'Adolescents';
        ELSIF idade BETWEEN 18 AND 50 THEN
            NEW.population_group := 'Adults';
        ELSIF idade BETWEEN 51 AND 60 THEN
            NEW.population_group := 'Elderly';
        ELSE
            NEW.population_group := 'Very elderly';
        END IF;
    ELSE
        NEW.population_group := NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trigger_atribuir_grupo_populacional
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION atribuir_grupo_populacional();

--Função para retornar produtos que propensos ao usuário consumir
CREATE OR REPLACE FUNCTION get_random_products_by_category(p_category TEXT)
RETURNS TABLE (
    product_id BIGINT,
    ean_code VARCHAR(50),
    name VARCHAR(255),
    image_url VARCHAR(255),
    food_id BIGINT,
    category_id BIGINT,
    description TEXT,
    brand_id BIGINT,
    amount NUMERIC(10, 2),
    unit VARCHAR(50),
    type VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT p.product_id, p.ean_code, p.name, p.image_url, p.food_id, 
           p.category_id, p.description, p.brand_id, p.amount, p.unit, p.type
    FROM products p
    JOIN foods f ON p.food_id = f.food_id
    WHERE 
        CASE
            WHEN f.food_name = 'Alcoholic beverages' THEN 'Alcoholic beverages'
            WHEN f.food_name = 'Beer and beer-like beverage' THEN 'Beer and beer-like beverage'
            WHEN f.food_name = 'Mixed alcoholic drinks' THEN 'Mixed alcoholic drinks'
            WHEN f.food_name = 'Unsweetened spirits and liqueurs' THEN 'Unsweetened spirits and liqueurs'
            WHEN f.food_name = 'Wine and wine-like drinks' THEN 'Wine and wine-like drinks'
            WHEN f.food_name = 'Animal and vegetable fats/oils' THEN 'Animal and vegetable fats/oils'
            WHEN f.food_name = 'Fat emulsions and blended fats' THEN 'Fat emulsions and blended fats'
            WHEN f.food_name = 'Hot drinks and similar (coffee, cocoa, tea and herbal infusions)' THEN 'Hot drinks and similar (coffee, cocoa, tea and herbal infusions)'
            WHEN f.food_name = 'Ingredients for coffee, cocoa, tea, and herbal infusions' THEN 'Ingredients for coffee, cocoa, tea, and herbal infusions'
            WHEN f.food_name = 'Dishes, incl. Ready to eat meals (excluding soups and salads)' THEN 'Dishes, incl. Ready to eat meals (excluding soups and salads)'
            WHEN f.food_name = 'Fried or extruded cereal, seed or root-based products' THEN 'Fried or extruded cereal, seed or root-based products'
            WHEN f.food_name = 'Soups and salads' THEN 'Soups and salads'
            WHEN f.food_name = 'Processed eggs' THEN 'Processed eggs'
            WHEN f.food_name = 'Unprocessed eggs' THEN 'Unprocessed eggs'
            WHEN f.food_name = 'Crustaceans' THEN 'Crustaceans'
            WHEN f.food_name = 'Fish (meat)' THEN 'Fish (meat)'
            WHEN f.food_name = 'Fish and seafood processed' THEN 'Fish and seafood processed'
            WHEN f.food_name = 'Molluscs' THEN 'Molluscs'
            WHEN f.food_name = 'Fruit used as fruit' THEN 'Fruit used as fruit'
            WHEN f.food_name = 'Processed fruit products' THEN 'Processed fruit products'
            WHEN f.food_name = 'Concentrated or dehydrated fruit/vegetables juices' THEN 'Concentrated or dehydrated fruit/vegetables juices'
            WHEN f.food_name = 'Extracts of plant origin' THEN 'Extracts of plant origin'
            WHEN f.food_name = 'Fruit / vegetable juices and nectars' THEN 'Fruit / vegetable juices and nectars'
            WHEN f.food_name = 'Bread and similar products' THEN 'Bread and similar products'
            WHEN f.food_name = 'Breakfast cereals' THEN 'Breakfast cereals'
            WHEN f.food_name = 'Cereals and cereal primary derivatives' THEN 'Cereals and cereal primary derivatives'
            WHEN f.food_name = 'Fine bakery wares' THEN 'Fine bakery wares'
            WHEN f.food_name = 'Pasta, doughs and similar products' THEN 'Pasta, doughs and similar products'
            WHEN f.food_name = 'Legumes' THEN 'Legumes'
            WHEN f.food_name = 'Nuts, oilseeds and oilfruits' THEN 'Nuts, oilseeds and oilfruits'
            WHEN f.food_name = 'Processed legumes, nuts, oilseeds and spices' THEN 'Processed legumes, nuts, oilseeds and spices'
            WHEN f.food_name = 'Spices' THEN 'Spices'
            WHEN f.food_name = 'Food flavourings' THEN 'Food flavourings'
            WHEN f.food_name = 'Miscellaneous agents for food processing' THEN 'Miscellaneous agents for food processing'
            WHEN f.food_name = 'Starches' THEN 'Starches'
            WHEN f.food_name = 'Animal edible offal, non-muscle, other than liver and kidney' THEN 'Animal edible offal, non-muscle, other than liver and kidney'
            WHEN f.food_name = 'Animal fresh fat tissues' THEN 'Animal fresh fat tissues'
            WHEN f.food_name = 'Animal liver' THEN 'Animal liver'
            WHEN f.food_name = 'Mammals and birds meat' THEN 'Mammals and birds meat'
            WHEN f.food_name = 'Meat specialties' THEN 'Meat specialties'
            WHEN f.food_name = 'Processed whole meat products' THEN 'Processed whole meat products'
            WHEN f.food_name = 'Sausages' THEN 'Sausages'
            WHEN f.food_name = 'Cheese' THEN 'Cheese'
            WHEN f.food_name = 'Dairy dessert and similar' THEN 'Dairy dessert and similar'
            WHEN f.food_name = 'Fermented milk or cream' THEN 'Fermented milk or cream'
            WHEN f.food_name = 'Milk and dairy powders and concentrates' THEN 'Milk and dairy powders and concentrates'
            WHEN f.food_name = 'Milk, whey and cream' THEN 'Milk, whey and cream'
            WHEN f.food_name = 'Artificial sweeteners (e.g., aspartam, saccharine)' THEN 'Artificial sweeteners (e.g., aspartam, saccharine)'
            WHEN f.food_name = 'Food for particular diets' THEN 'Food for particular diets'
            WHEN f.food_name = 'Food supplements and similar preparations' THEN 'Food supplements and similar preparations'
            WHEN f.food_name = 'Meat and dairy imitates' THEN 'Meat and dairy imitates'
            WHEN f.food_name = 'Condiments (including table-top formats)' THEN 'Condiments (including table-top formats)'
            WHEN f.food_name = 'Savoury extracts and sauce ingredients' THEN 'Savoury extracts and sauce ingredients'
            WHEN f.food_name = 'Seasonings and extracts' THEN 'Seasonings and extracts'
            WHEN f.food_name = 'Starchy roots and tubers' THEN 'Starchy roots and tubers'
            WHEN f.food_name = 'Confectionery including chocolate' THEN 'Confectionery including chocolate'
            WHEN f.food_name = 'Sugar and other sweetening ingredients (excluding intensive sweeteners)' THEN 'Sugar and other sweetening ingredients (excluding intensive sweeteners)'
            WHEN f.food_name = 'Bulb vegetables' THEN 'Bulb vegetables'
            WHEN f.food_name = 'Flowering brassica' THEN 'Flowering brassica'
            WHEN f.food_name = 'Fruiting vegetables' THEN 'Fruiting vegetables'
            WHEN f.food_name = 'Fungi, mosses and lichens' THEN 'Fungi, mosses and lichens'
            WHEN f.food_name = 'Herbs and edible flowers' THEN 'Herbs and edible flowers'
            WHEN f.food_name = 'Leafy vegetables' THEN 'Leafy vegetables'
            WHEN f.food_name = 'Legumes with pod' THEN 'Legumes with pod'
            WHEN f.food_name = 'Processed or preserved vegetables and similar' THEN 'Processed or preserved vegetables and similar'
            WHEN f.food_name = 'Root and tuber vegetables (excluding starchy- and sugar-)' THEN 'Root and tuber vegetables (excluding starchy- and sugar-)'
            WHEN f.food_name = 'Sprouts, shoots and similar' THEN 'Sprouts, shoots and similar'
            WHEN f.food_name = 'Stems/stalks eaten as vegetables' THEN 'Stems/stalks eaten as vegetables'
            WHEN f.food_name = 'Vegetables and vegetable products' THEN 'Vegetables and vegetable products'
            WHEN f.food_name = 'Drinking water' THEN 'Drinking water'
            WHEN f.food_name = 'Water based beverages' THEN 'Water based beverages'
            ELSE 'Other ingredients'
        END = p_category
    ORDER BY random()
    LIMIT 3;
END;
$$ LANGUAGE plpgsql;
