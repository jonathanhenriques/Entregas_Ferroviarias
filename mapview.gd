extends Node2D

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 18
const GRID_HEIGHT: int = 10

# DEFINICAO DOS BIOMAS E CUSTOS
enum Biome { PLAIN, FOREST, MOUNTAIN, RIVER }

const BIOME_DATA = {
	Biome.PLAIN: {"build": 50, "maint": 5, "color": Color(0.65, 0.75, 0.55)}, # Verde claro
	Biome.FOREST: {"build": 80, "maint": 15, "color": Color(0.25, 0.45, 0.25)}, # Verde escuro
	Biome.MOUNTAIN: {"build": 300, "maint": 10, "color": Color(0.55, 0.45, 0.35)}, # Marrom
	Biome.RIVER: {"build": 500, "maint": 20, "color": Color(0.3, 0.6, 0.8)} # Azul claro
}

var biome_map: Dictionary = {}

var astar_grid: AStarGrid2D
var city_a: Vector2i = Vector2i(2, 5)
var city_b: Vector2i = Vector2i(15, 5)

# CONTROLES DO MODO LAPIS
var is_dragging: bool = false
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
	_setup_astar()
	_setup_ui()

# Cria o mapa com os obstaculos
func _generate_biomes() -> void:
	# Preenche tudo com planicie primeiro
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			biome_map[Vector2i(x, y)] = Biome.PLAIN
			
	# Cria um Rio cortando o mapa
	for y in range(GRID_HEIGHT):
		biome_map[Vector2i(8, y)] = Biome.RIVER
		if y > 4:
			biome_map[Vector2i(9, y)] = Biome.RIVER

	# Cria uma Cordilheira de Montanhas
	for x in range(4, 7):
		for y in range(2, 6):
			biome_map[Vector2i(x, y)] = Biome.MOUNTAIN
			
	# Cria uma Floresta Densa
	for x in range(11, 15):
		for y in range(6, 10):
			biome_map[Vector2i(x, y)] = Biome.FOREST

func _setup_astar() -> void:
	astar_grid = AStarGrid2D.new()
	astar_grid.region = Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	astar_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	# O AStar agora e usado APENAS para preencher espacos se o mouse mover rapido
	astar_grid.update()

func _setup_ui() -> void:
	btn_go_desk = Button.new()
	btn_go_desk.text = "Ir para a Mesa ->"
	btn_go_desk.position = Vector2(20, 20)
	btn_go_desk.size = Vector2(180, 40)
	btn_go_desk.pressed.connect(_on_go_desk_pressed)
	add_child(btn_go_desk)

	validation_panel = Panel.new()
	validation_panel.position = Vector2(800, 50) 
	validation_panel.size = Vector2(320, 370) # Aumentado para caber o relatorio de pontes/tuneis
	validation_panel.visible = false
	add_child(validation_panel)

	info_label = Label.new()
	info_label.position = Vector2(15, 15)
	info_label.size = Vector2(290, 290) 
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation_panel.add_child(info_label)

	btn_accept = Button.new()
	btn_accept.text = "Aprovar Rota"
	btn_accept.position = Vector2(15, 310) 
	btn_accept.size = Vector2(135, 40)
	btn_accept.pressed.connect(_on_accept_pressed)
	validation_panel.add_child(btn_accept)

	btn_reject = Button.new()
	btn_reject.text = "Cancelar"
	btn_reject.position = Vector2(170, 310) 
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
				if astar_grid.is_in_bounds(cell.x, cell.y):
					is_dragging = true
					tentative_path = [cell]
					queue_redraw()
			else:
				if is_dragging:
					is_dragging = false
					if tentative_path.size() > 0:
						_calculate_and_show_validation()
					queue_redraw()
		
		# A Borracha
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			var cell = _get_cell_under_mouse(event.position)
			var deleted_something = false
			
			if tentative_path.has(cell):
				tentative_path.clear()
				deleted_something = true
			else:
				for i in range(confirmed_routes.size() - 1, -1, -1):
					if confirmed_routes[i].has(cell):
						# Reembolso dinamico baseado no terreno!
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
				if confirmed_routes.size() == 0:
					GameManager.has_active_route = false
				queue_redraw()

	elif event is InputEventMouseMotion and is_dragging:
		var cell = _get_cell_under_mouse(event.position)
		if astar_grid.is_in_bounds(cell.x, cell.y) and tentative_path.size() > 0:
			var last_cell = tentative_path.back()
			if cell != last_cell:
				# Traca uma reta do ultimo ponto ate o mouse (evita falhas se mover rapido)
				var path_segment = astar_grid.get_id_path(last_cell, cell)
				for i in range(1, path_segment.size()):
					var p = path_segment[i]
					var idx = tentative_path.find(p)
					# Se o jogador voltar o mouse por cima do proprio trilho, apaga (Borracha do Lapis)
					if idx != -1:
						tentative_path.resize(idx + 1)
					else:
						tentative_path.append(p)
				queue_redraw()

