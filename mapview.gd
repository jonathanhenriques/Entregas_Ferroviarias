extends Node2D

var ui_layer: CanvasLayer

# === NOVAS VARIÁVEIS DA FASE 4 ===
var status_panel: ColorRect
var status_vbox: VBoxContainer

const TILE_SIZE: int = 32
# Grelha restaurada para 2/3 da tela (40 colunas * 32px = 1280px)
var grid_width: int = 40  
var grid_height: int = 34 

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

# === VARIÁVEIS DA ESTAÇÃO DE TRIAGEM ===
var inspection_bg: ColorRect
var desk_bg: ColorRect 
var lbl_queue_count: Label
var btn_lever: Button
var btn_xray: Button
var scale_needle: ColorRect
var lbl_scale_digital: Label
var box_visual: ColorRect
var box_stamp: ColorRect
var box_xray_poly: Polygon2D
var clip_content: Label
var clip_weight: Label
var clip_stamp: Label
var btn_approve_pkg: Button
var btn_reject_pkg: Button
var lbl_strike_warning: Label

var current_package: Dictionary = {}
var is_xray_on: bool = false

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

func _ready() -> void:
	_validate_saved_routes()
	_generate_biomes()
	_setup_ui()
	_setup_status_panel() # <--- NOVA CHAMADA AQUI
	
	confirmed_routes = GameManager.saved_routes.duplicate()
	
	_check_disasters()
	_update_network_status()
	
	visibility_changed.connect(_on_visibility_changed)
	GameManager.package_queue_updated.connect(_on_queue_updated)
	GameManager.strike_received.connect(_on_strike_received)
	GameManager.contracts_updated.connect(_update_status_panel) # <--- NOVA CONEXÃO
	
	_on_queue_updated(GameManager.package_queue.size())
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
		_update_status_panel() # <--- ATUALIZA O STATUS AO ABRIR O MAPA
		
		if not GameManager.pending_blueprint.is_empty():
			btn_edit_mode.text = "[ PLANTA PENDENTE ]"
			btn_edit_mode.disabled = true
			btn_edit_mode.add_theme_color_override("font_color", Color.ORANGE)
		else:
			btn_edit_mode.text = "[ MODO OBRAS ]"
			btn_edit_mode.disabled = false
			btn_edit_mode.add_theme_color_override("font_color", Color.YELLOW)
			
		if GameManager.pendent_strike_warning != "":
			_show_strike_warning(GameManager.pendent_strike_warning)
			GameManager.pendent_strike_warning = ""



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

	var map_limit_x = grid_width * TILE_SIZE 
	var right_panel_width = 1920 - map_limit_x 
	
	# ==========================================================
	# 1. ESTAÇÃO DE TRIAGEM (Quadrante Direito) - INTACTA
	# ==========================================================
	inspection_bg = ColorRect.new()
	inspection_bg.color = Color(0.12, 0.14, 0.16)
	inspection_bg.size = Vector2(right_panel_width, 1080)
	inspection_bg.position = Vector2(map_limit_x, 0)
	ui_layer.add_child(inspection_bg)
	
	var insp_border = ReferenceRect.new()
	insp_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	insp_border.border_color = Color(0.3, 0.3, 0.35)
	insp_border.border_width = 4
	inspection_bg.add_child(insp_border)

	lbl_queue_count = Label.new()
	lbl_queue_count.text = "FILA: 0 ENCOMENDAS"
	lbl_queue_count.add_theme_font_size_override("font_size", 18)
	lbl_queue_count.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
	lbl_queue_count.position = Vector2(400, 20)
	inspection_bg.add_child(lbl_queue_count)

	lbl_timer = Label.new()
	lbl_timer.text = "PARTIDA EM: 00:00"
	lbl_timer.add_theme_font_size_override("font_size", 20)
	lbl_timer.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	lbl_timer.position = Vector2(400, 50)
	inspection_bg.add_child(lbl_timer)

	var scale_base = ColorRect.new()
	scale_base.color = Color(0.7, 0.75, 0.7)
	scale_base.size = Vector2(160, 130)
	scale_base.position = Vector2(240, 10)
	inspection_bg.add_child(scale_base)
	
	var scale_circle = ColorRect.new() 
	scale_circle.color = Color(0.9, 0.9, 0.9)
	scale_circle.size = Vector2(140, 110)
	scale_circle.position = Vector2(10, 10)
	scale_base.add_child(scale_circle)
	
	var scale_center = Vector2(70, 70)
	for i in range(11):
		var angle = lerp(-PI * 0.8, PI * 0.8, i / 10.0)
		var tick = ColorRect.new()
		tick.color = Color.BLACK
		tick.size = Vector2(4, 10)
		tick.pivot_offset = Vector2(2, 5)
		tick.position = (scale_center + Vector2(sin(angle), -cos(angle)) * 50) - tick.pivot_offset
		tick.rotation = angle
		scale_circle.add_child(tick)

	scale_needle = ColorRect.new()
	scale_needle.color = Color(0.8, 0.1, 0.1)
	scale_needle.size = Vector2(4, 60)
	scale_needle.pivot_offset = Vector2(2, 50)
	scale_needle.position = scale_center - Vector2(2, 50)
	scale_needle.rotation = -PI * 0.8
	scale_circle.add_child(scale_needle)
	
	lbl_scale_digital = Label.new()
	lbl_scale_digital.text = "0.0 kg"
	lbl_scale_digital.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_scale_digital.add_theme_color_override("font_color", Color.BLACK)
	lbl_scale_digital.position = Vector2(0, 80)
	lbl_scale_digital.size = Vector2(140, 30)
	scale_circle.add_child(lbl_scale_digital)

	var conveyor = ColorRect.new()
	conveyor.color = Color(0.10, 0.11, 0.12)
	conveyor.size = Vector2(640, 160)
	conveyor.position = Vector2(0, 150)
	inspection_bg.add_child(conveyor)
	
	for i in range(15):
		var roller = ColorRect.new()
		roller.color = Color(0.2, 0.22, 0.25)
		roller.size = Vector2(10, 160)
		roller.position = Vector2(i * 45, 0)
		conveyor.add_child(roller)

	box_visual = ColorRect.new()
	box_visual.size = Vector2(140, 120)
	box_visual.position = Vector2(-200, 170) 
	box_visual.visible = false
	inspection_bg.add_child(box_visual)
	
	box_stamp = ColorRect.new()
	box_stamp.size = Vector2(30, 30)
	box_stamp.position = Vector2(90, 20)
	box_visual.add_child(box_stamp)
	
	box_xray_poly = Polygon2D.new()
	box_xray_poly.color = Color(0.05, 0.2, 0.05, 0.9)
	box_xray_poly.visible = false
	box_visual.add_child(box_xray_poly)

	var scanner_arch = ColorRect.new()
	scanner_arch.color = Color(0.12, 0.12, 0.15, 0.85)
	scanner_arch.size = Vector2(180, 200)
	scanner_arch.position = Vector2(230, 130)
	inspection_bg.add_child(scanner_arch)

	lbl_strike_warning = Label.new()
	lbl_strike_warning.add_theme_color_override("font_color", Color.RED)
	lbl_strike_warning.add_theme_font_size_override("font_size", 18)
	lbl_strike_warning.size = Vector2(600, 40)
	lbl_strike_warning.position = Vector2(20, 320)
	lbl_strike_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_strike_warning.visible = false
	inspection_bg.add_child(lbl_strike_warning)

	desk_bg = ColorRect.new()
	desk_bg.color = Color(0.4, 0.28, 0.2) 
	desk_bg.size = Vector2(right_panel_width, 730)
	desk_bg.position = Vector2(0, 350)
	inspection_bg.add_child(desk_bg)
	
	var desk_border = ReferenceRect.new()
	desk_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	desk_border.border_color = Color(0.2, 0.1, 0.05)
	desk_border.border_width = 8
	desk_bg.add_child(desk_border)

	btn_lever = Button.new()
	btn_lever.text = "[ CHUTA ALAVANCA ]\nChamar Encomenda"
	btn_lever.size = Vector2(160, 60)
	btn_lever.position = Vector2(40, 40)
	btn_lever.pressed.connect(_on_btn_lever_pressed)
	desk_bg.add_child(btn_lever)

	btn_xray = Button.new()
	btn_xray.text = "[ LIGAR RAIO-X ]\nCusto: $15"
	btn_xray.size = Vector2(160, 60)
	btn_xray.position = Vector2(240, 40)
	btn_xray.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	btn_xray.pressed.connect(_on_btn_xray_pressed)
	desk_bg.add_child(btn_xray)

	btn_approve_pkg = Button.new()
	btn_approve_pkg.text = "[ CARREGAR NO TREM ]\n(Validado)"
	btn_approve_pkg.size = Vector2(200, 60)
	btn_approve_pkg.position = Vector2(40, 120) 
	btn_approve_pkg.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2))
	btn_approve_pkg.pressed.connect(_on_approve_pkg_pressed)
	desk_bg.add_child(btn_approve_pkg)
	
	btn_reject_pkg = Button.new()
	btn_reject_pkg.text = "[ DEVOLVER REMETENTE ]\n(Fraude)"
	btn_reject_pkg.size = Vector2(200, 60)
	btn_reject_pkg.position = Vector2(260, 120) 
	btn_reject_pkg.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	btn_reject_pkg.pressed.connect(_on_reject_pkg_pressed)
	desk_bg.add_child(btn_reject_pkg)

	var clipboard_bg = ColorRect.new()
	clipboard_bg.color = Color(0.85, 0.8, 0.65)
	clipboard_bg.size = Vector2(280, 400)
	clipboard_bg.position = Vector2(40, 220) 
	desk_bg.add_child(clipboard_bg)
	
	var clip_metal = ColorRect.new()
	clip_metal.color = Color(0.4, 0.4, 0.45)
	clip_metal.size = Vector2(100, 20)
	clip_metal.position = Vector2(90, 5)
	clipboard_bg.add_child(clip_metal)
	
	var clip_title = Label.new()
	clip_title.text = "MANIFESTO DE CARGA"
	clip_title.add_theme_color_override("font_color", Color.BLACK)
	clip_title.add_theme_font_size_override("font_size", 16)
	clip_title.position = Vector2(20, 40)
	clipboard_bg.add_child(clip_title)

	clip_content = Label.new()
	clip_content.add_theme_color_override("font_color", Color.BLACK)
	clip_content.position = Vector2(20, 80)
	clipboard_bg.add_child(clip_content)
	
	clip_weight = Label.new()
	clip_weight.add_theme_color_override("font_color", Color.BLACK)
	clip_weight.position = Vector2(20, 120)
	clipboard_bg.add_child(clip_weight)
	
	clip_stamp = Label.new()
	clip_stamp.add_theme_color_override("font_color", Color.BLACK)
	clip_stamp.position = Vector2(20, 160)
	clipboard_bg.add_child(clip_stamp)

	var manual_bg = ColorRect.new()
	manual_bg.color = Color(0.7, 0.7, 0.8)
	manual_bg.size = Vector2(260, 400)
	manual_bg.position = Vector2(340, 220)
	desk_bg.add_child(manual_bg)

	var man_title = Label.new()
	man_title.text = "MANUAL DE FISCALIZACAO"
	man_title.add_theme_color_override("font_color", Color.BLACK)
	man_title.position = Vector2(10, 20)
	manual_bg.add_child(man_title)

	var man_text = Label.new()
	man_text.text = "- CARTAS: Selo Branco.\n\n- PERECIVEIS: Selo Verde.\n\n- VALIOSOS: Selo Azul.\n\n* Atencao ao Peso Real!\n* Use Raio-X em Valiosos para\nevitar contrabando d'armas."
	man_text.add_theme_color_override("font_color", Color.DARK_SLATE_GRAY)
	man_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	man_text.size = Vector2(240, 300)
	man_text.position = Vector2(10, 60)
	manual_bg.add_child(man_text)

	# ==========================================================
	# 2. NOVO HUD DO MAPA (MENU INFERIOR E LEGENDA)
	# ==========================================================
	panel_overlay = ColorRect.new()
	panel_overlay.color = Color(0, 0, 0, 0.8) 
	panel_overlay.size = Vector2(1920 - map_limit_x, 1080)
	panel_overlay.position = Vector2(map_limit_x, 0)
	panel_overlay.visible = false
	ui_layer.add_child(panel_overlay)
	
	# LEGENDA DOS BIOMAS
	var legend_bg = ColorRect.new()
	legend_bg.color = Color(0.95, 0.95, 0.95, 0.85)
	legend_bg.size = Vector2(140, 140)
	legend_bg.position = Vector2(20, 140) 
	ui_layer.add_child(legend_bg)
	
	var leg_vbox = VBoxContainer.new()
	leg_vbox.position = Vector2(10, 10)
	leg_vbox.add_theme_constant_override("separation", 6)
	legend_bg.add_child(leg_vbox)
	
	var leg_items = [
		{"name": "Planicie", "color": Color(0.95, 0.95, 0.92)},
		{"name": "Floresta", "color": Color(0.75, 0.88, 0.75)},
		{"name": "Rio", "color": Color(0.65, 0.85, 0.95)},
		{"name": "Montanha", "color": Color(0.85, 0.82, 0.78)},
		{"name": "Gangues", "color": Color(0.9, 0.4, 0.4, 0.4)}
	]
	for item in leg_items:
		var hb = HBoxContainer.new()
		var c_rect = ColorRect.new()
		c_rect.custom_minimum_size = Vector2(16, 16)
		c_rect.color = item["color"]
		var l = Label.new()
		l.text = " " + item["name"]
		l.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		l.add_theme_font_size_override("font_size", 13)
		hb.add_child(c_rect)
		hb.add_child(l)
		leg_vbox.add_child(hb)

	# BARRA INFERIOR (BOTTOM BAR)
	var bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0.1, 0.1, 0.12, 0.95)
	bottom_bar.size = Vector2(map_limit_x, 70)
	bottom_bar.position = Vector2(0, 1080 - 70)
	ui_layer.add_child(bottom_bar)
	
	var map_hbox = HBoxContainer.new()
	map_hbox.position = Vector2(20, 10)
	map_hbox.size = Vector2(map_limit_x - 40, 50)
	map_hbox.add_theme_constant_override("separation", 20)
	bottom_bar.add_child(map_hbox)

	btn_go_desk = Button.new()
	btn_go_desk.text = "<- IR PARA ESCRITORIO"
	btn_go_desk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_go_desk.pressed.connect(_on_go_desk_pressed)
	map_hbox.add_child(btn_go_desk)
	
	btn_edit_mode = Button.new()
	btn_edit_mode.text = "[ ⚠️ OBRAS ]"
	btn_edit_mode.add_theme_color_override("font_color", Color.YELLOW)
	btn_edit_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_edit_mode.pressed.connect(_on_edit_mode_pressed)
	map_hbox.add_child(btn_edit_mode)

	btn_maint = Button.new()
	btn_maint.text = "[ 📖 ORCAMENTO ]"
	btn_maint.add_theme_color_override("font_color", Color.ORANGE)
	btn_maint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_maint.pressed.connect(_on_btn_maint_pressed)
	map_hbox.add_child(btn_maint)

	# ==========================================================
	# 3. PAINÉIS DE POPUP (OBRAS E MANUTENÇÃO)
	# ==========================================================
	var right_center_x = map_limit_x + (right_panel_width / 2.0)

	edit_panel = ColorRect.new()
	edit_panel.color = Color(0.1, 0.1, 0.15, 0.95)
	edit_panel.position = Vector2(right_center_x - 170, 200) 
	edit_panel.size = Vector2(340, 560) 
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
	maint_panel.position = Vector2(right_center_x - 200, 250)
	maint_panel.visible = false
	ui_layer.add_child(maint_panel)

	var border_maint = ReferenceRect.new()
	border_maint.set_anchors_preset(Control.PRESET_FULL_RECT)
	border_maint.border_color = Color.ORANGE
	border_maint.border_width = 3
	maint_panel.add_child(border_maint)

	var lbl_mtitle = Label.new()
	lbl_mtitle.text = "LIVRO DE MANUTENCAO DA MALHA"
	lbl_mtitle.position = Vector2(20, 20)
	lbl_mtitle.add_theme_color_override("font_color", Color.ORANGE)
	maint_panel.add_child(lbl_mtitle)

	var lbl_i = Label.new()
	lbl_i.text = "Infra Pesada (Pontes/Tuneis)"
	lbl_i.position = Vector2(20, 60)
	maint_panel.add_child(lbl_i)
	sld_infra = HSlider.new()
	sld_infra.position = Vector2(20, 85)
	sld_infra.size = Vector2(180, 20)
	sld_infra.min_value = 0
	sld_infra.max_value = 100
	sld_infra.step = 5
	sld_infra.value_changed.connect(_on_sld_infra_changed)
	maint_panel.add_child(sld_infra)
	lbl_infra_val = Label.new()
	lbl_infra_val.position = Vector2(210, 82)
	maint_panel.add_child(lbl_infra_val)

	var lbl_t = Label.new()
	lbl_t.text = "Carris (Velocidade/Quebra)"
	lbl_t.position = Vector2(20, 115)
	maint_panel.add_child(lbl_t)
	sld_tracks = HSlider.new()
	sld_tracks.position = Vector2(20, 140)
	sld_tracks.size = Vector2(180, 20)
	sld_tracks.min_value = 0
	sld_tracks.max_value = 100
	sld_tracks.step = 5
	sld_tracks.value_changed.connect(_on_sld_tracks_changed)
	maint_panel.add_child(sld_tracks)
	lbl_tracks_val = Label.new()
	lbl_tracks_val.position = Vector2(210, 137)
	maint_panel.add_child(lbl_tracks_val)

	var lbl_e = Label.new()
	lbl_e.text = "Controlo Ambiental (Incendios)"
	lbl_e.position = Vector2(20, 170)
	maint_panel.add_child(lbl_e)
	sld_env = HSlider.new()
	sld_env.position = Vector2(20, 195)
	sld_env.size = Vector2(180, 20)
	sld_env.min_value = 0
	sld_env.max_value = 100
	sld_env.step = 5
	sld_env.value_changed.connect(_on_sld_env_changed)
	maint_panel.add_child(sld_env)
	lbl_env_val = Label.new()
	lbl_env_val.position = Vector2(210, 192)
	maint_panel.add_child(lbl_env_val)

	var lbl_s = Label.new()
	lbl_s.text = "Seguranca (Patrulha de Gangues)"
	lbl_s.position = Vector2(20, 225)
	maint_panel.add_child(lbl_s)
	sld_sec = HSlider.new()
	sld_sec.position = Vector2(20, 250)
	sld_sec.size = Vector2(180, 20)
	sld_sec.min_value = 0
	sld_sec.max_value = 100
	sld_sec.step = 5
	sld_sec.value_changed.connect(_on_sld_sec_changed)
	maint_panel.add_child(sld_sec)
	lbl_sec_val = Label.new()
	lbl_sec_val.position = Vector2(210, 247)
	maint_panel.add_child(lbl_sec_val)

	var lbl_c = Label.new()
	lbl_c.text = "Salarios da Equipa"
	lbl_c.position = Vector2(20, 280)
	maint_panel.add_child(lbl_c)
	sld_crew = HSlider.new()
	sld_crew.position = Vector2(20, 305)
	sld_crew.size = Vector2(180, 20)
	sld_crew.min_value = 0
	sld_crew.max_value = 100
	sld_crew.step = 5
	sld_crew.value_changed.connect(_on_sld_crew_changed)
	maint_panel.add_child(sld_crew)
	lbl_crew_val = Label.new()
	lbl_crew_val.position = Vector2(210, 302)
	maint_panel.add_child(lbl_crew_val)

	var lbl_l = Label.new()
	lbl_l.text = "Relacoes Governamentais (Lobby)"
	lbl_l.position = Vector2(20, 335)
	maint_panel.add_child(lbl_l)
	sld_lobby = HSlider.new()
	sld_lobby.position = Vector2(20, 360)
	sld_lobby.size = Vector2(180, 20)
	sld_lobby.min_value = 0
	sld_lobby.max_value = 100
	sld_lobby.step = 5
	sld_lobby.value_changed.connect(_on_sld_lobby_changed)
	maint_panel.add_child(sld_lobby)
	lbl_lobby_val = Label.new()
	lbl_lobby_val.position = Vector2(210, 357)
	maint_panel.add_child(lbl_lobby_val)

	btn_close_maint = Button.new()
	btn_close_maint.text = "FECHAR LIVRO"
	btn_close_maint.position = Vector2(20, 400)
	btn_close_maint.size = Vector2(360, 40)
	btn_close_maint.pressed.connect(_on_btn_close_maint_pressed)
	maint_panel.add_child(btn_close_maint)

	_clear_inspection_desk()



