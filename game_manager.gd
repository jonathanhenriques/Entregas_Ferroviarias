extends Node

signal money_changed(new_amount)
signal day_changed(new_day)
signal maintenance_updated(new_maintenance)
signal contracts_updated() 
signal game_over(is_victory: bool, message: String)

var current_level: int = 1

# O NOSSO NOVO SISTEMA DE FASES (BASE DE DADOS)
var level_database = {
	1: {
		"name": "O Vale do Rio (Tutorial)",
		"budget": 1500,
		"goal": 4000,
		"map_layout": [
			# 36 colunas, 20 linhas (Este é o mapa V18 escrito em texto!)
			"...............FFFFF................",
			"...............FFFFF................",
			"...............FFFFF................",
			"...............FFFFF..........C.....",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"..A.....RR.....MMMM....B............",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			".......FFFF....MMMM.................",
			".......FFFF....MMMM.................",
			".......FFFF....MMMM.................",
			".......FFFF....MMMM................."
		]
	}
}

var money: int = 1500 :
	set(value):
		money = value
		money_changed.emit(money)

var current_day: int = 1 :
	set(value):
		current_day = value
		day_changed.emit(current_day)

var daily_maintenance: int = 0 :
	set(value):
		daily_maintenance = value
		maintenance_updated.emit(daily_maintenance)

var active_contracts: Array = []
const MAX_CONTRACTS: int = 3 
const BASE_COST: int = 25 

var network_connections: Array = []

func get_daily_income() -> int:
	var total = 0
	for c in active_contracts:
		if c["route_id"] in network_connections:
			total += c["reward"]
	return total

func reset_game() -> void:
	var lvl_data = level_database[current_level]
	money = lvl_data["budget"] # Agora le o orcamento da fase atual!
	current_day = 1
	daily_maintenance = 0
	active_contracts.clear()
	network_connections.clear()

func end_day() -> void:
	money += get_daily_income()
	money -= daily_maintenance
	money -= BASE_COST 
	
	var contracts_to_keep = []
	for c in active_contracts:
		c["days_left"] -= 1
		if c["days_left"] > 0:
			contracts_to_keep.append(c)
			
	active_contracts = contracts_to_keep
	contracts_updated.emit()
	
	current_day += 1
	
	var lvl_data = level_database[current_level]
	
	if money < 0:
		trigger_bankruptcy()
	elif money >= lvl_data["goal"]: # Agora le a meta da fase atual!
		trigger_victory()

func cancel_contract(index: int) -> void:
	if index >= 0 and index < active_contracts.size():
		var c = active_contracts[index]
		var total_projected_value = c["reward"] * c["days_left"]
		var penalty = int(total_projected_value * 0.20)
		
		money -= penalty
		active_contracts.remove_at(index)
		contracts_updated.emit()

func trigger_bankruptcy() -> void:
	var msg = "FALENCIA!\n\nO seu saldo ficou negativo. Os investidores retiraram o apoio e a sua empresa ferroviaria fechou."
	game_over.emit(false, msg)

func trigger_victory() -> void:
	var msg = "VITORIA!\n\nAtingiu a meta da regiao! A sua expansao para a proxima area foi autorizada."
	game_over.emit(true, msg)
