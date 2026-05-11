extends Node2D

var ui_layer: CanvasLayer

var agenda_rect: ColorRect
var clipboard_rect: ColorRect
var active_paper_rect: ColorRect
var diretrizes_rect: ColorRect
var diretrizes_label: Label
var diretrizes_bar: ProgressBar

var companies_vbox: VBoxContainer

# ================================
# NOVO: A PASTA DIEGETICA CENTRAL
# ================================
var folder_rect: ColorRect
var folder_title: Label
var folder_route: Label

# Documento Padrão
var doc_standard: ColorRect
var std_label: Label
var btn_call_std: Button

# Documento Urgente
var doc_urgent: ColorRect
var urg_label: Label
var btn_call_urg: Button

var btn_close_folder: Button

var report_label: Label
var btn_next_day: Button
var contracts_vbox: VBoxContainer 

var bg_rect: ColorRect
var btn_back_map: Button

var phone_cutscene: CutsceneDialog

var selected_company_data: Dictionary 
var is_negotiating_urgency: bool = false # Sabe o que voce clicou

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
	_update_diretrizes() 

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	bg_rect = ColorRect.new()
	bg_rect.color = Color(0.25, 0.15, 0.1) 
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(bg_rect)

	btn_back_map = Button.new()
	btn_back_map.text = "<- Voltar ao Mapa"
	btn_back_map.position = Vector2(20, 20)
	btn_back_map.size = Vector2(180, 40)
	btn_back_map.pressed.connect(_on_back_map_pressed)
	ui_layer.add_child(btn_back_map)

	diretrizes_rect = ColorRect.new()
	diretrizes_rect.color = Color(0.6, 0.15, 0.15) 
	diretrizes_rect.size = Vector2(870, 50)
	diretrizes_rect.position = Vector2(250, 15)
	ui_layer.add_child(diretrizes_rect)
	
	var selo_clip = ColorRect.new()
	selo_clip.color = Color(0.1, 0.1, 0.1)
	selo_clip.size = Vector2(20, 50)
	selo_clip.position = Vector2(0, 0)
	diretrizes_rect.add_child(selo_clip)
	
	diretrizes_label = Label.new()
	diretrizes_label.position = Vector2(40, 5)
	diretrizes_label.add_theme_font_size_override("font_size", 14)
	diretrizes_label.add_theme_color_override("font_color", Color.WHITE)
	diretrizes_rect.add_child(diretrizes_label)
	
	var bg_bar = StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.2, 0.1, 0.1)
	var fg_bar = StyleBoxFlat.new()
	fg_bar.bg_color = Color(0.2, 0.6, 0.2) 
	
	diretrizes_bar = ProgressBar.new()
	diretrizes_bar.position = Vector2(40, 28)
	diretrizes_bar.size = Vector2(800, 15)
	diretrizes_bar.show_percentage = false
	diretrizes_bar.add_theme_stylebox_override("background", bg_bar)
	diretrizes_bar.add_theme_stylebox_override("fill", fg_bar)
	diretrizes_rect.add_child(diretrizes_bar)

	# AGENDA TELEFONICA
	agenda_rect = ColorRect.new()
	agenda_rect.color = Color(0.85, 0.8, 0.6) 
	agenda_rect.size = Vector2(300, 400)
	agenda_rect.position = Vector2(40, 100)
	ui_layer.add_child(agenda_rect)
	
	var lombada = ColorRect.new()
	lombada.color = Color(0.1, 0.1, 0.1) 
	lombada.size = Vector2(30, 400)
	agenda_rect.add_child(lombada)
	
	var agenda_title = Label.new()
	agenda_title.text = "ARQUIVO DE CLIENTES"
	agenda_title.add_theme_color_override("font_color", Color.BLACK)
	agenda_title.position = Vector2(50, 20)
	agenda_rect.add_child(agenda_title)
	
	companies_vbox = VBoxContainer.new()
	companies_vbox.position = Vector2(40, 60)
	companies_vbox.size = Vector2(240, 320)
	agenda_rect.add_child(companies_vbox)

	# PRANCHETA DE RELATORIOS (Atrás da pasta)
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

	# =======================================
	# A PASTA DIEGETICA (Oculta por padrao)
	# =======================================
	folder_rect = ColorRect.new()
	folder_rect.color = Color(0.8, 0.65, 0.4) # Cor da Pasta Parda
	folder_rect.size = Vector2(440, 480)
	folder_rect.position = Vector2(360, 65) # Cobre a prancheta
	folder_rect.visible = false
	ui_layer.add_child(folder_rect)
	
	# Aba da Pasta (visual)
	var folder_tab = ColorRect.new()
	folder_tab.color = Color(0.8, 0.65, 0.4)
	folder_tab.size = Vector2(150, 30)
	folder_tab.position = Vector2(20, -20)
	folder_rect.add_child(folder_tab)
	
	folder_title = Label.new()
	folder_title.position = Vector2(20, 10)
	folder_title.add_theme_font_size_override("font_size", 20)
	folder_title.add_theme_color_override("font_color", Color.BLACK)
	folder_rect.add_child(folder_title)
	
	folder_route = Label.new()
	folder_route.position = Vector2(20, 40)
	folder_route.add_theme_color_override("font_color", Color.DARK_RED)
	folder_rect.add_child(folder_route)
	
	btn_close_folder = Button.new()
	btn_close_folder.text = "X"
	btn_close_folder.position = Vector2(400, 10)
	btn_close_folder.size = Vector2(30, 30)
	btn_close_folder.pressed.connect(_on_close_folder_pressed)
	folder_rect.add_child(btn_close_folder)

	# 1. Documento Padrao (Esquerda)
	doc_standard = ColorRect.new()
	doc_standard.color = Color(0.95, 0.95, 0.95)
	doc_standard.size = Vector2(190, 380)
	doc_standard.position = Vector2(20, 80)
	folder_rect.add_child(doc_standard)
	
	std_label = Label.new()
	std_label.position = Vector2(10, 10)
	std_label.size = Vector2(170, 300)
	std_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	std_label.add_theme_color_override("font_color", Color.BLACK)
	doc_standard.add_child(std_label)
	
	btn_call_std = Button.new()
	btn_call_std.text = "☎ LIGAR PADRAO"
	btn_call_std.position = Vector2(10, 330)
	btn_call_std.size = Vector2(170, 40)
	btn_call_std.pressed.connect(_on_call_standard_pressed)
	doc_standard.add_child(btn_call_std)

	# 2. Documento Urgente (Direita) - Vermelhado
	doc_urgent = ColorRect.new()
	doc_urgent.color = Color(0.95, 0.85, 0.85)
	doc_urgent.size = Vector2(190, 380)
	doc_urgent.position = Vector2(230, 80)
	folder_rect.add_child(doc_urgent)
	
	urg_label = Label.new()
	urg_label.position = Vector2(10, 10)
	urg_label.size = Vector2(170, 300)
	urg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	urg_label.add_theme_color_override("font_color", Color.DARK_RED)
	doc_urgent.add_child(urg_label)
	
	btn_call_urg = Button.new()
	btn_call_urg.text = "☎ LIGAR URGENCIA"
	btn_call_urg.position = Vector2(10, 330)
	btn_call_urg.size = Vector2(170, 40)
	btn_call_urg.pressed.connect(_on_call_urgent_pressed)
	doc_urgent.add_child(btn_call_urg)

	# FROTA ATIVA (Direita)
	active_paper_rect = ColorRect.new()
	active_paper_rect.color = Color(0.85, 0.9, 0.95) 
	active_paper_rect.size = Vector2(330, 400)
	active_paper_rect.position = Vector2(790, 100)
	ui_layer.add_child(active_paper_rect)

	var active_title = Label.new()
	active_title.text = "FROTA: 3 LOCOMOTIVAS A CARVAO" 
	active_title.add_theme_color_override("font_color", Color.BLACK)
	active_title.position = Vector2(20, 20)
	active_paper_rect.add_child(active_title)

	contracts_vbox = VBoxContainer.new()
	contracts_vbox.position = Vector2(20, 50)
	contracts_vbox.size = Vector2(290, 330)
	active_paper_rect.add_child(contracts_vbox)

