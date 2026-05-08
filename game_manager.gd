extends Node

# Sinais para avisar a interface quando algo mudar
signal money_changed(new_amount)
signal day_changed(new_day)
signal maintenance_updated(new_maintenance)

# Variáveis Globais de Economia e Tempo
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

# Função para iniciar ou reiniciar o jogo
func reset_game() -> void:
	money = 1000
	current_day = 1
	daily_maintenance = 0

# Função para processar a virada do dia
func end_day() -> void:
	# Aqui no futuro cobraremos a manutenção e pagaremos os contratos
	money -= daily_maintenance
	current_day += 1
	
	if money < 0:
		trigger_bankruptcy()

func trigger_bankruptcy() -> void:
	print("FALÊNCIA! O jogador ficou sem dinheiro.")
	# Futuramente chamaremos a tela de Game Over aqui
