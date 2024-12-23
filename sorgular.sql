-- Kategoriler Tablosu
CREATE TABLE Categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(255) NOT NULL
);

-- Platformlar Tablosu
CREATE TABLE Platforms (
    platform_id SERIAL PRIMARY KEY,
    platform_name VARCHAR(255) NOT NULL
);

-- Yayıncılar Tablosu
CREATE TABLE Publishers (
    publisher_id SERIAL PRIMARY KEY,
    publisher_name VARCHAR(255) NOT NULL,
    establishment_date DATE
);

-- Kullanıcıların Ortak Özelliklerini Tutacak Üst Tablo
CREATE TABLE BaseUsers (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    registration_date DATE DEFAULT CURRENT_DATE,
    user_type VARCHAR(10) NOT NULL CHECK (user_type IN ('Admin', 'Dev', 'Normal')) -- Disjoint Mantığı
);

-- Admin Kullanıcılar Tablosu (BaseUsers ile Disjoint ve Kalıtım)
CREATE TABLE Admins (
    user_id INTEGER PRIMARY KEY REFERENCES BaseUsers(user_id) ON DELETE CASCADE,
    yetki_seviyesi INTEGER NOT NULL,
    son_giris_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Geliştirici Kullanıcılar Tablosu (BaseUsers ile Disjoint ve Kalıtım)
create TABLE DevUsers (
    user_id INTEGER PRIMARY KEY REFERENCES BaseUsers(user_id) ON DELETE CASCADE,
    sirket_adi VARCHAR(255),
    onayli_gelistirici BOOLEAN DEFAULT FALSE
);

-- Normal Kullanıcılar Tablosu (BaseUsers ile Disjoint ve Kalıtım)
CREATE TABLE NormalUsers (
    user_id INTEGER PRIMARY KEY REFERENCES BaseUsers(user_id) ON DELETE CASCADE,
    dogum_tarihi DATE NOT NULL
);

-- Oyunlar Tablosu
CREATE TABLE Games (
    game_id SERIAL PRIMARY KEY,
    game_name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2),
    release_date DATE,
    developer_id INTEGER REFERENCES DevUsers(user_id) ON DELETE SET NULL, -- Geliştirici silinirse NULL
    publisher_id INTEGER REFERENCES Publishers(publisher_id),
    category_id INTEGER REFERENCES Categories(category_id) ON DELETE RESTRICT
);

-- Oyun Platformları Tablosu
CREATE TABLE Game_Platforms (
    game_id INTEGER REFERENCES Games(game_id) ON DELETE CASCADE,
    platform_id INTEGER REFERENCES Platforms(platform_id),
    PRIMARY KEY (game_id, platform_id)
);

-- Satın Alımlar Tablosu
CREATE TABLE Purchases (
    purchase_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES BaseUsers(user_id) ON DELETE CASCADE,
    game_id INTEGER REFERENCES Games(game_id) ON DELETE CASCADE,
    purchase_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    price DECIMAL(10, 2)
);

