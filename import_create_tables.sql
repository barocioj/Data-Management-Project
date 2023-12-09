/* 
replace path_name with the path name of each file
*/

-- Functions:
CREATE OR REPLACE FUNCTION get_pokemon_name(
	pokemon_game_name VARCHAR
)
RETURNS VARCHAR
LANGUAGE plpgsql
AS 
$$
DECLARE
	pokemon_name VARCHAR;
BEGIN
	IF pokemon_game_name NOT LIKE '%(%)' THEN
		RETURN pokemon_game_name;
	END IF
	;
	
	pokemon_name := substring(pokemon_game_name FROM '\(([^()]+)\)');
		
	IF pokemon_name = 'M' OR pokemon_name = 'F' THEN
		pokemon_name := (regexp_replace(pokemon_game_name, '\(.\)', ''));
	END IF
	;
	
	RETURN pokemon_name;
	
END;
$$
;

CREATE OR REPLACE FUNCTION remove_last_bar(
	players VARCHAR
)
RETURNS VARCHAR
LANGUAGE plpgsql
AS 
$$
BEGIN
	RETURN SUBSTRING(players FROM 1 FOR LENGTH(players) -1);
END;
$$
;

CREATE OR REPLACE FUNCTION modify_pokemon_name(input_string VARCHAR)
RETURNS VARCHAR 
LANGUAGE plpgsql
AS 
$$
DECLARE
    dash_position INT;
    prefix VARCHAR;
	suffix VARCHAR;
    modified_name VARCHAR;
BEGIN
    -- Find the position of the dash
    dash_position := POSITION('-' IN input_string);

    -- If dash is found, check for Alola, Hisui, Galar, or Rotom
	IF input_string LIKE '%Palafin%' THEN
		modified_name := 'Palafin (Hero Form)';
		RETURN modified_name;
	END IF;
    IF dash_position > 0 THEN
        suffix := SUBSTRING(input_string FROM dash_position + 1);
		prefix := SUBSTRING(input_string FROM 1 FOR dash_position - 1);
        CASE
            WHEN suffix = 'Alola' THEN
                modified_name := prefix || ' (Alolan ' || prefix || ')';
            WHEN suffix = 'Hisui' THEN
                modified_name := prefix || ' (Hisuian ' || prefix || ')';
            WHEN suffix = 'Galar' THEN
                modified_name := prefix || ' (Galarian ' || prefix || ')';
            WHEN prefix = 'Rotom' THEN
                modified_name := 'Rotom (' || suffix || ' Rotom)';
			WHEN prefix = 'Vivillon' THEN
				modified_name := 'Vivillon';
			WHEN prefix = 'Tauros' THEN
				suffix := SUBSTRING(suffix FROM dash_position + 1);
				IF suffix = 'Water' THEN
					suffix := 'Aqua';
				ELSIF suffix = 'Fire' THEN
					suffix := 'Blaze';
				END IF;
				modified_name := prefix || ' (' || suffix || ' Breed)';
			WHEN prefix = 'Gastrodon' THEN
				modified_name := prefix;
			WHEN prefix = 'Tatsugiri' THEN
				modified_name := prefix || ' (' || suffix || ' Form)';
			WHEN prefix = 'Enamorus' OR prefix = 'Thundurus' OR prefix = 'Landorus' OR prefix = 'Tornadus' THEN
				modified_name := prefix || ' (' || suffix || ' Forme)';
			WHEN prefix = 'Maushold' THEN
				modified_name := prefix || ' (Family of ' || suffix || ')';
			WHEN prefix = 'Urshifu' THEN
				suffix := REPLACE(suffix, '-', ' ');
				modified_name := prefix || ' (' || suffix || ' Style)';
			WHEN prefix = 'Indeedee' THEN
				IF suffix = 'M' THEN
					suffix := ' (Male)';
				ELSIF suffix = 'F' THEN
					suffix := ' (Female)';
				modified_name := prefix || suffix;
				END IF;
				
				
            ELSE
                modified_name := input_string;
        END CASE;
		
	ELSIF input_string = 'Maushold' THEN
		modified_name := 'Maushold (Family of Three)';
    ELSE
        modified_name := input_string;
    END IF;

    RETURN modified_name;
END;
$$ 
;

-- Create tables
-- natures
DROP TABLE IF EXISTS natures CASCADE;
CREATE TABLE natures (
	nature_id SMALLINT 
	, nature VARCHAR(20) PRIMARY KEY
	, increase VARCHAR(15)
	, decrease VARCHAR(15)
);
COPY natures
FROM '/natures.csv'
DELIMITER ','
CSV HEADER;
ALTER TABLE natures
DROP COLUMN IF EXISTS nature_id
;

