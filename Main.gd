extends Node2D

@onready var map_view: Node = $MapView
@onready var desk_view: Node = $DeskView

enum GameState { WORLD_MAP, MAP, DESK, END } 
var current_state: GameState = GameState.WORLD_MAP

var end_panel: Panel
var end_label: Label
var btn_restart: Button

var world_map_panel: Panel
var level_buttons_container: HBoxContainer

func _ready() -> void:
	_setup_end_screen()
	_setup_world_map()
	
	GameManager.game_over.connect(_on_game_over)
	
	if GameManager.start_in_world_map:
		go_to_world_map()
	else:
		go_to_map()

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

	# Agora le os niveis direto do seu ficheiro LevelData!
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

# CORRECAO DO BUG (Transicoes Blindadas)
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

func _input(event: InputEvent) -> void:
	if current_state == GameState.END or current_state == GameState.WORLD_MAP: return 
	
	if event.is_action_pressed("ui_accept"): 
		if current_state == GameState.MAP:
			go_to_desk()
		else:
			go_to_map()
