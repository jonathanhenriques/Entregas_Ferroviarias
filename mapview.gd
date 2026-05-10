extends Node2D

var ui_layer: CanvasLayer

const TILE_SIZE: int = 32
# As variaveis de tamanho deixaram de ser constantes. Agora o mapa adapta-se ao seu texto!
var grid_width: int = 0
var grid_height: int = 0

enum Biome { PLAIN, FOREST, MOUNTAIN, RIVER }

const BIOME_DATA = {
	Biome.PLAIN: {"build": 20, "maint": 2, "color": Color(0.65, 0.75, 0.55)},
	Biome.FOREST: {"build": 35, "maint": 5, "color": Color(0.25, 0.45, 0.25)}, 
	Biome.MOUNTAIN: {"build": 400, "maint": 10, "color": Color(0.55, 0.45, 0.35)}, 
	Biome.RIVER: {"build": 600, "maint": 15, "color": Color(0.3, 0.6, 0.8)} 
}

var biome_map: Dictionary = {}

# Iniciamos as cidades no "vazio". Elas so aparecem se você as digitar no mapa.
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

func _ready() -> void:
	_generate_biomes()
	_setup_ui()
	_update_network_status()
	
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if ui_layer:
		ui_layer.visible = visible

# A MAGIA ACONTECE AQUI: O leitor de ASCII Art
func _generate_biomes() -> void:
	biome_map.clear()
	city_a = Vector2i(-1, -1)
	city_b = Vector2i(-1, -1)
	city_c = Vector2i(-1, -1)
	
	# Pede ao GameManager o mapa da fase atual
	var layout = GameManager.level_database[GameManager.current_level]["map_layout"]
	
	grid_height = layout.size()
	grid_width = layout[0].length() if grid_height > 0 else 0
	
	for y in range(grid_height):
		var row = layout[y]
		for x in range(grid_width):
			var char = row[x]
			var cell = Vector2i(x, y)
			
			if char == ".":
				biome_map[cell] = Biome.PLAIN
			elif char == "F":
				biome_map[cell] = Biome.FOREST
			elif char == "M":
				biome_map[cell] = Biome.MOUNTAIN
			elif char == "R":
				biome_map[cell] = Biome.RIVER
			elif char == "A":
				biome_map[cell] = Biome.PLAIN # O chao por baixo da cidade e planicie
				city_a = cell
			elif char == "B":
				biome_map[cell] = Biome.PLAIN
				city_b = cell
			elif char == "C":
				biome_map[cell] = Biome.PLAIN
				city_c = cell
			else:
				biome_map[cell] = Biome.PLAIN # Segurança caso digite uma letra errada

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
	var built_tiles = {}
	for route in confirmed_routes:
		for cell in route:
			built_tiles[cell] = true
			
	if city_a != Vector2i(-1, -1): built_tiles[city_a] = true
	if city_b != Vector2i(-1, -1): built_tiles[city_b] = true
	if city_c != Vector2i(-1, -1): built_tiles[city_c] = true
	
	var connections = []
	
	# So testa conexao se a cidade existir no mapa
	if city_a != Vector2i(-1, -1) and city_b != Vector2i(-1, -1):
		if _bfs_check(city_a, city_b, built_tiles): 
			connections.append("Azul-Vermelha")
			connections.append("Vermelha-Azul")
			
	if city_a != Vector2i(-1, -1) and city_c != Vector2i(-1, -1):
		if _bfs_check(city_a, city_c, built_tiles): 
			connections.append("Azul-Verde")
			connections.append("Verde-Azul")
			
	if city_b != Vector2i(-1, -1) and city_c != Vector2i(-1, -1):
		if _bfs_check(city_b, city_c, built_tiles): 
			connections.append("Vermelha-Verde")
			connections.append("Verde-Vermelha")
		
	GameManager.network_connections = connections
	GameManager.contracts_updated.emit() 

