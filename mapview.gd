extends Node2D

var ui_layer: CanvasLayer

const TILE_SIZE: int = 32
var grid_width: int = 0
var grid_height: int = 0

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

var is_dragging: bool = false
var drag_current: Vector2i
var tentative_path: Array[Vector2i] = []
var confirmed_routes: Array = [] 

var validation_panel: Panel
var info_label: Label
var btn_accept: Button
var btn_reject: Button
var btn_go_desk: Button

var temp_cost: int = 0
var temp_maintenance: int = 0

# NOVO: Dicionario para gerir os trens em movimento
var active_trains: Dictionary = {}

func _ready() -> void:
	_generate_biomes()
	_setup_ui()
	_update_network_status()
	
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if ui_layer:
		ui_layer.visible = visible

func _generate_biomes() -> void:
	biome_map.clear()
	gang_map.clear()
	city_a = Vector2i(-1, -1)
	city_b = Vector2i(-1, -1)
	city_c = Vector2i(-1, -1)
	
	var level_info = LevelData.LEVELS[GameManager.current_level]
	var layout = level_info["map_layout"]
	
	grid_height = layout.size()
	grid_width = layout[0].length() if grid_height > 0 else 0
	
	for y in range(grid_height):
		var row = layout[y]
		for x in range(grid_width):
			var char = row[x]
			var cell = Vector2i(x, y)
			
			if char == ".": biome_map[cell] = Biome.PLAIN
			elif char == "F": biome_map[cell] = Biome.FOREST
			elif char == "M": biome_map[cell] = Biome.MOUNTAIN
			elif char == "R": biome_map[cell] = Biome.RIVER
			elif char == "A":
				biome_map[cell] = Biome.PLAIN 
				city_a = cell
			elif char == "B":
				biome_map[cell] = Biome.PLAIN
				city_b = cell
			elif char == "C":
				biome_map[cell] = Biome.PLAIN
				city_c = cell
			else:
				biome_map[cell] = Biome.PLAIN

	if level_info.has("gang_layout"):
		var g_layout = level_info["gang_layout"]
		for y in range(g_layout.size()):
			var row = g_layout[y]
			for x in range(row.length()):
				if row[x] == "G":
					gang_map[Vector2i(x, y)] = true

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	btn_go_desk = Button.new()
	btn_go_desk.text = "Ir para a Mesa ->"
	btn_go_desk.position = Vector2(20, 20)
	btn_go_desk.size = Vector2(180, 40)
	btn_go_desk.pressed.connect(_on_go_desk_pressed)
	ui_layer.add_child(btn_go_desk)

	validation_panel = Panel.new()
	validation_panel.position = Vector2(800, 50) 
	validation_panel.size = Vector2(320, 400) 
	validation_panel.visible = false
	ui_layer.add_child(validation_panel)

	info_label = Label.new()
	info_label.position = Vector2(15, 15)
	info_label.size = Vector2(290, 320) 
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation_panel.add_child(info_label)

	btn_accept = Button.new()
	btn_accept.text = "Aprovar Rota"
	btn_accept.position = Vector2(15, 340) 
	btn_accept.size = Vector2(135, 40)
	btn_accept.pressed.connect(_on_accept_pressed)
	validation_panel.add_child(btn_accept)

	btn_reject = Button.new()
	btn_reject.text = "Cancelar"
	btn_reject.position = Vector2(170, 340) 
	btn_reject.size = Vector2(135, 40)
	btn_reject.pressed.connect(_on_reject_pressed)
	validation_panel.add_child(btn_reject)

func _on_go_desk_pressed() -> void:
	var main_node = get_parent()
	if main_node.has_method("go_to_desk"):
		main_node.go_to_desk()

