extends Node2D

# Referencias visuais - Relatorio
var bg_rect: ColorRect
var report_panel: Panel
var report_label: Label
var btn_next_day: Button
var btn_back_map: Button

# Referencias visuais - Contratos
var contract_panel: Panel
var contract_label: Label
var btn_accept_contract: Button
var btn_reject_contract: Button

# Variaveis de controle do contrato do dia
var current_contract_reward: int = 0

func _ready() -> void:
	_setup_ui()
	
	# Conecta os sinais do GameManager para atualizar a UI
	GameManager.money_changed.connect(_on_stats_changed)
	GameManager.maintenance_updated.connect(_on_stats_changed)
	GameManager.income_updated.connect(_on_stats_changed)
	
	# Quando o dia mudar, alem de atualizar o texto, geramos um novo contrato
	GameManager.day_changed.connect(_on_day_changed)
	
	# Gera o primeiro contrato logo ao abrir o jogo
	_generate_new_contract()
	_update_report_text()

func _setup_ui() -> void:
	# 1. Fundo da mesa (cor de madeira escurecida)
	bg_rect = ColorRect.new()
	bg_rect.color = Color(0.25, 0.15, 0.1)
	bg_rect.size = Vector2(1152, 648)
	add_child(bg_rect)

	# 2. Papel do Relatorio Administrativo (Painel Central-Direita)
	report_panel = Panel.new()
	report_panel.position = Vector2(500, 150) # Desloquei um pouco para a direita
	report_panel.size = Vector2(350, 320)
	add_child(report_panel)

	report_label = Label.new()
	report_label.position = Vector2(20, 20)
	report_label.size = Vector2(310, 220)
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_panel.add_child(report_label)

	btn_next_day = Button.new()
	btn_next_day.text = "Finalizar Dia"
	btn_next_day.position = Vector2(20, 260)
	btn_next_day.size = Vector2(310, 40)
	btn_next_day.pressed.connect(_on_next_day_pressed)
	report_panel.add_child(btn_next_day)

	# 3. Painel de Oferta de Contratos (Painel Esquerda)
	contract_panel = Panel.new()
	contract_panel.position = Vector2(100, 150)
	contract_panel.size = Vector2(350, 240)
	add_child(contract_panel)

	contract_label = Label.new()
	contract_label.position = Vector2(20, 20)
	contract_label.size = Vector2(310, 150)
	contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract_panel.add_child(contract_label)

	btn_accept_contract = Button.new()
	btn_accept_contract.text = "Aceitar"
	btn_accept_contract.position = Vector2(20, 180)
	btn_accept_contract.size = Vector2(150, 40)
	btn_accept_contract.pressed.connect(_on_accept_contract)
	contract_panel.add_child(btn_accept_contract)

	btn_reject_contract = Button.new()
	btn_reject_contract.text = "Rejeitar"
	btn_reject_contract.position = Vector2(180, 180)
	btn_reject_contract.size = Vector2(150, 40)
	btn_reject_contract.pressed.connect(_on_reject_contract)
	contract_panel.add_child(btn_reject_contract)

	# 4. Botao para Voltar ao Mapa
	btn_back_map = Button.new()
	btn_back_map.text = "<- Voltar ao Mapa"
	btn_back_map.position = Vector2(20, 20)
	btn_back_map.size = Vector2(180, 40)
	btn_back_map.pressed.connect(_on_back_map_pressed)
	add_child(btn_back_map)

# Cria uma oferta de frete aleatoria
func _generate_new_contract() -> void:
	var products = ["Madeira", "Carvao", "Passageiros", "Aco", "Gado"]
	var random_index = randi() % products.size()
	var chosen_product = products[random_index]
	
	# O pagamento varia entre $80 e $300 por dia
	current_contract_reward = randi_range(80, 300)
	
	var text = "OFERTA DE CONTRATO (NOVO)\n\n"
	text += "Carga Solicitada: " + chosen_product + "\n"
	text += "Pagamento Oferecido: +$" + str(current_contract_reward) + " / dia\n\n"
	text += "Deseja assumir o risco desta operacao?"
	
	contract_label.text = text
	contract_panel.visible = true

# Ao aceitar, soma o valor na receita diaria e esconde o papel
func _on_accept_contract() -> void:
	GameManager.daily_income += current_contract_reward
	contract_panel.visible = false
	print("Contrato Aceito! Nova Receita Diaria: $", GameManager.daily_income)

# Ao rejeitar, simplesmente descarta o papel e fica sem lucro novo
func _on_reject_contract() -> void:
	contract_panel.visible = false
	print("Contrato Rejeitado.")

# Monta o texto do relatorio administrativo
func _update_report_text() -> void:
	var net_profit = GameManager.daily_income - GameManager.daily_maintenance
	
	var text = "RELATORIO ADMINISTRATIVO\n\n"
	text += "Dia de Operacao: " + str(GameManager.current_day) + "\n"
	text += "Saldo em Caixa: $" + str(GameManager.money) + "\n\n"
	text += "Receita Diaria (Contratos): +$" + str(GameManager.daily_income) + "\n"
	text += "Custo Diario (Manutencao): -$" + str(GameManager.daily_maintenance) + "\n"
	text += "----------------------------------\n"
	text += "Lucro Liquido Projetado: $" + str(net_profit) + "\n"
	
	if net_profit < 0 and abs(net_profit) > GameManager.money:
		text += "\nAVISO: O saldo nao cobre a operacao. Finalizar o dia causara FALENCIA!"
		
	report_label.text = text

# Atualiza textos genericos
func _on_stats_changed(_new_value) -> void:
	_update_report_text()

# Atualiza textos e gera novo contrato na virada do dia
func _on_day_changed(_new_day) -> void:
	_update_report_text()
	_generate_new_contract()

func _on_next_day_pressed() -> void:
	GameManager.end_day()

func _on_back_map_pressed() -> void:
	var main_node = get_parent()
	if main_node.has_method("go_to_map"):
		main_node.go_to_map()
