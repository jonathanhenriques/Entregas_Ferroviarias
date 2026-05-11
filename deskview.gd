extends Node2D

var ui_layer: CanvasLayer

var agenda_rect: ColorRect
var clipboard_rect: ColorRect
var active_paper_rect: ColorRect
var diretrizes_rect: ColorRect
var diretrizes_label: Label
var diretrizes_bar: ProgressBar

var companies_vbox: VBoxContainer

var folder_rect: ColorRect
var folder_title: Label
var folder_route: Label
var doc_standard: ColorRect
var std_label: Label
var btn_call_std: Button
var doc_urgent: ColorRect
var urg_label: Label
var btn_call_urg: Button
var btn_close_folder: Button

var report_label: Label
var btn_next_day: Button
var contracts_vbox: VBoxContainer 

var bg_rect: ColorRect
var btn_back_map: Button
var btn_organize: Button 

var phone_cutscene: CutsceneDialog

var selected_company_data: Dictionary 
var is_negotiating_urgency: bool = false 

var dragged_panel: Control = null
var drag_offset: Vector2 = Vector2.ZERO
var original_transforms: Dictionary = {}

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
	btn_back_map.position = Vector2(40, 40)
	btn_back_map.size = Vector2(180, 40)
	btn_back_map.pressed.connect(_on_back_map_pressed)
	ui_layer.add_child(btn_back_map)
	
	btn_organize = Button.new()
	btn_organize.text = "Arrumar a Mesa"
	btn_organize.position = Vector2(40, 100)
	btn_organize.size = Vector2(180, 40)
	btn_organize.pressed.connect(_on_organize_pressed)
	ui_layer.add_child(btn_organize)

	diretrizes_rect = ColorRect.new()
	diretrizes_rect.color = Color(0.6, 0.15, 0.15) 
	diretrizes_rect.size = Vector2(1000, 60)
	diretrizes_rect.position = Vector2(460, 40)
	ui_layer.add_child(diretrizes_rect)
	
	var selo_clip = ColorRect.new()
	selo_clip.color = Color(0.1, 0.1, 0.1)
	selo_clip.size = Vector2(25, 60)
	selo_clip.position = Vector2(0, 0)
	diretrizes_rect.add_child(selo_clip)
	
	diretrizes_label = Label.new()
	diretrizes_label.position = Vector2(40, 10)
	diretrizes_label.add_theme_font_size_override("font_size", 16)
	diretrizes_label.add_theme_color_override("font_color", Color.WHITE)
	diretrizes_rect.add_child(diretrizes_label)
	
	var bg_bar = StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.2, 0.1, 0.1)
	var fg_bar = StyleBoxFlat.new()
	fg_bar.bg_color = Color(0.2, 0.6, 0.2) 
	
	diretrizes_bar = ProgressBar.new()
	diretrizes_bar.position = Vector2(40, 35)
	diretrizes_bar.size = Vector2(920, 15)
	diretrizes_bar.show_percentage = false
	diretrizes_bar.add_theme_stylebox_override("background", bg_bar)
	diretrizes_bar.add_theme_stylebox_override("fill", fg_bar)
	diretrizes_rect.add_child(diretrizes_bar)

	agenda_rect = ColorRect.new()
	agenda_rect.color = Color(0.85, 0.8, 0.6) 
	agenda_rect.size = Vector2(300, 400)
	agenda_rect.position = Vector2(200, 350)
	ui_layer.add_child(agenda_rect)
	_make_draggable(agenda_rect)
	
	var lombada = ColorRect.new()
	lombada.color = Color(0.1, 0.1, 0.1) 
	lombada.size = Vector2(30, 400)
	lombada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	agenda_rect.add_child(lombada)
	
	var agenda_title = Label.new()
	agenda_title.text = "ARQUIVO DE CLIENTES"
	agenda_title.add_theme_color_override("font_color", Color.BLACK)
	agenda_title.position = Vector2(50, 20)
	agenda_rect.add_child(agenda_title)
	
	companies_vbox = VBoxContainer.new()
	companies_vbox.position = Vector2(40, 60)
	companies_vbox.size = Vector2(240, 320)
	companies_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	agenda_rect.add_child(companies_vbox)

	clipboard_rect = ColorRect.new()
	clipboard_rect.color = Color(0.95, 0.95, 0.9) 
	clipboard_rect.size = Vector2(350, 400)
	clipboard_rect.position = Vector2(780, 350)
	ui_layer.add_child(clipboard_rect)
	_make_draggable(clipboard_rect)
	
	var clipe_metal = ColorRect.new()
	clipe_metal.color = Color(0.5, 0.5, 0.55) 
	clipe_metal.size = Vector2(150, 20)
	clipe_metal.position = Vector2(100, 0)
	clipe_metal.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	active_paper_rect = ColorRect.new()
	active_paper_rect.color = Color(0.85, 0.9, 0.95) 
	active_paper_rect.size = Vector2(330, 400)
	active_paper_rect.position = Vector2(1380, 350)
	ui_layer.add_child(active_paper_rect)
	_make_draggable(active_paper_rect)

	var active_title = Label.new()
	active_title.text = "FROTA: 3 LOCOMOTIVAS A CARVAO" 
	active_title.add_theme_color_override("font_color", Color.BLACK)
	active_title.position = Vector2(20, 20)
	active_paper_rect.add_child(active_title)

	contracts_vbox = VBoxContainer.new()
	contracts_vbox.position = Vector2(20, 50)
	contracts_vbox.size = Vector2(290, 330)
	contracts_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_paper_rect.add_child(contracts_vbox)

	folder_rect = ColorRect.new()
	folder_rect.color = Color(0.8, 0.65, 0.4) 
	folder_rect.size = Vector2(440, 480)
	folder_rect.position = Vector2(740, 310) 
	folder_rect.visible = false
	ui_layer.add_child(folder_rect)
	_make_draggable(folder_rect)
	
	var folder_tab = ColorRect.new()
	folder_tab.color = Color(0.8, 0.65, 0.4)
	folder_tab.size = Vector2(150, 30)
	folder_tab.position = Vector2(20, -20)
	folder_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	doc_standard = ColorRect.new()
	doc_standard.color = Color(0.95, 0.95, 0.95)
	doc_standard.size = Vector2(190, 380)
	doc_standard.position = Vector2(20, 80)
	doc_standard.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	doc_urgent = ColorRect.new()
	doc_urgent.color = Color(0.95, 0.85, 0.85)
	doc_urgent.size = Vector2(190, 380)
	doc_urgent.position = Vector2(230, 80)
	doc_urgent.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