# =======================================
# NOVO: A VIDA NO MAPA (Animacao dos Trens)
# =======================================
func _process(delta: float) -> void:
	if not visible: return
	
	var needs_redraw = false
	
	# Verifica e move os trens dos contratos operantes
	for i in range(GameManager.active_contracts.size()):
		var c = GameManager.active_contracts[i]
		if GameManager.is_contract_operating(c):
			needs_redraw = true
			if not active_trains.has(i):
				_spawn_train(i, c)
			else:
				_move_train(i, delta)
		else:
			if active_trains.has(i):
				active_trains.erase(i)
				needs_redraw = true

	# Limpa trens fantasmas (contratos cancelados/terminados)
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
		start_city = city_a; target_city = city_b
	elif "Azul" in route_id and "Verde" in route_id:
		start_city = city_a; target_city = city_c
	elif "Vermelha" in route_id and "Verde" in route_id:
		start_city = city_b; target_city = city_c

	var valid_tiles = {}
	for r in confirmed_routes:
		for cell in r: valid_tiles[cell] = true
	valid_tiles[start_city] = true
	valid_tiles[target_city] = true

	var path_cells = _bfs_get_path_array(start_city, target_city, valid_tiles)
	if path_cells.size() < 2: return 
	
	var path_points = []
	for cell in path_cells:
		path_points.append(Vector2(cell.x * TILE_SIZE + TILE_SIZE/2.0, cell.y * TILE_SIZE + TILE_SIZE/2.0))

	var palette = [
		Color.CRIMSON,      
		Color.ROYAL_BLUE,   
		Color.GOLDENROD,    
		Color.DARK_VIOLET,  
		Color.DARK_ORANGE   
	]
	var v_color = palette[contract_index % palette.size()]

	active_trains[contract_index] = {
		"path": path_points,
		"progress": 0.0,
		"direction": 1,
		"speed": 60.0, 
		"color": v_color,
		"delay": contract_index * 1.5 # NOVO: Intervalo de 1.5 segundos entre cada trem!
	}

func _move_train(index: int, delta: float) -> void:
	var train = active_trains[index]
	if train["path"].size() < 2: return
	
	# O trem fica parado na estacao ate o delay dele acabar
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
	elif train["progress"] <= 0:
		train["progress"] = 0
		train["direction"] = 1

# Helper Matemático: Calcula exatamente a posicao e angulo num ponto da linha
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

# O coracao do GPS do trem (Retorna o Array exato da rota mais curta)
func _bfs_get_path_array(start_node: Vector2i, target_node: Vector2i, valid_tiles: Dictionary) -> Array[Vector2i]:
	# TIPAGEM FORTE: Declaramos explicitamente que a rota inicial e um Array de Vector2i
	var initial_path: Array[Vector2i] = [start_node]
	var queue = [initial_path]
	var visited = {start_node: true}

	while queue.size() > 0:
		# TIPAGEM FORTE: Garantimos que a rota que sai da fila mantem o tipo correto
		var path: Array[Vector2i] = queue.pop_front()
		var cell = path.back()

		if cell == target_node:
			return path

		var neighbors = [
			cell + Vector2i.UP, cell + Vector2i.DOWN,
			cell + Vector2i.LEFT, cell + Vector2i.RIGHT
		]
		for n in neighbors:
			if valid_tiles.has(n) and not visited.has(n):
				visited[n] = true
				var new_path: Array[Vector2i] = path.duplicate()
				new_path.append(n)
				queue.push_back(new_path)
				
	# Retorna um array vazio tipado como fallback de seguranca
	var empty_path: Array[Vector2i] = []
	return empty_path


