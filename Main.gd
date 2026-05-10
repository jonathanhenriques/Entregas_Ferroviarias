extends Node2D

@onready var map_view: Node = $MapView
@onready var desk_view: Node = $DeskView

# O estado PAUSE foi adicionado!
enum GameState { WORLD_MAP, MAP, DESK, END, PAUSE } 
var current_state: GameState = GameState.WORLD_MAP
var previous_state: GameState = GameState.WORLD_MAP # Lembra de onde viemos para despausar

var end_panel: Panel
var end_label: Label
var btn_restart: Button

var world_map_panel: Panel
var level_buttons_container: HBoxContainer

# Variaveis do Menu de Pausa
var pause_layer: CanvasLayer
var pause_panel: Panel
var settings_panel: Panel

func _ready() -> void:
	_setup_end_screen()
	_setup_world_map()
	_setup_pause_menu() # Iniciamos o menu de pausa aqui
	
	GameManager.game_over.connect(_on_game_over)
	
	if GameManager.start_in_world_map:
		go_to_world_map()
	else:
		go_to_map()

# ==========================================
# MENU DE PAUSA E CONFIGURACOES (NOVO)
# ==========================================
func _setup_pause_menu() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 100 # Garante que fica por cima do mapa, da mesa e do fim de jogo!
	pause_layer.visible = false
	add_child(pause_layer)
	
	# Tela escura transparente no fundo
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7) 
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT) 
	pause_layer.add_child(overlay)
	
	# PAINEL PRINCIPAL
	pause_panel = Panel.new()
	pause_panel.custom_minimum_size = Vector2(300, 350)
	pause_panel.set_anchors_preset(Control.PRESET_CENTER) # Fica sempre no centro do monitor
	pause_layer.add_child(pause_panel)
	
	var title = Label.new()
	title.text = "JOGO PAUSADO"
	title.position = Vector2(0, 30)
	title.size = Vector2(300, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_panel.add_child(title)
	
	var btn_continue = Button.new()
	btn_continue.text = "Continuar"
	btn_continue.position = Vector2(50, 100)
	btn_continue.size = Vector2(200, 50)
	btn_continue.pressed.connect(_on_continue_pressed)
	pause_panel.add_child(btn_continue)
	
	var btn_settings = Button.new()
	btn_settings.text = "Configuracoes"
	btn_settings.position = Vector2(50, 170)
	btn_settings.size = Vector2(200, 50)
	btn_settings.pressed.connect(_on_open_settings)
	pause_panel.add_child(btn_settings)
	
	var btn_quit = Button.new()
	btn_quit.text = "Sair para o Desktop"
	btn_quit.position = Vector2(50, 240)
	btn_quit.size = Vector2(200, 50)
	btn_quit.pressed.connect(_on_quit_pressed)
	pause_panel.add_child(btn_quit)
	
	# SUBMENU DE CONFIGURACOES DE TELA
	settings_panel = Panel.new()
	settings_panel.custom_minimum_size = Vector2(400, 380)
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.visible = false
	pause_layer.add_child(settings_panel)
	
	var set_title = Label.new()
	set_title.text = "CONFIGURACOES DE TELA"
	set_title.position = Vector2(0, 30)
	set_title.size = Vector2(400, 50)
	set_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_panel.add_child(set_title)
	
	# Os nossos tamanhos fixos combinados!
	var btn_res1 = Button.new()
	btn_res1.text = "Janela Pequena (1152x648)"
	btn_res1.position = Vector2(50, 80)
	btn_res1.size = Vector2(300, 40)
	btn_res1.pressed.connect(_set_resolution.bind(1152, 648, false))
	settings_panel.add_child(btn_res1)
	
	var btn_res2 = Button.new()
	btn_res2.text = "Janela HD (1280x720)"
	btn_res2.position = Vector2(50, 130)
	btn_res2.size = Vector2(300, 40)
	btn_res2.pressed.connect(_set_resolution.bind(1280, 720, false))
	settings_panel.add_child(btn_res2)
	
	var btn_res3 = Button.new()
	btn_res3.text = "Janela Full HD (1920x1080)"
	btn_res3.position = Vector2(50, 180)
	btn_res3.size = Vector2(300, 40)
	btn_res3.pressed.connect(_set_resolution.bind(1920, 1080, false))
	settings_panel.add_child(btn_res3)
	
	var btn_full = Button.new()
	btn_full.text = "Tela Cheia (Fullscreen)"
	btn_full.position = Vector2(50, 230)
	btn_full.size = Vector2(300, 40)
	btn_full.pressed.connect(_set_resolution.bind(0, 0, true))
	settings_panel.add_child(btn_full)
	
	var btn_back = Button.new()
	btn_back.text = "Voltar"
	btn_back.position = Vector2(100, 300)
	btn_back.size = Vector2(200, 50)
	btn_back.pressed.connect(_on_close_settings)
	settings_panel.add_child(btn_back)

# Funcoes dos Botoes do Menu
func _on_continue_pressed() -> void:
	pause_layer.visible = false
	current_state = previous_state 

func _on_open_settings() -> void:
	pause_panel.visible = false
	settings_panel.visible = true

func _on_close_settings() -> void:
	settings_panel.visible = false
	pause_panel.visible = true

func _set_resolution(w: int, h: int, is_fullscreen: bool) -> void:
	var janela = get_tree().root
	
	# Trava de seguranca: Impede o erro se o sistema bloquear redimensionamentos
	if janela.is_embedded():
		print("AVISO: O sistema detetou uma janela embutida. Redimensionamento bloqueado pelo S.O.")
		return
		
	if is_fullscreen:
		janela.mode = Window.MODE_FULLSCREEN
	else:
		janela.mode = Window.MODE_WINDOWED
		janela.size = Vector2i(w, h)
		
		# Centraliza a janela no monitor ativo
		var screen_id = janela.current_screen
		var screen_size = DisplayServer.screen_get_size(screen_id)
		janela.position = (screen_size / 2) - (Vector2i(w, h) / 2)



func _on_quit_pressed() -> void:
	get_tree().quit()

# Interceptador da Tecla ESC
func _unhandled_input(event: InputEvent) -> void:
	# Sistema de Pausa
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if current_state != GameState.END: # Nao deixa pausar na tela de Game Over
			if current_state == GameState.PAUSE:
				# Se ja esta pausado, ESC funciona como "Voltar"
				if settings_panel.visible:
					_on_close_settings()
				else:
					_on_continue_pressed()
			else:
				# Salva o estado atual e entra no modo PAUSE
				previous_state = current_state
				current_state = GameState.PAUSE
				pause_layer.visible = true

	# Transicao de tela com Espaço (Blindada contra o Pause)
	if event.is_action_pressed("ui_accept") and current_state != GameState.PAUSE: 
		if current_state == GameState.MAP:
			go_to_desk()
		elif current_state == GameState.DESK:
			go_to_map()

# ==========================================
# RESTANTE DO CODIGO (Mapa Mundi e Transicoes)
# ==========================================
func _setup_world_map() -> void:
	world_map_panel = Panel.new()
	world_map_panel.size = Vector2(1152, 648)
	world_map_panel.visible = false
	add_child(world_map_panel)

	var title = Label.new()
	title.text = "CIA DE ENTREGAS FERROVIARIAS\nSelecione a Regiao de Atuacao"
	title.position = Vector2(0, 100)
	title.size = Vector2(1152, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_map_panel.add_child(title)

	level_buttons_container = HBoxContainer.new()
	level_buttons_container.position = Vector2(250, 250)
	level_buttons_container.size = Vector2(650, 200)
	level_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	level_buttons_container.add_theme_constant_override("separation", 50)
	world_map_panel.add_child(level_buttons_container)

func _refresh_world_map() -> void:
	for child in level_buttons_container.get_children():
		child.queue_free()

	for lvl in LevelData.LEVELS.keys():
		var btn = Button.new()
		var data = LevelData.LEVELS[lvl]
		btn.text = "FASE " + str(lvl) + "\n\n" + data["name"] + "\n\nMeta: $" + str(data["goal"])
		btn.custom_minimum_size = Vector2(200, 200)
		
		if lvl > GameManager.highest_unlocked_level:
			btn.disabled = true
			btn.text += "\n\n[ BLOQUEADO ]"
		else:
			btn.pressed.connect(_on_level_selected.bind(lvl))
			
		level_buttons_container.add_child(btn)

func _on_level_selected(lvl: int) -> void:
	GameManager.current_level = lvl
	GameManager.start_in_world_map = false
	GameManager.reset_game()
	get_tree().reload_current_scene()

func go_to_world_map() -> void:
	current_state = GameState.WORLD_MAP
	map_view.visible = false
	desk_view.visible = false
	end_panel.visible = false
	world_map_panel.visible = true
	_refresh_world_map()

func _setup_end_screen() -> void:
	end_panel = Panel.new()
	end_panel.size = Vector2(600, 300)
	end_panel.position = Vector2(276, 174) 
	end_panel.visible = false
	add_child(end_panel)

	end_label = Label.new()
	end_label.position = Vector2(20, 40)
	end_label.size = Vector2(560, 180)
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_panel.add_child(end_label)

	btn_restart = Button.new()
	btn_restart.text = "Voltar ao Mapa Mundi"
	btn_restart.size = Vector2(250, 50)
	btn_restart.position = Vector2(175, 220)
	btn_restart.pressed.connect(_on_restart_pressed)
	end_panel.add_child(btn_restart)

func go_to_map() -> void:
	if current_state == GameState.END: return 
	current_state = GameState.MAP
	world_map_panel.visible = false
	desk_view.visible = false
	map_view.visible = true

func go_to_desk() -> void:
	if current_state == GameState.END: return 
	current_state = GameState.DESK
	world_map_panel.visible = false
	map_view.visible = false
	desk_view.visible = true

func _on_game_over(is_victory: bool, message: String) -> void:
	current_state = GameState.END
	map_view.visible = false
	desk_view.visible = false
	end_label.text = message
	
	if is_victory:
		end_label.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	else:
		end_label.add_theme_color_override("font_color", Color.INDIAN_RED)
		
	end_panel.visible = true

func _on_restart_pressed() -> void:
	GameManager.start_in_world_map = true
	get_tree().reload_current_scene()