# === LÓGICA DA TRIAGEM ===

func _clear_inspection_desk() -> void:
	box_visual.visible = false
	is_xray_on = false
	scale_needle.rotation = -PI * 0.8
	lbl_scale_digital.text = "0.0 kg"
	clip_content.text = "Aguardando carga..."
	clip_weight.text = ""
	clip_stamp.text = ""
	btn_approve_pkg.disabled = true
	btn_reject_pkg.disabled = true
	btn_xray.disabled = true

func _on_queue_updated(count: int) -> void:
	lbl_queue_count.text = "FILA: " + str(count) + " ENCOMENDAS"
	if count > 0 and current_package.is_empty():
		btn_lever.disabled = false
	else:
		btn_lever.disabled = true

func _on_btn_lever_pressed() -> void:
	if not current_package.is_empty() or GameManager.package_queue.size() == 0: return
	
	btn_lever.disabled = true
	current_package = GameManager.package_queue.pop_front()
	GameManager.package_queue_updated.emit(GameManager.package_queue.size())
	
	is_xray_on = false
	box_visual.color = Color(0.7, 0.55, 0.4) 
	box_xray_poly.visible = false
	btn_xray.disabled = false
	
	clip_content.text = "Declarado: " + current_package["declared_item"]
	clip_weight.text = "Peso Decl.: " + str(current_package["declared_weight"]) + " kg"
	clip_stamp.text = "Selo: " + current_package["stamp_used"]
	
	if current_package["stamp_used"] == "Selo Branco": 
		box_stamp.color = Color.WHITE
	else:
		if current_package["stamp_used"] == "Selo Verde": 
			box_stamp.color = Color(0.2, 0.8, 0.2)
		else:
			if current_package["stamp_used"] == "Selo Azul": 
				box_stamp.color = Color(0.2, 0.2, 0.8)
	
	# Animação HORIZONTAL: Surge da esquerda (-200, 170) para o meio (250, 170)
	box_visual.position = Vector2(-200, 170)
	box_visual.visible = true
	var tw = create_tween()
	tw.tween_property(box_visual, "position", Vector2(250, 170), 0.5).set_ease(Tween.EASE_OUT)
	
	var target_w = current_package["true_weight"]
	var angle = lerp(-PI * 0.8, PI * 0.8, clamp(target_w / 50.0, 0.0, 1.0))
	tw.parallel().tween_property(scale_needle, "rotation", angle, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	await tw.finished
	lbl_scale_digital.text = str(target_w) + " kg"
	btn_approve_pkg.disabled = false
	btn_reject_pkg.disabled = false

func _on_btn_xray_pressed() -> void:
	if current_package.is_empty() or is_xray_on or GameManager.money < 15: return
	
	GameManager.money -= 15
	is_xray_on = true
	btn_xray.disabled = true
	
	box_visual.color = Color(0.1, 0.8, 0.2, 0.85) 
	box_stamp.color = Color.TRANSPARENT 
	
	var points = PackedVector2Array()
	if current_package.get("is_contraband", false):
		# Silhueta de armas
		points = PackedVector2Array([Vector2(20, 60), Vector2(80, 60), Vector2(80, 50), Vector2(120, 50), Vector2(120, 60), Vector2(140, 60), Vector2(140, 70), Vector2(60, 70), Vector2(40, 90), Vector2(20, 90)])
	else:
		if current_package.get("true_category", "") == "Cartas":
			# Silhueta de envelopes
			points = PackedVector2Array([Vector2(30, 50), Vector2(110, 50), Vector2(110, 90), Vector2(30, 90)])
		else:
			if current_package.get("true_category", "") == "Perecivel": 
				# Silhueta de garrafas/carne
				points = PackedVector2Array([Vector2(60, 30), Vector2(80, 30), Vector2(80, 60), Vector2(100, 80), Vector2(100, 110), Vector2(40, 110), Vector2(40, 80), Vector2(60, 60)])
			else:
				if current_package.get("true_category", "") == "Valioso": 
					# Silhueta joias
					points = PackedVector2Array([Vector2(70, 40), Vector2(100, 70), Vector2(70, 100), Vector2(40, 70)])
		
	box_xray_poly.polygon = points
	box_xray_poly.visible = true

func _on_approve_pkg_pressed() -> void:
	_process_decision(true)

func _on_reject_pkg_pressed() -> void:
	_process_decision(false)

func _process_decision(approved: bool) -> void:
	btn_approve_pkg.disabled = true
	btn_reject_pkg.disabled = true
	btn_xray.disabled = true
	
	var is_fraud = current_package.get("is_contraband", false) or current_package["true_weight"] != current_package["declared_weight"] or current_package["stamp_used"] != current_package["true_stamp"]

	if approved:
		if current_package.get("is_contraband", false):
			if not GameManager.first_fiscal_warning_done:
				GameManager.first_fiscal_warning_done = true
				GameManager.pendent_strike_warning = "AVISO OFICIAL: Aprovou carga ilegal. Como e a primeira vez, a coima foi perdoada. Cuidado!"
				_show_strike_warning(GameManager.pendent_strike_warning)
			else:
				var fine = 1500
				GameManager.pending_fiscal_event = {
					"reason": "CONTRABANDO: O seu posto aprovou carga ilegal oculta! O Raio-X deveria ter sido usado!",
					"fine": fine,
					"can_bribe": (GameManager.maint_pct_lobby >= 0.7),
					"bribe_cost": int(fine * 0.15),
					"contract_name": "Remetente Avulso"
				}
		else:
			if is_fraud:
				if not GameManager.first_fiscal_warning_done:
					GameManager.first_fiscal_warning_done = true
					GameManager.pendent_strike_warning = "AVISO OFICIAL: Aprovou carga com peso ou selo fraudado. A coima foi perdoada desta vez!"
					_show_strike_warning(GameManager.pendent_strike_warning)
				else:
					if GameManager.has_method("add_strike"): GameManager.add_strike("Voce enviou uma carga com peso ou selo fraudado!")
			else:
				# NOVO CÁLCULO DE LUCRO (Recompensa - Custo do Peso Real)
				if GameManager.has_method("process_package_approval"):
					GameManager.process_package_approval(current_package)
	else:
		if not is_fraud:
			if GameManager.has_method("add_strike"): GameManager.add_strike("Voce bloqueou uma carga valida. O cliente abriu uma queixa!")
	
	var tw = create_tween()
	if approved:
		tw.tween_property(box_visual, "position", Vector2(700, 170), 0.5) 
	else:
		tw.tween_property(box_visual, "position", Vector2(-200, 170), 0.5) 

	await tw.finished
	current_package = {}
	_clear_inspection_desk()
	_on_queue_updated(GameManager.package_queue.size())



func _show_strike_warning(msg: String) -> void:
	lbl_strike_warning.text = "[!] " + msg
	lbl_strike_warning.visible = true
	var tw = create_tween()
	tw.tween_property(lbl_strike_warning, "modulate:a", 0.0, 0.5).set_delay(4.0)
	await tw.finished
	lbl_strike_warning.visible = false
	lbl_strike_warning.modulate.a = 1.0

func _on_strike_received(total: int, reason: String) -> void:
	_show_strike_warning(reason + " (" + str(total) + "/3 Ocorrencias)")

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
	maint_panel.visible = false
	
	draft_paths.clear()
	deleted_paths.clear()
	tentative_path.clear()
	repair_tiles.clear()
	
	panel_overlay.visible = true # ESCURECE A TELA
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
	
	draft_paths.clear()
	deleted_paths.clear()
	tentative_path.clear()
	repair_tiles.clear()
	queue_redraw()



func _on_confirm_edit_pressed() -> void:
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
		route_desc_string += "Ligacao: Estacao Azul para Vermelha\n"
	if _bfs_shortest_dist(city_a, city_c, untouched, false, false) == -1: 
		r_cd.append("Azul-Verde")
		route_desc_string += "Ligacao: Estacao Azul para Verde\n"
	if _bfs_shortest_dist(city_b, city_c, untouched, false, false) == -1: 
		r_cd.append("Vermelha-Verde")
		route_desc_string += "Ligacao: Estacao Vermelha para Verde\n"
		
	if route_desc_string == "": route_desc_string = "Manutencao ou Demolicao da Malha"

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
		"route_description": route_desc_string
	}
	
	GameManager.save_game()
	
	# === CORREÇÃO DO BUG ===
	# 1. Limpa o modo de edição visualmente
	_on_cancel_edit_pressed() 
	
	# 2. Atualiza as rotas confirmadas a partir do estado atualizado do GameManager
	confirmed_routes = GameManager.saved_routes.duplicate()
	
	# 3. Força um redesenho imediato para garantir que a planta gerada apareça
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

	# CORREÇÃO DE CONEXÃO: Analisa os rascunhos E as rotas já existentes validando o tile da cidade
	var temp_valid = {}
	for r in confirmed_routes:
		if not deleted_paths.has(r):
			for cell in r: temp_valid[cell] = true
	for r in draft_paths:
		for cell in r: temp_valid[cell] = true
		
	# Adiciona as cidades para o BFS conseguir encontra-las
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
	t += "[ DETALHES DA OBRA ]\nDistancia Construcao: " + str(dist_total) + " km\n"
	if tunnel_count > 0: t += "- Tuneis: " + str(tunnel_count) + "\n"
	if bridge_count > 0: t += "- Pontes: " + str(bridge_count) + "\n"
	if forest_count > 0: t += "- Desmatamento: " + str(forest_count) + "\n"
	if repair_tiles.size() > 0: t += "Reparos Solicitados: " + str(repair_tiles.size()) + "\n"
	
	t += "\n[ TAXAS GOVERNAMENTAIS ]\n"
	if current_env_tax > 0: t += "Licenca Ambiental: $" + str(current_env_tax) + "\n"
	if current_eng_tax > 0: t += "Licenca de Engenharia: $" + str(current_eng_tax) + "\n"
	if current_sec_tax > 0: t += "Taxa Seg. Armada: $" + str(current_sec_tax) + "\n"
	if current_env_tax == 0 and current_eng_tax == 0 and current_sec_tax == 0: t += "Isento de taxas especiais.\n"

	t += "\n[ FINANCEIRO ]\n"
	if build_cost > 0: t += "Novas Obras: $" + str(build_cost) + "\n"
	if repair_cost > 0: t += "Custos de Reparo: $" + str(repair_cost) + "\n"
	if refund_val > 0: t += "Reembolso Demolicao: +$" + str(refund_val) + "\n"
	t += "---------------------------\nCUSTO TOTAL DO PROJETO: $" + str(current_total_cost) + "\n"
	
	if draft_paths.size() > 0 or deleted_paths.size() > 0 or repair_tiles.size() > 0:
		if not has_conn and draft_paths.size() > 0:
			is_valid = false
			t += "\n[ ERRO: Rota desenhada nao toca nas estacoes! ]"
		else:
			if routes_created_msg != "":
				t += "\n[ CONEXOES ASSEGURADAS ]" + routes_created_msg + "\n"
				
		if current_total_cost > GameManager.money:
			is_valid = false
			t += "\n[ ERRO: Fundos Insuficientes! ]"
	else:
		is_valid = false
		t += "\nNenhuma alteracao projetada."

	edit_info.text = t
	btn_confirm.disabled = not is_valid




