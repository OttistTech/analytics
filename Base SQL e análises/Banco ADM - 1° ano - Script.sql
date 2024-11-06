-- 1 Tabela: address
CREATE TABLE address (
    address_id INTEGER PRIMARY KEY NOT NULL CHECK (address_id <> 0),
    cep_id INT REFERENCES cep(cep_id),
    state VARCHAR(255)
);

-- 2 Tabela: ingredient
CREATE TABLE ingredient ( ingredient_id INTEGER PRIMARY KEY NOT NULL UNIQUE
						, name          VARCHAR(255)        NOT NULL
						);


-- 3 Tabela: customer
CREATE TABLE users (    user_id           INTEGER PRIMARY KEY NOT NULL
		     		  , name              VARCHAR(255)        NOT NULL
		      		  , plan              VARCHAR(255)                 DEFAULT 'gratuito'
		    		  , type              VARCHAR(255)                 DEFAULT 'consumidor'
		   		      , deactivated_at    DATE                         DEFAULT NULL
		     		  , password          VARCHAR(255)        NOT NULL
		      		  , payment_method    VARCHAR(100)                 DEFAULT NULL
		     		  , business_type     VARCHAR(150)                 DEFAULT NULL
		     		  , email_login       VARCHAR(255)        NOT NULL
		     		  , register_date     DATE                NOT NULL
		      		  , food_restriction  VARCHAR(100)                 DEFAULT NULL
		      		  , address_id        INTEGER REFERENCES address(address_id)
					  , birthdate         date
		     		  );

-- 4 Tabela: pantry
CREATE TABLE pantry ( pantry_id   INTEGER PRIMARY KEY NOT NULL UNIQUE
		   		    , user_id     INTEGER             NOT NULL REFERENCES customer(customer_id)
		   		    );
-- 5 Tabela: product
CREATE TABLE product ( product_id    INTEGER PRIMARY KEY NOT NULL
		     		 , description   TEXT                               DEFAULT NULL
		     		 , barcode       BIGINT UNIQUE       NOT NULL
		   			 , name          VARCHAR(255)        NOT NULL
		     		 , type          VARCHAR(100)                       DEFAULT NULL
		     		 , weight_volume VARCHAR(100)        NOT NULL
					 , category_id   INT REFERENCES categories(category_id)
					 , brand_id      INT REFERENCES brand(brand_id)
		    		 );
					 

-- 6 Tabela: recipe
CREATE TABLE recipe ( recipe_id    INTEGER PRIMARY KEY NOT NULL
		    		, picture      TEXT                             DEFAULT NULL
		   		    , level        VARCHAR(255)                     DEFAULT NULL
		   		    , instructions TEXT                             DEFAULT NULL
		   		    , author       VARCHAR(255)                     DEFAULT NULL
	            	, name         VARCHAR(255)        NOT NULL
		    		, time         INT                 NOT NULL     DEFAULT 0
		    		, description  TEXT                             DEFAULT NULL
		   		    , shared       INTEGER CHECK (shared IN (0, 1)) DEFAULT 0
		    		, customer     INTEGER REFERENCES customer(customer_id)
		    		);

-- 7 Tabela: finished_recipes
CREATE TABLE finished_recipes ( finishedRecipes_id INTEGER PRIMARY KEY NOT NULL
			      			  , date               DATE                NOT NULL
			      			  , rating             INTEGER CHECK (rating BETWEEN 0 AND 5) DEFAULT 0
			      			  , customer           INTEGER REFERENCES customer(customer_id)
			                  , recipe_id          INTEGER REFERENCES recipe(recipe_id)
			      			  );

-- 8 Tabela: purchase
CREATE TABLE purchase ( purchase_id INTEGER PRIMARY KEY NOT NULL
		     		  , date        DATE                NOT NULL
		      		  , finished    BOOLEAN             NOT NULL DEFAULT FALSE
		     		  , total       INTEGER CHECK (total >= 0)   DEFAULT 0
		     		  , client_name VARCHAR(255)                 DEFAULT NULL
		      		  , customer_id INTEGER REFERENCES customer(customer_id)
		    		  );

