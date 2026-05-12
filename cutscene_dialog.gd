extends CanvasLayer
class_name CutsceneDialog

signal contract_accepted(final_reward)
signal contract_rejected()
signal call_closed() 

# NOVO: Sinais para o cancelamento de contrato
signal cancel_confirmed(idx: int)
signal cancel_aborted()

var overlay: ColorRect
var dialog_box: ColorRect 
var name_label: Label
var text_label: Label

var btn_accept: Button
var btn_reject: Button
var btn_close: Button 

var silhouette_body: ColorRect
var silhouette_head: ColorRect

var full_text: String = ""
var char_index: int = 0
var offered_reward: int = 0
var is_typing: bool = false
var fast_forward: bool = false 

var current_mode: String = ""
var pending_cancel_idx: int = -1

func _ready() -> void:
	layer = 200 
	visible = false
	_setup_visuals()

func _setup_visuals() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP 
	add_child(overlay)

	silhouette_body = ColorRect.new()
	silhouette_body.color = Color(0, 0, 0, 1)
	silhouette_body.size = Vector2(600, 750)
	silhouette_body.position = Vector2(100, 330)
	add_child(silhouette_body)
	
	silhouette_head = ColorRect.new()
	silhouette_head.color = Color(0, 0, 0, 1)
	silhouette_head.size = Vector2(180, 210)
	silhouette_head.position = Vector2(310, 150)
	add_child(silhouette_head)

	dialog_box = ColorRect.new()
	dialog_box.color = Color(0.05, 0.05, 0.15, 0.9) 
	dialog_box.size = Vector2(1400, 300)
	dialog_box.position = Vector2(260, 700)
	add_child(dialog_box)
	
	var border = ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color.WHITE
	border.border_width = 2
	dialog_box.add_child(border)

	name_label = Label.new()
	name_label.position = Vector2(40, 20)
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color.YELLOW)
	dialog_box.add_child(name_label)

	text_label = Label.new()
	text_label.position = Vector2(40, 80)
	text_label.size = Vector2(1320, 150)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 28)
	dialog_box.add_child(text_label)

	btn_accept = Button.new()
	btn_accept.text = "ENVIAR PROPOSTA"
	btn_accept.size = Vector2(250, 50)
	btn_accept.position = Vector2(850, 230)
	btn_accept.pressed.connect(_on_accept)
	dialog_box.add_child(btn_accept)

	btn_reject = Button.new()
	btn_reject.text = "DESLIGAR"
	btn_reject.size = Vector2(200, 50)
	btn_reject.position = Vector2(1150, 230)
	btn_reject.pressed.connect(_on_reject)
	dialog_box.add_child(btn_reject)
	
	btn_close = Button.new()
	btn_close.text = "DESLIGAR"
	btn_close.size = Vector2(300, 50)
	btn_close.position = Vector2(1050, 230)
	btn_close.add_theme_color_override("font_color", Color.INDIAN_RED)
	btn_close.pressed.connect(_on_close)
	dialog_box.add_child(btn_close)

func _input(event: InputEvent) -> void:
	if visible:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.is_pressed():
					if is_typing:
						fast_forward = true

func start_call(company_name: String, company_type: String, company_cargo: String, base_reward: int, is_urgent: bool = false) -> void:
	_reset_ui()
	current_mode = "CALL"
	
	var dice = randi_range(1, 6)
	var mult = 1.0 + (dice * 0.1)
	offered_reward = int(base_reward * mult)
	
	name_label.text = "[ TRANSMISSAO: " + company_name.to_upper() + " ]"
	
	if is_urgent:
		name_label.add_theme_color_override("font_color", Color.ORANGE)
		full_text = "Alo? Pelo amor de Deus, sou da " + company_name + "!\n"
		full_text += "Temos um frete URGENTE de " + company_cargo + " [" + company_type + "] que precisa sair HOJE!\n"
		full_text += "Pagamos $" + str(offered_reward) + " A VISTA na sua conta agora! Tem um trem livre?"
	else:
		full_text = "Alo? Sou o representante da " + company_name + ".\n"
		full_text += "Temos um frete padrao de " + company_cargo + " [" + company_type + "] parado aqui.\n"
		full_text += "Pagamos $" + str(offered_reward) + " por dia. Aceita os nossos termos?"

	_type_next_char(true)

