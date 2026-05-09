extends Node2D

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 18
const GRID_HEIGHT: int = 10

const COST_PER_KM: int = 50
const MAINTENANCE_PER_KM: int = 5

var astar_grid: AStarGrid2D
var city_a: Vector2i = Vector2i(2, 5)
var city_b: Vector2i = Vector2i(15, 5)

var is_dragging: bool = false
var drag_start: Vector2i
var drag_current: Vector2i
var tentative_path: Array[Vector2i] = []
var confirmed_path: Array[Vector2i] = []

var validation_panel: Panel
var info_label: Label
var btn_accept: Button
var btn_reject: Button
var btn_go_desk: Button

var temp_cost: int = 0
var temp_maintenance: int = 0

func _ready() -> void:
	_setup_astar()
	_setup_ui()

func _setup_astar() -> void:
	astar_grid = AStarGrid2D.new()
	astar_grid.region = Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	astar_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
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
	validation_panel.size = Vector2(300, 350) # AUMENTADO para resolver sobreposicao
	validation_panel.visible = false
	add_child(validation_panel)

	info_label = Label.new()
	info_label.position = Vector2(15, 15)
	info_label.size = Vector2(270, 270) # AUMENTADO para dar mais espaco ao texto
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation_panel.add_child(info_label)

	btn_accept = Button.new()
	btn_accept.text = "Aprovar Rota"
	btn_accept.position = Vector2(15, 290) # DESCIDO para evitar o texto
	btn_accept.size = Vector2(130, 40)
	btn_accept.pressed.connect(_on_accept_pressed)
	validation_panel.add_child(btn_accept)

	btn_reject = Button.new()
	btn_reject.text = "Cancelar"
	btn_reject.position = Vector2(155, 290) # DESCIDO para evitar o texto
	btn_reject.size = Vector2(130, 40)
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
				is_dragging = true
				drag_start = cell
				tentative_path.clear()
			else:
				if is_dragging:
					is_dragging = false
					if tentative_path.size() > 0:
						_calculate_and_show_validation()
					queue_redraw()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			tentative_path.clear()
			confirmed_path.clear()
			GameManager.daily_maintenance = 0
			GameManager.has_active_route = false 
			queue_redraw()

	elif event is InputEventMouseMotion and is_dragging:
		var cell = _get_cell_under_mouse(event.position)
		if cell != drag_current and astar_grid.is_in_bounds(cell.x, cell.y):
			drag_current = cell
			tentative_path = astar_grid.get_id_path(drag_start, drag_current)
			queue_redraw()

func _calculate_and_show_validation() -> void:
	var distance = tentative_path.size()
	temp_cost = distance * COST_PER_KM
	temp_maintenance = distance * MAINTENANCE_PER_KM

	var connects_cities = false
	if distance > 1:
		var start_pos = tentative_path[0]
		var end_pos = tentative_path[distance - 1]
		if (start_pos == city_a and end_pos == city_b) or (start_pos == city_b and end_pos == city_a):
			connects_cities = true

	var text = "RELATORIO DE CONSTRUCAO\n\n"
	
	if not connects_cities:
		text += "[ERRO: A rota deve iniciar exatamente em uma cidade e terminar na outra!]\n\n"
		btn_accept.disabled = true
	else:
		btn_accept.disabled = false

	text += "Distancia Total: " + str(distance) + " km\n"
	text += "Custo da Obra: $" + str(temp_cost) + "\n"
	text += "Manutencao Diaria Adicional: $" + str(temp_maintenance) + "\n\n"
	text += "Saldo da Empresa: $" + str(GameManager.money)

	info_label.text = text
	validation_panel.visible = true

func _on_accept_pressed() -> void:
	if GameManager.money >= temp_cost:
		GameManager.money -= temp_cost
		GameManager.daily_maintenance += temp_maintenance
		
		confirmed_path.append_array(tentative_path)
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
	for x in range(GRID_WIDTH + 1):
		draw_line(Vector2(x * TILE_SIZE, 0), Vector2(x * TILE_SIZE, GRID_HEIGHT * TILE_SIZE), Color(0.2, 0.2, 0.2), 1.0)
	for y in range(GRID_HEIGHT + 1):
		draw_line(Vector2(0, y * TILE_SIZE), Vector2(GRID_WIDTH * TILE_SIZE, y * TILE_SIZE), Color(0.2, 0.2, 0.2), 1.0)

	for cell in confirmed_path:
		draw_rect(Rect2(cell.x * TILE_SIZE + 16, cell.y * TILE_SIZE + 16, 32, 32), Color.DARK_GREEN)
	for cell in tentative_path:
		draw_rect(Rect2(cell.x * TILE_SIZE + 16, cell.y * TILE_SIZE + 16, 32, 32), Color.YELLOW)

	draw_rect(Rect2(city_a.x * TILE_SIZE, city_a.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.DODGER_BLUE)
	draw_rect(Rect2(city_b.x * TILE_SIZE, city_b.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.CRIMSON)
