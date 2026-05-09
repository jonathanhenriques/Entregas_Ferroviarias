extends Node2D

# Referencias visuais - Ofertas
var contract_panel: Panel
var contract_label: Label
var btn_accept_contract: Button
var btn_reject_contract: Button

# Referencias visuais - Relatorio
var report_panel: Panel
var report_label: Label
var btn_next_day: Button

# Referencias visuais - Contratos Ativos (NOVO)
var active_panel: Panel
var active_label: Label
var btn_cancel_first: Button

# Botoes e Fundo
var bg_rect: ColorRect
var btn_back_map: Button

# Variaveis de controle do contrato do dia
var current_offer_cargo: String = ""
var current_contract_reward: int = 0
var current_offer_duration: int = 0

func _ready() -> void:
	_setup_ui()
	
	# Conecta os sinais do GameManager para atualizar a UI
	GameManager.money_changed.connect(_on_stats_changed)
	GameManager.maintenance_updated.connect(_on_stats_changed)
	GameManager.contracts_updated.connect(_on_contracts_updated)
	GameManager.day_changed.connect(_on_day_changed)
	
	# Gera a interface pela primeira vez
	_generate_new_contract()
	_update_report_text()
	_update_active_contracts_text()

func _setup_ui() -> void:
	# Fundo da mesa
	bg_rect = ColorRect.new()
	bg_rect.color = Color(0.25, 0.15, 0.1)
	bg_rect.size = Vector2(1152, 648)
	add_child(bg_rect)

	# 1. Painel de Oferta (Esquerda)
	contract_panel = Panel.new()
	contract_panel.position = Vector2(50, 150)
	contract_panel.size = Vector2(320, 260)
	add_child(contract_panel)

	contract_label = Label.new()
	contract_label.position = Vector2(20, 20)
	contract_label.size = Vector2(280, 170)
	contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract_panel.add_child(contract_label)

	btn_accept_contract = Button.new()
	btn_accept_contract.text = "Aceitar"
	btn_accept_contract.position = Vector2(20, 200)
	btn_accept_contract.size = Vector2(130, 40)
	btn_accept_contract.pressed.connect(_on_accept_contract)
	contract_panel.add_child(btn_accept_contract)

	btn_reject_contract = Button.new()
	btn_reject_contract.text = "Rejeitar"
	btn_reject_contract.position = Vector2(170, 200)
	btn_reject_contract.size = Vector2(130, 40)
	btn_reject_contract.pressed.connect(_on_reject_contract)
	contract_panel.add_child(btn_reject_contract)

	# 2. Painel do Relatorio Administrativo (Centro)
	report_panel = Panel.new()
	report_panel.position = Vector2(400, 150)
	report_panel.size = Vector2(320, 320)
	add_child(report_panel)

	report_label = Label.new()
	report_label.position = Vector2(20, 20)
	report_label.size = Vector2(280, 220)
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_panel.add_child(report_label)

	btn_next_day = Button.new()
	btn_next_day.text = "Finalizar Dia"
	btn_next_day.position = Vector2(20, 260)
	btn_next_day.size = Vector2(280, 40)
	btn_next_day.pressed.connect(_on_next_day_pressed)
	report_panel.add_child(btn_next_day)

	# 3. Painel de Contratos Ativos (Direita) - NOVO
	active_panel = Panel.new()
	active_panel.position = Vector2(750, 150)
	active_panel.size = Vector2(350, 320)
	add_child(active_panel)

	active_label = Label.new()
	active_label.position = Vector2(20, 20)
	active_label.size = Vector2(310, 220)
	active_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_panel.add_child(active_label)

	btn_cancel_first = Button.new()
	btn_cancel_first.text = "Rescindir 1o Contrato (Multa $200)"
	btn_cancel_first.position = Vector2(20, 260)
	btn_cancel_first.size = Vector2(310, 40)
	btn_cancel_first.pressed.connect(_on_cancel_first_pressed)
	active_panel.add_child(btn_cancel_first)

	# Botao para Voltar ao Mapa
	btn_back_map = Button.new()
	btn_back_map.text = "<- Voltar ao Mapa"
	btn_back_map.position = Vector2(20, 20)
	btn_back_map.size = Vector2(180, 40)
	btn_back_map.pressed.connect(_on_back_map_pressed)
	add_child(btn_back_map)

