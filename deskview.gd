extends Node2D

var ui_layer: CanvasLayer

var agenda_rect: ColorRect
var clipboard_rect: ColorRect
var active_paper_rect: ColorRect

var companies_vbox: VBoxContainer
var active_contact_label: Label
var btn_call: Button

var selected_company_data: Dictionary 

var report_label: Label
var btn_next_day: Button
var contracts_vbox: VBoxContainer 

var bg_rect: ColorRect
var btn_back_map: Button

var phone_cutscene: CutsceneDialog

func _ready() -> void:
	_setup_ui()
	_setup_cutscene()
	
	GameManager.money_changed.connect(_on_stats_changed)
	GameManager.maintenance_updated.connect(_on_stats_changed)
	GameManager.contracts_updated.connect(_on_contracts_updated)
	GameManager.day_changed.connect(_on_day_changed)
	
	visibility_changed.connect(_on_visibility_changed)
	
	_load_agenda_contacts()
	_update_report_text()
	_update_active_contracts_text()

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	bg_rect = ColorRect.new()
	bg_rect.color = Color(0.25, 0.15, 0.1) 
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(bg_rect)

	# AGENDA TELEFONICA
	agenda_rect = ColorRect.new()
	agenda_rect.color = Color(0.85, 0.8, 0.6) 
	agenda_rect.size = Vector2(330, 400)
	agenda_rect.position = Vector2(50, 100)
	ui_layer.add_child(agenda_rect)
	
	var lombada = ColorRect.new()
	lombada.color = Color(0.1, 0.1, 0.1) 
	lombada.size = Vector2(30, 400)
	agenda_rect.add_child(lombada)
	
	var agenda_title = Label.new()
	agenda_title.text = "CONTATOS REGIONAIS"
	agenda_title.add_theme_color_override("font_color", Color.BLACK)
	agenda_title.position = Vector2(50, 20)
	agenda_rect.add_child(agenda_title)
	
	companies_vbox = VBoxContainer.new()
	companies_vbox.position = Vector2(40, 60)
	companies_vbox.size = Vector2(270, 180)
	agenda_rect.add_child(companies_vbox)
	
	active_contact_label = Label.new()
	active_contact_label.position = Vector2(40, 250)
	active_contact_label.size = Vector2(270, 90)
	active_contact_label.add_theme_color_override("font_color", Color.DARK_RED)
	active_contact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	agenda_rect.add_child(active_contact_label)
	
	btn_call = Button.new()
	btn_call.text = "☎ LIGAR"
	btn_call.position = Vector2(40, 340)
	btn_call.size = Vector2(250, 40)
	btn_call.visible = false
	btn_call.pressed.connect(_on_phone_call_pressed)
	agenda_rect.add_child(btn_call)

	# PRANCHETA DE RELATORIOS
	clipboard_rect = ColorRect.new()
	clipboard_rect.color = Color(0.95, 0.95, 0.9) 
	clipboard_rect.size = Vector2(350, 400)
	clipboard_rect.position = Vector2(410, 100)
	ui_layer.add_child(clipboard_rect)
	
	var clipe_metal = ColorRect.new()
	clipe_metal.color = Color(0.5, 0.5, 0.55) 
	clipe_metal.size = Vector2(150, 20)
	clipe_metal.position = Vector2(100, 0)
	clipboard_rect.add_child(clipe_metal)

	report_label = Label.new()
	report_label.position = Vector2(20, 40)
	report_label.size = Vector2(310, 280)
	report_label.add_theme_color_override("font_color", Color.BLACK)
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clipboard_rect.add_child(report_label)

	btn_next_day = Button.new()
	btn_next_day.text = "Assinar e Finalizar Dia"
	btn_next_day.position = Vector2(20, 340)
	btn_next_day.size = Vector2(310, 40)
	btn_next_day.pressed.connect(_on_next_day_pressed)
	clipboard_rect.add_child(btn_next_day)

	# PAPEL DE CONTRATOS ATIVOS
	active_paper_rect = ColorRect.new()
	active_paper_rect.color = Color(0.85, 0.9, 0.95) 
	active_paper_rect.size = Vector2(330, 400)
	active_paper_rect.position = Vector2(790, 100)
	ui_layer.add_child(active_paper_rect)

	var active_title = Label.new()
	active_title.text = "FROTA EM OPERACAO"
	active_title.add_theme_color_override("font_color", Color.BLACK)
	active_title.position = Vector2(20, 20)
	active_paper_rect.add_child(active_title)

	contracts_vbox = VBoxContainer.new()
	contracts_vbox.position = Vector2(20, 50)
	contracts_vbox.size = Vector2(290, 330)
	active_paper_rect.add_child(contracts_vbox)

	btn_back_map = Button.new()
	btn_back_map.text = "<- Voltar ao Mapa"
	btn_back_map.position = Vector2(20, 20)
	btn_back_map.size = Vector2(180, 40)
	btn_back_map.pressed.connect(_on_back_map_pressed)
	ui_layer.add_child(btn_back_map)

