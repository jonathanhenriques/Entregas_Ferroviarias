extends CanvasLayer
class_name CutsceneDialog

signal contract_accepted(final_reward)
signal contract_rejected()
signal call_closed() 
signal cancel_confirmed(idx: int)
signal cancel_aborted()
signal radio_choice_made(option_index: int)
signal fiscal_choice_made(is_bribe: bool, cost: int)

var overlay: ColorRect
var dialog_box: ColorRect 
var name_label: Label
var text_label: Label

var btn_accept: Button
var btn_reject: Button
var btn_close: Button 

var btn_opt_1: Button
var btn_opt_2: Button
var btn_opt_3: Button

var silhouette_body: ColorRect
var silhouette_head: ColorRect


var character_portrait: TextureRect

var tex_bear: Texture2D = preload("res://bear,chefe_v01.png")
var tex_badger: Texture2D = preload("res://maquinista,texugo_v01.png")
var tex_fiscal: Texture2D = preload("res://fiscal,garca_v01.png")

# --- NOVO: IMAGENS DOS CLIENTES ALEATÓRIOS ---
var tex_client_1: Texture2D = preload("res://cliente_01.png")
var tex_client_2: Texture2D = preload("res://cliente_02.png")

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

	# --- NOVO RETRATO DO PERSONAGEM (Substitui os antigos ColorRects) ---
	character_portrait = TextureRect.new()
	character_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Aumentamos o tamanho e a posição Y para cobrir desde a cabeça até a base da tela
	character_portrait.size = Vector2(600, 800)
	character_portrait.position = Vector2(100, 150) 
	add_child(character_portrait)

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

	btn_opt_1 = Button.new()
	btn_opt_1.text = "[ Pagar Pedágio ($150) ]"
	btn_opt_1.size = Vector2(420, 50)
	btn_opt_1.position = Vector2(40, 230)
	btn_opt_1.pressed.connect(_on_opt_1)
	dialog_box.add_child(btn_opt_1)

	btn_opt_2 = Button.new()
	btn_opt_2.text = "[ Recuar (Atrasa a Carga) ]"
	btn_opt_2.size = Vector2(420, 50)
	btn_opt_2.position = Vector2(480, 230)
	btn_opt_2.pressed.connect(_on_opt_2)
	dialog_box.add_child(btn_opt_2)
	
	btn_opt_3 = Button.new()
	btn_opt_3.text = "[ Avançar à Força (Risco) ]"
	btn_opt_3.size = Vector2(420, 50)
	btn_opt_3.position = Vector2(920, 230)
	btn_opt_3.add_theme_color_override("font_color", Color.INDIAN_RED)
	btn_opt_3.pressed.connect(_on_opt_3)
	dialog_box.add_child(btn_opt_3)

func _input(event: InputEvent) -> void:
	if visible:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.is_pressed():
					if is_typing:
						fast_forward = true

func start_call(company_name: String, company_type: String, company_cargo: String, base_reward: int, is_urgent: bool = false) -> void:
	_reset_ui()
	# --- NOVO: Sorteia um cliente ---
	var arts = [tex_client_1, tex_client_2]
	character_portrait.texture = arts.pick_random()
	
	current_mode = "CALL"
	
	var dice = randi_range(1, 6)
	var mult = 1.0 + (dice * 0.1)
	offered_reward = int(base_reward * mult)
	
	name_label.text = "[ TRANSMISSÃO: " + company_name.to_upper() + " ]"
	
	if is_urgent:
		name_label.add_theme_color_override("font_color", Color.ORANGE)
		full_text = "Alô? Pelo amor de Deus, sou da " + company_name + "!\n"
		full_text += "Temos um frete URGENTE de " + company_cargo + " [" + company_type + "] que precisa sair HOJE!\n"
		full_text += "Pagamos $" + str(offered_reward) + " À VISTA na sua conta agora! Tem um trem livre?"
	else:
		full_text = "Alô? Sou o representante da " + company_name + ".\n"
		full_text += "Temos um frete padrão de " + company_cargo + " [" + company_type + "] parado aqui.\n"
		full_text += "Pagamos $" + str(offered_reward) + " por dia. Aceita os nossos termos?"

	_type_next_char(true)