-- İndirmeler Tablosu
CREATE TABLE Downloads (
    download_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES BaseUsers(user_id) ON DELETE CASCADE,
    game_id INTEGER REFERENCES Games(game_id) ON DELETE CASCADE,
    download_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ödeme Yöntemleri Tablosu
CREATE TABLE Payment_Methods (
    payment_method_id SERIAL PRIMARY KEY,
    payment_method_name VARCHAR(255) NOT NULL
);

-- Satın Alma Ödeme Tablosu
CREATE TABLE Purchase_Payment (
    purchase_id INTEGER REFERENCES Purchases(purchase_id) ON DELETE CASCADE,
    payment_method_id INTEGER REFERENCES Payment_Methods(payment_method_id),
    PRIMARY KEY (purchase_id, payment_method_id)
);

-- Oyun Etiketleri Tablosu
CREATE TABLE Game_Tags (
    tag_id SERIAL PRIMARY KEY,
    tag_name VARCHAR(255) NOT NULL
);

-- Oyun OyunEtiketleri Tablosu
CREATE TABLE Game_GameTags (
    game_id INTEGER REFERENCES Games(game_id) ON DELETE CASCADE,
    tag_id INTEGER REFERENCES Game_Tags(tag_id),
    PRIMARY KEY (game_id, tag_id)
);


-- Favori Oyunlar Tablosu
CREATE TABLE Favorite_Games (
    user_id INTEGER REFERENCES BaseUsers(user_id) ON DELETE CASCADE,
    game_id INTEGER REFERENCES Games(game_id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, game_id)
);

BEGIN;

-- BaseUsers tablosuna normal kullanıcı ekle
WITH inserted_user AS (
    INSERT INTO BaseUsers (username, email, password, user_type)
    VALUES ('erenalbayrak', 'eren@example.com', 'securepassword123', 'Normal')
    RETURNING user_id
)
-- NormalUsers tablosuna ekleme yap
INSERT INTO NormalUsers (user_id, dogum_tarihi)
SELECT user_id, '2002-07-15' FROM inserted_user;

COMMIT;


CREATE OR REPLACE FUNCTION generate_random_password()
RETURNS TEXT AS
$$
DECLARE
    password TEXT;
BEGIN
    -- Şifreyi 10 karakter uzunluğunda oluşturuyoruz
    password := substr(md5(random()::text), 0, 11); 
    RETURN password;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_random_password()
RETURNS TRIGGER AS
$$
BEGIN
    -- Yeni kullanıcı eklenmeden önce şifreyi otomatik olarak belirle
    NEW.password := generate_random_password(); 
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER before_insert_baseusers
BEFORE INSERT ON "baseusers"
FOR EACH ROW
EXECUTE PROCEDURE set_random_password();

CREATE OR REPLACE FUNCTION delete_user_by_id(p_user_id INTEGER)
RETURNS VOID AS $$
BEGIN
    -- Kullanıcıya bağlı tablolarda verileri sil
    DELETE FROM normalusers WHERE user_id = p_user_id;
    DELETE FROM devusers WHERE user_id = p_user_id;
    DELETE FROM admins WHERE user_id = p_user_id;

    -- BaseUsers tablosundaki kullanıcıyı sil
    DELETE FROM baseusers WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_developer(
    p_username VARCHAR(255),
    p_email VARCHAR(255),
    p_company_name VARCHAR(255),
    p_verified BOOLEAN
)
RETURNS VOID AS
$$
BEGIN
    -- BaseUsers tablosuna yeni kullanıcı ekle
    WITH inserted_user AS (
        INSERT INTO BaseUsers (username, email, user_type)
        VALUES (p_username, p_email, 'Dev')
        RETURNING user_id
    )
    -- DevUsers tablosuna ekleme yap
    INSERT INTO DevUsers (user_id, sirket_adi, onayli_gelistirici)
    SELECT user_id, p_company_name, p_verified FROM inserted_user;

    
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_admin(
    p_username VARCHAR(255),
    p_email VARCHAR(255),
    p_yetki_seviyesi INTEGER
)
RETURNS VOID AS
$$
BEGIN
    -- BaseUsers tablosuna yeni kullanıcı ekle
    WITH inserted_user AS (
        INSERT INTO BaseUsers (username, email, password, user_type)
        VALUES (p_username, p_email, 'defaultpassword123', 'Admin') 
        RETURNING user_id
    )
    -- Admins tablosuna ekleme yap
    INSERT INTO Admins (user_id, yetki_seviyesi)
    SELECT user_id, p_yetki_seviyesi FROM inserted_user;

    -- Yeni kullanıcı Admin olarak eklendi
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_admin_authority(user_id_to_update INTEGER, new_authority_level INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE admins
    SET yetki_seviyesi = new_authority_level
    WHERE user_id = user_id_to_update;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Admin with user_id % does not exist.', user_id_to_update;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION normalize_email()
RETURNS TRIGGER AS $$
BEGIN
    NEW.email = LOWER(NEW.email);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER normalize_user_email
BEFORE INSERT OR UPDATE ON BaseUsers
FOR EACH ROW
EXECUTE FUNCTION normalize_email();




-- 10 Publishers ekleme
INSERT INTO Publishers (publisher_name, establishment_date) VALUES 
('Electronic Arts', '1982-05-28'),
('Ubisoft', '1986-03-28'),
('Activision', '1979-10-01'),
('Bethesda Softworks', '1986-06-28'),
('Square Enix', '1986-09-22'),
('CD Projekt Red', '1994-05-01'),
('Rockstar Games', '1998-12-01'),
('Nintendo', '1889-09-23'),
('Sony Interactive Entertainment', '1993-11-16'),
('Valve Corporation', '1996-08-24');

-- 4 Platforms ekleme
INSERT INTO Platforms (platform_name) VALUES
('PC'),
('PlayStation'),
('Xbox'),
('Nintendo Switch');

-- 10 Tags ekleme
INSERT INTO Game_Tags (tag_name) VALUES
('Action'),
('Adventure'),
('RPG'),
('Shooter'),
('Strategy'),
('Simulation'),
('Sports'),
('Horror'),
('Puzzle'),
('Indie');

-- 3 Payment Methods ekleme
INSERT INTO Payment_Methods (payment_method_name) VALUES
('Credit Card'),
('PayPal'),
('Cryptocurrency');

-- 5 Categories ekleme
INSERT INTO Categories (category_name) VALUES
('Single-player'),
('Multiplayer'),
('Open World'),
('Story-driven'),
('Battle Royale');


CREATE OR REPLACE FUNCTION add_game(
    p_category_id INT,
    p_developer_id INT,
    p_game_name VARCHAR,
    p_price NUMERIC,
    p_publisher_id INT
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO games (category_id, developer_id, game_name, price, publisher_id)
    VALUES (p_category_id, p_developer_id, p_game_name, p_price, p_publisher_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_purchase_price()
RETURNS TRIGGER AS $$
BEGIN
    -- Oyunun fiyatını al
    SELECT price INTO NEW.price
    FROM Games
    WHERE game_id = NEW.game_id;

    -- %20 vergi ekle
    NEW.price := NEW.price * 1.20;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER purchase_price_trigger
BEFORE INSERT ON Purchases
FOR EACH ROW
EXECUTE FUNCTION calculate_purchase_price();


CREATE OR REPLACE FUNCTION add_to_favorites()
RETURNS TRIGGER AS $$
BEGIN
    -- favorite_games tablosuna game_id ve user_id ekle
    INSERT INTO favorite_games (user_id, game_id)
    VALUES (NEW.user_id, NEW.game_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_purchase_add_favorite
AFTER INSERT ON purchases
FOR EACH ROW
EXECUTE FUNCTION add_to_favorites();

SELECT add_developer(
    'GenelDev',       
    'info@example.com', 
    'GenelDev',        
    TRUE                   
);

SELECT add_game(
    1,                    
    2,                      
    'The Witcher 3',        
    59.99,                  
    1                       
);

SELECT add_game(
    2,                      
    2,                      
    'Cyberpunk 2077',       
    49.99,                  
    1                       
);

SELECT add_game(
    3,                      
    2,                      
    'Elden Ring',           
    69.99,                  
    2                       
);

SELECT add_game(
    4,                      
    2,                      
    'Stardew Valley',       
    14.99,                  
    3                       
);
INSERT INTO Purchases (user_id, game_id)
    VALUES (1, 1);
    
INSERT INTO purchase_payment (purchase_id, payment_method_id)
VALUES (1, 2);