-- pokedex
DROP TABLE IF EXISTS pokedex CASCADE;
CREATE TABLE pokedex (
	num SMALLINT
	, image_link VARCHAR
	, pokedex_number SMALLINT
	, pokemon_name VARCHAR(50) PRIMARY KEY
	, type1 VARCHAR(10)
	, type2 VARCHAR(10)
	, bst SMALLINT
	, hp SMALLINT
	, atk SMALLINT
	, def SMALLINT
	, sp_atk SMALLINT
	, sp_def SMALLINT
	, spd SMALLINT
);
COPY pokedex
FROM '/pokemon_data.csv'
DELIMITER ','
CSV HEADER;
ALTER TABLE pokedex 
DROP COLUMN IF EXISTS num
;

-- players
DROP TABLE IF EXISTS players CASCADE;
CREATE TABLE players (
	num SMALLINT
	, team_id FLOAT
	, regulation VARCHAR(25)
	, player_names VARCHAR(50)
	, PRIMARY KEY (team_id, regulation)
);
COPY players
FROM '/pokemon_players.csv'
DELIMITER ','
CSV HEADER;
ALTER TABLE players
DROP COLUMN IF EXISTS num
;
DELETE FROM players 
WHERE (team_id, regulation) NOT IN (
	SELECT team_id, regulation FROM competitive_pokemon
)
;
UPDATE players
SET player_names = subquery.player_names
FROM (
	SELECT 
		remove_last_bar(player_names) AS player_names
		, team_id
		, regulation
	FROM players
) AS subquery
WHERE players.team_id = subquery.team_id
	AND players.regulation = subquery.regulation
;

-- moves
DROP TABLE IF EXISTS moves CASCADE;
CREATE TABLE moves (
	num SMALLINT
	, move_name VARCHAR(50) PRIMARY KEY
	, move_type VARCHAR(10)
	, category VARCHAR(15)
	, base_power VARCHAR(5)
	, accuracy VARCHAR(5)
	, pp VARCHAR
	, move_effect VARCHAR
	, effect_probability VARCHAR(5)
);
COPY moves
FROM '/pokemon_moves.csv'
DELIMITER ','
CSV HEADER;
ALTER TABLE moves 
DROP COLUMN IF EXISTS num
;

-- items
DROP TABLE IF EXISTS items CASCADE;
CREATE TABLE items (
	num SMALLINT
	, item_name VARCHAR PRIMARY KEY
	, item_category VARCHAR
	, item_effect VARCHAR 
);
COPY items
FROM '/pokemon_items.csv'
DELIMITER ','
CSV HEADER;
ALTER TABLE items 
DROP COLUMN IF EXISTS num
;
UPDATE items
SET item_effect = 'No Effect'
WHERE item_effect IS NULL
;
-- abilities
DROP TABLE IF EXISTS abilities CASCADE;
CREATE TABLE abilities (
	num SMALLINT
	, ability_name VARCHAR PRIMARY KEY
	, pokemon_amount SMALLINT
	, description VARCHAR
	, gen_introduced SMALLINT
);
COPY abilities
FROM '/ablities (1).csv'
DELIMITER ','
CSV HEADER;
ALTER TABLE abilities
DROP COLUMN IF EXISTS num
;
UPDATE abilities
SET description = 'No description provided'
WHERE description IS NULL
;

-- competitve_pokemon
DROP TABLE IF EXISTS competitive_pokemon CASCADE;
CREATE TABLE competitive_pokemon (
	pokemon_id SMALLINT PRIMARY KEY
	, team_id FLOAT
	, regulation VARCHAR(25)
	, game_name VARCHAR(50)
	, item VARCHAR(50)
	, ability VARCHAR(25)
	, teratype VARCHAR(10)
	, hp_evs FLOAT
	, atk_evs FLOAT
	, def_evs FLOAT
	, spatk_evs FLOAT
	, spdef_evs FLOAT
	, spe_evs FLOAT
	, nature VARCHAR(15)
	, ivs VARCHAR(25)
	, move1 VARCHAR(25)
	, move2 VARCHAR(25)
	, move3 VARCHAR(25)
	, move4 VARCHAR(25)
);
COPY competitive_pokemon
FROM '/pokemon_team.csv'
DELIMITER ','
CSV HEADER;
ALTER TABLE competitive_pokemon
	ALTER COLUMN team_id TYPE SMALLINT
	, ALTER COLUMN hp_evs TYPE SMALLINT
	, ALTER COLUMN atk_evs TYPE SMALLINT
	, ALTER COLUMN def_evs TYPE SMALLINT
	, ALTER COLUMN spatk_evs TYPE SMALLINT
	, ALTER COLUMN spdef_evs TYPE SMALLINT
	, ALTER COLUMN spe_evs TYPE SMALLINT
