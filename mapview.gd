extends Node2D

var ui_layer: CanvasLayer

const TILE_SIZE: int = 32

var grid_width: int = 60
var grid_height: int = 34 

enum Biome { PLAIN, FOREST, MOUNTAIN, RIVER }

const BIOME_DATA = {
	Biome.PLAIN: {"build": 20, "maint": 2, "color": Color(0.65, 0.75, 0.55)},
	Biome.FOREST: {"build": 35, "maint": 5, "color": Color(0.25, 0.45, 0.25)}, 
	Biome.MOUNTAIN: {"build": 400, "maint": 10, "color": Color(0.55, 0.45, 0.35)}, 
	Biome.RIVER: {"build": 600, "maint": 15, "color": Color(0.3, 0.6, 0.8)} 
}

const GANG_TOLL_RATE: int = 100 

var biome_map: Dictionary = {}
var gang_map: Dictionary = {} 

var city_a: Vector2i = Vector2i(-1, -1) 
var city_b: Vector2i = Vector2i(-1, -1) 
var city_c: Vector2i = Vector2i(-1, -1) 

var confirmed_routes: Array = [] 

# =======================================
# VARIAVEIS DO MODO DE OBRAS (RASCUNHO)
# =======================================
var is_edit_mode: bool = false
var is_dragging: bool = false
var tentative_path: Array[Vector2i] = []

var draft_paths: Array = []
var deleted_paths: Array = []

var btn_edit_mode: Button
var btn_go_desk: Button

var edit_panel: ColorRect
var edit_info: Label
var btn_confirm: Button
var btn_cancel: Button

var net_cost: int = 0
var net_maint: int = 0

var active_trains: Dictionary = {}

func _ready() -> void:
	_generate_biomes()
	_setup_ui()
	
	confirmed_routes = GameManager.saved_routes.duplicate()
	
	_update_network_status()
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if ui_layer:
		ui_layer.visible = visible
	if visible:
		confirmed_routes = GameManager.saved_routes.duplicate()
		_update_network_status()

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
			
			if char == ".": 
				biome_map[cell] = Biome.PLAIN
			else:
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
								biome_map[cell] = Biome.PLAIN 
								city_a = cell
							else:
								if char == "B":
									biome_map[cell] = Biome.PLAIN
									city_b = cell
								else:
									if char == "C":
										biome_map[cell] = Biome.PLAIN
										city_c = cell

	if level_info.has("gang_layout"):
		var g_layout = level_info["gang_layout"]
		for y in range(g_layout.size()):
			var row = g_layout[y]
			for x in range(row.length()):
				if row[x] == "G":
					gang_map[Vector2i(x + offset_x, y + offset_y)] = true

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	btn_go_desk = Button.new()
	btn_go_desk.text = "<- Ir para a Mesa"
	btn_go_desk.position = Vector2(40, 40)
	btn_go_desk.size = Vector2(180, 40)
	btn_go_desk.pressed.connect(_on_go_desk_pressed)
	ui_layer.add_child(btn_go_desk)
	
	btn_edit_mode = Button.new()
	btn_edit_mode.text = "[ ENTRAR MODO DE OBRAS ]"
	btn_edit_mode.position = Vector2(240, 40)
	btn_edit_mode.size = Vector2(250, 40)
	btn_edit_mode.add_theme_color_override("font_color", Color.YELLOW)
	btn_edit_mode.pressed.connect(_on_edit_mode_pressed)
	ui_layer.add_child(btn_edit_mode)

	# NOVO: Painel de Engenharia Burocrática
	edit_panel = ColorRect.new()
	edit_panel.color = Color(0.1, 0.1, 0.15, 0.95)
	edit_panel.position = Vector2(1550, 100) 
	edit_panel.size = Vector2(320, 360) 
	edit_panel.visible = false
	ui_layer.add_child(edit_panel)
	
	var border = ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color.GOLDENROD
	border.border_width = 3
	edit_panel.add_child(border)

	edit_info = Label.new()
	edit_info.position = Vector2(15, 15)
	edit_info.size = Vector2(290, 260) 
	edit_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	edit_info.add_theme_font_size_override("font_size", 18)
	edit_panel.add_child(edit_info)

	btn_confirm = Button.new()
	btn_confirm.text = "CONFIRMAR OBRAS"
	btn_confirm.position = Vector2(15, 300) 
	btn_confirm.size = Vector2(140, 45)
	btn_confirm.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	btn_confirm.pressed.connect(_on_confirm_edit_pressed)
	edit_panel.add_child(btn_confirm)

	btn_cancel = Button.new()
	btn_cancel.text = "DESCARTAR TUDO"
	btn_cancel.position = Vector2(165, 300) 
	btn_cancel.size = Vector2(140, 45)
	btn_cancel.add_theme_color_override("font_color", Color.INDIAN_RED)
	btn_cancel.pressed.connect(_on_cancel_edit_pressed)
	edit_panel.add_child(btn_cancel)