func _process(delta: float) -> void:
	if not visible: return
	
	# ATUALIZA O RELÓGIO DA TRIAGEM
	if is_instance_valid(lbl_timer):
		if GameManager.shift_active and GameManager.boss_package_intro_done:
			var m = int(GameManager.shift_time_left) / 60
			var s = int(GameManager.shift_time_left) % 60
			lbl_timer.text = "PARTIDA EM: %02d:%02d" % [m, s]
		else:
			lbl_timer.text = "AGUARDANDO COMBOIO"
	
	var needs_redraw = false
	for i in range(GameManager.active_contracts.size()):
		var c = GameManager.active_contracts[i]
		var is_op = GameManager.is_contract_operating(c)
		var is_under_construction = (GameManager.routes_under_construction.get(c["route_id"], 0) > 0)
		var has_physical_route = (c["route_id"] in GameManager.network_connections)

		if (is_op or is_under_construction) and has_physical_route:
			needs_redraw = true
			if not active_trains.has(i): _spawn_train(i, c)
			else:
				if is_op and not is_edit_mode: _move_train(i, delta)
		else:
			if active_trains.has(i):
				active_trains.erase(i)
				needs_redraw = true

	var keys = active_trains.keys()
	for k in keys:
		if k >= GameManager.active_contracts.size():
			active_trains.erase(k)
			needs_redraw = true

	if needs_redraw: queue_redraw()



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
	var default_font = ThemeDB.fallback_font
	
	# 1. BIOMAS E FUNDO (Cores sólidas minimalistas)
	for x in range(grid_width):
		for y in range(grid_height):
			var cell = Vector2i(x, y)
			var rect = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var b = biome_map.get(cell, Biome.PLAIN)
			
			var bg_color = Color(0.95, 0.95, 0.92) # Planície (Bege muito claro)
			if b == Biome.FOREST: bg_color = Color(0.75, 0.88, 0.75) # Verde suave
			elif b == Biome.MOUNTAIN: bg_color = Color(0.85, 0.82, 0.78) # Cinza/Castanho suave
			elif b == Biome.RIVER: bg_color = Color(0.65, 0.85, 0.95) # Azul suave
			
			draw_rect(rect, bg_color)
			
			# Área de Gangues (Subtil sobreposição avermelhada)
			if gang_map.has(cell):
				draw_rect(rect, Color(0.9, 0.4, 0.4, 0.25))
				
			# Grelha Subtil (Para manter a jogabilidade de construção precisa)
			draw_rect(rect, Color(0.0, 0.0, 0.0, 0.04), false, 1.0)
			
	# 2. DESMATAÇÃO VISUAL (Madeira/Terra cortada na floresta)
	var built_cells = {}
	for r in confirmed_routes:
		for c in r: built_cells[c] = true
	for p in draft_paths:
		for c in p: built_cells[c] = true
		
	for cell in built_cells.keys():
		if biome_map.get(cell) == Biome.FOREST:
			var center = _get_center(cell)
			# Círculo castanho simbolizando a terra aberta na floresta
			draw_circle(center, TILE_SIZE * 0.35, Color(0.55, 0.4, 0.3))

	# 3. CARRIS (Linhas vetoriais grossas e contínuas)
	for r in confirmed_routes:
		if deleted_paths.has(r): continue
		_draw_vector_path(r, Color(0.2, 0.2, 0.22), 8.0) # Carril Padrão
		
	for p in draft_paths:
		_draw_vector_path(p, Color(0.2, 0.6, 0.8, 0.85), 8.0) # Carril em Rascunho (Azul)
		
	if tentative_path.size() > 0:
		_draw_vector_path(tentative_path, Color(0.8, 0.8, 0.2, 0.8), 6.0) # Traçando (Amarelo)
		
	for p in deleted_paths:
		_draw_vector_path(p, Color(0.9, 0.2, 0.2, 0.6), 6.0) # Rota a ser demolida
		
	# 4. MANUTENÇÃO E FALHAS
	for cell in repair_tiles:
		draw_circle(_get_center(cell), TILE_SIZE * 0.4, Color(0.9, 0.8, 0.2, 0.6))
		
	for cell in GameManager.broken_tiles:
		var center = _get_center(cell)
		draw_circle(center, TILE_SIZE * 0.4, Color(0.9, 0.2, 0.2, 0.7))
		draw_string(default_font, center + Vector2(-6, 6), "X", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)

	# 5. CIDADES (Nomes e Ícones Minimalistas)
	if city_a != Vector2i(-1, -1):
		_draw_city(city_a, Color(0.2, 0.4, 0.8), "Cidade A (Azul)")
	if city_b != Vector2i(-1, -1):
		_draw_city(city_b, Color(0.8, 0.2, 0.2), "Cidade B (Vermelha)")
	if city_c != Vector2i(-1, -1):
		_draw_city(city_c, Color(0.2, 0.7, 0.3), "Cidade C (Verde)")





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
		# GAIOLA: Bloqueia cliques fora dos 1280px (Área do Mapa)
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			if event.position.x > grid_width * TILE_SIZE: return

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
	
	
	
	
	