# Cria uma oferta de frete com prazos aleatorios
func _generate_new_contract() -> void:
	var products = ["Madeira", "Carvao", "Passageiros", "Aco", "Gado"]
	current_offer_cargo = products[randi() % products.size()]
	current_contract_reward = randi_range(80, 300)
	current_offer_duration = randi_range(3, 7) # NOVO: Validade entre 3 e 7 dias
	
	var text = "OFERTA DE CONTRATO (NOVO)\n\n"
	text += "Carga Solicitada: " + current_offer_cargo + "\n"
	text += "Pagamento Oferecido: +$" + str(current_contract_reward) + " / dia\n"
	text += "Prazo do Frete: " + str(current_offer_duration) + " dias\n\n"
	text += "Deseja assumir esta operacao?"
	
	contract_label.text = text
	contract_panel.visible = true

# Cria um dicionario e adiciona a matriz de contratos ativos
func _on_accept_contract() -> void:
	var new_contract = {
		"cargo": current_offer_cargo,
		"reward": current_contract_reward,
		"days_left": current_offer_duration
	}
	GameManager.active_contracts.append(new_contract)
	GameManager.contracts_updated.emit() # Avisa a interface para redesenhar a lista
	contract_panel.visible = false

func _on_reject_contract() -> void:
	contract_panel.visible = false

# Rescinde o contrato mais antigo da lista (indice 0) pagando 200 de multa
func _on_cancel_first_pressed() -> void:
	if GameManager.active_contracts.size() > 0:
		GameManager.cancel_contract(0, 200)

# Monta o texto visualizando o que esta na lista global
func _update_active_contracts_text() -> void:
	var text = "CONTRATOS ATIVOS\n\n"
	
	if GameManager.active_contracts.size() == 0:
		text += "Nenhum contrato ativo no momento.\nCuidado com a manutencao ociosa!"
		btn_cancel_first.disabled = true
	else:
		btn_cancel_first.disabled = false
		var index = 1
		for c in GameManager.active_contracts:
			text += str(index) + ". " + c["cargo"] + " (+$" + str(c["reward"]) + "/dia) - Faltam " + str(c["days_left"]) + " dias\n"
			index += 1
			
	active_label.text = text

func _update_report_text() -> void:
	var current_income = GameManager.get_daily_income()
	var net_profit = current_income - GameManager.daily_maintenance
	
	var text = "RELATORIO ADMINISTRATIVO\n\n"
	text += "Dia de Operacao: " + str(GameManager.current_day) + "\n"
	text += "Saldo em Caixa: $" + str(GameManager.money) + "\n\n"
	text += "Receita Diaria: +$" + str(current_income) + "\n"
	text += "Manutencao Diaria: -$" + str(GameManager.daily_maintenance) + "\n"
	text += "----------------------------------\n"
	text += "Lucro Liquido Projetado: $" + str(net_profit) + "\n"
	
	if net_profit < 0 and abs(net_profit) > GameManager.money:
		text += "\nAVISO: O saldo nao cobre a operacao. Finalizar o dia causara FALENCIA!"
		
	report_label.text = text

# Diferentes reacoes baseadas em qual sinal foi disparado
func _on_stats_changed(_new_value) -> void:
	_update_report_text()

func _on_contracts_updated() -> void:
	_update_report_text()
	_update_active_contracts_text()

func _on_day_changed(_new_day) -> void:
	_update_report_text()
	_update_active_contracts_text()
	_generate_new_contract()

func _on_next_day_pressed() -> void:
	GameManager.end_day()

func _on_back_map_pressed() -> void:
	var main_node = get_parent()
	if main_node.has_method("go_to_map"):
		main_node.go_to_map()
