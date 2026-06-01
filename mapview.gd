extends Node2D

var ui_layer: CanvasLayer

const TILE_SIZE: int = 32
# --- INÍCIO DA ALTERAÇÃO (GRID TELA CHEIA) ---
var grid_width: int = 60  
var grid_height: int = 34 
# --- FIM DA ALTERAÇÃO ---


var status_panel: ColorRect
var status_vbox: VBoxContainer

enum Biome { PLAIN, FOREST, MOUNTAIN, RIVER }

const BIOME_DATA = {
	Biome.PLAIN: {"build": 20, "maint": 2, "color": Color(0.65, 0.75, 0.55)},
	Biome.FOREST: {"build": 35, "maint": 5, "color": Color(0.25, 0.45, 0.25)}, 
	Biome.MOUNTAIN: {"build": 400, "maint": 10, "color": Color(0.55, 0.45, 0.35)}, 
	Biome.RIVER: {"build": 600, "maint": 15, "color": Color(0.3, 0.6, 0.8)} 
}

const GANG_TOLL_RATE: int = 100 

var lbl_timer: Label

var biome_map: Dictionary = {}
var gang_map: Dictionary = {} 

var city_a: Vector2i = Vector2i(-1, -1) 
var city_b: Vector2i = Vector2i(-1, -1) 
var city_c: Vector2i = Vector2i(-1, -1) 

var confirmed_routes: Array = [] 
var is_edit_mode: bool = false
var is_dragging: bool = false
var tentative_path: Array[Vector2i] = []
var draft_paths: Array = []
var deleted_paths: Array = []
var repair_tiles: Array = [] 

var btn_toggle_dispatch: Button

var panel_overlay: ColorRect

# === UI DO MAPA E MESA ===
var btn_edit_mode: Button
var btn_go_desk: Button
var edit_panel: ColorRect
var edit_info: Label
var btn_confirm: Button
var btn_cancel: Button
var net_cost: int = 0
var net_maint: int = 0
var current_env_tax: int = 0
var current_eng_tax: int = 0
var current_sec_tax: int = 0
var current_total_cost: int = 0
var active_trains: Dictionary = {}
var btn_maint: Button
var maint_panel: ColorRect
var sld_infra: HSlider
var sld_tracks: HSlider
var sld_env: HSlider
var sld_sec: HSlider
var sld_crew: HSlider
var sld_lobby: HSlider
var lbl_infra_val: Label
var lbl_tracks_val: Label
var lbl_env_val: Label
var lbl_sec_val: Label
var lbl_crew_val: Label
var lbl_lobby_val: Label
var btn_close_maint: Button

# --- NOVO: PAINEL DE DESPACHO LOGÍSTICO ---
var dispatch_panel: ColorRect
var dispatch_vbox: VBoxContainer
var btn_dispatch: Button
var is_dispatching: bool = false

func _ready() -> void:
	_validate_saved_routes()
	_generate_biomes()
	_setup_ui()
	_setup_status_panel()
	
	confirmed_routes = GameManager.saved_routes.duplicate()
	
	_check_disasters()
	_update_network_status()
	
	visibility_changed.connect(_on_visibility_changed)
	_update_status_panel()




func _validate_saved_routes() -> void:
	var valid_routes = []
	for route in GameManager.saved_routes:
		var route_valid = true
		for cell in route:
			if cell.x >= grid_width or cell.y >= grid_height:
				route_valid = false
				break
		if route_valid:
			valid_routes.append(route)
	GameManager.saved_routes = valid_routes

func _on_visibility_changed() -> void:
	if ui_layer:
		ui_layer.visible = visible
	if visible:
		confirmed_routes = GameManager.saved_routes.duplicate()
		_check_disasters()
		_update_network_status()
		_update_status_panel()
		
		# --- NOVO: CONTROLE DE VISIBILIDADE DO DESPACHO ---
		if GameManager.day_phase == 2:
			btn_toggle_dispatch.visible = true
			_populate_dispatch_panel()
		if GameManager.day_phase != 2:
			btn_toggle_dispatch.visible = false
			dispatch_panel.visible = false
		
		if not GameManager.pending_blueprint.is_empty():
			btn_edit_mode.text = "[ PLANTA PENDENTE ]"
			btn_edit_mode.disabled = true
			btn_edit_mode.add_theme_color_override("font_color", Color.ORANGE)
		else:
			btn_edit_mode.text = "[ MODO OBRAS ]"
			btn_edit_mode.disabled = false
			btn_edit_mode.add_theme_color_override("font_color", Color.YELLOW)



func _check_disasters() -> void:
	if not GameManager.pending_disaster_check: return
	GameManager.pending_disaster_check = false
	var needs_save = false
	var valid_built = {}
	for r in confirmed_routes:
		for c in r: valid_built[c] = true
	if city_a != Vector2i(-1, -1): valid_built[city_a] = true
	if city_b != Vector2i(-1, -1): valid_built[city_b] = true
	if city_c != Vector2i(-1, -1): valid_built[city_c] = true
		
	var immune_tiles = {}
	if GameManager.routes_under_construction.get("Azul-Vermelha", 0) > 0:
		var p = _bfs_get_path_array(city_a, city_b, valid_built)
		for c in p: immune_tiles[c] = true
	if GameManager.routes_under_construction.get("Azul-Verde", 0) > 0:
		var p = _bfs_get_path_array(city_a, city_c, valid_built)
		for c in p: immune_tiles[c] = true
	if GameManager.routes_under_construction.get("Vermelha-Verde", 0) > 0:
		var p = _bfs_get_path_array(city_b, city_c, valid_built)
		for c in p: immune_tiles[c] = true
	
	for route in confirmed_routes:
		for cell in route:
			if immune_tiles.has(cell) or GameManager.broken_tiles.has(cell): continue
			var tile_health = GameManager.tile_data.get(cell, {}).get("h", 1.0)
			if tile_health <= 0.25 and randf() < 0.15:
				GameManager.broken_tiles.append(cell)
				needs_save = true
	if needs_save: GameManager.save_game()