func start_risk_call(company_name: String, route_name: String, base_reward: int, wait_days: int) -> void:
	_reset_ui()
	# --- NOVO: Sorteia um cliente ---
	var arts = [tex_client_1, tex_client_2]
	character_portrait.texture = arts.pick_random()
	
	current_mode = "RISK_CALL"
	
	var dice = randi_range(1, 6)
	var mult = 1.0 + (dice * 0.1)
	offered_reward = int(base_reward * mult)
	
	name_label.text = "[ TRANSMISSÃO: " + company_name.to_upper() + " ]"
	name_label.add_theme_color_override("font_color", Color.GOLDENROD)
	
	full_text = "Nossa operação logística exige sincronia perfeita.\n"
	full_text += "Assino o contrato hoje, mas o senhor tem exatamente " + str(wait_days) + " dia(s) para liberar um trem ou a via para a minha carga.\n"
	full_text += "Se falhar, os meus advogados destroem a sua empresa. Estamos entendidos?"
	
	_type_next_char(true)




func start_rejection_call(company_name: String, custom_reason: String = "") -> void:
	_reset_ui()
	# --- NOVO: Sorteia um cliente ---
	var arts = [tex_client_1, tex_client_2]
	character_portrait.texture = arts.pick_random()
	
	current_mode = "REJECT"
	
	name_label.text = "[ TRANSMISSÃO: " + company_name.to_upper() + " ]"
	name_label.add_theme_color_override("font_color", Color.INDIAN_RED)
	
	if custom_reason == "":
		full_text = "Você está de brincadeira comigo? Acabei de ver os relatórios dos fiscais...\n"
		full_text += "A sua empresa NÃO TEM infraestrutura construída nesta região!\n"
		full_text += "Vou bloquear o seu número. Só ligue quando for profissional."
	else:
		full_text = "Avaliamos a sua rota e não podemos fechar negócio!\n"
		full_text += custom_reason + "\n"
		full_text += "Refaça os trilhos e volte a ligar. Até lá, estão bloqueados."
	
	_type_next_char(false)

func start_angry_call() -> void:
	_reset_ui()
	# --- NOVO: Sorteia um cliente ---
	var arts = [tex_client_1, tex_client_2]
	character_portrait.texture = arts.pick_random()
	
	current_mode = "ANGRY"
	
	name_label.text = "[ TRANSMISSÃO: CLIENTE FURIOSO ]"
	name_label.add_theme_color_override("font_color", Color.RED)
	
	full_text = "VOCÊ ACHA QUE SOMOS PALHAÇOS? O nosso prazo estourou e o trem não saiu do lugar!\n"
	full_text += "A via não atendeu às exigências a tempo! Não sei se foi atraso nas obras, buraco no trilho ou quebra das regras VIP e Ecológicas...\n"
	full_text += "O contrato de risco está rescindido e a multa já foi debitada da sua conta!"
	
	_type_next_char(false)

func start_boss_intro() -> void:
	_reset_ui()
	current_mode = "INTRO"
	
	name_label.text = "[ TRANSMISSÃO: BEAR (DIRETORIA) ]"
	name_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	
	full_text = "Seu avô avisou que você viria. Temos locomotivas enferrujadas e clientes isolados.\n\n"
	full_text += "Preste atenção: neste mercado cruel, ninguém assina contrato sem ver trabalho feito.\n"
	full_text += "Vá ao mapa, construa a linha conectando as cidades e só depois ligue para os clientes.\n\n"
	full_text += "O problema agora é seu."
	
	_type_next_char(false)

func start_cancel_warning(company_name: String, idx: int) -> void:
	_reset_ui()
	# --- NOVO: Sorteia um cliente ---
	var arts = [tex_client_1, tex_client_2]
	character_portrait.texture = arts.pick_random()
	
	current_mode = "CANCEL_WARNING"
	pending_cancel_idx = idx
	
	name_label.text = "[ TRANSMISSÃO: " + company_name.to_upper() + " ]"
	name_label.add_theme_color_override("font_color", Color.ORANGE)
	
	full_text = "Você está louco?! Quer quebrar o nosso contrato no meio da operação?!\n\n"
	full_text += "Se você fizer isso, nossos advogados vão cobrar a multa de rescisão listada nos relatórios fiscais, "
	full_text += "e nós NÃO faremos negócios com a sua companhia por uma semana inteira!\n\n"
	full_text += "Tem certeza que quer recolher os trens e rasgar o contrato?!"
	
	_type_next_char(true)

