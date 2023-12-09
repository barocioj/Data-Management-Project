DROP VIEW IF EXISTS pokemon_and_players;
CREATE OR REPLACE VIEW pokemon_and_players AS (
	SELECT 
		cp.pokemon_id
		, cp.regulation
		, cp.team_id
		, pl.player_names
		, cp.pokemon_name
		, cp.game_name
		, cp.item
		, cp.ability
		, cp.nature
		, cp.move1
		, cp.move2
		, cp.move3
		, cp.move4
	FROM competitive_pokemon AS cp
	JOIN 
		players AS pl ON pl.regulation = cp.regulation
		AND pl.team_id = cp.team_id
	ORDER BY cp.pokemon_id
);

--SELECT * FROM pokemon_and_players;

DROP VIEW IF EXISTS pokemon_items;
CREATE OR REPLACE VIEW pokemon_items AS (
	SELECT 
		cp.pokemon_id
		, cp.regulation
		, cp.team_id
		, cp.pokemon_name
		, cp.game_name
		, cp.item
		, i.item_category
		, i.item_effect
	FROM competitive_pokemon AS cp
	JOIN items AS i ON i.item_name = cp.item
	ORDER BY pokemon_id
);

--SELECT * FROM pokemon_items;

DROP VIEW IF EXISTS pokemon_pokedex;
CREATE OR REPLACE VIEW pokemon_pokedex AS (
	SELECT 
		cp.pokemon_id
		, cp.team_id
		, cp.regulation
		, cp.game_name
		, cp.pokemon_name
		, po.type1
		, po.type2
		, cp.ability
		, cp.teratype
		, cp.nature
		, po.bst
		, po.hp
		, po.atk
		, po.def
		, po.sp_atk
		, po.sp_def
		, po.spd
	FROM competitive_pokemon AS cp
	JOIN pokedex AS po ON po.pokemon_name = cp.pokemon_name
	ORDER BY pokemon_id
);

--SELECT * FROM pokemon_pokedex;

DROP VIEW IF EXISTS pokemon_ability;
CREATE OR REPLACE VIEW pokemon_ability AS (
	SELECT 
		cp.pokemon_id
		, cp.team_id
		, cp.regulation
		, cp.ability
		, ab.description
	FROM competitive_pokemon AS cp
	JOIN abilities AS ab ON ab.ability_name = cp.ability
	ORDER BY cp.pokemon_id
);

--SELECT * FROM pokemon_ability;


CREATE OR REPLACE PROCEDURE export_view_to_csv(
	IN view_name VARCHAR
	, IN file_path VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE 'COPY (SELECT * FROM ' || quote_ident(view_name) || ') TO ''' || file_path || ''' WITH CSV HEADER;';
END;
$$;

CALL export_view_to_csv('pokemon_pokedex', '/Users/doug_ii/Desktop/Data 351/Final Project/Pokemon data/pokemon_pokedex.csv');

DROP TABLE IF EXISTS competitive_pokemon_archive;
CREATE TABLE competitive_pokemon_archive (
	deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	, pokemon_id SMALLINT PRIMARY KEY
	, team_id SMALLINT
	, regulation VARCHAR(25)
	, game_name VARCHAR(50)
	, item VARCHAR(50)
	, ability VARCHAR(25)
	, teratype VARCHAR(10)
	, hp_evs SMALLINT
	, atk_evs SMALLINT
	, def_evs SMALLINT
	, spatk_evs SMALLINT
	, spdef_evs SMALLINT
	, spe_evs SMALLINT
	, nature VARCHAR(15)
	, move1 VARCHAR(25)
	, move2 VARCHAR(25)
	, move3 VARCHAR(25)
	, move4 VARCHAR(25)
);
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


CREATE OR REPLACE FUNCTION archive_deleted_row()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO competitive_pokemon_archive (pokemon_id, regulation, game_name, item, ability, teratype, hp_evs, atk_evs, def_evs, spatk_evs, spdef_evs, spe_evs, nature, ivs, move1, move2, move3, move4)
    VALUES (OLD.pokemon_id, OLD.regulation, OLD.game_name, OLD.item, OLD.ability, OLD.teratype, OLD.hp_evs, OLD.atk_evs, OLD.def_evs, OLD.spatk_evs, OLD.spdef_evs, OLD.spe_evs, OLD.nature, OLD.ivs, OLD.move1, OLD.move2, OLD.move3, OLD.move4);

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS archive_deleted_trigger ON competitive_pokemon;
CREATE TRIGGER archive_deleted_trigger
BEFORE DELETE ON competitive_pokemon
FOR EACH ROW
EXECUTE FUNCTION archive_deleted_row();


SELECT * FROM natures