func _make_draggable(panel: Control) -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_gui_input.bind(panel))
	original_transforms[panel] = panel.position

func _on_panel_gui_input(event: InputEvent, panel: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			dragged_panel = panel
			panel.rotation_degrees = 0 
			drag_offset = panel.get_global_mouse_position() - panel.global_position
			panel.get_parent().move_child(panel, -1) 
		else:
			if dragged_panel == panel:
				dragged_panel = null
				panel.rotation_degrees = randf_range(-3.0, 3.0) 
				_clamp_to_screen(panel)
				
	if event is InputEventMouseMotion and dragged_panel == panel:
		panel.global_position = panel.get_global_mouse_position() - drag_offset
		_clamp_to_screen(panel)

func _clamp_to_screen(panel: Control) -> void:
	var s = get_viewport_rect().size
	var p = panel.global_position
	var sz = panel.size
	p.x = clamp(p.x, 0, s.x - sz.x)
	p.y = clamp(p.y, 0, s.y - sz.y)
	panel.global_position = p

func _on_organize_pressed() -> void:
	var tween = create_tween().set_parallel(true)
	for panel in original_transforms.keys():
		tween.tween_property(panel, "position", original_transforms[panel], 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "rotation_degrees", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _setup_cutscene() -> void:
	phone_cutscene = CutsceneDialog.new()
	add_child(phone_cutscene)
	phone_cutscene.contract_accepted.connect(_on_cutscene_accepted)
	phone_cutscene.contract_rejected.connect(_on_cutscene_rejected)
	phone_cutscene.call_closed.connect(_on_cutscene_closed) 

func _update_diretrizes() -> void:
	var lvl = LevelData.LEVELS[GameManager.current_level]
	var m = lvl["goal"]
	var a = GameManager.money
	
	diretrizes_label.text = "📌 DIRETRIZES DA REGIAO [" + lvl["name"] + "]  |  META: $" + str(m) + "  |  CAIXA: $" + str(a)
	
	var fg = diretrizes_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if a < 0: 
		fg.bg_color = Color(0.8, 0.2, 0.2)
		diretrizes_bar.max_value = 1
		diretrizes_bar.value = 1
	else: 
		fg.bg_color = Color(0.2, 0.6, 0.2)
		diretrizes_bar.max_value = m
		diretrizes_bar.value = a

func _load_agenda_contacts() -> void:
	for child in companies_vbox.get_children(): 
		child.queue_free()
		
	var companies = LevelData.LEVELS[GameManager.current_level]["companies"].duplicate(true)
	companies.append_array(GameManager.daily_generic_companies)
	
	for i in range(companies.size()):
		var c_data = companies[i]
		var c_name = c_data["name"]
		var btn = Button.new()
		
		var is_daily = "(Diario)" in c_name
		if GameManager.company_cooldowns.has(c_name) and GameManager.company_cooldowns[c_name] > 0 and not (is_daily and GameManager.current_day == 1):
			btn.text = c_name + " (" + str(GameManager.company_cooldowns[c_name]) + "d)"
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color.INDIAN_RED)
		else:
			var has_active = false
			for contract in GameManager.active_contracts:
				if contract.has("company_name") and contract["company_name"] == c_name: 
					has_active = true
					
			if has_active: 
				btn.text = c_name + " (EM CURSO)"
				btn.disabled = true
				btn.add_theme_color_override("font_color", Color.DIM_GRAY)
			else:
				if GameManager.daily_urgencies.has(c_name): 
					btn.text = c_name + " [!]"
					btn.add_theme_color_override("font_color", Color.DARK_RED)
				else: 
					btn.text = c_name
				btn.pressed.connect(_on_company_selected.bind(c_data))
				
		btn.custom_minimum_size = Vector2(200, 30)
		companies_vbox.add_child(btn)

func _on_company_selected(data: Dictionary) -> void:
	selected_company_data = data
	folder_title.text = "CLIENTE: " + data["name"]
	folder_route.text = "Exige Rota: " + data["route_name"] + " | Arquétipo: [" + data["type"] + "]"
	std_label.text = "CONTRATO PADRAO\n\nCarga: " + data["cargo"] + "\n\nDuracao: 5-10 dias\nPagamento: ~$" + str(data["base_reward"])
	
	if GameManager.daily_urgencies.has(data["name"]):
		doc_urgent.visible = true
		urg_label.text = "[!] URGENDA HOJE\n\nPAGAMENTO A VISTA:\n$" + str(GameManager.daily_urgencies[data["name"]]) + "\n\nOcupa trem por 1 dia."
	else: 
		doc_urgent.visible = false
		
	folder_rect.visible = true
	folder_rect.get_parent().move_child(folder_rect, -1)
	folder_rect.rotation_degrees = 0
	_clamp_to_screen(folder_rect)

func _on_close_folder_pressed() -> void: 
	folder_rect.visible = false
	selected_company_data = {}

func _on_call_standard_pressed() -> void: 
	is_negotiating_urgency = false
	_process_call()

func _on_call_urgent_pressed() -> void: 
	is_negotiating_urgency = true
	_process_call()

func _process_call() -> void:
	if GameManager.active_contracts.size() >= GameManager.MAX_CONTRACTS:
		phone_cutscene.start_rejection_call(selected_company_data["name"], "A frota esta lotada!")
		folder_rect.visible = false
		return
		
	var rid = selected_company_data["route_id"]
	var ctype = selected_company_data["type"]
	var has_route = rid in GameManager.network_connections
	var is_daily = "(Diario)" in selected_company_data["name"]
	var is_day_one = (GameManager.current_day == 1 and is_daily)
	var route_valid = false
	var reason = ""
	
	if has_route:
		var stats = GameManager.network_stats.get(rid, {})
		
		if ctype == "Expresso" and stats.get("dist", 999) > selected_company_data.get("max_dist", 999): 
			reason = "Rota longa!"
		else:
			if ctype == "VIP" and (stats.get("gangs", 0) > 0 or GameManager.active_contracts.size() > 0): 
				reason = "VIP exige seguranca/exclusividade!"
			else:
				if ctype == "Ecologico" and stats.get("forests", 0) > 0: 
					reason = "Crime ambiental!"
				else: 
					route_valid = true 
					
	if (not has_route and not is_day_one) or (has_route and not route_valid):
		phone_cutscene.start_rejection_call(selected_company_data["name"], reason)
		if not is_day_one: 
			GameManager.company_cooldowns[selected_company_data["name"]] = 1 
		folder_rect.visible = false
	else:
		var rew = GameManager.daily_urgencies[selected_company_data["name"]] if is_negotiating_urgency else selected_company_data["base_reward"]
		phone_cutscene.start_call(selected_company_data["name"], selected_company_data["type"], selected_company_data["cargo"], rew, is_negotiating_urgency)

func _on_cutscene_accepted(final_reward: int) -> void:
	if is_negotiating_urgency:
		GameManager.money += final_reward
		GameManager.active_contracts.append({"company_name": selected_company_data["name"], "cargo": "[URG] " + selected_company_data["cargo"], "route_id": selected_company_data["route_id"], "route_name": selected_company_data["route_name"], "reward": 0, "days_left": 1, "is_urgent": true})
		GameManager.daily_urgencies.erase(selected_company_data["name"]) 
	else:
		var new_c = {"company_name": selected_company_data["name"], "type": selected_company_data["type"], "cargo": selected_company_data["cargo"], "route_id": selected_company_data["route_id"], "route_name": selected_company_data["route_name"], "reward": final_reward, "days_left": randi_range(5, 10), "is_urgent": false}
		if selected_company_data.has("max_dist"): 
			new_c["max_dist"] = selected_company_data["max_dist"]
		GameManager.active_contracts.append(new_c)
		
	GameManager.contracts_updated.emit()
	folder_rect.visible = false
	selected_company_data = {}

func _on_cutscene_rejected() -> void:
	var is_daily = "(Diario)" in selected_company_data["name"]
	if not (is_daily and GameManager.current_day == 1):
		GameManager.company_cooldowns[selected_company_data["name"]] = 7
	_load_agenda_contacts()
	folder_rect.visible = false

func _on_cutscene_closed() -> void: 
	_load_agenda_contacts()
	folder_rect.visible = false
	
func _on_cancel_dynamic(idx: int) -> void: 
	GameManager.cancel_contract(idx)

func _update_active_contracts_text() -> void:
	for child in contracts_vbox.get_children(): 
		child.queue_free()
		
	if GameManager.active_contracts.size() == 0:
		var l = Label.new()
		l.text = "\nPatio vazio."
		l.add_theme_color_override("font_color", Color.DIM_GRAY)
		contracts_vbox.add_child(l)
	else:
		var i = 0
		for c in GameManager.active_contracts:
			var hbox = HBoxContainer.new()
			var is_act = GameManager.is_contract_operating(c)
			var st = ""
			var cl = Label.new()
			
			if is_act: 
				if c.get("is_urgent", false):
					st = "[PAGO]"
				else:
					st = "(+$" + str(c["reward"]) + ")"
				cl.add_theme_color_override("font_color", Color.DARK_SLATE_GRAY)
			else:
				cl.add_theme_color_override("font_color", Color.INDIAN_RED)
				if not (c["route_id"] in GameManager.network_connections): 
					st = "[SEM ROTA]"
				else: 
					var tp = c.get("type", "")
					var stats = GameManager.network_stats.get(c["route_id"], {})
					if tp == "Expresso" and stats.get("dist", 999) > c.get("max_dist", 999):
						st = "[PARADO: ROTA LONGA]"
					else:
						if tp == "VIP" and GameManager.active_contracts.size() > 1:
							st = "[PARADO: FIM EXCLUSIVIDADE]"
						else:
							if tp == "VIP" and stats.get("gangs", 0) > 0:
								st = "[PARADO: GANGUES NA LINHA]"
							else:
								if tp == "Ecologico" and stats.get("forests", 0) > 0:
									st = "[PARADO: CRIME AMBIENTAL]"
								else:
									st = "[PARADO: ILEGAL]"
									
			cl.text = "T" + str(i + 1) + ": " + c["cargo"] + "\n" + c["route_name"] + " " + st + "\n" + str(c["days_left"]) + "d"
			cl.custom_minimum_size = Vector2(230, 0)
			hbox.add_child(cl)
			
			var b = Button.new()
			b.text = "X"
			b.pressed.connect(_on_cancel_dynamic.bind(i))
			hbox.add_child(b)
			contracts_vbox.add_child(hbox)
			i += 1

func _update_report_text() -> void:
	var inc = GameManager.get_daily_income()
	var exp = GameManager.daily_maintenance + GameManager.BASE_COST + GameManager.daily_gang_toll
	var net = inc - exp
	
	var t = "RELATORIO ADMINISTRATIVO\n\nDia: " + str(GameManager.current_day) + "\nCaixa: $" + str(GameManager.money) + "\n\nReceita: +$" + str(inc) + "\nManutencao: -$" + str(GameManager.daily_maintenance) + "\nTaxas: -$" + str(GameManager.BASE_COST)
	
	if GameManager.daily_gang_toll > 0: 
		t += "\nPropinas: -$" + str(GameManager.daily_gang_toll)
		
	t += "\n----------------\nLucro: $" + str(net)
	report_label.text = t
	
	var has_op = false
	for c in GameManager.active_contracts:
		if GameManager.is_contract_operating(c): 
			has_op = true
			
	if GameManager.current_day == 1 and not has_op: 
		btn_next_day.disabled = true
		btn_next_day.text = "[ Exige contrato e trilho ]"
	else: 
		btn_next_day.disabled = false
		btn_next_day.text = "Assinar e Finalizar Dia"

func _on_stats_changed(_v) -> void: 
	_update_report_text()
	_update_diretrizes()

func _on_contracts_updated() -> void: 
	_update_report_text()
	_update_active_contracts_text()
	_load_agenda_contacts() 

func _on_day_changed(_v) -> void: 
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
		folder_rect.visible = false 
		
		_on_organize_pressed()
		
		if GameManager.pendent_angry_call: 
			GameManager.pendent_angry_call = false
			phone_cutscene.start_angry_call()
		else:
			# NOVO: A bronca inicial do diretor se for a primeira vez na mesa
			if not GameManager.intro_played:
				GameManager.intro_played = true
				phone_cutscene.start_boss_intro()

func _on_next_day_pressed() -> void: 
	GameManager.end_day()

func _on_back_map_pressed() -> void: 
	get_parent().go_to_map()