func _generate_biomes() -> void:
	biome_map.clear()
	gang_map.clear()
	for y in range(grid_height):
		for x in range(grid_width):
			biome_map[Vector2i(x, y)] = Biome.PLAIN
			
	var level_info = LevelData.LEVELS[GameManager.current_level]
	var layout = level_info["map_layout"]
	var layout_h = layout.size()
	var layout_w = layout[0].length() if layout_h > 0 else 0
	var offset_x = (grid_width - layout_w) / 2
	var offset_y = (grid_height - layout_h) / 2
	
	for y in range(layout_h):
		var row = layout[y]
		for x in range(layout_w):
			var char = row[x]
			var cell = Vector2i(x + offset_x, y + offset_y)
			if cell.x >= grid_width or cell.y >= grid_height or cell.x < 0 or cell.y < 0: continue

			if char == "F": 
				biome_map[cell] = Biome.FOREST
			else:
				if char == "M": 
					biome_map[cell] = Biome.MOUNTAIN
				else:
					if char == "R": 
						biome_map[cell] = Biome.RIVER
					else:
						if char == "A": 
							city_a = cell
						else:
							if char == "B": 
								city_b = cell
							else:
								if char == "C": 
									city_c = cell

	if level_info.has("gang_layout"):
		var g_layout = level_info["gang_layout"]
		for y in range(g_layout.size()):
			var row = g_layout[y]
			for x in range(row.length()):
				var cell = Vector2i(x + offset_x, y + offset_y)
				if cell.x >= grid_width or cell.y >= grid_height or cell.x < 0 or cell.y < 0: continue
				if row[x] == "G": gang_map[cell] = true

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# --- INÍCIO DA ALTERAÇÃO (BARRA INFERIOR E CCO) ---
	panel_overlay = ColorRect.new()
	panel_overlay.color = Color(0, 0, 0, 0.8)
	panel_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_overlay.visible = false
	ui_layer.add_child(panel_overlay)

	# Nova Barra Inferior
	var bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0.05, 0.05, 0.08, 0.95)
	bottom_bar.size = Vector2(1920, 80)
	bottom_bar.position = Vector2(0, 1000)
	ui_layer.add_child(bottom_bar)
	
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_theme_constant_override("separation", 40)
	bottom_bar.add_child(bottom_hbox)

	btn_go_desk = Button.new()
	btn_go_desk.text = "[ VOLTAR À MESA ]"
	btn_go_desk.custom_minimum_size = Vector2(240, 50)
	btn_go_desk.pressed.connect(_on_go_desk_pressed)
	bottom_hbox.add_child(btn_go_desk)

	btn_edit_mode = Button.new()
	btn_edit_mode.text = "[ MODO OBRAS ]"
	btn_edit_mode.custom_minimum_size = Vector2(240, 50)
	btn_edit_mode.add_theme_color_override("font_color", Color.YELLOW)
	btn_edit_mode.pressed.connect(_on_edit_mode_pressed)
	bottom_hbox.add_child(btn_edit_mode)

	btn_maint = Button.new()
	btn_maint.text = "[ LIVRO DE MANUTENÇÃO ]"
	btn_maint.custom_minimum_size = Vector2(240, 50)
	btn_maint.pressed.connect(_on_btn_maint_pressed)
	bottom_hbox.add_child(btn_maint)

	btn_toggle_dispatch = Button.new()
	btn_toggle_dispatch.text = "[ CENTRO DE CONTROLE (CCO) ]"
	btn_toggle_dispatch.custom_minimum_size = Vector2(300, 50)
	btn_toggle_dispatch.add_theme_color_override("font_color", Color.LIME_GREEN)
	btn_toggle_dispatch.pressed.connect(func(): dispatch_panel.visible = not dispatch_panel.visible)
	bottom_hbox.add_child(btn_toggle_dispatch)
	
	# Painéis flutuantes (Centralizados matematicamente)
	edit_panel = ColorRect.new()
	edit_panel.color = Color(0.15, 0.15, 0.15, 0.95)
	edit_panel.size = Vector2(340, 560)
	edit_panel.position = Vector2(1920/2 - 170, 1080/2 - 280)
	edit_panel.visible = false
	ui_layer.add_child(edit_panel)
	
	var border = ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color.GOLDENROD
	border.border_width = 3
	edit_panel.add_child(border)
	
	edit_info = Label.new()
	edit_info.position = Vector2(20, 20)
	edit_info.size = Vector2(300, 460)
	edit_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	edit_info.add_theme_font_size_override("font_size", 15)
	edit_panel.add_child(edit_info)
	
	btn_confirm = Button.new()
	btn_confirm.text = "GERAR PLANTA"
	btn_confirm.position = Vector2(20, 490)
	btn_confirm.size = Vector2(145, 50)
	btn_confirm.add_theme_color_override("font_color", Color.SKY_BLUE)
	btn_confirm.pressed.connect(_on_confirm_edit_pressed)
	edit_panel.add_child(btn_confirm)
	
	btn_cancel = Button.new()
	btn_cancel.text = "DESCARTAR TUDO"
	btn_cancel.position = Vector2(175, 490)
	btn_cancel.size = Vector2(145, 50)
	btn_cancel.add_theme_color_override("font_color", Color.INDIAN_RED)
	btn_cancel.pressed.connect(_on_cancel_edit_pressed)
	edit_panel.add_child(btn_cancel)

	maint_panel = ColorRect.new()
	maint_panel.color = Color(0.15, 0.15, 0.15, 0.95)
	maint_panel.size = Vector2(400, 460)
	maint_panel.position = Vector2(1920/2 - 200, 1080/2 - 230)
	maint_panel.visible = false
	ui_layer.add_child(maint_panel)
	
	var border_maint = ReferenceRect.new()
	border_maint.set_anchors_preset(Control.PRESET_FULL_RECT)
	border_maint.border_color = Color.ORANGE
	border_maint.border_width = 3
	maint_panel.add_child(border_maint)
	
	var lbl_mtitle = Label.new()
	lbl_mtitle.text = "LIVRO DE MANUTENÇÃO DA MALHA"
	lbl_mtitle.position = Vector2(20, 20)
	lbl_mtitle.add_theme_color_override("font_color", Color.ORANGE)
	maint_panel.add_child(lbl_mtitle)
	
	var lbl_i = Label.new()
	lbl_i.text = "Infra Pesada (Pontes/Túneis)"
	lbl_i.position = Vector2(20, 60)
	maint_panel.add_child(lbl_i)
	
	sld_infra = HSlider.new()
	sld_infra.position = Vector2(20, 85)
	sld_infra.size = Vector2(180, 20)
	sld_infra.max_value = 100
	sld_infra.value = 100
	sld_infra.value_changed.connect(_on_sld_infra_changed)
	maint_panel.add_child(sld_infra)
	
	lbl_infra_val = Label.new()
	lbl_infra_val.position = Vector2(210, 85)
	maint_panel.add_child(lbl_infra_val)
	
	var lbl_t = Label.new()
	lbl_t.text = "Trilhos e Dormentes"
	lbl_t.position = Vector2(20, 110)
	maint_panel.add_child(lbl_t)
	
	sld_tracks = HSlider.new()
	sld_tracks.position = Vector2(20, 135)
	sld_tracks.size = Vector2(180, 20)
	sld_tracks.max_value = 100
	sld_tracks.value = 100
	sld_tracks.value_changed.connect(_on_sld_tracks_changed)
	maint_panel.add_child(sld_tracks)
	
	lbl_tracks_val = Label.new()
	lbl_tracks_val.position = Vector2(210, 135)
	maint_panel.add_child(lbl_tracks_val)
	
	var lbl_e = Label.new()
	lbl_e.text = "Conservação Ambiental"
	lbl_e.position = Vector2(20, 160)
	maint_panel.add_child(lbl_e)
	
	sld_env = HSlider.new()
	sld_env.position = Vector2(20, 185)
	sld_env.size = Vector2(180, 20)
	sld_env.max_value = 100
	sld_env.value = 100
	sld_env.value_changed.connect(_on_sld_env_changed)
	maint_panel.add_child(sld_env)
	
	lbl_env_val = Label.new()
	lbl_env_val.position = Vector2(210, 185)
	maint_panel.add_child(lbl_env_val)
	
	var lbl_s = Label.new()
	lbl_s.text = "Segurança Privada (Antigangues)"
	lbl_s.position = Vector2(20, 220)
	maint_panel.add_child(lbl_s)
	
	sld_sec = HSlider.new()
	sld_sec.position = Vector2(20, 245)
	sld_sec.size = Vector2(180, 20)
	sld_sec.max_value = 100
	sld_sec.value = 100
	sld_sec.value_changed.connect(_on_sld_sec_changed)
	maint_panel.add_child(sld_sec)
	
	lbl_sec_val = Label.new()
	lbl_sec_val.position = Vector2(210, 245)
	maint_panel.add_child(lbl_sec_val)
	
	var lbl_c = Label.new()
	lbl_c.text = "Folha de Pagamento (Equipe)"
	lbl_c.position = Vector2(20, 270)
	maint_panel.add_child(lbl_c)
	
	sld_crew = HSlider.new()
	sld_crew.position = Vector2(20, 295)
	sld_crew.size = Vector2(180, 20)
	sld_crew.max_value = 100
	sld_crew.value = 100
	sld_crew.value_changed.connect(_on_sld_crew_changed)
	maint_panel.add_child(sld_crew)
	
	lbl_crew_val = Label.new()
	lbl_crew_val.position = Vector2(210, 295)
	maint_panel.add_child(lbl_crew_val)
	
	var lbl_l = Label.new()
	lbl_l.text = "Lobby Governamental (Fiscais)"
	lbl_l.position = Vector2(20, 320)
	maint_panel.add_child(lbl_l)
	
	sld_lobby = HSlider.new()
	sld_lobby.position = Vector2(20, 345)
	sld_lobby.size = Vector2(180, 20)
	sld_lobby.max_value = 100
	sld_lobby.value = 100
	sld_lobby.value_changed.connect(_on_sld_lobby_changed)
	maint_panel.add_child(sld_lobby)
	
	lbl_lobby_val = Label.new()
	lbl_lobby_val.position = Vector2(210, 345)
	maint_panel.add_child(lbl_lobby_val)
	
	btn_close_maint = Button.new()
	btn_close_maint.text = "FECHAR LIVRO"
	btn_close_maint.position = Vector2(20, 390)
	btn_close_maint.size = Vector2(360, 40)
	btn_close_maint.add_theme_color_override("font_color", Color.ORANGE)
	btn_close_maint.pressed.connect(_on_btn_close_maint_pressed)
	maint_panel.add_child(btn_close_maint)

	# UI DO CCO - Posicionado à direita como uma gaveta de controle
	dispatch_panel = ColorRect.new()
	dispatch_panel.color = Color(0.1, 0.15, 0.2, 0.95)
	dispatch_panel.size = Vector2(500, 500)
	dispatch_panel.position = Vector2(1920 - 520, 1000 - 520) 
	ui_layer.add_child(dispatch_panel)
	
	var dp_border = ReferenceRect.new()
	dp_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	dp_border.border_color = Color(0.3, 0.6, 0.9)
	dp_border.border_width = 3
	dispatch_panel.add_child(dp_border)
	
	var dp_title = Label.new()
	dp_title.text = "CENTRO DE CONTROLE OPERACIONAL (CCO)"
	dp_title.position = Vector2(0, 15)
	dp_title.size = Vector2(500, 30)
	dp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dispatch_panel.add_child(dp_title)
	
	dispatch_vbox = VBoxContainer.new()
	dispatch_vbox.position = Vector2(20, 60)
	dispatch_vbox.size = Vector2(460, 360)
	dispatch_panel.add_child(dispatch_vbox)
	
	btn_dispatch = Button.new()
	btn_dispatch.text = "[ INICIAR OPERAÇÃO DIÁRIA ]"
	btn_dispatch.size = Vector2(460, 50)
	btn_dispatch.position = Vector2(20, 430)
	btn_dispatch.add_theme_color_override("font_color", Color.LIME_GREEN)
	btn_dispatch.pressed.connect(_on_btn_dispatch_pressed)
	dispatch_panel.add_child(btn_dispatch)
	
	var btn_close_dp = Button.new()
	btn_close_dp.text = "X"
	btn_close_dp.position = Vector2(460, 10) 
	btn_close_dp.size = Vector2(30, 30)
	btn_close_dp.add_theme_color_override("font_color", Color.INDIAN_RED)
	btn_close_dp.pressed.connect(func(): dispatch_panel.visible = false)
	dispatch_panel.add_child(btn_close_dp)

	dispatch_panel.visible = false
	# --- FIM DA ALTERAÇÃO ---
