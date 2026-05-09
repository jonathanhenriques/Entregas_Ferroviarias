extends Node

# Sinais para avisar a interface quando algo mudar
signal money_changed(new_amount)
signal day_changed(new_day)
signal maintenance_updated(new_maintenance)
signal contracts_updated() # NOVO sinal: avisa quando um contrato entra, sai ou expira
signal game_over(is_victory: bool, message: String)

# Variaveis Globais de Economia e Tempo
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

# NOVA ESTRUTURA DE CONTRATOS
# Lista de dicionarios. Exemplo: {"cargo": "Madeira", "reward": 120, "days_left": 5}
var active_contracts: Array = []

# Funcao dinamica para calcular a receita baseada nos contratos ativos hoje
func get_daily_income() -> int:
	var total = 0
	for c in active_contracts:
		total += c["reward"]
	return total

# Funcao para iniciar ou reiniciar o jogo
func reset_game() -> void:
	money = 1000
	current_day = 1
	daily_maintenance = 0
	active_contracts.clear()

# Funcao para processar a virada do dia
func end_day() -> void:
	# O jogador recebe os lucros calculados e paga as manutencoes
	money += get_daily_income()
	money -= daily_maintenance
	
	# Atualiza o prazo de cada contrato e remove os que chegaram a zero
	var contracts_to_keep = []
	for c in active_contracts:
		c["days_left"] -= 1
		if c["days_left"] > 0:
			contracts_to_keep.append(c)
			
	active_contracts = contracts_to_keep
	contracts_updated.emit() # Forca a interface a se atualizar
	
	current_day += 1
	
	# Checa condicoes de vitoria ou derrota
	if money < 0:
		trigger_bankruptcy()
	elif money >= 3000:
		trigger_victory()

# NOVO: Funcao para cancelar um contrato prematuramente pagando multa
func cancel_contract(index: int, penalty: int) -> void:
	if index >= 0 and index < active_contracts.size():
		money -= penalty
		active_contracts.remove_at(index)
		contracts_updated.emit()

func trigger_bankruptcy() -> void:
	var msg = "FALENCIA!\n\nSeu saldo ficou negativo. Os investidores retiraram o apoio e sua empresa ferroviaria foi fechada."
	game_over.emit(false, msg)

func trigger_victory() -> void:
	var msg = "VITORIA!\n\nVoce atingiu a meta de $3000 em caixa! Sua operacao logistica e um sucesso absoluto na regiao."
	game_over.emit(true, msg)