func start_rejection_call(company_name: String, custom_reason: String = "") -> void:
	_reset_ui()
	current_mode = "REJECT"
	
	name_label.text = "[ TRANSMISSAO: " + company_name.to_upper() + " ]"
	name_label.add_theme_color_override("font_color", Color.INDIAN_RED)
	
	if custom_reason == "":
		full_text = "Voce esta a brincar comigo? Acabei de ver os relatorios dos fiscais...\n"
		full_text += "A sua empresa NAO TEM infraestrutura construida nesta regiao!\n"
		full_text += "Vou bloquear o seu numero. So ligue quando for profissional."
	else:
		full_text = "Avaliamos a sua rota e nao podemos fechar negocio!\n"
		full_text += custom_reason + "\n"
		full_text += "Refaca os trilhos e volte a ligar. Ate la, estao bloqueados."
	
	_type_next_char(false)

func start_angry_call() -> void:
	_reset_ui()
	current_mode = "ANGRY"
	
	name_label.text = "[ TRANSMISSAO: CLIENTE FURIOSO ]"
	name_label.add_theme_color_override("font_color", Color.RED)
	
	full_text = "OS NOSSOS COMBOIOS ESTAO PARADOS NO MEIO DO NADA!\n"
	full_text += "Os nossos maquinistas reportam que VOCE DESTRUIU AS LINHAS!\n"
	full_text += "O contrato esta rescindido e os nossos advogados ja cobraram a multa!"
	
	_type_next_char(false)

func start_boss_intro() -> void:
	_reset_ui()
	current_mode = "INTRO"
	
	name_label.text = "[ TRANSMISSAO: BEAR (DIRETORIA) ]"
	name_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	
	full_text = "Seu avo avisou que voce viria. Temos locomotivas enferrujadas e clientes isolados.\n\n"
	full_text += "Preste atencao: neste mercado cruel, ninguem assina contrato sem ver trabalho feito.\n"
	full_text += "Va ao mapa, construa a linha conectando as cidades e so depois ligue para os clientes.\n\n"
	full_text += "O problema agora e seu."
	
	_type_next_char(false)

# NOVO: O cliente reclamando da quebra de contrato
func start_cancel_warning(company_name: String, idx: int) -> void:
	_reset_ui()
	current_mode = "CANCEL_WARNING"
	pending_cancel_idx = idx
	
	name_label.text = "[ TRANSMISSAO: " + company_name.to_upper() + " ]"
	name_label.add_theme_color_override("font_color", Color.ORANGE)
	
	full_text = "Voce esta louco?! Quer quebrar o nosso contrato no meio da operacao?!\n\n"
	full_text += "Se voce fizer isso, nossos advogados vao cobrar a multa de rescisao listada nos relatorios fiscais, "
	full_text += "e nos NAO faremos negocios com a sua companhia por uma semana inteira!\n\n"
	full_text += "Tem certeza que quer recolher os trens e rasgar o contrato?!"
	
	_type_next_char(true)

func _reset_ui() -> void:
	visible = true
	is_typing = true
	fast_forward = false
	char_index = 0
	text_label.text = ""
	btn_accept.visible = false
	btn_reject.visible = false
	btn_close.visible = false
	name_label.add_theme_color_override("font_color", Color.YELLOW)

func _type_next_char(is_negotiation: bool) -> void:
	if fast_forward:
		text_label.text = full_text
		char_index = full_text.length()
		is_typing = false
		_show_buttons(is_negotiation)
		return

	if char_index < full_text.length():
		text_label.text += full_text[char_index]
		char_index += 1
		await get_tree().create_timer(0.02).timeout
		_type_next_char(is_negotiation)
	else:
		is_typing = false
		_show_buttons(is_negotiation)

func _show_buttons(is_negotiation: bool) -> void:
	if is_negotiation:
		btn_accept.visible = true
		btn_reject.visible = true
		# Muda o texto dos botoes se for o modo de aviso de cancelamento
		if current_mode == "CANCEL_WARNING":
			btn_accept.text = "ROMPER CONTRATO"
			btn_reject.text = "VOLTAR ATRAS"
		else:
			btn_accept.text = "ENVIAR PROPOSTA"
			btn_reject.text = "DESLIGAR"
	else:
		btn_close.visible = true

func _on_accept() -> void:
	visible = false
	if current_mode == "CANCEL_WARNING":
		cancel_confirmed.emit(pending_cancel_idx)
	else:
		contract_accepted.emit(offered_reward)

func _on_reject() -> void:
	visible = false
	if current_mode == "CANCEL_WARNING":
		cancel_aborted.emit()
	else:
		contract_rejected.emit()
	
func _on_close() -> void:
	visible = false
	call_closed.emit()