-- 9 Tabela: business_purchase
CREATE TABLE business_purchase ( businessPurchase_id INTEGER PRIMARY KEY NOT NULL
			   			  	   , active           BOOLEAN             NOT NULL DEFAULT TRUE
			    			   , price            INT CHECK (price >= 0) DEFAULT 0
			   			       , company_user_id  INTEGER REFERENCES customer(customer_id)
			    		       , recipe_id        INTEGER REFERENCES recipe(recipe_id)
			   			       );

-- 10 Tabela: product_pantry
CREATE TABLE product_pantry ( product_pantry_id INTEGER PRIMARY KEY NOT NULL
			   			    , buy_date          DATE                          DEFAULT NULL
			   			    , quantity          DECIMAL CHECK (quantity >= 0) DEFAULT 0
			    			, active            BOOLEAN             NOT NULL  DEFAULT TRUE
			    			, expiring_date     DATE                          DEFAULT NULL
			    			, pantry_id         INTEGER REFERENCES pantry(pantry_id)
			    			, product_id        INTEGER REFERENCES product(product_id)
			    			);

-- 11 Tabela: recipe_ingredient
CREATE TABLE recipe_ingredient ( recipeIngredient_id INTEGER PRIMARY KEY NOT NULL
			      			   , quantity            INTEGER CHECK (quantity > 0) DEFAULT 1
			      			   , unities             INTEGER CHECK (unities >= 0) DEFAULT 1
			       			   , essential           BOOLEAN             NOT NULL DEFAULT FALSE
			       			   , recipe_id           INTEGER REFERENCES recipe(recipe_id)
			       			   , ingredient_id       INTEGER REFERENCES ingredient(ingredient_id)
			       			   );

-- 12 Tabela: shopping_list_item
CREATE TABLE shopping_list_item ( shoppingListItem_id INTEGER PRIMARY KEY NOT NULL
								, quantity            DECIMAL CHECK (quantity >= 0) DEFAULT 0
								, bought_date         DATE                          DEFAULT NULL
								, customer_id         INTEGER REFERENCES customer(customer_id)
								, product_id          INTEGER REFERENCES product(product_id)
								);

-- 13 Tabela: product_list_item
CREATE TABLE product_list_item ( quantity           DECIMAL(5,2)                 DEFAULT 1.0 CHECK (quantity > 0)
			      			   , productListItem_id INTEGER PRIMARY KEY NOT NULL
			      			   , recipe_id          INTEGER REFERENCES recipe(recipe_id)         NOT NULL
			       			   , ingredient_id      INTEGER REFERENCES ingredient(ingredient_id) NOT NULL
			      			   );


-- 14 Tabela: tag
CREATE TABLE tag ( tag_id      INT PRIMARY KEY NOT NULL
		 		 , description VARCHAR(20)     NOT NULL
				 );

-- 15 Tabela: cep
CREATE TABLE cep (
	cep_id int primary key not null CHECK (cep_id <> 0),
    cep VARCHAR(8) UNIQUE NOT NULL, -- CEP deve ser único e não nulo
	street VARCHAR(255),
    state VARCHAR(255),
    city VARCHAR(255)
);

-- 16 Tabela: categories
CREATE TABLE categories ( category_id   INT PRIMARY KEY NOT NULL
						, category_name VARCHAR(255)    NOT NULL UNIQUE
						);

-- 17 Tabela: recipe_tag
CREATE TABLE recipe_tag ( product_id   INT REFERENCES product(product_id)
						, recipe_id    INT REFERENCES recipe(recipe_id)
						, recipeTag_id INT PRIMARY KEY NOT NULL
						, quantity     INT                      DEFAULT 1 CHECK (quantity > 0)
						);
--18 Tabela: brand
CREATE TABLE brand ( brand_id   INT PRIMARY KEY NOT NULL
				   , brand_name VARCHAR(255)    NOT NULL
				   )