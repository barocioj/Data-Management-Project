# Import statement
import requests
import csv
from bs4 import BeautifulSoup
import pandas as pd
import re
import time

# Constants
regulation_a_url = requests.get('https://victoryroadvgc.com/sv-rental-teams-reg-set-A/')
regulation_b_url = requests.get('https://victoryroadvgc.com/sv-rental-teams-reg-set-B/')
regulation_c_url = requests.get('https://victoryroadvgc.com/sv-rental-teams-reg-set-C/')
regulation_d_url = requests.get('https://victoryroadvgc.com/sv-rental-teams-reg-set-D/')
regulation_e_url = requests.get('https://victoryroadvgc.com/sv-rental-teams/')
VICTORYROADY_URLS = [regulation_a_url, regulation_b_url, regulation_c_url, regulation_d_url, regulation_e_url]
VICTORYROAD_TABLE_CLASS = 'infobox2' # class of all the tables on the victroyroad webpage
VICTORYROAD_PASTE_INDEX = 5 # index for link to team info in each row of victoryroad table
VICTORYROAD_PLAYERS_INDEX = 1 # index for the players names in each row of victory road table 
VICTORYROAD_TEAM_ALTERNATIVE_INDEX = 3 # The alternative index for the team if no team info is avalable 
POKEMON_DATA_EMPTY = {
        'Team_id': [],
        'Regulation': [],
        'Name': [],
        'Item': [],
        'Ability': [],
        'Tera Type': [],
        'HP Evs': [],
        'Atk Evs': [],
        'Def Evs': [],
        'SpAtk Evs': [],
        'SpDef Evs': [],
        'Spe Evs': [],
        'Nature': [],
        'IVs': [],
        'Move 1': [],
        'Move 2': [],
        'Move 3': [],
        'Move 4': []
}
TEAM_DATA_EMPTY = {
    'Team id': [],
    'Regulation': [],
    'Player': []
}

# Test variables
kommo_o_url = 'https://pokepast.es/1ced34f938614832' # test team url
amoongus_url = 'https://pokepast.es/8e9b20c6847f102b'
baxcalibur_url = 'https://pokepast.es/762a7dc9b02f248a'
regulation_e_soup = BeautifulSoup(regulation_e_url.text, 'html.parser')
regulation_e_table1 = regulation_e_soup.find_all('tbody')[0]

# Helper functions
def team_scrape(url, team_id, regulation):
    """
    Description: Scrapes the team page 

    Args: 
    - url (str): url of the page

    Returns: pandas dataframe of pokemon information
    """
    # Function variables
    team_html = requests.get(url)
    team_soup = BeautifulSoup(team_html.text, 'html.parser')
    team_soup_articles = team_soup.find_all('article')
    stat_names = [('HP', 'HP Evs'), ('Atk', 'Atk Evs'), ('Def', 'Def Evs'), ('SpA', 'SpAtk Evs'), ('SpD', 'SpDef Evs'), ('Spe', 'Spe Evs')] # Tuple of names of stats on pokepaste and the corresposing dataframe keys (stat, key)
    pokemon_move_keys = ['Move 1', 'Move 2', 'Move 3', 'Move 4'] # list of pokemon data keys

    pokemon_data = POKEMON_DATA_EMPTY
    
    for article in team_soup_articles:
        # Spliting each pokemon (html article tag) into a list
        article_text= article.find('pre').text
        article_info = re.split('\n', article_text)

        # Check for empty pokemon
        if len(article_info) < 3:
            break

         # Index if level, shiny and teratypes are missing
        article_index = 0
        if article_info[2].find('Level:') != -1:
            article_index += 1
        if article_info[2 + article_index].find('Shiny:') != -1:
            article_index += 1
        if article_info[2 + article_index].find('Tera Type:') != -1:
            article_teratype = article_info[2+article_index]
            pokemon_teratype = article_teratype[article_teratype.find(':')+1:].strip()
            article_index += 1
        else: 
            pokemon_teratype = None

        # Finding the corresponding index for each columnn on in the article list
        article_name_item = article_info[0]
        article_ability = article_info[1]
        article_stats = article_info[2+article_index]
        article_stats = article_stats[article_stats.find(':')+1:]
        article_nature = article_info[3+article_index]
        article_ivs = article_info[4+article_index]
        article_moves = article_info[len(article_info)-6:len(article_info)-2]

        # Defining the variable that we want for each pokemon and appending it to its corresponding empty list
        pokemon_name = article_name_item[: article_name_item.find('@') - 1]
        pokemon_item = article_name_item[article_name_item.find('@')+1:].strip()
        pokemon_ability = article_ability[article_ability.find(':')+1:].strip()
        pokemon_nature = article_nature[:article_nature.find('Nature')-1].strip()
        if article_ivs.find('IVs:')==-1:
            pokemon_iv = 'None'
        else:
            pokemon_iv = article_ivs[article_ivs.find(':')+ 2:].strip()

        for i in range(6):
            if stat_names[i][0] in article_stats:
                stat = int(article_stats[: article_stats.find(stat_names[i][0])].strip())
                article_stats = article_stats[article_stats.find('/')+1:]
                pokemon_data[stat_names[i][1]].append(stat)
            else:
                pokemon_data[stat_names[i][1]].append(0)
        
        for i in range(4):
            pokemon_data[pokemon_move_keys[i]].append(article_moves[i][article_moves[i].find('-')+1:].strip())

        pokemon_data['Name'].append(pokemon_name)
        pokemon_data['Item'].append(pokemon_item)
        pokemon_data['Ability'].append(pokemon_ability)
        pokemon_data['Tera Type'].append(pokemon_teratype)
        pokemon_data['Nature'].append(pokemon_nature)
        pokemon_data['IVs'].append(pokemon_iv)
        pokemon_data['Team_id'].append(team_id)
        pokemon_data['Regulation'].append(regulation)

    pokemon_article_dataframe = pd.DataFrame(pokemon_data)
    return pokemon_article_dataframe