func _on_go_desk_pressed() -> void:
	var main_node = get_parent()
	if main_node.has_method("go_to_desk"):
		main_node.go_to_desk()

func _on_edit_mode_pressed() -> void:
	is_edit_mode = true
	btn_edit_mode.visible = false
	btn_go_desk.visible = false
	
	draft_paths.clear()
	deleted_paths.clear()
	tentative_path.clear()
	
	edit_panel.visible = true
	_update_edit_panel()
	queue_redraw()

func _on_cancel_edit_pressed() -> void:
	is_edit_mode = false
	edit_panel.visible = false
	btn_edit_mode.visible = true
	btn_go_desk.visible = true
	
	draft_paths.clear()
	deleted_paths.clear()
	tentative_path.clear()
	queue_redraw()

# NOVO: O painel que valida a engneharia da via!
func _update_edit_panel() -> void:
	var cost = 0
	var maint = 0
	var has_gangs = false
	
	for path in draft_paths:
		for cell in path:
			var b = biome_map.get(cell, Biome.PLAIN)
			cost += BIOME_DATA[b]["build"]
			maint += BIOME_DATA[b]["maint"]
			if gang_map.has(cell):
				has_gangs = true

	var refund = 0
	var r_maint = 0
	for path in deleted_paths:
		for cell in path:
			var b = biome_map.get(cell, Biome.PLAIN)
			refund += BIOME_DATA[b]["build"]
			r_maint += BIOME_DATA[b]["maint"]

	net_cost = cost - refund
	net_maint = maint - r_maint

	var temp_valid = {}
	for r in confirmed_routes:
		if not deleted_paths.has(r):
			for cell in r:
				temp_valid[cell] = true
	for r in draft_paths:
		for cell in r:
			temp_valid[cell] = true

	temp_valid[city_a] = true
	temp_valid[city_b] = true
	temp_valid[city_c] = true

	var has_conn = false
	if _bfs_shortest_dist(city_a, city_b, temp_valid, false, false) != -1: has_conn = true
	if _bfs_shortest_dist(city_a, city_c, temp_valid, false, false) != -1: has_conn = true
	if _bfs_shortest_dist(city_b, city_c, temp_valid, false, false) != -1: has_conn = true

	var is_valid = true
	var t = "== PROJETO DE ENGENHARIA ==\n\n"

	if has_gangs:
		t += "[!] CUIDADO: Obras em zona de gangues!\n\n"

	t += "Novos Trilhos: $" + str(cost) + "\n"
	t += "Reembolso Demolicao: +$" + str(refund) + "\n"
	t += "CUSTO LIQUIDO: $" + str(net_cost) + "\n\n"
	t += "Nova Manutencao: $" + str(net_maint) + " /dia\n\n"

	if draft_paths.size() > 0 or deleted_paths.size() > 0:
		if not has_conn:
			var total_tiles = temp_valid.size()
			if total_tiles > 3: 
				is_valid = false
				t += "[ ERRO: A malha nao conecta nenhuma cidade! ]\n"
		
		if net_cost > GameManager.money:
			is_valid = false
			t += "[ ERRO: Voce nao tem fundos no Caixa! ]\n"
	else:
		is_valid = false
		t += "Nenhuma alteracao estrutural desenhada."

	edit_info.text = t
	btn_confirm.disabled = not is_valid