# === LÓGICA DO MAPA (Sem alterações) ===

func _sync_maint_ui() -> void:
	sld_infra.value = GameManager.maint_pct_infra * 100
	sld_tracks.value = GameManager.maint_pct_tracks * 100
	sld_env.value = GameManager.maint_pct_env * 100
	sld_sec.value = GameManager.maint_pct_sec * 100
	sld_crew.value = GameManager.maint_pct_crew * 100
	sld_lobby.value = GameManager.maint_pct_lobby * 100

	var i_id = GameManager.ideal_maint_infra
	var t_id = GameManager.ideal_maint_tracks
	var e_id = GameManager.ideal_maint_env
	var s_id = GameManager.ideal_maint_sec
	var c_id = GameManager.ideal_maint_crew
	var l_id = GameManager.ideal_maint_lobby

	lbl_infra_val.text = "$" + str(int(i_id * GameManager.maint_pct_infra)) + " / $" + str(i_id) + " (" + str(int(GameManager.maint_pct_infra * 100)) + "%)"
	lbl_tracks_val.text = "$" + str(int(t_id * GameManager.maint_pct_tracks)) + " / $" + str(t_id) + " (" + str(int(GameManager.maint_pct_tracks * 100)) + "%)"
	lbl_env_val.text = "$" + str(int(e_id * GameManager.maint_pct_env)) + " / $" + str(e_id) + " (" + str(int(GameManager.maint_pct_env * 100)) + "%)"
	lbl_sec_val.text = "$" + str(int(s_id * GameManager.maint_pct_sec)) + " / $" + str(s_id) + " (" + str(int(GameManager.maint_pct_sec * 100)) + "%)"
	lbl_crew_val.text = "$" + str(int(c_id * GameManager.maint_pct_crew)) + " / $" + str(c_id) + " (" + str(int(GameManager.maint_pct_crew * 100)) + "%)"
	lbl_lobby_val.text = "$" + str(int(l_id * GameManager.maint_pct_lobby)) + " / $" + str(l_id) + " (" + str(int(GameManager.maint_pct_lobby * 100)) + "%)"

func _on_sld_infra_changed(val: float) -> void:
	GameManager.maint_pct_infra = val / 100.0
	GameManager.update_actual_maintenance()
	_sync_maint_ui()

func _on_sld_tracks_changed(val: float) -> void:
	GameManager.maint_pct_tracks = val / 100.0
	GameManager.update_actual_maintenance()
	_sync_maint_ui()

func _on_sld_env_changed(val: float) -> void:
	GameManager.maint_pct_env = val / 100.0
	GameManager.update_actual_maintenance()
	_sync_maint_ui()

func _on_sld_sec_changed(val: float) -> void:
	GameManager.maint_pct_sec = val / 100.0
	GameManager.update_actual_maintenance()
	_sync_maint_ui()

func _on_sld_crew_changed(val: float) -> void:
	GameManager.maint_pct_crew = val / 100.0
	GameManager.update_actual_maintenance()
	_sync_maint_ui()

func _on_sld_lobby_changed(val: float) -> void:
	GameManager.maint_pct_lobby = val / 100.0
	GameManager.update_actual_maintenance()
	_sync_maint_ui()

func _on_go_desk_pressed() -> void:
	var main_node = get_parent()
	if main_node.has_method("go_to_desk"):
		main_node.go_to_desk()

func _on_edit_mode_pressed() -> void:
	is_edit_mode = true
	btn_edit_mode.visible = false
	btn_go_desk.visible = false
	btn_maint.visible = false
	if is_instance_valid(btn_toggle_dispatch): btn_toggle_dispatch.visible = false
	maint_panel.visible = false
	
	draft_paths.clear()
	deleted_paths.clear()
	tentative_path.clear()
	repair_tiles.clear()
	
	panel_overlay.visible = true 
	edit_panel.visible = true
	_update_edit_panel()
	queue_redraw()

func _on_cancel_edit_pressed() -> void:
	is_edit_mode = false
	edit_panel.visible = false
	panel_overlay.visible = false 
	btn_edit_mode.visible = true
	btn_go_desk.visible = true
	btn_maint.visible = true
	if GameManager.day_phase == 2 and is_instance_valid(btn_toggle_dispatch): 
		btn_toggle_dispatch.visible = true
	
	draft_paths.clear()
	deleted_paths.clear()
	tentative_path.clear()
	repair_tiles.clear()
	queue_redraw()

func _update_edit_info() -> void:
	var total_dist = 0
	var forests = 0
	var mountains = 0
	var rivers = 0
	var gangs = 0
	
	net_cost = 0
	current_env_tax = 0
	current_eng_tax = 0
	current_sec_tax = 0
	current_total_cost = 0
	
	var all_cells = []
	for p in draft_paths:
		for c in p: all_cells.append(c)
	for c in tentative_path: all_cells.append(c)
		
	total_dist = all_cells.size()
	
	if total_dist == 0 and repair_tiles.size() == 0 and deleted_paths.size() == 0:
		edit_info.text = "PROJETO DE ENGENHARIA\n\nSelecione o ponto de partida e o destino no mapa para gerar o estudo de viabilidade técnica, ambiental e financeira da via."
		btn_confirm.disabled = true
		return
		
	for cell in all_cells:
		var b = biome_map.get(cell, Biome.PLAIN)
		if b == Biome.FOREST: forests += 1
		if b == Biome.MOUNTAIN: mountains += 1
		if b == Biome.RIVER: rivers += 1
		if gang_map.has(cell): gangs += 1
		net_cost += GameManager.COSTS[b]
		
	current_env_tax = forests * 50
	current_eng_tax = (mountains + rivers) * 100
	current_sec_tax = gangs * 75
	current_total_cost = net_cost + current_env_tax + current_eng_tax + current_sec_tax
	
	var km_total = total_dist * 15 
	var maint_cost = total_dist * 25
	
	btn_confirm.disabled = false
	
	var relatorio = "[ PROJETO DE ENGENHARIA ]\n\n"
	relatorio += "► ESPECIFICAÇÕES DA VIA\n"
	relatorio += "Extensão Total: " + str(km_total) + " km\n"
	relatorio += "Orçamento Base: $" + str(net_cost) + "\n"
	relatorio += "Custo Total (c/ taxas): $" + str(current_total_cost) + "\n"
	relatorio += "Manutenção Diária: $" + str(maint_cost) + "\n\n"
	
	relatorio += "► OBRAS DE ARTE\n"
	relatorio += "Pontes: " + str(rivers) + " | Túneis: " + str(mountains) + "\n\n"
	
	relatorio += "► AVALIAÇÃO DE RISCO\n"
	if forests > 0:
		relatorio += "Ambiental: ALERTA (" + str(forests) + " zonas florestais afetadas).\n"
	else:
		relatorio += "Ambiental: Impacto mínimo.\n"
		
	if gangs > 0:
		relatorio += "Segurança: ROTA CRÍTICA (" + str(gangs) + " áreas sob domínio de gangues).\n"
	else:
		relatorio += "Segurança: Baixo risco.\n"
		
	edit_info.text = relatorio

func _on_confirm_edit_pressed() -> void:
	if tentative_path.size() >= 2:
		draft_paths.append(tentative_path.duplicate())
		
	var affected_tiles = {}
	for d in deleted_paths:
		for cell in d: affected_tiles[cell] = true
	for r_cell in repair_tiles: affected_tiles[r_cell] = true
	for p in draft_paths:
		for cell in p: affected_tiles[cell] = true
		
	var built = {}
	for route in confirmed_routes:
		for cell in route: built[cell] = true
	built[city_a] = true
	built[city_b] = true
	built[city_c] = true
	
	var untouched = built.duplicate()
	for bt in GameManager.broken_tiles: untouched.erase(bt)
	for cell in affected_tiles.keys(): untouched.erase(cell)
	
	var r_cd = []
	var route_desc_string = ""
	
	if _bfs_shortest_dist(city_a, city_b, untouched, false, false) == -1: 
		r_cd.append("Azul-Vermelha")
		route_desc_string += "Ligação: Estação Azul para Vermelha\n"
	if _bfs_shortest_dist(city_a, city_c, untouched, false, false) == -1: 
		r_cd.append("Azul-Verde")
		route_desc_string += "Ligação: Estação Azul para Verde\n"
	if _bfs_shortest_dist(city_b, city_c, untouched, false, false) == -1: 
		r_cd.append("Vermelha-Verde")
		route_desc_string += "Ligação: Estação Vermelha para Verde\n"
		
	if route_desc_string == "": route_desc_string = "Manutenção ou Demolição da Malha"

	var dist = 0
	var forests = 0
	var gangs = 0
	var tunnels = 0
	var bridges = 0

	for path in draft_paths:
		for cell in path:
			dist += 1
			var b = biome_map.get(cell, Biome.PLAIN)
			if b == Biome.FOREST: forests += 1
			if b == Biome.MOUNTAIN: tunnels += 1
			if b == Biome.RIVER: bridges += 1
			if gang_map.has(cell): gangs += 1

	var is_demolition = (deleted_paths.size() > 0 and draft_paths.size() == 0)
	var is_new_build = draft_paths.size() > 0
	var proj_type = "Manutenção Geral"
	if is_new_build: proj_type = "Nova Construção"
	if is_demolition: proj_type = "Demolição de Via"
	
	# === CORREÇÃO DE BALANCEAMENTO ===
	# O prazo é rigidamente fixado em 1 dia para manter o fluxo do jogo dinâmico.
	var est_days = 1 

	GameManager.pending_blueprint = {
		"draft_paths": draft_paths.duplicate(true),
		"deleted_paths": deleted_paths.duplicate(true),
		"repair_tiles": repair_tiles.duplicate(true),
		"net_cost": net_cost,
		"tax_env": current_env_tax,
		"tax_eng": current_eng_tax,
		"tax_sec": current_sec_tax,
		"total_cost": current_total_cost,
		"routes_to_cooldown": r_cd,
		"route_description": route_desc_string,
		"dist": dist,
		"forests": forests,
		"gangs": gangs,
		"tunnels": tunnels,
		"bridges": bridges,
		"proj_type": proj_type,
		"est_days": est_days
	}
	
	GameManager.save_game()
	_on_cancel_edit_pressed() 
	confirmed_routes = GameManager.saved_routes.duplicate()
	queue_redraw()
	