func start_badger_radio() -> void:
	_reset_ui()
	# --- NOVO: Troca para a arte do Maquinista
	character_portrait.texture = tex_badger
	
	name_label.text = "[ FREQUÊNCIA 104.2: MAQUINISTA BADGER ]"
	name_label.add_theme_color_override("font_color", Color.SKY_BLUE)
	
	name_label.text = "[ FREQUÊNCIA 104.2: MAQUINISTA BADGER ]"
	name_label.add_theme_color_override("font_color", Color.SKY_BLUE)
	
	if GameManager.broken_tiles.size() > 0:
		current_mode = "RADIO_DISASTER"
		full_text = "ALERTA VERMELHO CHEFE! A via cedeu logo à frente do nosso trem!\n\n"
		full_text += "A composição está parada e não podemos avançar. Precisamos que o senhor entre no Mapa, "
		full_text += "ative o Modo de Obras e reconstrua o trecho destruído imediatamente!\n\n"
		full_text += "A carga vai apodrecer aqui se não formos rápidos!"
		
		btn_opt_1.text = "[ Entendido. Preparando obras. ]"
	else:
		current_mode = "RADIO_EVENT"
		full_text = "Chefe. Aqui é o Badger. Motoqueiros trancaram a linha na planície de novo.\n\n"
		full_text += "O povo das cidades tá esperando esses suprimentos pra comer hoje, mas se eu passar com o trem "
		full_text += "por cima desses bandidos, eles vão atirar contra a caldeira. E se a gente recuar, a carga atrasa e a empresa perde moral.\n\n"
		full_text += "Aguardo ordens, Chefe."
		
		btn_opt_1.text = "[ Pagar Pedágio ($150) ]"
		btn_opt_2.text = "[ Recuar (Atrasa a Carga) ]"
		btn_opt_3.text = "[ Avançar à Força (Risco) ]"
		
	_type_next_char(false)

func _reset_ui() -> void:
	visible = true
	is_typing = true
	fast_forward = false
	char_index = 0
	text_label.text = ""
	
	btn_accept.visible = false
	btn_reject.visible = false
	btn_close.visible = false
	btn_opt_1.visible = false
	btn_opt_2.visible = false
	btn_opt_3.visible = false
	
	name_label.add_theme_color_override("font_color", Color.YELLOW)
	# --- NOVO: Define a arte do Urso como o padrão ao iniciar qualquer chamada
	character_portrait.texture = tex_bear

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
	if current_mode == "RADIO_EVENT":
		btn_opt_1.visible = true
		btn_opt_2.visible = true
		btn_opt_3.visible = true
		return

	if current_mode == "RADIO_DISASTER":
		btn_opt_1.visible = true
		return

	if current_mode == "LOAN_SHARK":
		btn_accept.visible = true
		btn_reject.visible = true
		return
		
	if current_mode == "FISCAL": # <--- NOVA REGRA DE EXCEÇÃO PARA O FISCAL
		btn_opt_1.visible = true
		var bp = GameManager.pending_fiscal_event
		if bp.get("can_bribe", false):
			btn_opt_2.visible = true
		return

	if is_negotiation:
		btn_accept.visible = true
		btn_reject.visible = true
		if current_mode == "CANCEL_WARNING":
			btn_accept.text = "ROMPER CONTRATO"
			btn_reject.text = "VOLTAR ATRÁS"
		else:
			btn_accept.text = "ENVIAR PROPOSTA"
			btn_reject.text = "DESLIGAR"
	else:
		btn_close.visible = true



func _on_accept() -> void:
	visible = false
	if current_mode == "CANCEL_WARNING":
		cancel_confirmed.emit(pending_cancel_idx)
		return

	if current_mode == "LOAN_SHARK":
		GameManager.is_shark_calling = false # <--- A TRAVA É LIBERADA AQUI
		GameManager.pending_shark_paper = true
		call_closed.emit()
		return
		
	contract_accepted.emit(offered_reward)




func _on_reject() -> void:
	visible = false
	if current_mode == "CANCEL_WARNING":
		cancel_aborted.emit()
		return
		
	if current_mode == "LOAN_SHARK":
		GameManager.is_shark_calling = false # <--- A TRAVA É LIBERADA AQUI
		GameManager.shark_declined = true
		call_closed.emit()
		return
		
	contract_rejected.emit()
	
	
func _on_close() -> void:
	visible = false
	call_closed.emit()
	
	if current_mode == "VICTORY":
		GameManager.trigger_victory()
	else:
		if current_mode == "DEFEAT":
			GameManager.trigger_bankruptcy()

func _on_opt_1() -> void:
	visible = false
	if current_mode == "FISCAL":
		var bp = GameManager.pending_fiscal_event
		if bp["can_bribe"]:
			fiscal_choice_made.emit(true, bp["bribe_cost"])
		else:
			fiscal_choice_made.emit(false, bp["fine"])
	else:
		radio_choice_made.emit(0)

