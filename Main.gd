extends Node2D

var map_node: Node2D
var desk_node: Node2D

var esc_layer: CanvasLayer
var esc_overlay: ColorRect
var btn_esc_map: Button
var btn_esc_desk: Button
var btn_esc_quit: Button
var is_esc_open: bool = false

func _ready() -> void:
	map_node = $MapView
	desk_node = $DeskView
	
	if GameManager.start_in_world_map:
		go_to_map()
	else:
		go_to_desk()
		
	_setup_esc_menu()
	
	GameManager.game_over.connect(_on_game_over)

func go_to_map() -> void:
	desk_node.visible = false
	map_node.visible = true
	if is_esc_open: _toggle_esc_menu() 

func go_to_desk() -> void:
	map_node.visible = false
	desk_node.visible = true
	if is_esc_open: _toggle_esc_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): 
		_toggle_esc_menu()
	
	# RESTAURADO: Alternar entre telas com ESPAÇO
	if event.is_action_pressed("ui_select") and not is_esc_open:
		if map_node.visible:
			go_to_desk()
		else:
			go_to_map()

func _setup_esc_menu() -> void:
	esc_layer = CanvasLayer.new()
	esc_layer.layer = 250
	add_child(esc_layer)
	
	esc_overlay = ColorRect.new()
	esc_overlay.color = Color(0, 0, 0, 0.7)
	esc_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	esc_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	esc_layer.add_child(esc_overlay)
	
	var menu_w = 400
	var start_x = 960 - (menu_w / 2.0)
	var start_y = 300 
	
	var title_esc = Label.new()
	title_esc.text = "MENU DE PAUSA"
	title_esc.add_theme_font_size_override("font_size", 40)
	title_esc.add_theme_color_override("font_color", Color.YELLOW)
	title_esc.position = Vector2(start_x, start_y - 80)
	title_esc.size = Vector2(menu_w, 60)
	title_esc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esc_layer.add_child(title_esc)
	
	btn_esc_map = Button.new()
	btn_esc_map.text = "VOLTAR AO MAPA"
	btn_esc_map.position = Vector2(start_x, start_y)
	btn_esc_map.size = Vector2(menu_w, 60)
	btn_esc_map.pressed.connect(_on_btn_esc_map_pressed)
	esc_layer.add_child(btn_esc_map)
	
	btn_esc_desk = Button.new()
	btn_esc_desk.text = "VOLTAR À MESA"
	btn_esc_desk.position = Vector2(start_x, start_y + 80)
	btn_esc_desk.size = Vector2(menu_w, 60)
	btn_esc_desk.pressed.connect(_on_btn_esc_desk_pressed)
	esc_layer.add_child(btn_esc_desk)
	
	btn_esc_quit = Button.new()
	btn_esc_quit.text = "SAIR PARA O DESKTOP"
	btn_esc_quit.add_theme_color_override("font_color", Color.INDIAN_RED)
	btn_esc_quit.position = Vector2(start_x, start_y + 160)
	btn_esc_quit.size = Vector2(menu_w, 60)
	btn_esc_quit.pressed.connect(_on_btn_esc_quit_pressed)
	esc_layer.add_child(btn_esc_quit)
	
	esc_layer.visible = false

func _toggle_esc_menu() -> void:
	is_esc_open = not is_esc_open
	esc_layer.visible = is_esc_open
	
	if is_esc_open:
		if map_node.visible: btn_esc_map.disabled = true; btn_esc_map.text = "[ NO MAPA ]"
		else: btn_esc_desk.disabled = true; btn_esc_desk.text = "[ NA MESA ]"
	else:
		btn_esc_map.disabled = false; btn_esc_map.text = "VOLTAR AO MAPA"
		btn_esc_desk.disabled = false; btn_esc_desk.text = "VOLTAR À MESA"

func _on_btn_esc_map_pressed() -> void: go_to_map()
func _on_btn_esc_desk_pressed() -> void: go_to_desk()
func _on_btn_esc_quit_pressed() -> void: get_tree().quit()

func _on_game_over(is_victory: bool, message: String) -> void:
	if esc_layer: esc_layer.queue_free()
	go_to_desk()