# === FASE 5: IDENTIDADE VISUAL MINIMALISTA (HELPERS) ===

func _get_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)

func _draw_vector_path(path: Array, color: Color, width: float) -> void:
	if path.size() == 0: return
	if path.size() == 1:
		draw_circle(_get_center(path[0]), width / 2.0, color)
		return
		
	var pts = PackedVector2Array()
	for c in path:
		pts.append(_get_center(c))
		
	# Desenha a linha grossa e contínua
	draw_polyline(pts, color, width, true)
	
	# Desenha círculos nas pontas e esquinas para arredondar o traço
	for pt in pts:
		draw_circle(pt, width / 2.0, color)

func _draw_city(cell: Vector2i, color: Color, name: String) -> void:
	var center = _get_center(cell)
	
	# Desenha a "Estação" (Forma geométrica limpa com interior branco)
	draw_rect(Rect2(center.x - 14, center.y - 14, 28, 28), color)
	draw_rect(Rect2(center.x - 7, center.y - 7, 14, 14), Color.WHITE)
	
	# Desenha o nome da Cidade
	var default_font = ThemeDB.fallback_font
	var text_size = default_font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(default_font, center + Vector2(-text_size.x / 2.0, 30), name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.1, 0.1, 0.15))
	
	
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
	if not is_instance_valid(status_vbox): return
	for child in status_vbox.get_children():
		child.queue_free()
		
	var routes_to_check = [
		{"id": "Azul-Vermelha", "name": "Azul <-> Vermelha"},
		{"id": "Azul-Verde", "name": "Azul <-> Verde"},
		{"id": "Vermelha-Verde", "name": "Vermelha <-> Verde"}
	]
	
	for r in routes_to_check:
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
		elif is_broken:
			status_text = "Interditada (Falha na Via)"
			color = Color.CRIMSON
		elif not is_built:
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