def player_scrape(tbody, team_id, regulation):
    """
    Description: For each table on VictoryRoad, makes a dataframe of the players and the regulation of their team along with a corresponding team_id

    Args:
    - tbody (html.tag): The tbody element of the table that is being scraped
    - team_id (int): the team id of the table
    - regulation (string): the regulation of the webpage

    Returns:
    - player key (tuple): A tuple containing a tuple with the team_id and regulation and a dataframe of the players ((team_id, regulation),[players])
    """
    player_regulation_data = TEAM_DATA_EMPTY

    for row in tbody.find_all('tr'):
        tds_in_row = row.find_all('td')
        paste_a = tds_in_row[VICTORYROAD_PASTE_INDEX].find('a')
        if paste_a != None:
            players = ''
            for player in tds_in_row[VICTORYROAD_PLAYERS_INDEX].find_all('b'):
                players = players + player.text + '|'
            player_regulation_data['Player'].append(players)
            player_regulation_data['Team id'].append(team_id)
            player_regulation_data['Regulation'].append(regulation)
            team_id += 1       
    player_dataframe = pd.DataFrame(player_regulation_data)
    return player_dataframe

def table_scrape(tbody, team_id, regulation):
    """
    Description: Takes each tbody for each table and returns the dataframe of pokemon from each 
    table

    Args: 
    - tbody (html.tag): The tbody element of the table that you are scraping for
    - team_id (int): The team index for the regulation
    - regulation: the regulation of the table

    Returns: 
    - pokemon_table_dataframe (pands.DataFrame): A dataframe of pokemon from the table
    - player_table_dataframe (pands.DataFrame): A dataframe of all the players and the correspoding
    - team_id (int): Team index for the page
    """
    pokemon_table_dataframe = pd.DataFrame(POKEMON_DATA_EMPTY)
    player_table_dataframe = pd.DataFrame(TEAM_DATA_EMPTY)

    player_table_dataframe = pd.concat([player_table_dataframe, player_scrape(tbody, team_id, regulation)], )
    for row in tbody.find_all('tr'):
        tds_in_row = row.find_all('td')
        paste_a = tds_in_row[VICTORYROAD_PASTE_INDEX].find('a')
        if paste_a != None:
            team_link = paste_a.get('href')
            pokemon_table_dataframe = pd.concat([pokemon_table_dataframe, team_scrape(team_link, team_id, regulation)])
            time.sleep(2)
        team_id += 1
    
    return pokemon_table_dataframe, player_table_dataframe, team_id

# Single Webpage Scrape
def webpage_scrape(url):
    """
    Description: A regulation page of all the teams and returns 2 dataframes. One contains all the team info
    such as description, regulation, etc and a team_id the second dataframe contains the pokemon on each team
    and its build info such as item, nature, ev spread, ability, etc and is related to the team tables through
    a team_id

    Args:
    - url: The url of the webpage as a requests.models.Response type. The requests.get(url)

    Returns: 
    - teams_dataframe (pandas.DataFrame): DataFrame of all the teams with team id, regulation, description, etc
    - pokemon_dataframe (pandas.DataFrame): DataFrame of all the pokemon on teams. Relates to team table through team id
    """
    page_soup = BeautifulSoup(url.text, 'html.parser')
    page_tbodys = page_soup.find_all('tbody')
    page_regulation = page_soup.find('h2').text
    team_id = 1
    
    pokemon_dataframe = pd.DataFrame(POKEMON_DATA_EMPTY)
    player_dataframe = pd.DataFrame(TEAM_DATA_EMPTY)

    for tbody in page_tbodys:
        if tbody.find('td').text != 'Regulation Set A':
            table_dataframe, player_table_dataframe, team_id = table_scrape(tbody, team_id, page_regulation)
            pokemon_dataframe = pd.concat([pokemon_dataframe,table_dataframe])  
            player_dataframe = pd.concat([player_dataframe, player_table_dataframe])
    
    return pokemon_dataframe, player_dataframe

def webscrape(url_list):

    pokemon_dataframe = pd.DataFrame(POKEMON_DATA_EMPTY)
    player_dataframe = pd.DataFrame(TEAM_DATA_EMPTY)

    for url in url_list:
        webpage_pokemon_dataframe, webpage_player_dataframe = webpage_scrape(url)
        pokemon_dataframe = pd.concat([pokemon_dataframe, webpage_pokemon_dataframe])
        player_dataframe = pd.concat([player_dataframe, webpage_player_dataframe])

    pokemon_dataframe = pokemon_dataframe.drop_duplicates()
    player_dataframe = player_dataframe.drop_duplicates()
    return pokemon_dataframe, player_dataframe



if __name__ == "__main__":
    #pokemon_teams_df()
    #print(webpage_scrape(regulation_d_url))
    #print(webpage_scrape(regulation_a_url))
    #print(team_scrape(kommo_o_url))
    #print(team_scrape(amoongus_url))
    #print(webpage_scrape(regulation_a_url))
    #print(team_scrape(baxcalibur_url))
    #print(type(regulation_a_url))
    #print(webpage_scrape(regulation_d_url))
    #table_scrape(regulation_e_table1,1, 'E')
    pokemon, players = webscrape(VICTORYROADY_URLS)
    print(pokemon)
    print(players)
    pokemon.to_csv('/Users/doug_ii/Desktop/Data 351/Final Project/Pokemon team data/pokemon_team.csv')
    players.to_csv('/Users/doug_ii/Desktop/Data 351/Final Project/Pokemon team data/pokemon_players.csv')

    

