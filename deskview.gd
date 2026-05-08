extends Node2D

# Referencias visuais
var bg_rect: ColorRect
var report_panel: Panel
var report_label: Label
var btn_next_day: Button
var btn_back_map: Button

func _ready() -> void:
	_setup_ui()
	
	# Conecta os sinais do GameManager para atualizar o relatorio sempre que a economia mudar
	GameManager.money_changed.connect(_on_stats_changed)
	GameManager.day_changed.connect(_on_stats_changed)
	GameManager.maintenance_updated.connect(_on_stats_changed)

func _setup_ui() -> void:
	# 1. Fundo da mesa (cor de madeira escurecida)
	bg_rect = ColorRect.new()
	bg_rect.color = Color(0.25, 0.15, 0.1) # Marrom escuro
	bg_rect.size = Vector2(1152, 648) # Cobre a resolucao padrao
	add_child(bg_rect)

	# 2. Papel do Relatorio (Painel central)
	report_panel = Panel.new()
	report_panel.position = Vector2(400, 150)
	report_panel.size = Vector2(350, 300)
	add_child(report_panel)

	# 3. Texto do Relatorio
	report_label = Label.new()
	report_label.position = Vector2(20, 20)
	report_label.size = Vector2(310, 200)
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_panel.add_child(report_label)

	# 4. Botao de Passar o Dia
	btn_next_day = Button.new()
	btn_next_day.text = "Finalizar Dia (Pagar Manutencao)"
	btn_next_day.position = Vector2(20, 240)
	btn_next_day.size = Vector2(310, 40)
	btn_next_day.pressed.connect(_on_next_day_pressed)
	report_panel.add_child(btn_next_day)

	# 5. Botao para Voltar ao Mapa (Alternativa ao 'Espaco/Enter')
	btn_back_map = Button.new()
	btn_back_map.text = "<- Voltar ao Mapa"
	btn_back_map.position = Vector2(20, 20)
	btn_back_map.size = Vector2(180, 40)
	btn_back_map.pressed.connect(_on_back_map_pressed)
	add_child(btn_back_map)

	# Preenche o texto pela primeira vez ao abrir
	_update_report_text()

# Monta o texto atualizado lendo as variaveis globais
func _update_report_text() -> void:
	var text = "RELATORIO ADMINISTRATIVO\n\n"
	text += "Dia de Operacao: " + str(GameManager.current_day) + "\n"
	text += "Saldo em Caixa: $" + str(GameManager.money) + "\n"
	text += "Custo de Manutencao Diaria: -$" + str(GameManager.daily_maintenance) + "\n"
	
	# Alerta caso o jogador corra risco de falencia ao passar o dia
	if GameManager.daily_maintenance > GameManager.money:
		text += "\nAVISO: O saldo nao cobre a manutencao. Finalizar o dia causara FALENCIA!"
		
	report_label.text = text

# Funcao coringa que recebe os sinais do GameManager e forca a atualizacao do texto
func _on_stats_changed(_new_value) -> void:
	_update_report_text()

# Logica de apertar o botao de passar o dia
func _on_next_day_pressed() -> void:
	# Chama a funcao que criamos no Passo 1 no game_manager.gd
	GameManager.end_day()

# Logica para voltar a tela do mapa via interface
func _on_back_map_pressed() -> void:
	var main_node = get_parent()
	if main_node.has_method("go_to_map"):
		main_node.go_to_map()
