extends Node2D

var ui_layer: CanvasLayer # NOVO: O vidro protetor da interface

var contract_panel: Panel
var contract_label: Label
var btn_accept_contract: Button
var btn_reject_contract: Button

var report_panel: Panel
var report_label: Label
var btn_next_day: Button

var active_panel: Panel
var contracts_vbox: VBoxContainer 

var bg_rect: ColorRect
var btn_back_map: Button

var current_offer_cargo: String = ""
var current_offer_route_id: String = ""
var current_offer_route_name: String = ""
var current_contract_reward: int = 0
var current_offer_duration: int = 0

func _ready() -> void:
	_setup_ui()
	
	GameManager.money_changed.connect(_on_stats_changed)
	GameManager.maintenance_updated.connect(_on_stats_changed)
	GameManager.contracts_updated.connect(_on_contracts_updated)
	GameManager.day_changed.connect(_on_day_changed)
	
	visibility_changed.connect(_on_visibility_changed)
	
	_generate_new_contract()
	_update_report_text()
	_update_active_contracts_text()

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	bg_rect = ColorRect.new()
	bg_rect.color = Color(0.25, 0.15, 0.1)
	bg_rect.size = Vector2(1152, 648)
	ui_layer.add_child(bg_rect) # Adicionado ao CanvasLayer!

	contract_panel = Panel.new()
	contract_panel.position = Vector2(50, 150)
	contract_panel.size = Vector2(330, 320) 
	ui_layer.add_child(contract_panel) # Adicionado ao CanvasLayer!

	contract_label = Label.new()
	contract_label.position = Vector2(20, 20)
	contract_label.size = Vector2(290, 230) 
	contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract_panel.add_child(contract_label)

	btn_accept_contract = Button.new()
	btn_accept_contract.text = "Aceitar"
	btn_accept_contract.position = Vector2(20, 260) 
	btn_accept_contract.size = Vector2(130, 40)
	btn_accept_contract.pressed.connect(_on_accept_contract)
	contract_panel.add_child(btn_accept_contract)

	btn_reject_contract = Button.new()
	btn_reject_contract.text = "Rejeitar"
	btn_reject_contract.position = Vector2(180, 260) 
	btn_reject_contract.size = Vector2(130, 40)
	btn_reject_contract.pressed.connect(_on_reject_contract)
	contract_panel.add_child(btn_reject_contract)

	report_panel = Panel.new()
	report_panel.position = Vector2(400, 150)
	report_panel.size = Vector2(330, 340)
	ui_layer.add_child(report_panel) # Adicionado ao CanvasLayer!

	report_label = Label.new()
	report_label.position = Vector2(20, 20)
	report_label.size = Vector2(290, 240)
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_panel.add_child(report_label)

	btn_next_day = Button.new()
	btn_next_day.text = "Finalizar Dia"
	btn_next_day.position = Vector2(20, 280)
	btn_next_day.size = Vector2(290, 40)
	btn_next_day.pressed.connect(_on_next_day_pressed)
	report_panel.add_child(btn_next_day)

	active_panel = Panel.new()
	active_panel.position = Vector2(750, 150)
	active_panel.size = Vector2(370, 320) 
	ui_layer.add_child(active_panel) # Adicionado ao CanvasLayer!

	var title_label = Label.new()
	title_label.text = "CONTRATOS ATIVOS (Frota)"
	title_label.position = Vector2(20, 15)
	active_panel.add_child(title_label)

	contracts_vbox = VBoxContainer.new()
	contracts_vbox.position = Vector2(20, 50)
	contracts_vbox.size = Vector2(330, 250)
	active_panel.add_child(contracts_vbox)

	btn_back_map = Button.new()
	btn_back_map.text = "<- Voltar ao Mapa"
	btn_back_map.position = Vector2(20, 20)
	btn_back_map.size = Vector2(180, 40)
	btn_back_map.pressed.connect(_on_back_map_pressed)
	ui_layer.add_child(btn_back_map) # Adicionado ao CanvasLayer!

func _generate_new_contract() -> void:
	var products = ["Madeira", "Carvao", "Passageiros", "Aco", "Gado"]
	var possible_routes = [
		{"id": "Azul-Vermelha", "name": "Azul <-> Vermelha"},
		{"id": "Azul-Verde", "name": "Azul <-> Verde"},
		{"id": "Vermelha-Verde", "name": "Vermelha <-> Verde"}
	]
	
	current_offer_cargo = products[randi() % products.size()]
	
	var r = possible_routes[randi() % possible_routes.size()]
	current_offer_route_id = r["id"]
	current_offer_route_name = r["name"]
	
	current_contract_reward = randi_range(80, 300)
	current_offer_duration = randi_range(3, 7)
	
	contract_panel.visible = true
	_update_offer_ui()