func _setup_cutscene() -> void:
	phone_cutscene = CutsceneDialog.new()
	add_child(phone_cutscene)
	phone_cutscene.contract_accepted.connect(_on_cutscene_accepted)
	phone_cutscene.contract_rejected.connect(_on_cutscene_rejected)
	phone_cutscene.call_closed.connect(_on_cutscene_closed) 

func _load_agenda_contacts() -> void:
	for child in companies_vbox.get_children():
		child.queue_free()
		
	var companies = LevelData.LEVELS[GameManager.current_level]["companies"].duplicate(true)
	companies.append_array(GameManager.daily_generic_companies)
	
	for i in range(companies.size()):
		var c_data = companies[i]
		var c_name = c_data["name"]
		var btn = Button.new()
		
		if GameManager.company_cooldowns.has(c_name) and GameManager.company_cooldowns[c_name] > 0:
			btn.text = c_name + " (" + str(GameManager.company_cooldowns[c_name]) + "d)"
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color.INDIAN_RED)
		else:
			var has_active_contract = false
			for contract in GameManager.active_contracts:
				if contract.has("company_name") and contract["company_name"] == c_name:
					has_active_contract = true
			
			if has_active_contract:
				btn.text = c_name + " (EM CURSO)"
				btn.disabled = true
				btn.add_theme_color_override("font_color", Color.DIM_GRAY)
			else:
				btn.text = c_name
				btn.pressed.connect(_on_company_selected.bind(c_data))
				
		btn.custom_minimum_size = Vector2(250, 30)
		companies_vbox.add_child(btn)

func _on_company_selected(company_data: Dictionary) -> void:
	selected_company_data = company_data
	
	# NOVO VISUAL DA AGENDA: Revela a Demanda e a Rota antes de Ligar!
	active_contact_label.text = "Empresa: " + company_data["name"] + "\n"
	active_contact_label.text += "Telefone: ☎ " + company_data["phone"] + "\n\n"
	active_contact_label.text += "Demanda: " + company_data["cargo"] + " [" + company_data["type"] + "]\n"
	active_contact_label.text += "Rota Exigida: " + company_data["route_name"]
	
	if GameManager.active_contracts.size() >= GameManager.MAX_CONTRACTS:
		btn_call.disabled = true
		btn_call.text = "FROTA CHEIA"
	else:
		btn_call.disabled = false
		btn_call.text = "☎ LIGAR AGORA"
		
	btn_call.visible = true



func _on_phone_call_pressed() -> void:
	if not selected_company_data.is_empty():
		var has_route = selected_company_data["route_id"] in GameManager.network_connections
		var is_daily = "(Diario)" in selected_company_data["name"]
		
		# EXCECAO DE GAME DESIGN: O Corretor Diario aceita negociar no Dia 1 sem exigir trilhos prontos!
		var is_day_one_exception = (GameManager.current_day == 1 and is_daily)
		
		# A VERDADEIRA BLINDAGEM: Verifica se a rota esta concluida (com a nossa excecao)
		if not has_route and not is_day_one_exception:
			phone_cutscene.start_rejection_call(selected_company_data["name"])
			GameManager.company_cooldowns[selected_company_data["name"]] = 1 
			_clear_selection()
		else:
			phone_cutscene.start_call(selected_company_data["name"], selected_company_data["type"], selected_company_data["cargo"], selected_company_data["base_reward"])




func _on_cutscene_accepted(final_reward: int) -> void:
	var new_contract = {
		"company_name": selected_company_data["name"], 
		"cargo": selected_company_data["cargo"], 
		"route_id": selected_company_data["route_id"], 
		"route_name": selected_company_data["route_name"],
		"reward": final_reward,
		"days_left": randi_range(5, 10)
	}
	GameManager.active_contracts.append(new_contract)
	GameManager.contracts_updated.emit()
	_clear_selection()

func _on_cutscene_rejected() -> void:
	GameManager.company_cooldowns[selected_company_data["name"]] = 7
	_load_agenda_contacts() 
	_clear_selection()