func _on_confirm_edit_pressed() -> void:
	GameManager.money -= net_cost
	GameManager.daily_maintenance += net_maint
	
	for d in deleted_paths:
		confirmed_routes.erase(d)
		
	for p in draft_paths:
		confirmed_routes.append(p.duplicate())
		
	GameManager.saved_routes = confirmed_routes.duplicate() 
	
	_update_network_status()
	
	# O CASTIGO DAS OBRAS: As rotas afetadas ganham 2 dias de cooldown!
	for rid in GameManager.network_connections:
		GameManager.routes_under_construction[rid] = 2
		
	GameManager.contracts_updated.emit()
	GameManager.save_game()
	
	_on_cancel_edit_pressed() 

func _process(delta: float) -> void:
	if not visible: return
	
	var needs_redraw = false
	
	for i in range(GameManager.active_contracts.size()):
		var c = GameManager.active_contracts[i]
		var is_op = GameManager.is_contract_operating(c)
		var is_under_construction = (GameManager.routes_under_construction.get(c["route_id"], 0) > 0)
		var has_physical_route = (c["route_id"] in GameManager.network_connections)

		if (is_op or is_under_construction) and has_physical_route:
			needs_redraw = true
			if not active_trains.has(i):
				_spawn_train(i, c)
			else:
				if is_op and not is_edit_mode:
					_move_train(i, delta)
		else:
			if active_trains.has(i):
				active_trains.erase(i)
				needs_redraw = true

	var keys = active_trains.keys()
	for k in keys:
		if k >= GameManager.active_contracts.size():
			active_trains.erase(k)
			needs_redraw = true

	if needs_redraw:
		queue_redraw()

func _spawn_train(contract_index: int, contract: Dictionary) -> void:
	var route_id = contract["route_id"]
	var start_city = Vector2i(-1, -1)
	var target_city = Vector2i(-1, -1)

	if "Azul" in route_id and "Vermelha" in route_id:
		start_city = city_a
		target_city = city_b
	else:
		if "Azul" in route_id and "Verde" in route_id:
			start_city = city_a
			target_city = city_c
		else:
			if "Vermelha" in route_id and "Verde" in route_id:
				start_city = city_b
				target_city = city_c

	var valid_tiles = {}
	for r in confirmed_routes:
		for cell in r: 
			valid_tiles[cell] = true
			
	valid_tiles[start_city] = true
	valid_tiles[target_city] = true

	var path_cells = _bfs_get_path_array(start_city, target_city, valid_tiles)
	if path_cells.size() < 2: 
		return 
	
	var path_points = []
	for cell in path_cells:
		path_points.append(Vector2(cell.x * TILE_SIZE + TILE_SIZE/2.0, cell.y * TILE_SIZE + TILE_SIZE/2.0))

	var palette = [Color.CRIMSON, Color.ROYAL_BLUE, Color.GOLDENROD, Color.DARK_VIOLET, Color.DARK_ORANGE]
	var v_color = palette[contract_index % palette.size()]

	active_trains[contract_index] = {
		"path": path_points,
		"progress": 0.0,
		"direction": 1,
		"speed": 60.0, 
		"color": v_color,
		"delay": contract_index * 1.5
	}

func _move_train(index: int, delta: float) -> void:
	var train = active_trains[index]
	if train["path"].size() < 2: return
	if train.has("delay") and train["delay"] > 0:
		train["delay"] -= delta
		return
	
	var path_len = 0.0
	for i in range(train["path"].size() - 1):
		path_len += train["path"][i].distance_to(train["path"][i+1])
		
	train["progress"] += train["speed"] * delta * train["direction"]

	if train["progress"] >= path_len:
		train["progress"] = path_len
		train["direction"] = -1
	else:
		if train["progress"] <= 0:
			train["progress"] = 0
			train["direction"] = 1

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
			if seg_len > 0: 
				t = (dist - accum) / seg_len
			t = clamp(t, 0.0, 1.0)
			var pos = path[i].lerp(path[i+1], t)
			var dir = (path[i+1] - path[i]).normalized()
			if dir == Vector2.ZERO: 
				dir = Vector2.RIGHT
			return {"pos": pos, "dir": dir}
		accum += seg_len
	return {"pos": path.back(), "dir": Vector2.RIGHT}