;
DELETE FROM competitive_pokemon
WHERE (team_id, regulation) NOT IN (
	SELECT team_id, regulation FROM players
)
;
ALTER TABLE competitive_pokemon
DROP COLUMN IF EXISTS pokemon_name
;
ALTER TABLE competitive_pokemon
DROP COLUMN IF EXISTS ivs;
ALTER TABLE competitive_pokemon
ADD COLUMN pokemon_name VARCHAR
;
UPDATE competitive_pokemon
SET pokemon_name = subquery.pokemon_name
FROM (
	SELECT 
		get_pokemon_name(game_name) AS pokemon_name
		, pokemon_id
	FROM competitive_pokemon
) AS subquery
WHERE competitive_pokemon.pokemon_id = subquery.pokemon_id
;
UPDATE competitive_pokemon
SET pokemon_name = TRIM(TRAILING ' ' FROM pokemon_name)
;
UPDATE competitive_pokemon
SET move4 = 'None'
WHERE move4 IS NULL
;
UPDATE competitive_pokemon
SET teratype = 'None'
WHERE teratype IS NULL
;
UPDATE competitive_pokemon
SET nature = 'Hardy'
WHERE nature NOT IN (SELECT nature FROM natures)
;
UPDATE competitive_pokemon
SET pokemon_name = subquery.new_name
FROM (
	SELECT 
	pokemon_name
	, modify_pokemon_name(pokemon_name) AS new_name
	FROM competitive_pokemon
	WHERE pokemon_name NOT IN (
		SELECT 
			pokemon_name
		FROM pokedex
	)
) AS subquery
WHERE competitive_pokemon.pokemon_name = subquery.pokemon_name
;
DELETE FROM competitive_pokemon
WHERE pokemon_name IN (
	SELECT 
	pokemon_name
	FROM competitive_pokemon
	WHERE pokemon_name NOT IN (
		SELECT 
			pokemon_name
		FROM pokedex
	)
)
;
DELETE FROM competitive_pokemon
WHERE item IN (
	SELECT item
	FROM competitive_pokemon
	WHERE item NOT IN (
		SELECT 
			item_name
		FROM items
	)
)
;
ALTER TABLE competitive_pokemon
DROP CONSTRAINT IF EXISTS fk_natures;
ALTER TABLE competitive_pokemon
ADD CONSTRAINT fk_natures
FOREIGN KEY (nature)
REFERENCES natures (nature)
;
ALTER TABLE competitive_pokemon
DROP CONSTRAINT IF EXISTS fk_team_players;
ALTER TABLE competitive_pokemon
ADD CONSTRAINT fk_team_players
FOREIGN KEY (team_id, regulation)
REFERENCES players (team_id, regulation)
;
ALTER TABLE competitive_pokemon
DROP CONSTRAINT IF EXISTS fk_pokedex;
ALTER TABLE competitive_pokemon
ADD CONSTRAINT fk_pokedex
FOREIGN KEY (pokemon_name)
REFERENCES pokedex(pokemon_name)
;
ALTER TABLE competitive_pokemon
DROP CONSTRAINT IF EXISTS fk_item;
ALTER TABLE competitive_pokemon
ADD CONSTRAINT fk_item
FOREIGN KEY (item)
REFERENCES items(item_name)
;

CREATE OR REPLACE FUNCTION insert_info_move (
	move_name VARCHAR
	, move_type VARCHAR
	, category VARCHAR
	, base_power VARCHAR
	, accuracy VARCHAR
	, pp VARCHAR
	, move_effect VARCHAR
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
	INSERT INTO moves(move_name, move_type, category, base_power, accuracy, pp, move_effect)
	VALUES (move_name, move_type, category, base_power, accuracy, pp, move_effect);
END;
$$;

SELECT insert_info_move ('None', 'None', 'None', 'None', 'None', 'None', 'None')
;

ALTER TABLE competitive_pokemon
DROP CONSTRAINT IF EXISTS fk_move1;
ALTER TABLE competitive_pokemon
ADD CONSTRAINT fk_move1
FOREIGN KEY (move1)
REFERENCES moves(move_name);
ALTER TABLE competitive_pokemon
DROP CONSTRAINT IF EXISTS fk_move2;
ALTER TABLE competitive_pokemon
ADD CONSTRAINT fk_move2
FOREIGN KEY (move2)
REFERENCES moves(move_name);
ALTER TABLE competitive_pokemon
DROP CONSTRAINT IF EXISTS fk_move3;
ALTER TABLE competitive_pokemon
ADD CONSTRAINT fk_move3
FOREIGN KEY (move3)
REFERENCES moves(move_name);
ALTER TABLE competitive_pokemon
DROP CONSTRAINT IF EXISTS fk_move4;
ALTER TABLE competitive_pokemon
ADD CONSTRAINT fk_move4
FOREIGN KEY (move4)
REFERENCES moves(move_name);