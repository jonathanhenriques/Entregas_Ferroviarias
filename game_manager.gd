extends Node

signal money_changed(new_amount)
signal day_changed(new_day)
signal maintenance_updated(new_maintenance)
signal contracts_updated() 
signal game_over(is_victory: bool, message: String)

var money: int = 1000 :
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
var has_active_route: bool = false
const MAX_CONTRACTS: int = 3 

# CORRECAO: O lucro agora depende inteiramente da existencia da rota!
func get_daily_income() -> int:
	if not has_active_route:
		return 0 # Sem trilhos = sem dinheiro
		
	var total = 0
	for c in active_contracts:
		total += c["reward"]
	return total

func reset_game() -> void:
	money = 1000
	current_day = 1
	daily_maintenance = 0
	active_contracts.clear()
	has_active_route = false

func end_day() -> void:
	money += get_daily_income()
	money -= daily_maintenance
	
	var contracts_to_keep = []
	for c in active_contracts:
		c["days_left"] -= 1
		if c["days_left"] > 0:
			contracts_to_keep.append(c)
			
	active_contracts = contracts_to_keep
	contracts_updated.emit()
	
	current_day += 1
	
	if money < 0:
		trigger_bankruptcy()
	elif money >= 3000:
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
	var msg = "FALENCIA!\n\nSeu saldo ficou negativo. Os investidores retiraram o apoio e sua empresa ferroviaria foi fechada."
	game_over.emit(false, msg)

func trigger_victory() -> void:
	var msg = "VITORIA!\n\nVoce atingiu a meta de $3000 em caixa! Sua operacao logistica e um sucesso absoluto na regiao."
	game_over.emit(true, msg)