# =======================================
# LÓGICA DE CLIQUE E DESENHO
# =======================================
func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if validation_panel.visible: return

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
						_calculate_and_show_validation()
					queue_redraw()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			var cell = _get_cell_under_mouse(event.position)
			var deleted_something = false
			
			var old_connections = GameManager.network_connections.duplicate()
			
			if tentative_path.has(cell):
				tentative_path.clear()
				deleted_something = true
			else:
				for i in range(confirmed_routes.size() - 1, -1, -1):
					if confirmed_routes[i].has(cell):
						var maint_refund = 0
						var build_refund = 0
						for c in confirmed_routes[i]:
							var b = biome_map.get(c, Biome.PLAIN)
							build_refund += BIOME_DATA[b]["build"]
							maint_refund += BIOME_DATA[b]["maint"]
						
						GameManager.daily_maintenance -= maint_refund
						GameManager.money += build_refund 
						confirmed_routes.remove_at(i)
						deleted_something = true
						break 
			
			if deleted_something:
				_update_network_status() 
				var lost_contracts = []
				for i in range(GameManager.active_contracts.size()):
					var c = GameManager.active_contracts[i]
					if c["route_id"] in old_connections and not GameManager.is_contract_operating(c):
						lost_contracts.append(i)
				
				if lost_contracts.size() > 0:
					GameManager.pendent_angry_call = true 
					for i in range(lost_contracts.size() - 1, -1, -1):
						GameManager.cancel_contract(lost_contracts[i])
				
				queue_redraw()

	elif event is InputEventMouseMotion and is_dragging:
		var cell = _get_cell_under_mouse(event.position)
		cell.x = clamp(cell.x, 0, grid_width - 1)
		cell.y = clamp(cell.y, 0, grid_height - 1)
		
		if tentative_path.size() > 0:
			var last_cell = tentative_path.back()
			if cell != last_cell:
				var path_segment = _get_orthogonal_path(last_cell, cell)
				for p in path_segment:
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
	active_trains.clear() # Forca os trens a recalcularem as rotas caso a rede mude
	
	var built_tiles = {}
	var current_gang_toll = 0
	
	for route in confirmed_routes:
		var has_gang = false
		for cell in route:
			built_tiles[cell] = true
			if gang_map.has(cell):
				has_gang = true
		if has_gang:
			current_gang_toll += GANG_TOLL_RATE
			
	GameManager.daily_gang_toll = current_gang_toll
			
	if city_a != Vector2i(-1, -1): built_tiles[city_a] = true
	if city_b != Vector2i(-1, -1): built_tiles[city_b] = true
	if city_c != Vector2i(-1, -1): built_tiles[city_c] = true
	
	var connections = []
	var stats = {}
	
	if city_a != Vector2i(-1, -1) and city_b != Vector2i(-1, -1):
		var res = _get_route_capabilities(city_a, city_b, built_tiles)
		if not res.is_empty():
			connections.append("Azul-Vermelha")
			connections.append("Vermelha-Azul")
			stats["Azul-Vermelha"] = res
			stats["Vermelha-Azul"] = res
			
	if city_a != Vector2i(-1, -1) and city_c != Vector2i(-1, -1):
		var res = _get_route_capabilities(city_a, city_c, built_tiles)
		if not res.is_empty():
			connections.append("Azul-Verde")
			connections.append("Verde-Azul")
			stats["Azul-Verde"] = res
			stats["Verde-Azul"] = res
			
	if city_b != Vector2i(-1, -1) and city_c != Vector2i(-1, -1):
		var res = _get_route_capabilities(city_b, city_c, built_tiles)
		if not res.is_empty():
			connections.append("Vermelha-Verde")
			connections.append("Verde-Vermelha")
			stats["Vermelha-Verde"] = res
			stats["Verde-Vermelha"] = res
		
	GameManager.network_connections = connections
	GameManager.network_stats = stats
	GameManager.contracts_updated.emit() 

func _get_route_capabilities(start_node: Vector2i, target_node: Vector2i, valid_tiles: Dictionary) -> Dictionary:
	var shortest_dist = _bfs_shortest_dist(start_node, target_node, valid_tiles, false, false)
	if shortest_dist == -1: return {} 

	var avoids_gangs = _bfs_shortest_dist(start_node, target_node, valid_tiles, true, false) != -1
	var avoids_forests = _bfs_shortest_dist(start_node, target_node, valid_tiles, false, true) != -1

	return {
		"dist": shortest_dist,
		"gangs": 0 if avoids_gangs else 1,
		"forests": 0 if avoids_forests else 1
	}