func _on_btn_maint_pressed() -> void:
	if is_edit_mode: return 
	panel_overlay.visible = true # ESCURECE A TELA
	maint_panel.visible = true
	_sync_maint_ui()

func _on_btn_close_maint_pressed() -> void:
	maint_panel.visible = false
	panel_overlay.visible = false # CLAREIA A TELA


func _get_tile_type(cell: Vector2i) -> String:
	var b = biome_map.get(cell, Biome.PLAIN)
	if b == Biome.MOUNTAIN or b == Biome.RIVER: return "infra"
	if b == Biome.FOREST: return "env"
	return "tracks"



func _update_edit_panel() -> void:
	var build_cost = 0
	var repair_cost = 0
	var build_maint = 0
	var tunnel_count = 0
	var bridge_count = 0
	var forest_count = 0
	var dist_total = 0
	var has_gangs = false
	
	for path in draft_paths:
		for cell in path:
			dist_total += 1
			var b = biome_map.get(cell, Biome.PLAIN)
			build_cost += BIOME_DATA[b]["build"]
			build_maint += BIOME_DATA[b]["maint"]
			if b == Biome.MOUNTAIN: tunnel_count += 1
			if b == Biome.RIVER: bridge_count += 1
			if b == Biome.FOREST: forest_count += 1
			if gang_map.has(cell): has_gangs = true

	for cell in repair_tiles:
		var b = biome_map.get(cell, Biome.PLAIN)
		repair_cost += BIOME_DATA[b]["build"]

	var refund_val = 0
	var refund_maint = 0
	for path in deleted_paths:
		for cell in path:
			if not GameManager.broken_tiles.has(cell):
				var b = biome_map.get(cell, Biome.PLAIN)
				refund_val += BIOME_DATA[b]["build"]
				refund_maint += BIOME_DATA[b]["maint"]

	net_cost = build_cost + repair_cost - refund_val
	net_maint = build_maint - refund_maint
	current_env_tax = forest_count * 50
	current_eng_tax = (tunnel_count * 200) + (bridge_count * 300)
	current_sec_tax = 0
	if has_gangs: current_sec_tax = 200
	current_total_cost = net_cost + current_env_tax + current_eng_tax + current_sec_tax

	var temp_valid = {}
	for r in confirmed_routes:
		if not deleted_paths.has(r):
			for cell in r: temp_valid[cell] = true
	for r in draft_paths:
		for cell in r: temp_valid[cell] = true
		
	if city_a != Vector2i(-1, -1): temp_valid[city_a] = true
	if city_b != Vector2i(-1, -1): temp_valid[city_b] = true
	if city_c != Vector2i(-1, -1): temp_valid[city_c] = true

	var has_conn = false
	var routes_created_msg = ""
	
	if city_a != Vector2i(-1, -1) and city_b != Vector2i(-1, -1):
		if _bfs_shortest_dist(city_a, city_b, temp_valid, false, false) != -1: 
			has_conn = true
			routes_created_msg += "\n* Rota: Azul <-> Vermelha"
			
	if city_a != Vector2i(-1, -1) and city_c != Vector2i(-1, -1):
		if _bfs_shortest_dist(city_a, city_c, temp_valid, false, false) != -1: 
			has_conn = true
			routes_created_msg += "\n* Rota: Azul <-> Verde"
			
	if city_b != Vector2i(-1, -1) and city_c != Vector2i(-1, -1):
		if _bfs_shortest_dist(city_b, city_c, temp_valid, false, false) != -1: 
			has_conn = true
			routes_created_msg += "\n* Rota: Vermelha <-> Verde"

	var is_valid = true
	var t = "== PROJETO DE ENGENHARIA ==\n\n"
	t += "[ DETALHES DA OBRA ]\nDistância de Construção: " + str(dist_total) + " km\n"
	if tunnel_count > 0: t += "- Túneis: " + str(tunnel_count) + "\n"
	if bridge_count > 0: t += "- Pontes: " + str(bridge_count) + "\n"
	if forest_count > 0: t += "- Desmatamento: " + str(forest_count) + "\n"
	if repair_tiles.size() > 0: t += "Reparos Solicitados: " + str(repair_tiles.size()) + "\n"
	
	t += "\n[ TAXAS GOVERNAMENTAIS ]\n"
	if current_env_tax > 0: t += "Licença Ambiental: $" + str(current_env_tax) + "\n"
	if current_eng_tax > 0: t += "Licença de Engenharia: $" + str(current_eng_tax) + "\n"
	if current_sec_tax > 0: t += "Taxa Seg. Armada: $" + str(current_sec_tax) + "\n"
	if current_env_tax == 0 and current_eng_tax == 0 and current_sec_tax == 0: t += "Isento de taxas especiais.\n"

	t += "\n[ FINANCEIRO ]\n"
	if build_cost > 0: t += "Novas Obras: $" + str(build_cost) + "\n"
	if repair_cost > 0: t += "Custos de Reparo: $" + str(repair_cost) + "\n"
	if refund_val > 0: t += "Reembolso por Demolição: +$" + str(refund_val) + "\n"
	t += "---------------------------\nCUSTO TOTAL DO PROJETO: $" + str(current_total_cost) + "\n"
	
	if draft_paths.size() > 0 or deleted_paths.size() > 0 or repair_tiles.size() > 0:
		if not has_conn and draft_paths.size() > 0:
			is_valid = false
			t += "\n[ ERRO: Rota desenhada não toca nas estações! ]"
		else:
			if routes_created_msg != "":
				t += "\n[ CONEXÕES ASSEGURADAS ]" + routes_created_msg + "\n"
				
		if current_total_cost > GameManager.money:
			is_valid = false
			t += "\n[ ERRO: Fundos Insuficientes! ]"
	else:
		is_valid = false
		t += "\nNenhuma alteração projetada."

	edit_info.text = t
	btn_confirm.disabled = not is_valid



func _process(delta: float) -> void:
	if not visible: return
	
	# --- NOVO: MOTOR DE MOVIMENTO E ANIMAÇÃO ---
	if is_dispatching:
		var all_finished = true
		var needs_redraw = false
		
		for index in active_trains.keys():
			var train_anim = active_trains[index]
			if train_anim["finished"]: 
				continue
			
			all_finished = false
			needs_redraw = true
			
			if train_anim.has("delay") and train_anim["delay"] > 0:
				train_anim["delay"] -= delta
				continue
				
			var path_len = 0.0
			for i in range(train_anim["path"].size() - 1): 
				path_len += train_anim["path"][i].distance_to(train_anim["path"][i+1])
				
			train_anim["progress"] += train_anim["speed"] * delta
			
			# Trem chegou ao destino
			if train_anim["progress"] >= path_len:
				train_anim["progress"] = path_len
				train_anim["finished"] = true
		
		if needs_redraw:
			queue_redraw()
			
		# Se todos os trens chegaram, encerra a operação
		if all_finished and active_trains.size() > 0:
			_finish_dispatch_operation()