func _setup_cutscene() -> void:
	phone_cutscene = CutsceneDialog.new()
	add_child(phone_cutscene)
	phone_cutscene.contract_accepted.connect(_on_cutscene_accepted)
	phone_cutscene.contract_rejected.connect(_on_cutscene_rejected)
	phone_cutscene.call_closed.connect(_on_cutscene_closed) 

func _update_diretrizes() -> void:
	var lvl_data = LevelData.LEVELS[GameManager.current_level]
	var meta = lvl_data["goal"]
	var atual = GameManager.money
	
	diretrizes_label.text = "📌 DIRETRIZES DA REGIAO [" + lvl_data["name"] + "]  |  META: $" + str(meta) + "  |  CAIXA: $" + str(atual)
	
	var fg_bar = diretrizes_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if atual < 0:
		fg_bar.bg_color = Color(0.8, 0.2, 0.2) 
		diretrizes_bar.min_value = 0
		diretrizes_bar.max_value = 1
		diretrizes_bar.value = 1
	else:
		fg_bar.bg_color = Color(0.2, 0.6, 0.2) 
		diretrizes_bar.min_value = 0
		diretrizes_bar.max_value = meta
		diretrizes_bar.value = atual

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
				# Se tem urgencia, mostra uma exclamacao no nome!
				if GameManager.daily_urgencies.has(c_name):
					btn.text = c_name + " [!]"
					btn.add_theme_color_override("font_color", Color.DARK_RED)
				else:
					btn.text = c_name
					
				btn.pressed.connect(_on_company_selected.bind(c_data))
				
		btn.custom_minimum_size = Vector2(200, 30)
		companies_vbox.add_child(btn)

