extends Node

signal money_changed(new_amount)
signal day_changed(new_day)
signal maintenance_updated(new_maintenance)
signal contracts_updated() 
signal game_over(is_victory: bool, message: String)

var current_level: int = 1
var highest_unlocked_level: int = 1
var start_in_world_map: bool = true 

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

# NOVO: O valor diario extorquido pela mafia
var daily_gang_toll: int = 0

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
	var lvl_data = LevelData.LEVELS[current_level]
	money = lvl_data["budget"] 
	current_day = 1
	daily_maintenance = 0
	daily_gang_toll = 0
	active_contracts.clear()
	network_connections.clear()

func end_day() -> void:
	money += get_daily_income()
	money -= daily_maintenance
	money -= BASE_COST 
	money -= daily_gang_toll # A mafia recolhe o dinheiro aqui!
	
	var contracts_to_keep = []
	for c in active_contracts:
		c["days_left"] -= 1
		if c["days_left"] > 0:
			contracts_to_keep.append(c)
			
	active_contracts = contracts_to_keep
	contracts_updated.emit()
	
	current_day += 1
	var lvl_data = LevelData.LEVELS[current_level]
	
	if money < 0:
		trigger_bankruptcy()
	elif money >= lvl_data["goal"]: 
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
	var msg = "FALENCIA!\n\nO seu saldo ficou negativo. A sua empresa fechou as portas nesta regiao."
	game_over.emit(false, msg)

func trigger_victory() -> void:
	if current_level == highest_unlocked_level and LevelData.LEVELS.has(current_level + 1):
		highest_unlocked_level += 1
		
	var msg = "VITORIA!\n\nAtingiu a meta da regiao! O governo autorizou a sua expansao."
	game_over.emit(true, msg)