func _draw_trains() -> void:
	for index in active_trains.keys():
		var train = active_trains[index]
		var path = train["path"]
		if path.size() < 2: continue

		var current_dist = train["progress"]
		if train.has("delay") and train["delay"] > 0: 
			current_dist = 0.0 

		var loco_dist = current_dist
		var wagon_dist = current_dist - (14.0 * train["direction"])

		var loco_info = _get_path_info(path, loco_dist)
		var wagon_info = _get_path_info(path, wagon_dist)

		var loco_dir = loco_info["dir"]
		var wagon_dir = wagon_info["dir"]
		if train["direction"] == -1:
			loco_dir = -loco_dir
			wagon_dir = -wagon_dir

		draw_set_transform(wagon_info["pos"], wagon_dir.angle(), Vector2.ONE)
		draw_rect(Rect2(-8, -5, 16, 10), train["color"])
		draw_set_transform(loco_info["pos"], loco_dir.angle(), Vector2.ONE)
		draw_rect(Rect2(-10, -6, 20, 12), Color(0.15, 0.15, 0.15)) 
		draw_rect(Rect2(2, -4, 6, 8), Color(0.7, 0.7, 0.7)) 
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _bfs_get_path_array(start_node: Vector2i, target_node: Vector2i, valid_tiles: Dictionary) -> Array[Vector2i]:
	var initial_path: Array[Vector2i] = [start_node]
	var queue = [initial_path]
	var visited = {start_node: true}
	while queue.size() > 0:
		var path: Array[Vector2i] = queue.pop_front()
		var cell = path.back()
		if cell == target_node: 
			return path
		var neighbors = [cell + Vector2i.UP, cell + Vector2i.DOWN, cell + Vector2i.LEFT, cell + Vector2i.RIGHT]
		for n in neighbors:
			if valid_tiles.has(n) and not visited.has(n):
				visited[n] = true
				var new_path: Array[Vector2i] = path.duplicate()
				new_path.append(n)
				queue.push_back(new_path)
	return []

func _is_cell_occupied_by_track(cell: Vector2i) -> bool:
	for route in confirmed_routes:
		if cell in route: 
			return true
	if cell in tentative_path: 
		return true
	for draft in draft_paths:
		if cell in draft:
			return true
	return false