func _on_company_selected(company_data: Dictionary) -> void:
	selected_company_data = company_data
	
	folder_title.text = "CLIENTE: " + company_data["name"]
	folder_route.text = "Exige Rota: " + company_data["route_name"] + " | Arquétipo: [" + company_data["type"] + "]"
	
	# Prepara Documento Padrao
	std_label.text = "CONTRATO PADRAO\n\n"
	std_label.text += "Carga: " + company_data["cargo"] + "\n\n"
	std_label.text += "Duracao Media: 5 a 10 dias\n"
	std_label.text += "Pagamento Diario: ~$" + str(company_data["base_reward"]) + "\n"
	
	# Prepara Documento Urgente (Se houver)
	if GameManager.daily_urgencies.has(company_data["name"]):
		doc_urgent.visible = true
		urg_label.text = "[!] URGENDA PARA HOJE\n\n"
		urg_label.text += "Precisamos escoar " + company_data["cargo"] + " imediatamente!\n\n"
		urg_label.text += "PAGAMENTO A VISTA:\n$" + str(GameManager.daily_urgencies[company_data["name"]]) + "\n\n"
		urg_label.text += "Ocupa a locomotiva por apenas 1 dia."
	else:
		doc_urgent.visible = false

	folder_rect.visible = true

func _on_close_folder_pressed() -> void:
	folder_rect.visible = false
	selected_company_data = {}

func _on_call_standard_pressed() -> void:
	is_negotiating_urgency = false
	_process_call()

func _on_call_urgent_pressed() -> void:
	is_negotiating_urgency = true
	_process_call()

# Lógica unificada de validação e disparo da cutscene
func _process_call() -> void:
	if GameManager.active_contracts.size() >= GameManager.MAX_CONTRACTS:
		phone_cutscene.start_rejection_call(selected_company_data["name"], "A sua frota esta lotada! Nao faca a gente perder tempo.")
		folder_rect.visible = false
		return

	var route_id = selected_company_data["route_id"]
	var c_type = selected_company_data["type"]
	
	var has_route = route_id in GameManager.network_connections
	var is_daily = "(Diario)" in selected_company_data["name"]
	var is_day_one_exception = (GameManager.current_day == 1 and is_daily)
	
	var route_valid = false
	var reject_reason = ""
	
	if has_route:
		var stats = GameManager.network_stats.get(route_id, {})
		
		if c_type == "Expresso":
			var limit = selected_company_data.get("max_dist", 999)
			if stats.get("dist", 999) > limit:
				reject_reason = "A sua rota (" + str(stats["dist"]) + " km) excede o nosso limite de " + str(limit) + " km!"
			else:
				route_valid = true
		elif c_type == "VIP":
			if stats.get("gangs", 0) > 0:
				reject_reason = "A sua rota cruza territorio de gangues! Nossos clientes exigem seguranca total."
			elif GameManager.active_contracts.size() > 0:
				reject_reason = "Exigimos EXCLUSIVIDADE! Cancele os seus outros contratos reles antes de nos ligar."
			else:
				route_valid = true
		elif c_type == "Ecologico":
			if stats.get("forests", 0) > 0:
				reject_reason = "A sua rota causou desmatamento! Refaca os trilhos desviando das florestas."
			else:
				route_valid = true
		else:
			route_valid = true 

	if (not has_route and not is_day_one_exception) or (has_route and not route_valid):
		phone_cutscene.start_rejection_call(selected_company_data["name"], reject_reason)
		GameManager.company_cooldowns[selected_company_data["name"]] = 1 
		folder_rect.visible = false
	else:
		var base_rew = GameManager.daily_urgencies[selected_company_data["name"]] if is_negotiating_urgency else selected_company_data["base_reward"]
		phone_cutscene.start_call(selected_company_data["name"], selected_company_data["type"], selected_company_data["cargo"], base_rew, is_negotiating_urgency)

