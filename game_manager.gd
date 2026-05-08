extends Node

# Sinais para avisar a interface quando algo mudar
signal money_changed(new_amount)
signal day_changed(new_day)
signal maintenance_updated(new_maintenance)
signal income_updated(new_income)
signal game_over(is_victory: bool, message: String) # NOVO sinal de fim de jogo

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

var daily_income: int = 0 :
	set(value):
		daily_income = value
		income_updated.emit(daily_income)

# Funcao para iniciar ou reiniciar o jogo
func reset_game() -> void:
	money = 1000
	current_day = 1
	daily_maintenance = 0
	daily_income = 0

# Funcao para processar a virada do dia
func end_day() -> void:
	# O jogador recebe os lucros e paga as manutencoes
	money += daily_income
	money -= daily_maintenance
	current_day += 1
	
	# Checa se o jogador faliu
	if money < 0:
		trigger_bankruptcy()
	# Checa se o jogador venceu o MVP (Meta: $3000)
	elif money >= 3000:
		trigger_victory()

func trigger_bankruptcy() -> void:
	var msg = "FALENCIA!\n\nSeu saldo ficou negativo. Os investidores retiraram o apoio e sua empresa ferroviaria foi fechada."
	game_over.emit(false, msg)

func trigger_victory() -> void:
	var msg = "VITORIA!\n\nVoce atingiu a meta de $3000 em caixa! Sua operacao logistica e um sucesso absoluto na regiao."
	game_over.emit(true, msg)