func _on_opt_2() -> void:
	visible = false
	if current_mode == "FISCAL":
		var bp = GameManager.pending_fiscal_event
		fiscal_choice_made.emit(false, bp["fine"]) 
	else:
		radio_choice_made.emit(1)

func _on_opt_3() -> void:
	visible = false
	radio_choice_made.emit(2)
	
func start_fiscal_audit(data: Dictionary) -> void:
	_reset_ui()
	current_mode = "FISCAL"
	
	# Troca para a arte do Fiscal
	character_portrait.texture = tex_fiscal
	
	name_label.text = "[ MINISTÉRIO DOS TRANSPORTES: AUDITORIA ]"
	name_label.add_theme_color_override("font_color", Color.ORANGE)
	
	full_text = "Atenção Gestor. Os nossos agentes pararam o seu trem que serve a empresa " + data["contract_name"] + ".\n\n"
	full_text += data["reason"] + "\n\n"
	
	if data["can_bribe"]:
		full_text += "Como a sua empresa tem 'excelentes relações' com o Governo, podemos arquivar este relatório por uma taxa administrativa de $" + str(data["bribe_cost"]) + ".\nO que me diz?"
		btn_opt_1.text = "[ Pagar Propina / Caixa 2 (-$" + str(data["bribe_cost"]) + ") ]"
		btn_opt_2.text = "[ Recusar e Pagar Multa Oficial (-$" + str(data["fine"]) + ") ]"
		# (Removemos a alteração prematura de visible = true daqui)
	else:
		full_text += "A sua empresa não possui aliados em Brasília. O senhor será autuado com o rigor máximo da lei.\nA multa de $" + str(data["fine"]) + " foi emitida."
		btn_opt_1.text = "[ Aceitar Multa (-$" + str(data["fine"]) + ") ]"
		# (Removemos a alteração prematura de visible = true daqui)
	
	_type_next_char(false)




func start_boss_package_call() -> void:
	_reset_ui()
	current_mode = "INTRO" 
	
	name_label.text = "[ TRANSMISSÃO: BEAR (DIRETORIA) ]"
	name_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	
	full_text = "Gestor! Vi que a nossa primeira rota está finalmente operando!\n\n"
	full_text += "A partir de agora, os clientes começarão a deixar encomendas avulsas na Estação de Triagem.\n"
	full_text += "Vá até lá toda manhã e valide os pacotes. Não deixe a esteira acumular!"
	
	_type_next_char(false)

func start_loan_shark_call() -> void:
	_reset_ui()
	current_mode = "LOAN_SHARK"

	name_label.text = "[ TRANSMISSÃO DESCONHECIDA ]"
	name_label.add_theme_color_override("font_color", Color.CRIMSON)

	full_text = "Estou vendo que as coisas vão mal por aí, Gestor... Conta no vermelho, não é?\n\n"
	full_text += "Eu posso limpar a sua dívida e lhe deixar com $1500 na mão agora mesmo.\n"
	full_text += "Em troca, cobrarei $150 por dia durante os próximos 20 dias.\n\n"
	full_text += "Pega ou larga. Se disser não e falir, o problema é seu."

	btn_accept.text = "[ ACEITAR ]"
	btn_reject.text = "[ RECUSAR ]"

	_type_next_char(false)
	
	
	#cutscenes chefe bear
func start_victory_call() -> void:
	_reset_ui()
	current_mode = "VICTORY"
	
	character_portrait.texture = tex_bear
	name_label.text = "[ TRANSMISSÃO: BEAR (DIRETORIA) ]"
	name_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	
	full_text = "Muito bem... Você conseguiu.\n"
	full_text += "Olhando para os relatórios, vejo que superou a nossa meta de caixa de forma espetacular.\n"
	full_text += "Seu avô vai ficar muito orgulhoso quando souber. Você passou no teste, o cargo de gestor é oficialmente seu!\n"
	full_text += "Aproveite a sua vitória."
	
	_type_next_char(false)

func start_defeat_call() -> void:
	_reset_ui()
	current_mode = "DEFEAT"
	
	character_portrait.texture = tex_bear
	name_label.text = "[ TRANSMISSÃO: BEAR (DIRETORIA) ]"
	name_label.add_theme_color_override("font_color", Color.RED)
	
	full_text = "O que você fez com a nossa empresa?!\n"
	full_text += "O nosso caixa está destruído. As dívidas estão nos afogando. Você é uma vergonha para o seu avô!\n"
	full_text += "Eu avisei que este mercado era cruel. Você falhou no teste. Pegue as suas coisas, você está DEMITIDO.\n"
	full_text += "E não volte mais aqui."
	
	_type_next_char(false)