func _bfs_shortest_dist(start_node: Vector2i, target_node: Vector2i, valid_tiles: Dictionary, avoid_gangs: bool, avoid_forests: bool) -> int:
	var queue = [{"cell": start_node, "dist": 0}]
	var visited = {start_node: true}

	while queue.size() > 0:
		var curr = queue.pop_front()
		var cell = curr["cell"]

		if cell == target_node:
			return curr["dist"]

		var neighbors = [
			cell + Vector2i.UP, cell + Vector2i.DOWN,
			cell + Vector2i.LEFT, cell + Vector2i.RIGHT
		]
		for n in neighbors:
			if valid_tiles.has(n) and not visited.has(n):
				if avoid_gangs and gang_map.has(n): continue
				if avoid_forests and biome_map.get(n, Biome.PLAIN) == Biome.FOREST: continue

				visited[n] = true
				queue.push_back({"cell": n, "dist": curr["dist"] + 1})

	return -1


func _calculate_and_show_validation() -> void:
	var distance = tentative_path.size()
	temp_cost = 0
	temp_maintenance = 0
	
	var count_tunnels = 0
	var count_bridges = 0
	var count_forests = 0
	var has_gang = false

	for cell in tentative_path:
		var b = biome_map.get(cell, Biome.PLAIN)
		temp_cost += BIOME_DATA[b]["build"]
		temp_maintenance += BIOME_DATA[b]["maint"]
		
		if b == Biome.MOUNTAIN: count_tunnels += 1
		elif b == Biome.RIVER: count_bridges += 1
		elif b == Biome.FOREST: count_forests += 1
		
		if gang_map.has(cell):
			has_gang = true

	var text = "RELATORIO DE CONSTRUCAO\n\n"
	
	btn_accept.disabled = false
	
	if has_gang:
		text += "[!] AVISO: Rota cruza territorio de Gangues!\n"
		text += "    Pedagio exigido: +$" + str(GANG_TOLL_RATE) + " / dia\n\n"

	text += "Distancia Total do Trecho: " + str(distance) + " km\n"
	text += "Custo da Obra: $" + str(temp_cost) + "\n"
	
	if count_bridges > 0 or count_tunnels > 0 or count_forests > 0:
		text += "↳ Obras Especiais Inclusas:\n"
		if count_bridges > 0: text += "  - " + str(count_bridges) + " Ponte(s) = +$" + str(count_bridges * BIOME_DATA[Biome.RIVER]["build"]) + "\n"
		if count_tunnels > 0: text += "  - " + str(count_tunnels) + " Tunel(is) = +$" + str(count_tunnels * BIOME_DATA[Biome.MOUNTAIN]["build"]) + "\n"
		if count_forests > 0: text += "  - " + str(count_forests) + " Desmata. = +$" + str(count_forests * BIOME_DATA[Biome.FOREST]["build"]) + "\n"
		
	text += "\nManutencao Diaria Adicional: $" + str(temp_maintenance) + "\n\n"
	text += "Saldo da Empresa: $" + str(GameManager.money)

	info_label.text = text
	validation_panel.visible = true

func _on_accept_pressed() -> void:
	if GameManager.money >= temp_cost:
		GameManager.money -= temp_cost
		GameManager.daily_maintenance += temp_maintenance
		
		confirmed_routes.append(tentative_path.duplicate())
		tentative_path.clear()
		
		_update_network_status() 
		validation_panel.visible = false
		queue_redraw()
	else:
		info_label.text = "ALERTA: FUNDOS INSUFICIENTES!\n\nVoce precisa de $" + str(temp_cost) + " para construir esta rota."

func _on_reject_pressed() -> void:
	tentative_path.clear()
	validation_panel.visible = false
	queue_redraw()

func _get_cell_under_mouse(mouse_pos: Vector2) -> Vector2i:
	return Vector2i(mouse_pos.x / TILE_SIZE, mouse_pos.y / TILE_SIZE)