func _on_cutscene_closed() -> void:
	_load_agenda_contacts()
	_clear_selection()

func _clear_selection() -> void:
	selected_company_data = {}
	active_contact_label.text = ""
	btn_call.visible = false

func _update_active_contracts_text() -> void:
	for child in contracts_vbox.get_children():
		contracts_vbox.remove_child(child)
		child.queue_free()
	
	if GameManager.active_contracts.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "\nNenhum contrato ativo."
		empty_label.add_theme_color_override("font_color", Color.DIM_GRAY)
		contracts_vbox.add_child(empty_label)
	else:
		var index = 0
		for c in GameManager.active_contracts:
			var hbox = HBoxContainer.new()
			var is_active = c["route_id"] in GameManager.network_connections
			
			var c_label = Label.new()
			var status = "(+$" + str(c["reward"]) + ")" if is_active else "[PARADO $0]"
			
			c_label.text = str(index + 1) + ". " + c["cargo"] + "\n" + c["route_name"] + " " + status + "\nFaltam: " + str(c["days_left"]) + "d"
			c_label.custom_minimum_size = Vector2(230, 0)
			
			if not is_active:
				c_label.add_theme_color_override("font_color", Color.INDIAN_RED)
			else:
				c_label.add_theme_color_override("font_color", Color.DARK_SLATE_GRAY)
				
			hbox.add_child(c_label)
			
			var penalty = int((c["reward"] * c["days_left"]) * 0.20)
			var btn_cancel = Button.new()
			btn_cancel.text = "❌"
			btn_cancel.pressed.connect(_on_cancel_dynamic.bind(index))
			hbox.add_child(btn_cancel)
			
			contracts_vbox.add_child(hbox)
			index += 1

func _on_cancel_dynamic(idx: int) -> void:
	GameManager.cancel_contract(idx)

func _update_report_text() -> void:
	var current_income = GameManager.get_daily_income()
	var total_expenses = GameManager.daily_maintenance + GameManager.BASE_COST + GameManager.daily_gang_toll
	var net_profit = current_income - total_expenses
	
	var text = "RELATORIO ADMINISTRATIVO\n\n"
	text += "Dia de Operacao: " + str(GameManager.current_day) + "\n"
	text += "Saldo em Caixa: $" + str(GameManager.money) + "\n\n"
	
	var has_broken_route = false
	var has_operating_contract = false 
	
	for c in GameManager.active_contracts:
		if not (c["route_id"] in GameManager.network_connections):
			has_broken_route = true
		else:
			has_operating_contract = true
			
	if has_broken_route:
		text += "[!] Trecho vital destruido. Trens parados.\n\n"
	
	text += "Receita Diaria: +$" + str(current_income) + "\n"
	text += "Manutencao da Rota: -$" + str(GameManager.daily_maintenance) + "\n"
	text += "Taxas Administrativas: -$" + str(GameManager.BASE_COST) + "\n"
	
	if GameManager.daily_gang_toll > 0:
		text += "Pagamento de Propinas: -$" + str(GameManager.daily_gang_toll) + "\n"
		
	text += "----------------------------------\n"
	text += "Lucro Liquido Projetado: $" + str(net_profit) + "\n"
	
	if net_profit < 0 and abs(net_profit) > GameManager.money:
		text += "\nAVISO: O saldo nao cobre a operacao. Risco de Falencia!"
		
	report_label.text = text

	if GameManager.current_day == 1 and not has_operating_contract:
		btn_next_day.disabled = true
		btn_next_day.text = "[ Exige infraestrutura e contrato ]"
	else:
		btn_next_day.disabled = false
		btn_next_day.text = "Assinar e Finalizar Dia"

func _on_stats_changed(_new_value) -> void:
	_update_report_text()

func _on_contracts_updated() -> void:
	_update_report_text()
	_update_active_contracts_text()
	_load_agenda_contacts() 

func _on_day_changed(_new_day) -> void:
	_update_report_text()
	_update_active_contracts_text()
	_load_agenda_contacts() 

func _on_visibility_changed() -> void:
	if ui_layer:
		ui_layer.visible = visible
	if visible:
		_load_agenda_contacts()
		_update_report_text()
		
		if GameManager.pendent_angry_call:
			GameManager.pendent_angry_call = false
			phone_cutscene.start_angry_call()

func _on_next_day_pressed() -> void:
	GameManager.end_day()

func _on_back_map_pressed() -> void:
	var main_node = get_parent()
	if main_node.has_method("go_to_map"):
		main_node.go_to_map()