func _on_cutscene_accepted(final_reward: int) -> void:
	if is_negotiating_urgency:
		# LÓGICA DE URGÊNCIA: Paga na hora, mas bloqueia o trem por 1 dia
		GameManager.money += final_reward
		var new_contract = {
			"company_name": selected_company_data["name"], 
			"type": selected_company_data["type"], 
			"cargo": "[URGENTE] " + selected_company_data["cargo"], 
			"route_id": selected_company_data["route_id"], 
			"route_name": selected_company_data["route_name"],
			"reward": 0, # Ja recebeu a vista!
			"days_left": 1,
			"is_urgent": true
		}
		GameManager.active_contracts.append(new_contract)
		GameManager.daily_urgencies.erase(selected_company_data["name"]) # Consumiu a urgencia
	else:
		# LÓGICA PADRÃO
		var new_contract = {
			"company_name": selected_company_data["name"], 
			"type": selected_company_data["type"], 
			"cargo": selected_company_data["cargo"], 
			"route_id": selected_company_data["route_id"], 
			"route_name": selected_company_data["route_name"],
			"reward": final_reward,
			"days_left": randi_range(5, 10),
			"is_urgent": false
		}
		if selected_company_data.has("max_dist"):
			new_contract["max_dist"] = selected_company_data["max_dist"]
			
		GameManager.active_contracts.append(new_contract)
		
	GameManager.contracts_updated.emit()
	folder_rect.visible = false
	selected_company_data = {}

func _on_cutscene_rejected() -> void:
	GameManager.company_cooldowns[selected_company_data["name"]] = 7
	_load_agenda_contacts() 
	folder_rect.visible = false

func _on_cutscene_closed() -> void:
	_load_agenda_contacts()
	folder_rect.visible = false

func _update_active_contracts_text() -> void:
	for child in contracts_vbox.get_children():
		contracts_vbox.remove_child(child)
		child.queue_free()
	
	if GameManager.active_contracts.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "\nLocomotivas paradas no patio."
		empty_label.add_theme_color_override("font_color", Color.DIM_GRAY)
		contracts_vbox.add_child(empty_label)
	else:
		var index = 0
		for c in GameManager.active_contracts:
			var hbox = HBoxContainer.new()
			
			var is_active = GameManager.is_contract_operating(c)
			var status = ""
			var c_label = Label.new()
			
			if is_active:
				if c.get("is_urgent", false):
					status = "[PAGO A VISTA]"
				else:
					status = "(+$" + str(c["reward"]) + ")"
				c_label.add_theme_color_override("font_color", Color.DARK_SLATE_GRAY)
			else:
				c_label.add_theme_color_override("font_color", Color.INDIAN_RED)
				if not (c["route_id"] in GameManager.network_connections):
					status = "[PARADO: SEM ROTA]"
				else:
					var type = c.get("type", "")
					var stats = GameManager.network_stats.get(c["route_id"], {})
					if type == "Expresso" and stats.get("dist", 999) > c.get("max_dist", 999):
						status = "[PARADO: ROTA LONGA]"
					elif type == "VIP" and GameManager.active_contracts.size() > 1:
						status = "[PARADO: FIM EXCLUSIVIDADE]"
					elif type == "VIP" and stats.get("gangs", 0) > 0:
						status = "[PARADO: GANGUES NA LINHA]"
					elif type == "Ecologico" and stats.get("forests", 0) > 0:
						status = "[PARADO: CRIME AMBIENTAL]"
					else:
						status = "[PARADO: ILEGAL]"
			
			c_label.text = "Trem " + str(index + 1) + ": " + c["cargo"] + "\n" + c["route_name"] + " " + status + "\nFaltam: " + str(c["days_left"]) + "d"
			c_label.custom_minimum_size = Vector2(230, 0)
				
			hbox.add_child(c_label)
			
			# Contratos urgentes nao tem multa de cancelamento, mas libertam o trem
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
	var has_invalid_route = false
	var has_operating_contract = false 
	
	for c in GameManager.active_contracts:
		if not (c["route_id"] in GameManager.network_connections):
			has_broken_route = true
		elif not GameManager.is_contract_operating(c):
			has_invalid_route = true
		else:
			has_operating_contract = true
			
	if has_broken_route:
		text += "[!] Trecho vital destruido. Trens parados.\n\n"
	if has_invalid_route:
		text += "[!] Trem retido na estacao. Padroes de qualidade nao atingidos.\n\n"
	
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
	_update_diretrizes() 

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
		_update_diretrizes()
		folder_rect.visible = false # Esconde a pasta ao abrir a mesa
		
		if GameManager.pendent_angry_call:
			GameManager.pendent_angry_call = false
			phone_cutscene.start_angry_call()

func _on_next_day_pressed() -> void:
	GameManager.end_day()

func _on_back_map_pressed() -> void:
	var main_node = get_parent()
	if main_node.has_method("go_to_map"):
		main_node.go_to_map()