func _bfs_check(start_node: Vector2i, target_node: Vector2i, valid_tiles: Dictionary) -> bool:
	var queue = [start_node]
	var visited = {start_node: true}

	while queue.size() > 0:
		var curr = queue.pop_front()
		if curr == target_node:
			return true

		var neighbors = [
			curr + Vector2i.UP, curr + Vector2i.DOWN,
			curr + Vector2i.LEFT, curr + Vector2i.RIGHT
		]
		for n in neighbors:
			if valid_tiles.has(n) and not visited.has(n):
				visited[n] = true
				queue.push_back(n)
				
	return false

func _calculate_and_show_validation() -> void:
	var distance = tentative_path.size()
	temp_cost = 0
	temp_maintenance = 0
	
	var count_tunnels = 0
	var count_bridges = 0
	var count_forests = 0

	for cell in tentative_path:
		var b = biome_map.get(cell, Biome.PLAIN)
		temp_cost += BIOME_DATA[b]["build"]
		temp_maintenance += BIOME_DATA[b]["maint"]
		
		if b == Biome.MOUNTAIN: count_tunnels += 1
		elif b == Biome.RIVER: count_bridges += 1
		elif b == Biome.FOREST: count_forests += 1

	var text = "RELATORIO DE CONSTRUCAO\n\n"
	
	btn_accept.disabled = false

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

func _draw() -> void:
	# Desenha Biomas
	for x in range(grid_width):
		for y in range(grid_height):
			var cell = Vector2i(x, y)
			var b = biome_map.get(cell, Biome.PLAIN)
			var color = BIOME_DATA[b]["color"]
			draw_rect(Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE), color)

	# Desenha Grade
	for x in range(grid_width + 1):
		draw_line(Vector2(x * TILE_SIZE, 0), Vector2(x * TILE_SIZE, grid_height * TILE_SIZE), Color(0, 0, 0, 0.1), 1.0)
	for y in range(grid_height + 1):
		draw_line(Vector2(0, y * TILE_SIZE), Vector2(grid_width * TILE_SIZE, y * TILE_SIZE), Color(0, 0, 0, 0.1), 1.0)

	# Desenha Rotas
	for route in confirmed_routes:
		_draw_custom_track(route, false) 

	_draw_custom_track(tentative_path, true)

	# Desenha Cidades (So desenha se elas existirem no layout)
	if city_a != Vector2i(-1, -1):
		draw_rect(Rect2(city_a.x * TILE_SIZE, city_a.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.DODGER_BLUE)
	if city_b != Vector2i(-1, -1):
		draw_rect(Rect2(city_b.x * TILE_SIZE, city_b.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.CRIMSON)
	if city_c != Vector2i(-1, -1):
		draw_rect(Rect2(city_c.x * TILE_SIZE, city_c.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.FOREST_GREEN)

func _draw_custom_track(path: Array, is_preview: bool) -> void:
	if path.size() == 0: return
	
	var line_color = Color.YELLOW if is_preview else Color.BLACK
	var line_width = 2.0 

	if path.size() == 1:
		draw_circle(Vector2(path[0].x * TILE_SIZE + TILE_SIZE/2.0, path[0].y * TILE_SIZE + TILE_SIZE/2.0), 4.0, line_color)
		return

	var points = PackedVector2Array()
	for cell in path:
		points.append(Vector2(cell.x * TILE_SIZE + TILE_SIZE/2.0, cell.y * TILE_SIZE + TILE_SIZE/2.0))

	draw_polyline(points, line_color, line_width, true)

	for i in range(points.size() - 1):
		var p1 = points[i]
		var p2 = points[i+1]
		var dir = (p2 - p1).normalized()
		var normal = Vector2(-dir.y, dir.x) 
		
		var segment_length = p1.distance_to(p2)
		var spacing = 10.0 
		var num_ties = int(segment_length / spacing)
		
		for j in range(1, num_ties + 1):
			var tie_center = p1 + dir * (j * spacing)
			draw_line(tie_center - normal * 4, tie_center + normal * 4, line_color, line_width)
