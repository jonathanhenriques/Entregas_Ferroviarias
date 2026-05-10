extends CanvasLayer
class_name CutsceneDialog

signal contract_accepted(final_reward)
signal contract_rejected()
signal call_closed() # NOVO: Para quando voce apenas leva uma bronca e desliga

var overlay: ColorRect
var dialog_box: ColorRect 
var name_label: Label
var text_label: Label

var btn_accept: Button
var btn_reject: Button
var btn_close: Button # NOVO: Botao unico para rejeicoes/furia

var silhouette_body: ColorRect
var silhouette_head: ColorRect

var full_text: String = ""
var char_index: int = 0
var offered_reward: int = 0
var is_typing: bool = false

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
	silhouette_body.size = Vector2(400, 500)
	silhouette_body.position = Vector2(50, 200)
	add_child(silhouette_body)
	
	silhouette_head = ColorRect.new()
	silhouette_head.color = Color(0, 0, 0, 1)
	silhouette_head.size = Vector2(120, 140)
	silhouette_head.position = Vector2(190, 80)
	add_child(silhouette_head)

	dialog_box = ColorRect.new()
	dialog_box.color = Color(0.05, 0.05, 0.15, 0.9) 
	dialog_box.size = Vector2(1000, 220)
	dialog_box.position = Vector2(76, 400)
	add_child(dialog_box)
	
	var border = ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color.WHITE
	border.border_width = 2
	dialog_box.add_child(border)

	name_label = Label.new()
	name_label.position = Vector2(20, 10)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color.YELLOW)
	dialog_box.add_child(name_label)

	text_label = Label.new()
	text_label.position = Vector2(20, 50)
	text_label.size = Vector2(960, 120)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 20)
	dialog_box.add_child(text_label)

	btn_accept = Button.new()
	btn_accept.text = "ACEITAR"
	btn_accept.size = Vector2(180, 45)
	btn_accept.position = Vector2(600, 160)
	btn_accept.pressed.connect(_on_accept)
	dialog_box.add_child(btn_accept)

	btn_reject = Button.new()
	btn_reject.text = "DESLIGAR"
	btn_reject.size = Vector2(180, 45)
	btn_reject.position = Vector2(800, 160)
	btn_reject.pressed.connect(_on_reject)
	dialog_box.add_child(btn_reject)
	
	btn_close = Button.new()
	btn_close.text = "DESLIGAR (E assumir a culpa)"
	btn_close.size = Vector2(250, 45)
	btn_close.position = Vector2(730, 160)
	btn_close.add_theme_color_override("font_color", Color.INDIAN_RED)
	btn_close.pressed.connect(_on_close)
	dialog_box.add_child(btn_close)

# --- TIPOS DE CHAMADA ---

# Chamada Normal (Negociacao)
func start_call(company_name: String, company_type: String, company_cargo: String, base_reward: int) -> void:
	_reset_ui()
	var dice = randi_range(1, 6)
	var mult = 1.0 + (dice * 0.1)
	offered_reward = int(base_reward * mult)
	
	name_label.text = "[ TRANSMISSAO: " + company_name.to_upper() + " ]"
	full_text = "Alo? Sou o representante da " + company_name + ".\n"
	full_text += "Temos um frete de " + company_cargo + " [" + company_type + "] parado aqui.\n"
	full_text += "Pagamos $" + str(offered_reward) + " por dia. Aceita os nossos termos?"

	_type_next_char(true)



# Rejeicao (Tentou ligar sem ter trilhos)
func start_rejection_call(company_name: String) -> void:
	_reset_ui()
	name_label.text = "[ TRANSMISSAO: " + company_name.to_upper() + " ]"
	name_label.add_theme_color_override("font_color", Color.INDIAN_RED)
	
	full_text = "Voce esta a brincar comigo? Acabei de ver os relatorios dos fiscais...\n"
	full_text += "A sua empresa NAO TEM infraestrutura construida nesta regiao!\n"
	full_text += "Vou bloquear o seu numero. So ligue quando for profissional."
	
	_type_next_char(false)

# Furia (Apagou um trilho em uso)
func start_angry_call() -> void:
	_reset_ui()
	name_label.text = "[ TRANSMISSAO: CLIENTE FURIOSO ]"
	name_label.add_theme_color_override("font_color", Color.RED)
	
	full_text = "OS NOSSOS COMBOIOS ESTAO PARADOS NO MEIO DO NADA!\n"
	full_text += "Os nossos maquinistas reportam que VOCE DESTRUIU AS LINHAS!\n"
	full_text += "O contrato esta rescindido e os nossos advogados ja cobraram a multa!"
	
	_type_next_char(false)

func _reset_ui() -> void:
	visible = true
	is_typing = true
	char_index = 0
	text_label.text = ""
	btn_accept.visible = false
	btn_reject.visible = false
	btn_close.visible = false
	name_label.add_theme_color_override("font_color", Color.YELLOW)

func _type_next_char(is_negotiation: bool) -> void:
	if char_index < full_text.length():
		text_label.text += full_text[char_index]
		char_index += 1
		await get_tree().create_timer(0.03).timeout
		_type_next_char(is_negotiation)
	else:
		is_typing = false
		if is_negotiation:
			btn_accept.visible = true
			btn_reject.visible = true
		else:
			btn_close.visible = true

func _on_accept() -> void:
	visible = false
	contract_accepted.emit(offered_reward)

func _on_reject() -> void:
	visible = false
	contract_rejected.emit()
	
func _on_close() -> void:
	visible = false
	call_closed.emit()