func _spawn_train(contract_index: int, contract: Dictionary) -> void:
	var route_id = contract["route_id"]
	var start_city = Vector2i(-1, -1)
	var target_city = Vector2i(-1, -1)

	if "Azul" in route_id and "Vermelha" in route_id:
		start_city = city_a; target_city = city_b
	else:
		if "Azul" in route_id and "Verde" in route_id:
			start_city = city_a; target_city = city_c
		else:
			if "Vermelha" in route_id and "Verde" in route_id:
				start_city = city_b; target_city = city_c

	var valid_tiles = {}
	for r in confirmed_routes:
		for cell in r: valid_tiles[cell] = true
	valid_tiles[start_city] = true
	valid_tiles[target_city] = true

	var path_cells = _bfs_get_path_array(start_city, target_city, valid_tiles)
	if path_cells.size() < 2: return 
	
	var path_points = []
	for cell in path_cells: path_points.append(Vector2(cell.x * TILE_SIZE + TILE_SIZE/2.0, cell.y * TILE_SIZE + TILE_SIZE/2.0))

	var palette = [Color.CRIMSON, Color.ROYAL_BLUE, Color.GOLDENROD, Color.DARK_VIOLET, Color.DARK_ORANGE]
	active_trains[contract_index] = {
		"path": path_points, "progress": 0.0, "direction": 1,
		"speed": 100.0, "color": palette[contract_index % palette.size()], "delay": contract_index * 1.5
	}

func _move_train(index: int, delta: float) -> void:
	var train = active_trains[index]
	if train["path"].size() < 2: return
	if train.has("delay") and train["delay"] > 0:
		train["delay"] -= delta
		return
		
	var current_dist = train["progress"]
	var loco_info = _get_path_info(train["path"], current_dist)
	var pos = loco_info["pos"]
	var cell = Vector2i(int(pos.x / TILE_SIZE), int(pos.y / TILE_SIZE))
	
	var tile_health = GameManager.tile_data.get(cell, {}).get("h", 1.0)
	var speed_mult = 0.2 + (0.8 * tile_health)
	
	var path_len = 0.0
	for i in range(train["path"].size() - 1): path_len += train["path"][i].distance_to(train["path"][i+1])
		
	train["progress"] += train["speed"] * speed_mult * delta * train["direction"]

	if train["progress"] >= path_len:
		train["progress"] = path_len; train["direction"] = -1
	else:
		if train["progress"] <= 0:
			train["progress"] = 0; train["direction"] = 1

func _get_path_info(path: Array, dist: float) -> Dictionary:
	var path_len = 0.0
	var seg_lengths = []
	for i in range(path.size() - 1):
		var d = path[i].distance_to(path[i+1])
		seg_lengths.append(d)
		path_len += d
	dist = clamp(dist, 0.0, path_len)
	var accum = 0.0
	for i in range(path.size() - 1):
		var seg_len = seg_lengths[i]
		if accum + seg_len >= dist or i == path.size() - 2:
			var t = 0.0
			if seg_len > 0: t = (dist - accum) / seg_len
			t = clamp(t, 0.0, 1.0)
			var pos = path[i].lerp(path[i+1], t)
			var dir = (path[i+1] - path[i]).normalized()
			if dir == Vector2.ZERO: dir = Vector2.RIGHT
			return {"pos": pos, "dir": dir}
		accum += seg_len
	return {"pos": path.back(), "dir": Vector2.RIGHT}

func _draw_trains() -> void:
	for index in active_trains.keys():
		var train = active_trains[index]
		var path = train["path"]
		if path.size() < 2: continue
		var current_dist = train["progress"]
		if train.has("delay") and train["delay"] > 0: current_dist = 0.0 
		var loco_info = _get_path_info(path, current_dist)
		var wagon_info = _get_path_info(path, current_dist - (20.0 * train["direction"]))
		var loco_dir = loco_info["dir"]
		var wagon_dir = wagon_info["dir"]
		if train["direction"] == -1:
			loco_dir = -loco_dir; wagon_dir = -wagon_dir
			
		draw_set_transform(wagon_info["pos"], wagon_dir.angle(), Vector2.ONE)
		draw_rect(Rect2(-10, -6, 20, 12), train["color"]) 
		draw_set_transform(loco_info["pos"], loco_dir.angle(), Vector2.ONE)
		draw_rect(Rect2(-12, -8, 24, 16), Color(0.15, 0.15, 0.15)) 
		draw_rect(Rect2(2, -4, 8, 10), Color(0.7, 0.7, 0.7)) 
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _bfs_get_path_array(start_node: Vector2i, target_node: Vector2i, valid_tiles: Dictionary) -> Array[Vector2i]:
	var initial_path: Array[Vector2i] = [start_node]
	var queue = [initial_path]
	var visited = {start_node: true}
	while queue.size() > 0:
		var path: Array[Vector2i] = queue.pop_front()
		var cell = path.back()
		if cell == target_node: return path
		for n in [cell + Vector2i.UP, cell + Vector2i.DOWN, cell + Vector2i.LEFT, cell + Vector2i.RIGHT]:
			if valid_tiles.has(n) and not visited.has(n):
				visited[n] = true
				var new_path: Array[Vector2i] = path.duplicate()
				new_path.append(n)
				queue.push_back(new_path)
	return []

func _is_cell_occupied_by_track(cell: Vector2i) -> bool:
	for route in confirmed_routes:
		if cell in route: return true
	if cell in tentative_path: return true
	for draft in draft_paths:
		if cell in draft: return true
	if not GameManager.pending_blueprint.is_empty():
		for draft in GameManager.pending_blueprint.get("draft_paths", []):
			if cell in draft: return true
	return false