# Helper novo: Verifica se a celula tem algum trilho (confirmado ou em planeamento)
func _is_cell_occupied_by_track(cell: Vector2i) -> bool:
	for route in confirmed_routes:
		if cell in route: return true
	if cell in tentative_path: return true
	return false


func _draw() -> void:
	for x in range(grid_width):
		for y in range(grid_height):
			var cell = Vector2i(x, y)
			var b = biome_map.get(cell, Biome.PLAIN)
			
			# O chao da Floresta agora usa a cor da Planicie como base
			var bg_color = BIOME_DATA[Biome.PLAIN]["color"] if b == Biome.FOREST else BIOME_DATA[b]["color"]
			draw_rect(Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE), bg_color)
			
			# NOVA ARVORE: Desenha o Pinheiro (Triangulo) se for Floresta e NAO tiver trilho
			if b == Biome.FOREST and not _is_cell_occupied_by_track(cell):
				var p1 = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + 6)
				var p2 = Vector2(x * TILE_SIZE + 6, y * TILE_SIZE + TILE_SIZE - 6)
				var p3 = Vector2(x * TILE_SIZE + TILE_SIZE - 6, y * TILE_SIZE + TILE_SIZE - 6)
				draw_polygon(PackedVector2Array([p1, p2, p3]), [Color(0.15, 0.4, 0.15)]) # Verde escuro

	for cell in gang_map.keys():
		draw_rect(Rect2(cell.x * TILE_SIZE, cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color(0.8, 0.1, 0.1, 0.4))

	for x in range(grid_width + 1):
		draw_line(Vector2(x * TILE_SIZE, 0), Vector2(x * TILE_SIZE, grid_height * TILE_SIZE), Color(0, 0, 0, 0.1), 1.0)
	for y in range(grid_height + 1):
		draw_line(Vector2(0, y * TILE_SIZE), Vector2(grid_width * TILE_SIZE, y * TILE_SIZE), Color(0, 0, 0, 0.1), 1.0)

	for route in confirmed_routes:
		_draw_custom_track(route, false) 

	_draw_custom_track(tentative_path, true)

	if city_a != Vector2i(-1, -1):
		draw_rect(Rect2(city_a.x * TILE_SIZE, city_a.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.DODGER_BLUE)
	if city_b != Vector2i(-1, -1):
		draw_rect(Rect2(city_b.x * TILE_SIZE, city_b.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.CRIMSON)
	if city_c != Vector2i(-1, -1):
		draw_rect(Rect2(city_c.x * TILE_SIZE, city_c.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.FOREST_GREEN)
		
	_draw_trains()



# =======================================
# LÓGICA DE DESENHO GEOMÉTRICO
# =======================================
func _get_track_color(b: int, is_preview: bool) -> Color:
	if is_preview: return Color.YELLOW
	if b == Biome.RIVER: return Color.SADDLE_BROWN 
	if b == Biome.MOUNTAIN: return Color.DARK_SLATE_GRAY 
	return Color.BLACK


func _draw_custom_track(path: Array, is_preview: bool) -> void:
	if path.size() == 0: return

	if path.size() == 1:
		var b = biome_map.get(path[0], Biome.PLAIN)
		draw_circle(Vector2(path[0].x * TILE_SIZE + TILE_SIZE/2.0, path[0].y * TILE_SIZE + TILE_SIZE/2.0), 4.0, _get_track_color(b, is_preview))
		return
		
	# NOVO VISUAL DE DESMATAMENTO: Um toco bege unico
	for cell in path:
		if biome_map.get(cell, Biome.PLAIN) == Biome.FOREST:
			var cx = cell.x * TILE_SIZE
			var cy = cell.y * TILE_SIZE
			# Posiciona o toco levemente deslocado para o trilho nao o tapar totalmente
			var stump = Vector2(cx + 10, cy + 10) 
			draw_circle(stump, 5.0, Color(0.85, 0.75, 0.55)) # Bege (Madeira clara)
			draw_circle(stump, 2.5, Color(0.7, 0.6, 0.4))    # Miolo escuro

	for i in range(path.size() - 1):
		var p1_cell = path[i]
		var p2_cell = path[i+1]
		var b1 = biome_map.get(p1_cell, Biome.PLAIN)
		var b2 = biome_map.get(p2_cell, Biome.PLAIN)

		var segment_biome = Biome.PLAIN
		if b1 == Biome.MOUNTAIN or b2 == Biome.MOUNTAIN: segment_biome = Biome.MOUNTAIN
		elif b1 == Biome.RIVER or b2 == Biome.RIVER: segment_biome = Biome.RIVER
		elif b1 == Biome.FOREST or b2 == Biome.FOREST: segment_biome = Biome.FOREST

		var line_color = _get_track_color(segment_biome, is_preview)
		var line_width = 5.0 if segment_biome == Biome.MOUNTAIN else 2.0

		var p1 = Vector2(p1_cell.x * TILE_SIZE + TILE_SIZE/2.0, p1_cell.y * TILE_SIZE + TILE_SIZE/2.0)
		var p2 = Vector2(p2_cell.x * TILE_SIZE + TILE_SIZE/2.0, p2_cell.y * TILE_SIZE + TILE_SIZE/2.0)

		draw_line(p1, p2, line_color, line_width)

		if segment_biome != Biome.MOUNTAIN:
			var dir = (p2 - p1).normalized()
			var normal = Vector2(-dir.y, dir.x)
			var segment_length = p1.distance_to(p2)
			
			var spacing = 5.0 if segment_biome == Biome.RIVER else 10.0
			var num_ties = int(segment_length / spacing)
			var tie_color = Color(0.3, 0.2, 0.1) if (segment_biome == Biome.RIVER and not is_preview) else line_color

			for j in range(1, num_ties + 1):
				var tie_center = p1 + dir * (j * spacing)
				var tie_width = 5 if segment_biome == Biome.RIVER else 4
				draw_line(tie_center - normal * tie_width, tie_center + normal * tie_width, tie_color, 2.0)
		else:
			var dir = (p2 - p1).normalized()
			var segment_length = p1.distance_to(p2)
			var spacing = 6.0
			var num_ties = int(segment_length / spacing)
			for j in range(1, num_ties + 1):
				if j % 2 == 0:
					var dot_center = p1 + dir * (j * spacing)
					var dot_color = Color.YELLOW if is_preview else Color.WHITE
					draw_circle(dot_center, 1.5, dot_color)


func _draw_trains() -> void:
	for index in active_trains.keys():
		var train = active_trains[index]
		var path = train["path"]
		if path.size() < 2: continue

		var current_dist = train["progress"]
		if train.has("delay") and train["delay"] > 0:
			current_dist = 0.0 # Segura o trem no inicio se estiver em delay

		# Magia da Articulacao: Locomotiva vai à frente, vagao vai 20 pixels atras!
		var loco_dist = current_dist
		var wagon_dist = current_dist - (20.0 * train["direction"])

		var loco_info = _get_path_info(path, loco_dist)
		var wagon_info = _get_path_info(path, wagon_dist)

		var loco_dir = loco_info["dir"]
		var wagon_dir = wagon_info["dir"]

		if train["direction"] == -1:
			loco_dir = -loco_dir
			wagon_dir = -wagon_dir

		# Desenha o Vagao Colorido Articulado
		draw_set_transform(wagon_info["pos"], wagon_dir.angle(), Vector2.ONE)
		draw_rect(Rect2(-8, -5, 16, 10), train["color"])
		
		# Desenha a Locomotiva
		draw_set_transform(loco_info["pos"], loco_dir.angle(), Vector2.ONE)
		draw_rect(Rect2(-10, -6, 20, 12), Color(0.15, 0.15, 0.15)) 
		draw_rect(Rect2(2, -4, 6, 8), Color(0.7, 0.7, 0.7)) 
		
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
