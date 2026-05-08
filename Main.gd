extends Node2D

@onready var map_view: Node = $MapView
@onready var desk_view: Node = $DeskView

# Estados do jogo para controle
enum GameState { MAP, DESK, END } # Adicionado o estado END
var current_state: GameState = GameState.MAP

# Interface de Fim de Jogo (Construida via codigo)
var end_panel: Panel
var end_label: Label
var btn_restart: Button

func _ready() -> void:
	_setup_end_screen()
	
	# Ouve o GameManager para saber se o jogo acabou
	GameManager.game_over.connect(_on_game_over)
	
	go_to_map()

# Cria o painel de Game Over/Vitoria
func _setup_end_screen() -> void:
	end_panel = Panel.new()
	end_panel.size = Vector2(600, 300)
	end_panel.position = Vector2(276, 174) # Centralizado na tela padrao (1152x648)
	end_panel.visible = false
	add_child(end_panel)

	end_label = Label.new()
	end_label.position = Vector2(20, 40)
	end_label.size = Vector2(560, 180)
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_panel.add_child(end_label)

	btn_restart = Button.new()
	btn_restart.text = "Jogar Novamente"
	btn_restart.size = Vector2(200, 50)
	btn_restart.position = Vector2(200, 220)
	btn_restart.pressed.connect(_on_restart_pressed)
	end_panel.add_child(btn_restart)

# Transicao para a tela de Mapa
func go_to_map() -> void:
	if current_state == GameState.END: return # Bloqueia se o jogo acabou
	
	current_state = GameState.MAP
	map_view.visible = true
	desk_view.visible = false

# Transicao para a tela de Mesa
func go_to_desk() -> void:
	if current_state == GameState.END: return # Bloqueia se o jogo acabou
	
	current_state = GameState.DESK
	map_view.visible = false
	desk_view.visible = true

# Chamado quando a empresa vai a falencia ou atinge a meta
func _on_game_over(is_victory: bool, message: String) -> void:
	current_state = GameState.END
	
	# Esconde o jogo e mostra o painel
	map_view.visible = false
	desk_view.visible = false
	
	end_label.text = message
	
	# Muda a cor do texto dependendo do resultado
	if is_victory:
		end_label.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	else:
		end_label.add_theme_color_override("font_color", Color.INDIAN_RED)
		
	end_panel.visible = true

# Reinicia a partida
func _on_restart_pressed() -> void:
	GameManager.reset_game()
	# Recarrega a cena atual inteira, limpando os trilhos e contratos antigos
	get_tree().reload_current_scene()

# Pressione ESPACO para trocar de tela
func _input(event: InputEvent) -> void:
	if current_state == GameState.END: return # Bloqueia atalhos de teclado no Game Over
	
	if event.is_action_pressed("ui_accept"): 
		if current_state == GameState.MAP:
			go_to_desk()
		else:
			go_to_map()