func _draw() -> void:
	for x in range(grid_width):
		for y in range(grid_height):
			var cell = Vector2i(x, y)
			var b = biome_map.get(cell, Biome.PLAIN)
			var bg_color = BIOME_DATA[b]["color"]
			if b == Biome.FOREST: bg_color = BIOME_DATA[Biome.PLAIN]["color"]
			draw_rect(Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE), bg_color)
			if b == Biome.FOREST and not _is_cell_occupied_by_track(cell):
				var p1 = Vector2(x * TILE_SIZE + 16, y * TILE_SIZE + 6)
				var p2 = Vector2(x * TILE_SIZE + 6, y * TILE_SIZE + 26)
				var p3 = Vector2(x * TILE_SIZE + 26, y * TILE_SIZE + 26)
				draw_polygon(PackedVector2Array([p1, p2, p3]), [Color(0.15, 0.4, 0.15)])

	for cell in gang_map.keys():
		draw_rect(Rect2(cell.x * TILE_SIZE, cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color(0.8, 0.1, 0.1, 0.4))

	for x in range(grid_width + 1):
		draw_line(Vector2(x * TILE_SIZE, 0), Vector2(x * TILE_SIZE, grid_height * TILE_SIZE), Color(0, 0, 0, 0.1), 1.0)
	for y in range(grid_height + 1):
		draw_line(Vector2(0, y * TILE_SIZE), Vector2(grid_width * TILE_SIZE, y * TILE_SIZE), Color(0, 0, 0, 0.1), 1.0)

	var valid_built = {}
	for r in confirmed_routes:
		for c in r: valid_built[c] = true
	if city_a != Vector2i(-1, -1): valid_built[city_a] = true
	if city_b != Vector2i(-1, -1): valid_built[city_b] = true
	if city_c != Vector2i(-1, -1): valid_built[city_c] = true
	
	var path_ab = []
	var path_ac = []
	var path_bc = []
	if city_a != Vector2i(-1, -1) and city_b != Vector2i(-1, -1): path_ab = _bfs_get_path_array(city_a, city_b, valid_built)
	if city_a != Vector2i(-1, -1) and city_c != Vector2i(-1, -1): path_ac = _bfs_get_path_array(city_a, city_c, valid_built)
	if city_b != Vector2i(-1, -1) and city_c != Vector2i(-1, -1): path_bc = _bfs_get_path_array(city_b, city_c, valid_built)

	var const_cells = {}
	if GameManager.routes_under_construction.get("Azul-Vermelha", 0) > 0:
		for c in path_ab: const_cells[c] = GameManager.routes_under_construction["Azul-Vermelha"]
	if GameManager.routes_under_construction.get("Azul-Verde", 0) > 0:
		for c in path_ac: const_cells[c] = GameManager.routes_under_construction["Azul-Verde"]
	if GameManager.routes_under_construction.get("Vermelha-Verde", 0) > 0:
		for c in path_bc: const_cells[c] = GameManager.routes_under_construction["Vermelha-Verde"]

	var drawn_texts = {}
	for route in confirmed_routes: 
		var is_del = deleted_paths.has(route)
		if not GameManager.pending_blueprint.is_empty():
			for d in GameManager.pending_blueprint.get("deleted_paths", []):
				if _are_routes_equal(route, d): is_del = true

		var route_is_const = false
		var max_d = 0
		for cell in route:
			if const_cells.has(cell):
				route_is_const = true
				if const_cells[cell] > max_d: max_d = const_cells[cell]
				
		_draw_custom_track(route, false, route_is_const, is_del) 
		if route_is_const and not is_del and route.size() > 2:
			var mid = route[route.size() / 2]
			var px = mid.x * TILE_SIZE + 16
			var py = mid.y * TILE_SIZE + 16
			var mid_str = str(mid.x) + "_" + str(mid.y)
			if not drawn_texts.has(mid_str):
				drawn_texts[mid_str] = true
				draw_rect(Rect2(px - 50, py - 12, 100, 24), Color(0.1, 0.1, 0.1, 0.9))
				draw_string(ThemeDB.fallback_font, Vector2(px - 45, py + 4), "[ OBRAS: " + str(max_d) + "d ]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.ORANGE)
	
	for draft in draft_paths: _draw_custom_track(draft, true, false, false)
	_draw_custom_track(tentative_path, true, false, false)

	if not GameManager.pending_blueprint.is_empty():
		for draft in GameManager.pending_blueprint.get("draft_paths", []):
			_draw_custom_track(draft, true, false, false)
			if draft.size() > 2:
				var mid = draft[draft.size() / 2]
				var px = mid.x * TILE_SIZE + 16
				var py = mid.y * TILE_SIZE + 16
				var mid_str = "plan_" + str(mid.x) + "_" + str(mid.y)
				if not drawn_texts.has(mid_str):
					drawn_texts[mid_str] = true
					draw_rect(Rect2(px - 75, py - 12, 150, 24), Color(0.1, 0.2, 0.4, 0.9))
					draw_string(ThemeDB.fallback_font, Vector2(px - 70, py + 4), "[ AGUARDANDO APROV. ]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.SKY_BLUE)
					
		for cell in GameManager.pending_blueprint.get("repair_tiles", []):
			draw_arc(Vector2(cell.x * TILE_SIZE + 16, cell.y * TILE_SIZE + 16), 18.0, 0, TAU, 16, Color.SKY_BLUE, 3.0)

	if city_a != Vector2i(-1, -1): draw_rect(Rect2(city_a.x * TILE_SIZE, city_a.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.DODGER_BLUE)
	if city_b != Vector2i(-1, -1): draw_rect(Rect2(city_b.x * TILE_SIZE, city_b.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.CRIMSON)
	if city_c != Vector2i(-1, -1): draw_rect(Rect2(city_c.x * TILE_SIZE, city_c.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.FOREST_GREEN)
	
	_draw_trains()
	
	for cell in GameManager.broken_tiles:
		var px = cell.x * TILE_SIZE + 16
		var py = cell.y * TILE_SIZE + 16
		if biome_map.get(cell, Biome.PLAIN) == Biome.FOREST:
			draw_circle(Vector2(px, py), 14.0, Color(0.8, 0.2, 0.0))
			draw_circle(Vector2(px, py - 4), 8.0, Color(0.9, 0.6, 0.1))
		else:
			draw_line(Vector2(px - 14, py - 14), Vector2(px + 14, py + 14), Color.RED, 4.0)
			draw_line(Vector2(px + 14, py - 14), Vector2(px - 14, py + 14), Color.RED, 4.0)
		if repair_tiles.has(cell):
			draw_arc(Vector2(px, py), 18.0, 0, TAU, 16, Color.YELLOW, 3.0)

	# --- INÍCIO DA ALTERAÇÃO ---
	# (As linhas que desenhavam o Rect2 preto foram removidas daqui para o mapa ocupar a tela toda)
	# --- FIM DA ALTERAÇÃO ---

func _get_track_color(b: int, is_preview: bool, is_construction: bool, is_deleted: bool = false) -> Color:
	if is_deleted: return Color(0.8, 0.2, 0.2, 0.7) 
	if is_preview: return Color.YELLOW
	if is_construction: return Color(0.9, 0.7, 0.1) 
	if b == Biome.RIVER: return Color.SADDLE_BROWN 
	if b == Biome.MOUNTAIN: return Color.DARK_SLATE_GRAY 
	return Color.BLACK

func _draw_custom_track(path: Array, is_preview: bool, is_const: bool, is_deleted: bool = false) -> void:
	if path.size() == 0: return
	if path.size() == 1:
		draw_circle(Vector2(path[0].x * 32 + 16, path[0].y * 32 + 16), 5.0, _get_track_color(biome_map.get(path[0], Biome.PLAIN), is_preview, is_const, is_deleted))
		return
	for cell in path:
		if biome_map.get(cell, Biome.PLAIN) == Biome.FOREST:
			draw_circle(Vector2(cell.x * 32 + 10, cell.y * 32 + 10), 5.0, Color(0.85, 0.75, 0.55))
			draw_circle(Vector2(cell.x * 32 + 10, cell.y * 32 + 10), 2.0, Color(0.7, 0.6, 0.4))
	for i in range(path.size() - 1):
		var p1_cell = path[i]
		var p2_cell = path[i+1]
		var b1 = biome_map.get(p1_cell, Biome.PLAIN)
		var b2 = biome_map.get(p2_cell, Biome.PLAIN)
		var segment_biome = Biome.PLAIN
		if b1 == Biome.MOUNTAIN or b2 == Biome.MOUNTAIN: segment_biome = Biome.MOUNTAIN
		else:
			if b1 == Biome.RIVER or b2 == Biome.RIVER: segment_biome = Biome.RIVER
			else:
				if b1 == Biome.FOREST or b2 == Biome.FOREST: segment_biome = Biome.FOREST
		
		var line_color = _get_track_color(segment_biome, is_preview, is_const, is_deleted)
		var line_width = 3.0
		if segment_biome == Biome.MOUNTAIN:
			line_width = 7.0
			
		var p1 = Vector2(p1_cell.x * 32 + 16, p1_cell.y * 32 + 16)
		var p2 = Vector2(p2_cell.x * 32 + 16, p2_cell.y * 32 + 16)
		draw_line(p1, p2, line_color, line_width)
		
		if segment_biome != Biome.MOUNTAIN:
			var dir = (p2 - p1).normalized()
			var normal = Vector2(-dir.y, dir.x)
			var spacing = 10.0
			if segment_biome == Biome.RIVER:
				spacing = 5.0
			var num_ties = int(p1.distance_to(p2) / spacing)
			var tie_color = line_color
			if segment_biome == Biome.RIVER and not is_preview:
				tie_color = Color(0.3, 0.2, 0.1)
			else:
				if is_const and not is_deleted:
					tie_color = Color.BLACK
			
			for j in range(1, num_ties + 1):
				var tie_center = p1 + dir * (j * spacing)
				draw_line(tie_center - normal * 5.0, tie_center + normal * 5.0, tie_color, 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if is_edit_mode:
		# --- INÍCIO DA ALTERAÇÃO ---
		# GAIOLA: Bloqueia cliques para não desenhar trilhos em cima da HUD Inferior
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			if event.position.y > 1000: return
		# --- FIM DA ALTERAÇÃO ---

		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.is_pressed():
					var cell = _get_cell_under_mouse(event.position)
					if cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height:
						is_dragging = true
						tentative_path = [cell]
						queue_redraw()
				else:
					if is_dragging: 
						is_dragging = false
						if tentative_path.size() > 0:
							draft_paths.append(tentative_path.duplicate())
							tentative_path.clear()
							_update_edit_panel()
						queue_redraw()
			else:
				if event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
					var cell = _get_cell_under_mouse(event.position)
					var handled = false
					for i in range(draft_paths.size() - 1, -1, -1):
						if draft_paths[i].has(cell):
							draft_paths.remove_at(i)
							handled = true
							break
					if not handled:
						if GameManager.broken_tiles.has(cell):
							var route_is_deleted = false
							for r in deleted_paths:
								if r.has(cell): route_is_deleted = true
							if not route_is_deleted: 
								if repair_tiles.has(cell): repair_tiles.erase(cell)
								else: repair_tiles.append(cell)
								handled = true
					if not handled:
						for r in confirmed_routes:
							if r.has(cell):
								if deleted_paths.has(r): deleted_paths.erase(r) 
								else: 
									deleted_paths.append(r)
									for c in r:
										if repair_tiles.has(c): repair_tiles.erase(c)
								break
					_update_edit_panel()
					queue_redraw()
		else:
			if event is InputEventMouseMotion and is_dragging:
				var cell = _get_cell_under_mouse(event.position)
				cell.x = clamp(cell.x, 0, grid_width - 1)
				cell.y = clamp(cell.y, 0, grid_height - 1)
				if tentative_path.size() > 0:
					var last = tentative_path.back()
					if cell != last:
						for p in _get_orthogonal_path(last, cell):
							var idx = tentative_path.find(p)
							if idx != -1: tentative_path.resize(idx + 1)
							else: tentative_path.append(p)
						queue_redraw()

func _get_orthogonal_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = start
	while current.x != end.x: 
		current.x += sign(end.x - current.x)
		path.append(current)
	while current.y != end.y: 
		current.y += sign(end.y - current.y)
		path.append(current)
	return path

func _update_network_status() -> void:
	active_trains.clear()
	var valid_for_path = {}
	for r in confirmed_routes:
		for c in r: valid_for_path[c] = true
	if city_a != Vector2i(-1, -1): valid_for_path[city_a] = true
	if city_b != Vector2i(-1, -1): valid_for_path[city_b] = true
	if city_c != Vector2i(-1, -1): valid_for_path[city_c] = true
	
	var path_ab = []
	var path_ac = []
	var path_bc = []
	if city_a != Vector2i(-1, -1) and city_b != Vector2i(-1, -1): path_ab = _bfs_get_path_array(city_a, city_b, valid_for_path)
	if city_a != Vector2i(-1, -1) and city_c != Vector2i(-1, -1): path_ac = _bfs_get_path_array(city_a, city_c, valid_for_path)
	if city_b != Vector2i(-1, -1) and city_c != Vector2i(-1, -1): path_bc = _bfs_get_path_array(city_b, city_c, valid_for_path)

	var const_cells = {}
	if GameManager.routes_under_construction.get("Azul-Vermelha", 0) > 0:
		for c in path_ab: const_cells[c] = true
	if GameManager.routes_under_construction.get("Azul-Verde", 0) > 0:
		for c in path_ac: const_cells[c] = true
	if GameManager.routes_under_construction.get("Vermelha-Verde", 0) > 0:
		for c in path_bc: const_cells[c] = true
		
	var built = {}
	var toll = 0
	var i_infra = 0
	var i_tracks = 0
	var i_env = 0
	var i_sec = 0
	
	for route in confirmed_routes:
		var has_g = false
		var is_route_const = false
		for cell in route:
			built[cell] = true
			if gang_map.has(cell): has_g = true
			if const_cells.has(cell): is_route_const = true
		if has_g and not is_route_const: toll += GANG_TOLL_RATE
		
	for cell in built.keys():
		if const_cells.has(cell): continue
		var b = biome_map.get(cell, Biome.PLAIN)
		if b == Biome.MOUNTAIN or b == Biome.RIVER: i_infra += BIOME_DATA[b]["maint"]
		else:
			if b == Biome.PLAIN: i_tracks += BIOME_DATA[b]["maint"]
			else:
				if b == Biome.FOREST: i_env += BIOME_DATA[b]["maint"]
			
	i_sec = toll

	GameManager.ideal_maint_infra = i_infra
	GameManager.ideal_maint_tracks = i_tracks
	GameManager.ideal_maint_env = i_env
	GameManager.ideal_maint_sec = i_sec
	GameManager.ideal_maint_crew = GameManager.active_contracts.size() * 25
	GameManager.ideal_maint_lobby = 50
	
	GameManager.update_actual_maintenance()
	if is_instance_valid(maint_panel): _sync_maint_ui()
	
	if city_a != Vector2i(-1, -1): built[city_a] = true
	if city_b != Vector2i(-1, -1): built[city_b] = true
	if city_c != Vector2i(-1, -1): built[city_c] = true
	
	var built_unbroken = built.duplicate()
	for bt in GameManager.broken_tiles: built_unbroken.erase(bt)
	
	var connections = []
	var stats = {}
	
	if city_a != Vector2i(-1, -1) and city_b != Vector2i(-1, -1):
		var res_unb = _get_route_capabilities(city_a, city_b, built_unbroken)
		if not res_unb.is_empty(): 
			connections.append("Azul-Vermelha")
			stats["Azul-Vermelha"] = res_unb
		else:
			var res_b = _get_route_capabilities(city_a, city_b, built)
			if not res_b.is_empty():
				connections.append("Azul-Vermelha")
				res_b["is_broken"] = true
				stats["Azul-Vermelha"] = res_b
			
	if city_a != Vector2i(-1, -1) and city_c != Vector2i(-1, -1):
		var res_unb = _get_route_capabilities(city_a, city_c, built_unbroken)
		if not res_unb.is_empty(): 
			connections.append("Azul-Verde")
			stats["Azul-Verde"] = res_unb
		else:
			var res_b = _get_route_capabilities(city_a, city_c, built)
			if not res_b.is_empty():
				connections.append("Azul-Verde")
				res_b["is_broken"] = true
				stats["Azul-Verde"] = res_b
			
	if city_b != Vector2i(-1, -1) and city_c != Vector2i(-1, -1):
		var res_unb = _get_route_capabilities(city_b, city_c, built_unbroken)
		if not res_unb.is_empty(): 
			connections.append("Vermelha-Verde")
			stats["Vermelha-Verde"] = res_unb
		else:
			var res_b = _get_route_capabilities(city_b, city_c, built)
			if not res_b.is_empty():
				connections.append("Vermelha-Verde")
				res_b["is_broken"] = true
				stats["Vermelha-Verde"] = res_b
			
	GameManager.network_connections = connections
	GameManager.network_stats = stats
	GameManager.contracts_updated.emit() 

func _get_route_capabilities(start: Vector2i, target: Vector2i, valid: Dictionary) -> Dictionary:
	var shortest = _bfs_shortest_dist(start, target, valid, false, false)
	if shortest == -1: return {} 
	var gangs = 1
	if _bfs_shortest_dist(start, target, valid, true, false) != -1: gangs = 0
	var forests = 1
	if _bfs_shortest_dist(start, target, valid, false, true) != -1: forests = 0
	return {"dist": shortest, "gangs": gangs, "forests": forests}

func _bfs_shortest_dist(start: Vector2i, target: Vector2i, valid: Dictionary, avoid_g: bool, avoid_f: bool) -> int:
	var q = [{"cell": start, "dist": 0}]
	var vis = {start: true}
	while q.size() > 0:
		var curr = q.pop_front()
		var cell = curr["cell"]
		if cell == target: return curr["dist"]
		for n in [cell + Vector2i.UP, cell + Vector2i.DOWN, cell + Vector2i.LEFT, cell + Vector2i.RIGHT]:
			if valid.has(n) and not vis.has(n):
				if avoid_g and gang_map.has(n): continue
				if avoid_f and biome_map.get(n, Biome.PLAIN) == Biome.FOREST: continue
				vis[n] = true
				q.push_back({"cell": n, "dist": curr["dist"] + 1})
	return -1
	
func _are_routes_equal(r1: Array, r2: Array) -> bool:
	if r1.size() != r2.size(): return false
	for i in range(r1.size()):
		if r1[i] != r2[i]: return false
	return true

func _get_cell_under_mouse(p: Vector2) -> Vector2i: 
	return Vector2i(p.x / TILE_SIZE, p.y / TILE_SIZE)
	
	
func _setup_map_legend() -> void:
	# Cria o fundo da legenda
	var legend_bg = ColorRect.new()
	legend_bg.color = Color(0.92, 0.92, 0.9) # Fundo claro como na sua referência
	legend_bg.size = Vector2(150, 180)
	legend_bg.position = Vector2(20, 850) # Canto inferior esquerdo do mapa
	ui_layer.add_child(legend_bg)

	# Container vertical para organizar os itens
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(15, 15)
	vbox.add_theme_constant_override("separation", 12)
	legend_bg.add_child(vbox)

	# Array com os dados mapeando para suas constantes reais
	var legend_items = [
		{"nome": "Planície", "cor": BIOME_DATA[Biome.PLAIN]["color"]},
		{"nome": "Floresta", "cor": BIOME_DATA[Biome.FOREST]["color"]},
		{"nome": "Rio", "cor": BIOME_DATA[Biome.RIVER]["color"]},
		{"nome": "Montanha", "cor": BIOME_DATA[Biome.MOUNTAIN]["color"]},
		{"nome": "Gangues", "cor": Color(0.9, 0.6, 0.6)} # Cor baseada na sua transparência vermelha
	]

	# Loop para gerar os quadros de cor e os textos
	for item in legend_items:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var color_box = ColorRect.new()
		color_box.custom_minimum_size = Vector2(20, 20)
		color_box.color = item["cor"]
		hbox.add_child(color_box)

		var lbl = Label.new()
		lbl.text = item["nome"]
		lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		lbl.add_theme_font_size_override("font_size", 15)
		hbox.add_child(lbl)

		vbox.add_child(hbox)


# === FASE 4: PAINEL DE STATUS DA MALHA ===

func _setup_status_panel() -> void:
	status_panel = ColorRect.new()
	status_panel.color = Color(0.1, 0.1, 0.15, 0.85)
	status_panel.size = Vector2(280, 110)
	status_panel.position = Vector2(20, 20) # Canto superior esquerdo do mapa
	ui_layer.add_child(status_panel)
	
	var border = ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(0.4, 0.5, 0.6)
	border.border_width = 2
	status_panel.add_child(border)
	
	var title = Label.new()
	title.text = "STATUS DA MALHA FERROVIARIA"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = Vector2(10, 10)
	status_panel.add_child(title)
	
	status_vbox = VBoxContainer.new()
	status_vbox.position = Vector2(10, 35)
	status_vbox.size = Vector2(260, 70)
	status_panel.add_child(status_vbox)

func _update_status_panel() -> void:
	for child in status_vbox.get_children():
		child.queue_free()
		
	var routes = [
		{"id": "Azul-Vermelha", "name": "Azul <-> Vermelha"},
		{"id": "Azul-Verde", "name": "Azul <-> Verde"},
		{"id": "Vermelha-Verde", "name": "Vermelha <-> Verde"}
	]
	
	for r in routes:
		var rid = r["id"]
		var rname = r["name"]
		var status_text = ""
		var color = Color.GRAY
		
		var is_built = rid in GameManager.network_connections
		var is_constructing = GameManager.routes_under_construction.get(rid, 0) > 0
		var is_broken = false
		if is_built:
			var stats = GameManager.network_stats.get(rid, {})
			is_broken = stats.get("is_broken", false)
			
		if is_constructing:
			status_text = "Interditada (Em Obras)"
			color = Color.CRIMSON
		else:
			if is_broken:
				status_text = "Interditada (Falha na Via)"
				color = Color.CRIMSON
			else:
				if not is_built:
					status_text = "Inexistente"
					color = Color.DIM_GRAY
				else:
					var active_trains_count = 0
					for c in GameManager.active_contracts:
						if c["route_id"] == rid and GameManager.is_contract_operating(c):
							active_trains_count += 1
							
					if active_trains_count > 0:
						status_text = "Operacional (" + str(active_trains_count) + " Trem(s))"
						color = Color.LIME_GREEN
					else:
						status_text = "Ociosa (Sem Contratos)"
						color = Color.GOLD
				
		var hbox = HBoxContainer.new()
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(12, 12)
		icon.color = color
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var lbl = Label.new()
		lbl.text = " " + rname + ": " + status_text
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		
		hbox.add_child(icon)
		hbox.add_child(lbl)
		status_vbox.add_child(hbox)
		
		
		
# --- NOVO: LÓGICA DO PLANO DE VIAGEM COM PUNIÇÃO E MULTA ---



func _populate_dispatch_panel() -> void:
	for child in dispatch_vbox.get_children():
		child.queue_free()
		
	var loaded_trains = 0
	var has_blocked_train = false
	
	# Trava o botão de despacho se houver erro logístico
	for i in range(GameManager.fleet.size()):
		var train = GameManager.fleet[i]
		if train["loaded_packages"].size() > 0:
			loaded_trains += 1
			var hbox = HBoxContainer.new()
			
			var cargo_dest = "Qualquer"
			var total_cargo_value = 0 
			
			# --- LENDO O NOME DA CARGA DOS VAGÕES ---
			var cargo_names = ""
			var pkgs = train["loaded_packages"]
			for j in range(pkgs.size()):
				total_cargo_value += pkgs[j].get("base_reward", 0)
				if pkgs[j].get("destination", "Qualquer Rota") != "Qualquer Rota":
					cargo_dest = pkgs[j]["destination"]
				
				cargo_names += pkgs[j].get("declared_item", "Carga")
				if j < pkgs.size() - 1:
					cargo_names += ", "
			# ----------------------------------------
					
			var is_route_ok = true
			var route_status_msg = ""
			
			if cargo_dest != "Qualquer":
				var route_id_check = cargo_dest.replace(" <-> ", "-") 
				var is_built = route_id_check in GameManager.network_connections
				var is_building = GameManager.routes_under_construction.get(route_id_check, 0) > 0
				
				if is_building:
					is_route_ok = false
					route_status_msg = " [ EM OBRAS ]"
				if not is_building:
					if not is_built:
						is_route_ok = false
						route_status_msg = " [ INEXISTENTE ]"

			# --- LAYOUT DA LABEL ATUALIZADO ---
			var lbl = Label.new()
			lbl.text = train["name"] + " (" + str(train["current_weight"]) + "kg)\nCarga: " + cargo_names + "\nDestino: " + cargo_dest + route_status_msg
			lbl.custom_minimum_size = Vector2(230, 60)
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			# ----------------------------------
			
			if not is_route_ok:
				lbl.add_theme_color_override("font_color", Color.INDIAN_RED)
			hbox.add_child(lbl)
			
			var opt = OptionButton.new()
			opt.custom_minimum_size = Vector2(170, 40)
			opt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			if is_route_ok:
				opt.add_item("Azul <-> Vermelha", 0)
				opt.add_item("Azul <-> Verde", 1)
				opt.add_item("Vermelha <-> Verde", 2)
				
				# Tenta pré-selecionar a rota que a carga exige
				for j in range(opt.get_item_count()):
					if opt.get_item_text(j) == cargo_dest:
						opt.select(j)
						
			if not is_route_ok:
				opt.add_item("ROTA BLOQUEADA", 0)
				opt.disabled = true
				has_blocked_train = true
				
			hbox.add_child(opt)
			
			# --- BOTÃO DE DESCARTAR CARGA ---
			if not is_route_ok:
				var fine_value = int(total_cargo_value * 0.4)
				var btn_discard = Button.new()
				btn_discard.text = "DESCARTAR\n(-$" + str(fine_value) + ")"
				btn_discard.custom_minimum_size = Vector2(110, 40)
				btn_discard.add_theme_color_override("font_color", Color.RED)
				btn_discard.add_theme_font_size_override("font_size", 12)
				btn_discard.pressed.connect(_on_discard_train_cargo.bind(i, fine_value))
				hbox.add_child(btn_discard)
				
			train["ui_option_button"] = opt
			dispatch_vbox.add_child(hbox)
			
	if loaded_trains == 0:
		var lbl = Label.new()
		lbl.text = "Nenhum trem carregado. Termine a Triagem."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dispatch_vbox.add_child(lbl)
		btn_dispatch.disabled = true
		
	if loaded_trains > 0:
		if has_blocked_train:
			btn_dispatch.disabled = true
			btn_dispatch.text = "[ FROTA BLOQUEADA POR ERRO DE ROTA ]"
			btn_dispatch.add_theme_color_override("font_color", Color.GRAY)
		if not has_blocked_train:
			btn_dispatch.disabled = false
			btn_dispatch.text = "[ INICIAR OPERAÇÃO DIÁRIA ]"
			btn_dispatch.add_theme_color_override("font_color", Color.LIME_GREEN)




func _on_discard_train_cargo(train_index: int, fine: int) -> void:
	GameManager.money -= fine
	var train = GameManager.fleet[train_index]
	train["loaded_packages"].clear()
	train["current_weight"] = 0.0
	_populate_dispatch_panel() # Recarrega a tela imediatamente após descartar



func _on_btn_dispatch_pressed() -> void:
	dispatch_panel.visible = false
	active_trains.clear()
	
	# Mapeia os tiles válidos para o caminho (incluindo as cidades)
	var valid_tiles = {}
	for r in confirmed_routes:
		for cell in r: 
			valid_tiles[cell] = true
	if city_a != Vector2i(-1, -1): valid_tiles[city_a] = true
	if city_b != Vector2i(-1, -1): valid_tiles[city_b] = true
	if city_c != Vector2i(-1, -1): valid_tiles[city_c] = true

	var palette = [Color.CRIMSON, Color.ROYAL_BLUE, Color.GOLDENROD, Color.DARK_VIOLET, Color.DARK_ORANGE]
	
	# Prepara a animação para cada trem carregado
	for i in range(GameManager.fleet.size()):
		var train = GameManager.fleet[i]
		if train["loaded_packages"].size() > 0:
			var opt = train.get("ui_option_button")
			var route_str = opt.get_item_text(opt.get_selected_id())
			train["temp_route_str"] = route_str # Salva para o Livro de Registros depois
			
			var start_city = Vector2i(-1, -1)
			var target_city = Vector2i(-1, -1)
			
			# Descobre de onde pra onde o trem vai baseado na escolha
			if "Azul" in route_str and "Vermelha" in route_str:
				start_city = city_a
				target_city = city_b
			if "Azul" in route_str and "Verde" in route_str:
				start_city = city_a
				target_city = city_c
			if "Vermelha" in route_str and "Verde" in route_str:
				start_city = city_b
				target_city = city_c
				
			# Traça o caminho usando o algoritmo BFS que já existe no jogo
			var path_cells = _bfs_get_path_array(start_city, target_city, valid_tiles)
			if path_cells.size() >= 2:
				var path_points = []
				for cell in path_cells: 
					path_points.append(Vector2(cell.x * TILE_SIZE + TILE_SIZE/2.0, cell.y * TILE_SIZE + TILE_SIZE/2.0))
				
				active_trains[i] = {
					"path": path_points,
					"progress": 0.0,
					"direction": 1,
					"speed": 180.0, # Velocidade da animação no mapa
					"color": palette[i % palette.size()],
					"delay": i * 1.5, # Trens saem em fila (1.5s de diferença)
					"finished": false
				}

	# Trava de segurança: se algum erro impedir os trens de existirem, pula a animação
	if active_trains.size() == 0:
		_finish_dispatch_operation()
	if active_trains.size() > 0:
		is_dispatching = true



# --- NOVO: FINALIZAÇÃO DA VIAGEM E PREENCHIMENTO DO LIVRO ---
func _finish_dispatch_operation() -> void:
	is_dispatching = false
	active_trains.clear()
	queue_redraw()
	
	# Processa a frota
	for train in GameManager.fleet:
		if train["loaded_packages"].size() > 0:
			var route_str = train.get("temp_route_str", "Desconhecida")
			
			# Escreve cada pacote entregue no Livro de Registros
			for pkg in train["loaded_packages"]:
				# --- NOVO: LÊ O LUCRO E PAGA O JOGADOR NA ENTREGA ---
				var profit_final = pkg.get("net_profit", pkg["base_reward"])
				var record = {
					"day": GameManager.current_day,
					"train_name": train["name"],
					"route": route_str,
					"item": pkg["declared_item"],
					"weight": pkg["true_weight"],
					"profit": profit_final
				}
				GameManager.delivery_history.append(record)
				GameManager.money += profit_final # O dinheiro entra no caixa do jogador aqui!
				
			# Esvazia os vagões para o dia seguinte
			train["loaded_packages"].clear()
			train["current_weight"] = 0.0
			train.erase("temp_route_str")
			
	# Devolve o jogador para a mesa para finalizar o dia e cobrar a manutenção
	var main_node = get_parent()
	if main_node.has_method("go_to_desk"):
		main_node.go_to_desk()