func _calculate_and_show_validation() -> void:
	var distance = tentative_path.size()
	temp_cost = 0
	temp_maintenance = 0
	
	var count_tunnels = 0
	var count_bridges = 0
	var count_forests = 0

	# Calcula custos reais baseados no mapa
	for cell in tentative_path:
		var b = biome_map.get(cell, Biome.PLAIN)
		temp_cost += BIOME_DATA[b]["build"]
		temp_maintenance += BIOME_DATA[b]["maint"]
		
		if b == Biome.MOUNTAIN: count_tunnels += 1
		elif b == Biome.RIVER: count_bridges += 1
		elif b == Biome.FOREST: count_forests += 1

	var connects_cities = false
	if distance > 1:
		var start_pos = tentative_path[0]
		var end_pos = tentative_path[distance - 1]
		if (start_pos == city_a and end_pos == city_b) or (start_pos == city_b and end_pos == city_a):
			connects_cities = true

	var text = "RELATORIO DE CONSTRUCAO\n\n"
	
	if not connects_cities:
		text += "[ERRO: A rota deve iniciar na cidade e terminar na outra!]\n\n"
		btn_accept.disabled = true
	else:
		btn_accept.disabled = false

	text += "Distancia Total: " + str(distance) + " km\n"
	text += "Custo da Obra: $" + str(temp_cost) + "\n"
	
	# Relatorio de engenharia!
	if count_bridges > 0 or count_tunnels > 0 or count_forests > 0:
		var extras = []
		if count_bridges > 0: extras.append(str(count_bridges) + " Ponte(s)")
		if count_tunnels > 0: extras.append(str(count_tunnels) + " Tunel(is)")
		if count_forests > 0: extras.append(str(count_forests) + " Desmatamento(s)")
		
		text += "  ↳ Obras Especiais: " + ", ".join(extras) + "\n"
		
	text += "Manutencao Diaria Adicional: $" + str(temp_maintenance) + "\n\n"
	text += "Saldo da Empresa: $" + str(GameManager.money)

	info_label.text = text
	validation_panel.visible = true

func _on_accept_pressed() -> void:
	if GameManager.money >= temp_cost:
		GameManager.money -= temp_cost
		GameManager.daily_maintenance += temp_maintenance
		
		confirmed_routes.append(tentative_path.duplicate())
		tentative_path.clear()
		
		GameManager.has_active_route = true 
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
	# 1. Desenha os Biomas pintando os quadrados
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell = Vector2i(x, y)
			var b = biome_map.get(cell, Biome.PLAIN)
			var color = BIOME_DATA[b]["color"]
			draw_rect(Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE), color)

	# 2. Desenha a Grade de fundo (transparente por cima das cores)
	for x in range(GRID_WIDTH + 1):
		draw_line(Vector2(x * TILE_SIZE, 0), Vector2(x * TILE_SIZE, GRID_HEIGHT * TILE_SIZE), Color(0, 0, 0, 0.1), 1.0)
	for y in range(GRID_HEIGHT + 1):
		draw_line(Vector2(0, y * TILE_SIZE), Vector2(GRID_WIDTH * TILE_SIZE, y * TILE_SIZE), Color(0, 0, 0, 0.1), 1.0)

	for route in confirmed_routes:
		_draw_custom_track(route, false) 

	_draw_custom_track(tentative_path, true)

	draw_rect(Rect2(city_a.x * TILE_SIZE, city_a.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.DODGER_BLUE)
	draw_rect(Rect2(city_b.x * TILE_SIZE, city_b.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.CRIMSON)

# Funcao de desenho vetorial (Linha Fina Estilo Planta)
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
		var spacing = 12.0 
		var num_ties = int(segment_length / spacing)
		
		for j in range(1, num_ties + 1):
			var tie_center = p1 + dir * (j * spacing)
			draw_line(tie_center - normal * 5, tie_center + normal * 5, line_color, line_width)