func _draw() -> void:
	for x in range(grid_width):
		for y in range(grid_height):
			var cell = Vector2i(x, y)
			var b = biome_map.get(cell, Biome.PLAIN)
			var bg_color = BIOME_DATA[b]["color"]
			if b == Biome.FOREST:
				bg_color = BIOME_DATA[Biome.PLAIN]["color"]
				
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

	var is_const = false
	var max_d = 0
	for k in GameManager.routes_under_construction.keys():
		var d = GameManager.routes_under_construction[k]
		if d > 0:
			is_const = true
			if d > max_d:
				max_d = d

	# NOVO: Desenha as Rotas Confirmadas (Vermelhas se marcadas para demolicao)
	for route in confirmed_routes: 
		var is_del = deleted_paths.has(route)
		_draw_custom_track(route, false, is_const, is_del) 
		if is_const and not is_del:
			if route.size() > 2:
				var mid = route[route.size() / 2]
				var px = mid.x * TILE_SIZE + 16
				var py = mid.y * TILE_SIZE + 16
				draw_rect(Rect2(px - 50, py - 12, 100, 24), Color(0.1, 0.1, 0.1, 0.9))
				draw_string(ThemeDB.fallback_font, Vector2(px - 45, py + 4), "[ OBRAS: " + str(max_d) + "d ]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.ORANGE)
	
	# NOVO: Desenha os rascunhos de obras em Amarelo
	for draft in draft_paths:
		_draw_custom_track(draft, true, false, false)
		
	_draw_custom_track(tentative_path, true, false, false)

	if city_a != Vector2i(-1, -1): 
		draw_rect(Rect2(city_a.x * TILE_SIZE, city_a.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.DODGER_BLUE)
	if city_b != Vector2i(-1, -1): 
		draw_rect(Rect2(city_b.x * TILE_SIZE, city_b.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.CRIMSON)
	if city_c != Vector2i(-1, -1): 
		draw_rect(Rect2(city_c.x * TILE_SIZE, city_c.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.FOREST_GREEN)
		
	_draw_trains()

func _get_track_color(b: int, is_preview: bool, is_construction: bool, is_deleted: bool = false) -> Color:
	if is_deleted: 
		return Color(0.8, 0.2, 0.2, 0.7) 
	if is_preview: 
		return Color.YELLOW
	if is_construction:
		return Color(0.9, 0.7, 0.1) 
	if b == Biome.RIVER: 
		return Color.SADDLE_BROWN 
	if b == Biome.MOUNTAIN: 
		return Color.DARK_SLATE_GRAY 
	return Color.BLACK

func _draw_custom_track(path: Array, is_preview: bool, is_const: bool, is_deleted: bool = false) -> void:
	if path.size() == 0: 
		return
	if path.size() == 1:
		var b = biome_map.get(path[0], Biome.PLAIN)
		draw_circle(Vector2(path[0].x * TILE_SIZE + 16, path[0].y * TILE_SIZE + 16), 4.0, _get_track_color(b, is_preview, is_const, is_deleted))
		return
		
	for cell in path:
		if biome_map.get(cell, Biome.PLAIN) == Biome.FOREST:
			draw_circle(Vector2(cell.x * TILE_SIZE + 6, cell.y * TILE_SIZE + 6), 4.0, Color(0.85, 0.75, 0.55))
			draw_circle(Vector2(cell.x * TILE_SIZE + 6, cell.y * TILE_SIZE + 6), 2.0, Color(0.7, 0.6, 0.4))

	for i in range(path.size() - 1):
		var p1_cell = path[i]
		var p2_cell = path[i+1]
		var b1 = biome_map.get(p1_cell, Biome.PLAIN)
		var b2 = biome_map.get(p2_cell, Biome.PLAIN)
		var segment_biome = Biome.PLAIN
		
		if b1 == Biome.MOUNTAIN or b2 == Biome.MOUNTAIN: 
			segment_biome = Biome.MOUNTAIN
		else:
			if b1 == Biome.RIVER or b2 == Biome.RIVER: 
				segment_biome = Biome.RIVER
			else:
				if b1 == Biome.FOREST or b2 == Biome.FOREST: 
					segment_biome = Biome.FOREST

		var line_color = _get_track_color(segment_biome, is_preview, is_const, is_deleted)
		var line_width = 5.0
		if segment_biome != Biome.MOUNTAIN:
			line_width = 2.0
			
		var p1 = Vector2(p1_cell.x * TILE_SIZE + 16, p1_cell.y * TILE_SIZE + 16)
		var p2 = Vector2(p2_cell.x * TILE_SIZE + 16, p2_cell.y * TILE_SIZE + 16)
		draw_line(p1, p2, line_color, line_width)

		if segment_biome != Biome.MOUNTAIN:
			var dir = (p2 - p1).normalized()
			var normal = Vector2(-dir.y, dir.x)
			var segment_length = p1.distance_to(p2)
			
			var spacing = 10.0
			if segment_biome == Biome.RIVER:
				spacing = 5.0
				
			var num_ties = int(segment_length / spacing)
			var tie_color = line_color
			if segment_biome == Biome.RIVER and not is_preview:
				tie_color = Color(0.3, 0.2, 0.1)
				
			if is_const and not is_deleted:
				tie_color = Color.BLACK
				
			for j in range(1, num_ties + 1):
				var tie_center = p1 + dir * (j * spacing)
				draw_line(tie_center - normal * 4, tie_center + normal * 4, tie_color, 2.0)

# NOVO: Dinamica de Desenho e Demolicao por Blocos
func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if edit_panel.visible == false and not is_edit_mode: return 
	
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
				
				# Tenta apagar um rascunho primeiro
				for i in range(draft_paths.size() - 1, -1, -1):
					if draft_paths[i].has(cell):
						draft_paths.remove_at(i)
						handled = true
						break
				
				# Se nao apagou rascunho, marca/desmarca uma via construida para demolicao
				if not handled:
					for r in confirmed_routes:
						if r.has(cell):
							if deleted_paths.has(r):
								deleted_paths.erase(r) 
							else:
								deleted_paths.append(r)
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
					var segment = _get_orthogonal_path(last, cell)
					for p in segment:
						var idx = tentative_path.find(p)
						if idx != -1: 
							tentative_path.resize(idx + 1)
						else: 
							tentative_path.append(p)
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
	var built = {}
	var toll = 0
	
	for route in confirmed_routes:
		var has_g = false
		for cell in route:
			built[cell] = true
			if gang_map.has(cell): 
				has_g = true
		if has_g: 
			toll += GANG_TOLL_RATE
			
	GameManager.daily_gang_toll = toll
	
	if city_a != Vector2i(-1, -1): built[city_a] = true
	if city_b != Vector2i(-1, -1): built[city_b] = true
	if city_c != Vector2i(-1, -1): built[city_c] = true
	
	var connections = []
	var stats = {}
	
	if city_a != Vector2i(-1, -1) and city_b != Vector2i(-1, -1):
		var res = _get_route_capabilities(city_a, city_b, built)
		if not res.is_empty(): 
			connections.append("Azul-Vermelha")
			stats["Azul-Vermelha"] = res
			
	if city_a != Vector2i(-1, -1) and city_c != Vector2i(-1, -1):
		var res = _get_route_capabilities(city_a, city_c, built)
		if not res.is_empty(): 
			connections.append("Azul-Verde")
			stats["Azul-Verde"] = res
			
	if city_b != Vector2i(-1, -1) and city_c != Vector2i(-1, -1):
		var res = _get_route_capabilities(city_b, city_c, built)
		if not res.is_empty(): 
			connections.append("Vermelha-Verde")
			stats["Vermelha-Verde"] = res
			
	GameManager.network_connections = connections
	GameManager.network_stats = stats
	GameManager.contracts_updated.emit() 

func _get_route_capabilities(start: Vector2i, target: Vector2i, valid: Dictionary) -> Dictionary:
	var shortest = _bfs_shortest_dist(start, target, valid, false, false)
	if shortest == -1: 
		return {} 
		
	var gangs = 1
	if _bfs_shortest_dist(start, target, valid, true, false) != -1:
		gangs = 0
		
	var forests = 1
	if _bfs_shortest_dist(start, target, valid, false, true) != -1:
		forests = 0
		
	return {"dist": shortest, "gangs": gangs, "forests": forests}

func _bfs_shortest_dist(start: Vector2i, target: Vector2i, valid: Dictionary, avoid_g: bool, avoid_f: bool) -> int:
	var q = [{"cell": start, "dist": 0}]
	var vis = {start: true}
	
	while q.size() > 0:
		var curr = q.pop_front()
		var cell = curr["cell"]
		if cell == target: 
			return curr["dist"]
			
		for n in [cell + Vector2i.UP, cell + Vector2i.DOWN, cell + Vector2i.LEFT, cell + Vector2i.RIGHT]:
			if valid.has(n) and not vis.has(n):
				if avoid_g and gang_map.has(n): 
					continue
				if avoid_f and biome_map.get(n, Biome.PLAIN) == Biome.FOREST: 
					continue
				vis[n] = true
				q.push_back({"cell": n, "dist": curr["dist"] + 1})
	return -1
	
func _get_cell_under_mouse(p: Vector2) -> Vector2i: 
	return Vector2i(p.x / TILE_SIZE, p.y / TILE_SIZE)
