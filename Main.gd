extends Node2D

@onready var map_view: Node = $MapView
@onready var desk_view: Node = $DeskView

# Estados do jogo para controle
enum GameState { MAP, DESK }
var current_state: GameState = GameState.MAP

func _ready() -> void:
	# O jogo sempre começa no mapa
	go_to_map()

# Transição para a tela de Mapa
func go_to_map() -> void:
	current_state = GameState.MAP
	map_view.visible = true
	desk_view.visible = false
	print("Entrou no Modo: MAPA")

# Transição para a tela de Mesa
func go_to_desk() -> void:
	current_state = GameState.DESK
	map_view.visible = false
	desk_view.visible = true
	print("Entrou no Modo: MESA")

# Função temporária de teste: Pressione ESPAÇO para trocar de tela
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"): # Padrão do Godot: Enter ou Espaço
		if current_state == GameState.MAP:
			go_to_desk()
		else:
			go_to_map()
