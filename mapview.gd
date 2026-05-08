extends Node2D

# Configuracoes da Grade
const TILE_SIZE: int = 64
const GRID_WIDTH: int = 18
const GRID_HEIGHT: int = 10

# Custos Base da Ferrovia
const COST_PER_KM: int = 50
const MAINTENANCE_PER_KM: int = 5

# Variaveis do Pathfinding e Mapa
var astar_grid: AStarGrid2D
var city_a: Vector2i = Vector2i(2, 5)
var city_b: Vector2i = Vector2i(15, 5)

# Controles de Interacao
var is_dragging: bool = false
var drag_start: Vector2i
var drag_current: Vector2i
var tentative_path: Array[Vector2i] = []
var confirmed_path: Array[Vector2i] = []

# Variaveis de UI Criadas via Codigo
var validation_panel: Panel
var info_label: Label
var btn_accept: Button
var btn_reject: Button

# Variaveis temporarias para os custos calculados
var temp_cost: int = 0
var temp_maintenance: int = 0

func _ready() -> void:
	_setup_astar()
	_setup_ui() # Chama a construcao da interface

# Prepara a malha matematica para achar caminhos
func _setup_astar() -> void:
	astar_grid = AStarGrid2D.new()
	astar_grid.region = Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	astar_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()

# Cria o painel fixo de validacao inteiramente por codigo
func _setup_ui() -> void:
	# Criando o painel de fundo (Fixo no canto direito)
	validation_panel = Panel.new()
	validation_panel.position = Vector2(800, 50) 
	validation_panel.size = Vector2(300, 220)
	validation_panel.visible = false # Comeca escondido
	add_child(validation_panel)

	# Criando o texto de informacao
	info_label = Label.new()
	info_label.position = Vector2(15, 15)
	info_label.size = Vector2(270, 120)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation_panel.add_child(info_label)

	# Botao Aprovar
	btn_accept = Button.new()
	btn_accept.text = "Aprovar Rota"
	btn_accept.position = Vector2(15, 160)
	btn_accept.size = Vector2(130, 40)
	btn_accept.pressed.connect(_on_accept_pressed)
	validation_panel.add_child(btn_accept)

	# Botao Rejeitar
	btn_reject = Button.new()
	btn_reject.text = "Cancelar"
	btn_reject.position = Vector2(155, 160)
	btn_reject.size = Vector2(130, 40)
	btn_reject.pressed.connect(_on_reject_pressed)
	validation_panel.add_child(btn_reject)

# Captura os cliques e o arrastar do mouse
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Se o painel estiver aberto, bloqueia o desenho de novos trilhos
	if validation_panel.visible:
		return

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
		
		# Exclui todos os caminhos
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			print("Construcao excluida.")
			tentative_path.clear()
			confirmed_path.clear()
			GameManager.daily_maintenance = 0 # Zera a manutencao ao excluir
			queue_redraw()

	elif event is InputEventMouseMotion and is_dragging:
		var cell = _get_cell_under_mouse(event.position)
		if cell != drag_current and astar_grid.is_in_bounds(cell.x, cell.y):
			drag_current = cell
			tentative_path = astar_grid.get_id_path(drag_start, drag_current)
			queue_redraw()

# Calcula os valores baseados na distancia e mostra o painel
func _calculate_and_show_validation() -> void:
	var distance = tentative_path.size()
	temp_cost = distance * COST_PER_KM
	temp_maintenance = distance * MAINTENANCE_PER_KM

	var text = "RELATORIO DE CONSTRUCAO\n\n"
	text += "Distancia Total: " + str(distance) + " km\n"
	text += "Custo da Obra: $" + str(temp_cost) + "\n"
	text += "Manutencao Diaria Adicional: $" + str(temp_maintenance) + "\n\n"
	text += "Saldo da Empresa: $" + str(GameManager.money)

	info_label.text = text
	validation_panel.visible = true

# Funcao chamada ao clicar no botao Aprovar
func _on_accept_pressed() -> void:
	if GameManager.money >= temp_cost:
		# Desconta o dinheiro e aumenta a manutencao global
		GameManager.money -= temp_cost
		GameManager.daily_maintenance += temp_maintenance
		
		# Transfere os trilhos amarelos para verdes
		confirmed_path.append_array(tentative_path)
		tentative_path.clear()
		
		print("Rota Aprovada! Saldo: $", GameManager.money, " | Manutencao: $", GameManager.daily_maintenance)
		validation_panel.visible = false
		queue_redraw()
	else:
		# Avisa o jogador se faltar dinheiro
		info_label.text = "ALERTA: FUNDOS INSUFICIENTES!\n\nVoce precisa de $" + str(temp_cost) + " para construir esta rota."

# Funcao chamada ao clicar no botao Cancelar
func _on_reject_pressed() -> void:
	tentative_path.clear()
	validation_panel.visible = false
	queue_redraw()

func _get_cell_under_mouse(mouse_pos: Vector2) -> Vector2i:
	return Vector2i(mouse_pos.x / TILE_SIZE, mouse_pos.y / TILE_SIZE)

# Desenha os elementos na tela
func _draw() -> void:
	# Grade
	for x in range(GRID_WIDTH + 1):
		draw_line(Vector2(x * TILE_SIZE, 0), Vector2(x * TILE_SIZE, GRID_HEIGHT * TILE_SIZE), Color(0.2, 0.2, 0.2), 1.0)
	for y in range(GRID_HEIGHT + 1):
		draw_line(Vector2(0, y * TILE_SIZE), Vector2(GRID_WIDTH * TILE_SIZE, y * TILE_SIZE), Color(0.2, 0.2, 0.2), 1.0)

	# Trilhos Aprovados (Verde Escuro)
	for cell in confirmed_path:
		draw_rect(Rect2(cell.x * TILE_SIZE + 16, cell.y * TILE_SIZE + 16, 32, 32), Color.DARK_GREEN)

	# Trilhos em Analise (Amarelo)
	for cell in tentative_path:
		draw_rect(Rect2(cell.x * TILE_SIZE + 16, cell.y * TILE_SIZE + 16, 32, 32), Color.YELLOW)

	# Cidades
	draw_rect(Rect2(city_a.x * TILE_SIZE, city_a.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.DODGER_BLUE)
	draw_rect(Rect2(city_b.x * TILE_SIZE, city_b.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color.CRIMSON)
