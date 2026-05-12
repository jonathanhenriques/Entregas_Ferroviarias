extends Node2D

var map_node: Node2D
var desk_node: Node2D

var esc_layer: CanvasLayer
var esc_overlay: ColorRect
var btn_esc_map: Button
var btn_esc_desk: Button
var btn_esc_quit: Button
var is_esc_open: bool = false

var menu_layer: CanvasLayer
var letter_layer: CanvasLayer
var letter_label: Label
var letter_bg: ColorRect

var intro_texts: Array[String] = [
	"Para o meu neto.\n\nO tempo das nossas pequenas ferrovias acabou. Os grandes monopolios esmagaram quase tudo. A nossa velha companhia e uma das ultimas que ainda respira.",
	"O meu tempo acabou, mas as cidades ainda precisam de nos. O Bear, o meu velho socio, vai precisar de ti para manter os trens a andar. Nao e um trabalho bonito, mas e vital.",
	"Ele deixou os papeis na tua mesa.\n\nA partir de hoje, o peso dos trilhos e teu.\n\nBoa sorte."
]
var current_intro_page: int = 0
var is_letter_typing: bool = false
var letter_char_index: int = 0
var letter_fast_forward: bool = false

func _ready() -> void:
	map_node = $MapView
	desk_node = $DeskView
	
	map_node.visible = false
	desk_node.visible = false
		
	_setup_esc_menu()
	_setup_main_menu()
	_setup_intro_letter()
	
	GameManager.game_over.connect(_on_game_over)
	
	menu_layer.visible = true

func _setup_main_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 400
	add_child(menu_layer)
	
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(bg)
	
	var title = Label.new()
	title.text = "CIA. DE ENTREGAS FERROVIARIAS"
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color.GOLDENROD)
	title.position = Vector2(0, 200)
	title.size = Vector2(1920, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_layer.add_child(title)
	
	var start_x = 960 - 200
	
	var btn_new = Button.new()
	btn_new.text = "NOVO JOGO"
	btn_new.position = Vector2(start_x, 450)
	btn_new.size = Vector2(400, 70)
	btn_new.pressed.connect(_on_btn_new_game_pressed)
	menu_layer.add_child(btn_new)
	
	var btn_continue = Button.new()
	btn_continue.position = Vector2(start_x, 550)
	btn_continue.size = Vector2(400, 70)
	
	# NOVO: Ativa o botao Continuar se houver save!
	if GameManager.has_save():
		btn_continue.text = "CONTINUAR JOGO"
		btn_continue.disabled = false
		btn_continue.pressed.connect(_on_btn_continue_pressed)
	else:
		btn_continue.text = "NENHUM ARQUIVO ENCONTRADO"
		btn_continue.disabled = true
		
	menu_layer.add_child(btn_continue)
	
	var btn_quit = Button.new()
	btn_quit.text = "SAIR"
	btn_quit.position = Vector2(start_x, 650)
	btn_quit.size = Vector2(400, 70)
	btn_quit.pressed.connect(_on_btn_esc_quit_pressed)
	menu_layer.add_child(btn_quit)

func _setup_intro_letter() -> void:
	letter_layer = CanvasLayer.new()
	letter_layer.layer = 350
	add_child(letter_layer)
	
	letter_bg = ColorRect.new()
	letter_bg.color = Color(0.05, 0.05, 0.05, 1.0)
	letter_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	letter_layer.add_child(letter_bg)
	
	var paper = ColorRect.new()
	paper.color = Color(0.8, 0.7, 0.5) 
	paper.size = Vector2(800, 600)
	paper.position = Vector2(560, 240)
	letter_bg.add_child(paper)
	
	letter_label = Label.new()
	letter_label.position = Vector2(50, 50)
	letter_label.size = Vector2(700, 500)
	letter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	letter_label.add_theme_font_size_override("font_size", 32)
	letter_label.add_theme_color_override("font_color", Color.BLACK)
	paper.add_child(letter_label)
	
	var click_catcher = Control.new()
	click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_catcher.gui_input.connect(_on_letter_input)
	letter_layer.add_child(click_catcher)
	
	letter_layer.visible = false

func _on_btn_new_game_pressed() -> void:
	GameManager.reset_game()
	menu_layer.visible = false
	_start_intro_letter()

# NOVO: Funcao de Continuar o Jogo
func _on_btn_continue_pressed() -> void:
	if GameManager.load_game():
		menu_layer.visible = false
		go_to_desk()

func _start_intro_letter() -> void:
	letter_layer.visible = true
	current_intro_page = 0
	_play_letter_page()

func _play_letter_page() -> void:
	letter_char_index = 0
	letter_label.text = ""
	is_letter_typing = true
	letter_fast_forward = false
	_type_letter_char()

func _type_letter_char() -> void:
	var full_text = intro_texts[current_intro_page]
	if letter_fast_forward:
		letter_label.text = full_text
		is_letter_typing = false
		return
	
	if letter_char_index < full_text.length():
		letter_label.text += full_text[letter_char_index]
		letter_char_index += 1
		await get_tree().create_timer(0.04).timeout
		_type_letter_char()
	else:
		is_letter_typing = false

func _on_letter_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				if is_letter_typing:
					letter_fast_forward = true
				else:
					current_intro_page += 1
					if current_intro_page < intro_texts.size():
						_play_letter_page()
					else:
						letter_layer.visible = false
						go_to_desk()

func go_to_map() -> void:
	desk_node.visible = false
	map_node.visible = true
	if is_esc_open: _toggle_esc_menu() 

func go_to_desk() -> void:
	map_node.visible = false
	desk_node.visible = true
	if is_esc_open: _toggle_esc_menu()

func _unhandled_input(event: InputEvent) -> void:
	if menu_layer.visible or letter_layer.visible: return
	
	if event.is_action_pressed("ui_cancel"): 
		_toggle_esc_menu()
	
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
		if map_node.visible: 
			btn_esc_map.disabled = true
			btn_esc_map.text = "[ NO MAPA ]"
		else: 
			btn_esc_desk.disabled = true
			btn_esc_desk.text = "[ NA MESA ]"
	else:
		btn_esc_map.disabled = false
		btn_esc_map.text = "VOLTAR AO MAPA"
		btn_esc_desk.disabled = false
		btn_esc_desk.text = "VOLTAR À MESA"

func _on_btn_esc_map_pressed() -> void: go_to_map()
func _on_btn_esc_desk_pressed() -> void: go_to_desk()
func _on_btn_esc_quit_pressed() -> void: get_tree().quit()

func _on_game_over(is_victory: bool, message: String) -> void:
	if esc_layer: esc_layer.queue_free()
	go_to_desk()
