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
        IF idade <= 12 THEN
            NEW.population_group := 'Criança';
        ELSIF idade BETWEEN 13 AND 17 THEN
            NEW.population_group := 'Adolescente';
        ELSIF idade BETWEEN 18 AND 30 THEN
            NEW.population_group := 'Jovem adulto';
        ELSIF idade BETWEEN 31 AND 49 THEN
            NEW.population_group := 'Adulto';
        ELSIF idade BETWEEN 50 AND 59 THEN
            NEW.population_group := 'Velho adulto';
        ELSE
            NEW.population_group := 'Idoso';
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
    product_id BIGINT,          -- Alterado para BIGINT se o tipo real for BIGINT
    ean_code VARCHAR(50),
    name VARCHAR(255),
    image_url VARCHAR(255),
    food_id BIGINT,               -- Mantenha INT se for INT na tabela
    category_id BIGINT,           -- Mantenha INT se for INT na tabela
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
            WHEN f.food_name LIKE '%Açúcar%' THEN 'Sugar and similar, confectionery and water-based sweet desserts'
            WHEN f.food_name LIKE '%Cheetos%' THEN 'Composite dishes'
            WHEN f.food_name LIKE '%Arroz%' THEN 'Grains and grain-based products'
            WHEN f.food_name LIKE '%Feijão%' THEN 'Legumes, nuts, oilseeds and spices'
            WHEN f.food_name LIKE '%Água%' THEN 'Water and water-based beverages'
            WHEN f.food_name LIKE '%Alho%' THEN 'Vegetables and vegetable products'
            WHEN f.food_name LIKE '%Leite Condensado%' THEN 'Milk and dairy products'
            WHEN f.food_name LIKE '%Manteiga%' THEN 'Animal and vegetable fats and oils and primary derivatives thereof'
            WHEN f.food_name LIKE '%Chocolate%' THEN 'Sugar and similar, confectionery and water-based sweet desserts'
            WHEN f.food_name LIKE '%Milk Shake%' THEN 'Milk and dairy products'
            WHEN f.food_name LIKE '%milho%' THEN 'Vegetables and vegetable products'
            WHEN f.food_name LIKE '%Sal%' THEN 'Seasoning, sauces and condiments'
            WHEN f.food_name LIKE '%Biscoito%' THEN 'Sugar and similar, confectionery and water-based sweet desserts'
            WHEN f.food_name LIKE '%Farinha%' THEN 'Grains and grain-based products'
            WHEN f.food_name LIKE '%Café%' THEN 'Coffee, cocoa, tea and infusions'
            WHEN f.food_name LIKE '%Batata Palha%' THEN 'Vegetables and vegetable products'
            WHEN f.food_name LIKE '%Azeite%' THEN 'Animal and vegetable fats and oils and primary derivatives thereof'
            WHEN f.food_name LIKE '%Gelatina%' THEN 'Other ingredients'
            WHEN f.food_name LIKE '%Macarrão%' THEN 'Grains and grain-based products'
            WHEN f.food_name LIKE '%Molho%' THEN 'Seasoning, sauces and condiments'
            ELSE 'Other ingredients'
        END = p_category
    ORDER BY random()
    LIMIT 3;
END;
$$ LANGUAGE plpgsql;