func _update_offer_ui() -> void:
	if not contract_panel.visible: return
		
	var text = "OFERTA DE CONTRATO (NOVO)\n\n"
	text += "Carga Solicitada: " + current_offer_cargo + "\n"
	text += "Rota Exigida: " + current_offer_route_name + "\n"
	text += "Pagamento Oferecido: +$" + str(current_contract_reward) + " / dia\n"
	text += "Prazo do Frete: " + str(current_offer_duration) + " dias\n\n"
	
	if not (current_offer_route_id in GameManager.network_connections):
		text += "[ BLOQUEADO: Exige infraestrutura ligando as cidades acima ]"
		btn_accept_contract.disabled = true
	elif GameManager.active_contracts.size() >= GameManager.MAX_CONTRACTS:
		text += "[ BLOQUEADO: Limite de " + str(GameManager.MAX_CONTRACTS) + " vagoes na frota atingido ]"
		btn_accept_contract.disabled = true
	else:
		text += "Deseja assumir esta operacao?"
		btn_accept_contract.disabled = false
		
	contract_label.text = text

	if GameManager.current_day == 1:
		btn_reject_contract.disabled = true
		btn_reject_contract.text = "Rejeitar (Bloq.)"
	else:
		btn_reject_contract.disabled = false
		btn_reject_contract.text = "Rejeitar"

func _on_accept_contract() -> void:
	var new_contract = {
		"cargo": current_offer_cargo,
		"route_id": current_offer_route_id,
		"route_name": current_offer_route_name,
		"reward": current_contract_reward,
		"days_left": current_offer_duration
	}
	GameManager.active_contracts.append(new_contract)
	GameManager.contracts_updated.emit()
	contract_panel.visible = false

func _on_reject_contract() -> void:
	contract_panel.visible = false

func _update_active_contracts_text() -> void:
	for child in contracts_vbox.get_children():
		contracts_vbox.remove_child(child)
		child.queue_free()
	
	if GameManager.active_contracts.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "\nNenhum frete em andamento.\nConstrua trilhos e aceite ofertas."
		contracts_vbox.add_child(empty_label)
	else:
		var index = 0
		for c in GameManager.active_contracts:
			var hbox = HBoxContainer.new()
			var is_active = c["route_id"] in GameManager.network_connections
			
			var c_label = Label.new()
			var status = "(+$" + str(c["reward"]) + ")" if is_active else "[PARADO $0]"
			
			c_label.text = str(index + 1) + ". " + c["cargo"] + " " + status + "\n" + c["route_name"] + " | Faltam: " + str(c["days_left"]) + "d"
			c_label.custom_minimum_size = Vector2(230, 0)
			
			if not is_active:
				c_label.add_theme_color_override("font_color", Color.INDIAN_RED)
				
			hbox.add_child(c_label)
			
			var penalty = int((c["reward"] * c["days_left"]) * 0.20)
			var btn_cancel = Button.new()
			btn_cancel.text = "❌ (-$" + str(penalty) + ")"
			btn_cancel.pressed.connect(_on_cancel_dynamic.bind(index))
			hbox.add_child(btn_cancel)
			
			contracts_vbox.add_child(hbox)
			index += 1

func _on_cancel_dynamic(idx: int) -> void:
	GameManager.cancel_contract(idx)

func _update_report_text() -> void:
	var current_income = GameManager.get_daily_income()
	var total_expenses = GameManager.daily_maintenance + GameManager.BASE_COST
	var net_profit = current_income - total_expenses
	
	var text = "RELATORIO ADMINISTRATIVO\n\n"
	text += "Dia de Operacao: " + str(GameManager.current_day) + "\n"
	text += "Saldo em Caixa: $" + str(GameManager.money) + "\n\n"
	
	var has_broken_route = false
	for c in GameManager.active_contracts:
		if not (c["route_id"] in GameManager.network_connections):
			has_broken_route = true
			break
			
	if has_broken_route:
		text += "[ALERTA: Trecho vital destruido! Alguns trens estao parados e perdendo lucro.]\n\n"
	
	text += "Receita Diaria: +$" + str(current_income) + "\n"
	text += "Manutencao da Rota: -$" + str(GameManager.daily_maintenance) + "\n"
	text += "Taxas Administrativas: -$" + str(GameManager.BASE_COST) + "\n"
	text += "----------------------------------\n"
	text += "Lucro Liquido Projetado: $" + str(net_profit) + "\n"
	
	if net_profit < 0 and abs(net_profit) > GameManager.money:
		text += "\nAVISO: O saldo nao cobre a operacao. Finalizar o dia causara FALENCIA!"
		
	report_label.text = text

	if GameManager.current_day == 1 and GameManager.active_contracts.size() == 0:
		btn_next_day.disabled = true
		btn_next_day.text = "Aceite uma oferta para iniciar"
	else:
		btn_next_day.disabled = false
		btn_next_day.text = "Finalizar Dia"

func _on_stats_changed(_new_value) -> void:
	_update_report_text()

func _on_contracts_updated() -> void:
	_update_report_text()
	_update_active_contracts_text()
	_update_offer_ui() 

func _on_day_changed(_new_day) -> void:
	_update_report_text()
	_update_active_contracts_text()
	_generate_new_contract() 

# O segredo do CanvasLayer: Sincroniza a visibilidade do vidro com a cena!
func _on_visibility_changed() -> void:
	if ui_layer:
		ui_layer.visible = visible
	if visible:
		_update_offer_ui() 
		_update_report_text()

func _on_next_day_pressed() -> void:
	GameManager.end_day()

func _on_back_map_pressed() -> void:
	var main_node = get_parent()
	if main_node.has_method("go_to_map"):
		main_node.go_to_map()
