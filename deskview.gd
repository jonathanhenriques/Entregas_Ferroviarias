extends Node2D

var ui_layer: CanvasLayer

# --- NOVO: VARIÁVEIS DO LIVRO DE REGISTROS ---
var btn_open_ledger: Button
var ledger_book: ColorRect
var ledger_content: Label
var btn_ledger_prev: Button
var btn_ledger_next: Button
var btn_ledger_close: Button
var ledger_page: int = 0

# --- NOVO: CONTROLE DE PÁGINA DA PRANCHETA ---
var clipboard_page: int = 0

var agenda_rect: ColorRect
var clipboard_rect: ColorRect

var diretrizes_rect: ColorRect
var diretrizes_label: Label
var diretrizes_bar: ProgressBar

var companies_vbox: VBoxContainer

# === NOVAS VARIÁVEIS DA FASE 3 ===
var current_agenda_contacts: Array = []
var current_agenda_page: int = 0
var btn_prev_page: Button
var btn_next_page: Button
var lbl_page: Label

var calendar_rect: ColorRect

var folder_rect: ColorRect
var folder_title: Label
var folder_route: Label
var doc_standard: ColorRect
var std_label: Label
var btn_call_std: Button
var doc_urgent: ColorRect
var urg_label: Label
var btn_call_urg: Button
var btn_close_folder: Button

var report_label: Label
var btn_next_day: Button


var bg_rect: ColorRect
var btn_back_map: Button
var btn_organize: Button 

var phone_cutscene: CutsceneDialog

var selected_company_data: Dictionary 

var dragged_panel: Control = null
var drag_offset: Vector2 = Vector2.ZERO
var original_transforms: Dictionary = {}

var phone_rect: ColorRect
var phone_display: Label
var dial_rect: Control

# --- INÍCIO DA ADIÇÃO: VARIÁVEL DAS FICHAS METÁLICAS VISUAIS ---
var token_visuals: Array = []
# --- FIM DA ADIÇÃO ---

var current_dialed: String = ""
var pending_company_data: Dictionary = {}

# --- INÍCIO DA CORREÇÃO: VARIÁVEIS DECLARADAS ---
var pending_is_urgent: bool = false
var pending_is_risk: bool = false

# Variáveis do Jornal Matinal
# Variáveis do Jornal Matinal
var newspaper_layer: CanvasLayer
var newspaper_bg: ColorRect
var newspaper_paper: ColorRect
var is_newspaper_open: bool = false

# --- INÍCIO DA ALTERAÇÃO 1: Variáveis do Alerta ---
var alert_rect: ColorRect
var alert_label: Label
var alert_blink_timer: float = 0.0
# --- FIM DA ALTERAÇÃO 1 ---

# --- INÍCIO: Variáveis do Alerta Giratório ---
var alert_container: Control
var alert_pivot: Node2D
var alert_bulb: Panel
	# --- FIM: Variáveis do Alerta Giratório ---




# --- INÍCIO DA ADIÇÃO: VARIÁVEL DO GUIA REGIONAL ---
var current_guide_region: String = ""
# --- FIM DA ADIÇÃO ---

var HOLE_ANGLES = [
	0.0, -PI * 1.5, -PI * 1.3333, -PI * 1.1666, -PI,
	-PI * 0.8333, -PI * 0.6666, -PI * 0.5, -PI * 0.3333, -PI * 0.1666
]
var STOP_ANGLE = PI / 4.0 

var is_dial_dragging: bool = false
var dialing_number: int = -1
var dial_start_angle: float = 0.0
var dial_current_rot: float = 0.0
var max_rot: float = 0.0

var spawned_papers: Array = []

var outbox_rect: ColorRect
var trash_rect: Panel

# === NOVAS VARIÁVEIS DA LIXEIRA (POP-UP) ===
var trash_dialog: ColorRect
var btn_trash_yes: Button
var btn_trash_no: Button
var trash_target_paper: Control = null

var tool_pen: ColorRect
var stamp_reject: ColorRect
var stamp_cia: ColorRect

var pad_extension: ColorRect

var eod_layer: CanvasLayer
var eod_lines_container: VBoxContainer
var btn_eod_sleep: Button
var skip_eod_anim: bool = false
var pending_upfront_income: int = 0

# --- INÍCIO DA ALTERAÇÃO 1 (ACUMULADORES DIÁRIOS) ---
var daily_new_c: int = 0
var daily_rej_c: int = 0
var daily_ext_c: int = 0
var daily_bp_cost: int = 0
var daily_shark_income: int = 0
var daily_upfront_income: int = 0
# --- FIM DA ALTERAÇÃO 1 ---

var radio_rect: ColorRect
var radio_led: ColorRect

var task_pad_rect: ColorRect
var task_vbox: VBoxContainer

func _ready() -> void:
	_setup_ui()
	_setup_cutscene()
	_setup_eod_ui()
	
	# --- INÍCIO DA CORREÇÃO: INICIALIZA O JORNAL NA LARGADA ---
	_setup_newspaper_ui()
	# --- FIM DA CORREÇÃO ---
	
	GameManager.money_changed.connect(_on_stats_changed)
	GameManager.maintenance_updated.connect(_on_stats_changed)
	GameManager.contracts_updated.connect(_on_contracts_updated)
	GameManager.day_changed.connect(_on_day_changed)
	
	# --- INÍCIO DA ALTERAÇÃO 3: Ouvindo a Esteira ---
	GameManager.package_queue_updated.connect(_on_package_queue_updated)
	# --- FIM DA ALTERAÇÃO 3 ---
	
	visibility_changed.connect(_on_visibility_changed)
	
	_load_agenda_contacts()
	_update_report_text()
	_update_diretrizes() 
	_update_task_pad()
	
	_update_tokens_visual()

func _process(delta: float) -> void:
	# --- INÍCIO: Animação do Giroflex ---
	if is_instance_valid(alert_container) and alert_container.visible:
		alert_pivot.rotation += delta * 8.0 # Gira o feixe de luz rapidamente
		alert_bulb.modulate.a = 0.6 + (sin(Time.get_ticks_msec() * 0.01) * 0.4) # Faz a lâmpada pulsar
	# --- FIM: Animação do Giroflex ---
	if not visible: return
	
	if not is_dial_dragging:
		if dial_current_rot > 0.0:
			dial_current_rot -= delta * 5.0 
			if dial_current_rot < 0.0:
				dial_current_rot = 0.0
			dial_rect.queue_redraw()

	if GameManager.pending_defeat_call:
		GameManager.pending_defeat_call = false
		phone_cutscene.start_defeat_call()
	else:
		if GameManager.pending_victory_call:
			GameManager.pending_victory_call = false
			phone_cutscene.start_victory_call()
		else:
			if GameManager.pending_badger_package_warning:
				GameManager.pending_badger_package_warning = false
				phone_cutscene.start_badger_package_warning()
			else:
				if GameManager.pendent_angry_call: 
					GameManager.pendent_angry_call = false
					phone_cutscene.start_angry_call()
				else:
					if not GameManager.pending_fiscal_event.is_empty() and not GameManager.is_fiscal_calling:
						GameManager.is_fiscal_calling = true 
						phone_cutscene.start_fiscal_audit(GameManager.pending_fiscal_event)
					else:
						if GameManager.pending_boss_package_call and not GameManager.boss_package_intro_done:
							GameManager.pending_boss_package_call = false
							GameManager.boss_package_intro_done = true
							phone_cutscene.start_boss_package_call()
						else:
							if GameManager.pending_shark_call and not GameManager.shark_declined and not GameManager.has_loan_shark and not GameManager.is_shark_calling:
								GameManager.pending_shark_call = false
								GameManager.is_shark_calling = true
								if phone_cutscene.has_method("start_loan_shark_call"):
									phone_cutscene.start_loan_shark_call()
							else:
								if GameManager.pending_shark_paper:
									GameManager.pending_shark_paper = false
									_spawn_shark_paper()
								else:
									if not GameManager.intro_played:
										GameManager.intro_played = true
										phone_cutscene.start_boss_intro()
		
	if GameManager.pending_shark_paper:
			GameManager.pending_shark_paper = false
			_spawn_shark_paper()


func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	bg_rect = ColorRect.new()
	bg_rect.color = Color(0.25, 0.15, 0.1) 
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(bg_rect)

	btn_back_map = Button.new()
	btn_back_map.text = "<- Voltar ao Mapa"
	btn_back_map.position = Vector2(40, 40)
	btn_back_map.size = Vector2(180, 40)
	btn_back_map.pressed.connect(_on_back_map_pressed)
	ui_layer.add_child(btn_back_map)
	
	btn_organize = Button.new()
	btn_organize.text = "Arrumar a Mesa"
	btn_organize.position = Vector2(240, 40)
	btn_organize.size = Vector2(150, 40)
	btn_organize.pressed.connect(_on_organize_pressed)
	ui_layer.add_child(btn_organize)
	
	var btn_go_inspection = Button.new()
	btn_go_inspection.text = "Ir para a Triagem ->"
	btn_go_inspection.position = Vector2(1650, 40)
	btn_go_inspection.size = Vector2(230, 40)
	btn_go_inspection.pressed.connect(_on_go_inspection_pressed)
	ui_layer.add_child(btn_go_inspection)
	
	btn_open_ledger = Button.new()
	btn_open_ledger.text = "LIVRO DE REGISTROS"
	btn_open_ledger.position = Vector2(1650, 100)
	btn_open_ledger.size = Vector2(230, 40)
	btn_open_ledger.pressed.connect(_on_open_ledger_pressed)
	ui_layer.add_child(btn_open_ledger)
	
	ledger_book = ColorRect.new()
	ledger_book.color = Color(0.15, 0.15, 0.18, 0.98)
	ledger_book.size = Vector2(600, 700)
	ledger_book.position = Vector2(660, 150)
	ledger_book.visible = false
	ui_layer.add_child(ledger_book)
	
	var ledger_border = ReferenceRect.new()
	ledger_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	ledger_border.border_color = Color.GOLDENROD
	ledger_border.border_width = 4
	ledger_book.add_child(ledger_border)
	
	var ledger_title = Label.new()
	ledger_title.text = "REGISTRO DE OPERAÇÕES LOGÍSTICAS"
	ledger_title.position = Vector2(0, 20)
	ledger_title.size = Vector2(600, 30)
	ledger_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ledger_title.add_theme_color_override("font_color", Color.GOLDENROD)
	ledger_book.add_child(ledger_title)
	
	ledger_content = Label.new()
	ledger_content.position = Vector2(30, 80)
	ledger_content.size = Vector2(540, 520)
	ledger_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ledger_content.add_theme_font_size_override("font_size", 16)
	ledger_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ledger_book.add_child(ledger_content)
	
	btn_ledger_prev = Button.new()
	btn_ledger_prev.text = "<- Pág. Anterior"
	btn_ledger_prev.position = Vector2(30, 620)
	btn_ledger_prev.size = Vector2(150, 40)
	btn_ledger_prev.pressed.connect(_on_ledger_prev_pressed)
	ledger_book.add_child(btn_ledger_prev)
	
	btn_ledger_next = Button.new()
	btn_ledger_next.text = "Próx. Pág ->"
	btn_ledger_next.position = Vector2(420, 620)
	btn_ledger_next.size = Vector2(150, 40)
	btn_ledger_next.pressed.connect(_on_ledger_next_pressed)
	ledger_book.add_child(btn_ledger_next)
	
	btn_ledger_close = Button.new()
	btn_ledger_close.text = "FECHAR LIVRO"
	btn_ledger_close.position = Vector2(225, 620)
	btn_ledger_close.size = Vector2(150, 40)
	btn_ledger_close.add_theme_color_override("font_color", Color.INDIAN_RED)
	btn_ledger_close.pressed.connect(_on_close_ledger_pressed)
	ledger_book.add_child(btn_ledger_close)

	diretrizes_rect = ColorRect.new()
	diretrizes_rect.color = Color(0.6, 0.15, 0.15) 
	diretrizes_rect.size = Vector2(1000, 60)
	diretrizes_rect.position = Vector2(420, 40)
	ui_layer.add_child(diretrizes_rect)
	
	diretrizes_label = Label.new()
	diretrizes_label.position = Vector2(40, 10)
	diretrizes_label.add_theme_font_size_override("font_size", 16)
	diretrizes_label.add_theme_color_override("font_color", Color.WHITE)
	diretrizes_rect.add_child(diretrizes_label)
	
	var bg_bar = StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.2, 0.1, 0.1)
	var fg_bar = StyleBoxFlat.new()
	fg_bar.bg_color = Color(0.2, 0.6, 0.2) 
	
	diretrizes_bar = ProgressBar.new()
	diretrizes_bar.position = Vector2(40, 35)
	diretrizes_bar.size = Vector2(920, 15)
	diretrizes_bar.show_percentage = false
	diretrizes_bar.add_theme_stylebox_override("background", bg_bar)
	diretrizes_bar.add_theme_stylebox_override("fill", fg_bar)
	diretrizes_rect.add_child(diretrizes_bar)

	tool_pen = ColorRect.new()
	tool_pen.color = Color(0.8, 0.8, 0.85) 
	tool_pen.size = Vector2(12, 110)
	tool_pen.position = Vector2(500, 120)
	tool_pen.rotation_degrees = -35.0
	ui_layer.add_child(tool_pen)
	_make_draggable(tool_pen, "tool_pen")
	
	var pen_tip = Polygon2D.new()
	pen_tip.color = Color(0.2, 0.2, 0.2)
	pen_tip.polygon = PackedVector2Array([ Vector2(0, 110), Vector2(12, 110), Vector2(6, 125) ])
	tool_pen.add_child(pen_tip)

	stamp_reject = ColorRect.new()
	stamp_reject.color = Color.TRANSPARENT
	stamp_reject.size = Vector2(70, 90)
	stamp_reject.position = Vector2(600, 120)
	ui_layer.add_child(stamp_reject)
	_make_draggable(stamp_reject, "tool_reject")
	
	var reject_base = ColorRect.new()
	reject_base.color = Color(0.6, 0.2, 0.2)
	reject_base.size = Vector2(70, 30)
	reject_base.position = Vector2(0, 60)
	reject_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_reject.add_child(reject_base)
	
	var reject_handle = ColorRect.new()
	reject_handle.color = Color(0.3, 0.1, 0.1)
	reject_handle.size = Vector2(24, 60)
	reject_handle.position = Vector2(23, 0)
	reject_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_reject.add_child(reject_handle)
	
	var lbl_r = Label.new()
	lbl_r.text = "REJEITAR"
	lbl_r.add_theme_font_size_override("font_size", 12)
	lbl_r.add_theme_color_override("font_color", Color.WHITE)
	lbl_r.position = Vector2(5, 65)
	stamp_reject.add_child(lbl_r)

	stamp_cia = ColorRect.new()
	stamp_cia.color = Color.TRANSPARENT
	stamp_cia.size = Vector2(70, 90)
	stamp_cia.position = Vector2(720, 120)
	ui_layer.add_child(stamp_cia)
	_make_draggable(stamp_cia, "tool_cia")
	
	var cia_base = ColorRect.new()
	cia_base.color = Color(0.2, 0.3, 0.5)
	cia_base.size = Vector2(70, 30)
	cia_base.position = Vector2(0, 60)
	cia_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_cia.add_child(cia_base)
	
	var cia_handle = ColorRect.new()
	cia_handle.color = Color(0.1, 0.15, 0.25)
	cia_handle.size = Vector2(24, 60)
	cia_handle.position = Vector2(23, 0)
	cia_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_cia.add_child(cia_handle)
	
	var lbl_cia = Label.new()
	lbl_cia.text = "SELO CIA"
	lbl_cia.add_theme_font_size_override("font_size", 12)
	lbl_cia.add_theme_color_override("font_color", Color.WHITE)
	lbl_cia.position = Vector2(5, 65)
	stamp_cia.add_child(lbl_cia)

	outbox_rect = ColorRect.new()
	outbox_rect.color = Color(0.3, 0.25, 0.2, 0.5) 
	outbox_rect.size = Vector2(260, 360) 
	outbox_rect.position = Vector2(1580, 40)
	outbox_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(outbox_rect)
	
	var outbox_border = ReferenceRect.new()
	outbox_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	outbox_border.border_color = Color(0.6, 0.5, 0.4)
	outbox_border.border_width = 4
	outbox_rect.add_child(outbox_border)
	
	var outbox_title = Label.new()
	outbox_title.text = "BANDEJA DE SAÍDA\n(Contratos Validados)"
	outbox_title.add_theme_color_override("font_color", Color.WHITE)
	outbox_title.position = Vector2(20, 20)
	outbox_rect.add_child(outbox_title)

	trash_rect = Panel.new()
	var trash_style = StyleBoxFlat.new()
	trash_style.bg_color = Color(0.1, 0.1, 0.12)
	trash_style.corner_radius_top_left = 110
	trash_style.corner_radius_top_right = 110
	trash_style.corner_radius_bottom_left = 110
	trash_style.corner_radius_bottom_right = 110
	trash_rect.add_theme_stylebox_override("panel", trash_style)
	trash_rect.size = Vector2(220, 220)
	trash_rect.position = Vector2(1650, 830)
	trash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(trash_rect)
	
	agenda_rect = ColorRect.new()
	agenda_rect.color = Color(0.85, 0.8, 0.6) 
	agenda_rect.size = Vector2(400, 520) 
	agenda_rect.position = Vector2(40, 200)
	ui_layer.add_child(agenda_rect)
	_make_draggable(agenda_rect, "panel")
	
	var lombada = ColorRect.new()
	lombada.color = Color(0.1, 0.1, 0.1) 
	lombada.size = Vector2(30, 520)
	lombada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	agenda_rect.add_child(lombada)
	
	var agenda_title = Label.new()
	agenda_title.text = "ARQUIVO DE CLIENTES"
	agenda_title.add_theme_color_override("font_color", Color.BLACK)
	agenda_title.position = Vector2(50, 20)
	agenda_rect.add_child(agenda_title)
	
	companies_vbox = VBoxContainer.new()
	companies_vbox.position = Vector2(40, 60)
	companies_vbox.size = Vector2(340, 380)
	companies_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	agenda_rect.add_child(companies_vbox)

	btn_prev_page = Button.new()
	btn_prev_page.text = "<- Pág."
	btn_prev_page.size = Vector2(80, 40)
	btn_prev_page.position = Vector2(40, 460)
	btn_prev_page.pressed.connect(_on_prev_page_pressed)
	agenda_rect.add_child(btn_prev_page)
	
	lbl_page = Label.new()
	lbl_page.text = "Pág. 1"
	lbl_page.add_theme_color_override("font_color", Color.BLACK)
	lbl_page.position = Vector2(170, 470)
	agenda_rect.add_child(lbl_page)

	btn_next_page = Button.new()
	btn_next_page.text = "Pág. ->"
	btn_next_page.size = Vector2(80, 40)
	btn_next_page.position = Vector2(300, 460)
	btn_next_page.pressed.connect(_on_next_page_pressed)
	agenda_rect.add_child(btn_next_page)

	pad_extension = ColorRect.new()
	pad_extension.color = Color(0.35, 0.4, 0.45)
	pad_extension.size = Vector2(140, 180)
	pad_extension.position = Vector2(480, 200)
	pad_extension.visible = false
	ui_layer.add_child(pad_extension)
	
	# --- INÍCIO DA ALTERAÇÃO 2: UI do Alerta de Caixas ---
	# --- INÍCIO: UI do Alerta Giratório (Mesa) ---
	alert_container = Control.new()
	alert_container.position = Vector2(20, 330) # Posicionado logo abaixo da bandeja de entrada
	alert_container.visible = false
	
	var base_style = StyleBoxFlat.new()
	base_style.bg_color = Color(0.1, 0.1, 0.1)
	base_style.corner_radius_top_left = 30; base_style.corner_radius_top_right = 30
	base_style.corner_radius_bottom_left = 30; base_style.corner_radius_bottom_right = 30
	
	var base_panel = Panel.new()
	base_panel.size = Vector2(60, 60)
	base_panel.add_theme_stylebox_override("panel", base_style)
	alert_container.add_child(base_panel)
	
	var bulb_style = StyleBoxFlat.new()
	bulb_style.bg_color = Color(0.9, 0.1, 0.1)
	bulb_style.corner_radius_top_left = 25; bulb_style.corner_radius_top_right = 25
	bulb_style.corner_radius_bottom_left = 25; bulb_style.corner_radius_bottom_right = 25
	
	alert_bulb = Panel.new()
	alert_bulb.size = Vector2(50, 50)
	alert_bulb.position = Vector2(5, 5)
	alert_bulb.add_theme_stylebox_override("panel", bulb_style)
	base_panel.add_child(alert_bulb)
	
	alert_pivot = Node2D.new()
	alert_pivot.position = Vector2(30, 30)
	alert_container.add_child(alert_pivot)
	
	var alert_beam = ColorRect.new()
	alert_beam.color = Color(1.0, 0.2, 0.2, 0.3) # Feixe de luz transparente vermelho
	alert_beam.size = Vector2(200, 30)
	alert_beam.position = Vector2(0, -15)
	alert_pivot.add_child(alert_beam)
	
	alert_label = Label.new()
	alert_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	alert_label.add_theme_font_size_override("font_size", 16)
	alert_label.position = Vector2(70, 15)
	alert_container.add_child(alert_label)
	
	ui_layer.add_child(alert_container)
	# --- FIM: UI do Alerta Giratório ---
	# --- FIM DA ALTERAÇÃO 2 ---
	
	var pad_clip_ext = ColorRect.new()
	pad_clip_ext.color = Color(0.1, 0.1, 0.1)
	pad_clip_ext.size = Vector2(140, 20)
	pad_extension.add_child(pad_clip_ext)
	
	var pad_ext_lbl = Label.new()
	pad_ext_lbl.text = "FORM.\nEXTENSÃO"
	pad_ext_lbl.add_theme_font_size_override("font_size", 14)
	pad_ext_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pad_ext_lbl.position = Vector2(0, 50)
	pad_ext_lbl.size = Vector2(140, 40)
	pad_extension.add_child(pad_ext_lbl)
	pad_extension.mouse_filter = Control.MOUSE_FILTER_STOP
	pad_extension.gui_input.connect(_on_pad_extension_input)

	clipboard_rect = ColorRect.new()
	clipboard_rect.color = Color(0.95, 0.95, 0.9) 
	clipboard_rect.size = Vector2(350, 400)
	clipboard_rect.position = Vector2(750, 200)
	ui_layer.add_child(clipboard_rect)
	_make_draggable(clipboard_rect, "panel")
	
	var clipe_metal = ColorRect.new()
	clipe_metal.color = Color(0.5, 0.5, 0.55) 
	clipe_metal.size = Vector2(150, 20)
	clipe_metal.position = Vector2(100, 0)
	clipe_metal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clipboard_rect.add_child(clipe_metal)

	report_label = Label.new()
	report_label.position = Vector2(20, 40)
	report_label.size = Vector2(310, 280)
	report_label.add_theme_color_override("font_color", Color.BLACK)
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clipboard_rect.add_child(report_label)

	btn_next_day = Button.new()
	btn_next_day.text = "Processar Saídas e Finalizar Dia"
	btn_next_day.position = Vector2(20, 340)
	btn_next_day.size = Vector2(310, 40)
	btn_next_day.pressed.connect(_on_next_day_pressed)
	clipboard_rect.add_child(btn_next_day)

	task_pad_rect = ColorRect.new()
	task_pad_rect.color = Color(0.95, 0.92, 0.65)
	task_pad_rect.size = Vector2(380, 380)
	task_pad_rect.position = Vector2(1100, 200) 
	ui_layer.add_child(task_pad_rect)
	_make_draggable(task_pad_rect, "panel")

	var pad_clip = ColorRect.new()
	pad_clip.color = Color(0.7, 0.2, 0.2) 
	pad_clip.size = Vector2(380, 20)
	task_pad_rect.add_child(pad_clip)

	var task_title = Label.new()
	task_title.text = "PRANCHETA DE OPERAÇÕES"
	task_title.add_theme_color_override("font_color", Color.BLACK)
	task_title.position = Vector2(20, 25)
	task_pad_rect.add_child(task_title)

	task_vbox = VBoxContainer.new()
	task_vbox.position = Vector2(15, 55)
	task_vbox.size = Vector2(350, 310)
	task_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_pad_rect.add_child(task_vbox)

	radio_rect = ColorRect.new()
	radio_rect.color = Color(0.2, 0.2, 0.25)
	radio_rect.size = Vector2(140, 320)
	radio_rect.position = Vector2(420, 690)
	ui_layer.add_child(radio_rect)
	_make_draggable(radio_rect, "radio")
	
	var radio_antenna = ColorRect.new()
	radio_antenna.color = Color(0.1, 0.1, 0.1)
	radio_antenna.size = Vector2(16, 80)
	radio_antenna.position = Vector2(20, -70)
	radio_antenna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radio_rect.add_child(radio_antenna)
	
	var radio_speaker = ColorRect.new()
	radio_speaker.color = Color(0.1, 0.1, 0.1)
	radio_speaker.size = Vector2(100, 100)
	radio_speaker.position = Vector2(20, 120)
	radio_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radio_rect.add_child(radio_speaker)
	
	var radio_lbl = Label.new()
	radio_lbl.text = "RÁDIO PTT\nFREQ 104.2"
	radio_lbl.add_theme_color_override("font_color", Color.WHITE)
	radio_lbl.position = Vector2(20, 20)
	radio_rect.add_child(radio_lbl)
	
	radio_led = ColorRect.new()
	radio_led.color = Color(0.2, 0.05, 0.05) 
	radio_led.size = Vector2(24, 24)
	radio_led.position = Vector2(96, 70)
	radio_led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radio_rect.add_child(radio_led)

	phone_rect = ColorRect.new()
	phone_rect.color = Color(0.1, 0.25, 0.15) 
	phone_rect.size = Vector2(340, 260) 
	phone_rect.position = Vector2(40, 750)
	ui_layer.add_child(phone_rect)
	_make_draggable(phone_rect, "panel")
	
	var handset_rect = ColorRect.new()
	handset_rect.color = Color(0.08, 0.2, 0.12)
	handset_rect.size = Vector2(300, 40)
	handset_rect.position = Vector2(20, -20)
	handset_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_rect.add_child(handset_rect)
	
	phone_display = Label.new()
	phone_display.text = "VISOR: ---"
	phone_display.position = Vector2(40, 30)
	phone_display.size = Vector2(260, 40)
	phone_display.add_theme_font_size_override("font_size", 24)
	phone_display.add_theme_color_override("font_color", Color.WHITE)
	phone_rect.add_child(phone_display)
	
	dial_rect = Control.new()
	dial_rect.position = Vector2(170, 160) 
	dial_rect.size = Vector2(240, 240)
	dial_rect.position -= dial_rect.size / 2.0
	dial_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	dial_rect.draw.connect(_on_dial_draw)
	dial_rect.gui_input.connect(_on_dial_gui_input)
	phone_rect.add_child(dial_rect)
	
	# --- INÍCIO DA ADIÇÃO: INSTANCIAÇÃO DAS FICHAS FÍSICAS NA MESA ---
	token_visuals.clear()
	for i in range(3):
		var token = Panel.new()
		var token_style = StyleBoxFlat.new()
		token_style.bg_color = Color(0.7, 0.55, 0.2) # Tom metálico de latão/bronze antigo
		token_style.corner_radius_top_left = 20
		token_style.corner_radius_top_right = 20
		token_style.corner_radius_bottom_left = 20
		token_style.corner_radius_bottom_right = 20
		token_style.border_width_left = 2
		token_style.border_width_top = 2
		token_style.border_width_right = 2
		token_style.border_width_bottom = 2
		token_style.border_color = Color(0.4, 0.3, 0.1) # Borda metálica escura para dar relevo
		token.add_theme_stylebox_override("panel", token_style)
		
		token.size = Vector2(30, 30)
		# Posiciona horizontalmente uma ao lado da outra, logo à direita do telefone (eixo X)
		token.position = Vector2(400 + (i * 40), 860)
		token.mouse_filter = Control.MOUSE_FILTER_IGNORE # Elemento puramente estático e visual
		ui_layer.add_child(token)
		token_visuals.append(token)
	# --- FIM DA ADIÇÃO ---
	
	calendar_rect = ColorRect.new()
	calendar_rect.color = Color(0.9, 0.9, 0.9)
	calendar_rect.size = Vector2(220, 160)
	calendar_rect.position = Vector2(1150, 520)
	ui_layer.add_child(calendar_rect)
	_make_draggable(calendar_rect, "panel")
	
	var cal_clip = ColorRect.new()
	cal_clip.name = "clip"
	cal_clip.color = Color(0.2, 0.2, 0.2)
	cal_clip.size = Vector2(100, 15)
	cal_clip.position = Vector2(60, 0)
	calendar_rect.add_child(cal_clip)

	folder_rect = ColorRect.new()
	folder_rect.color = Color(0.8, 0.65, 0.4) 
	folder_rect.size = Vector2(500, 480)
	folder_rect.position = Vector2(700, 310) 
	folder_rect.visible = false
	ui_layer.add_child(folder_rect)
	_make_draggable(folder_rect, "panel")
	
	var folder_tab = ColorRect.new()
	folder_tab.color = Color(0.8, 0.65, 0.4)
	folder_tab.size = Vector2(150, 30)
	folder_tab.position = Vector2(20, -20)
	folder_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	folder_rect.add_child(folder_tab)
	
	folder_title = Label.new()
	folder_title.position = Vector2(20, 10)
	folder_title.add_theme_font_size_override("font_size", 20)
	folder_title.add_theme_color_override("font_color", Color.BLACK)
	folder_rect.add_child(folder_title)
	
	folder_route = Label.new()
	folder_route.position = Vector2(20, 40)
	folder_route.add_theme_color_override("font_color", Color.DARK_RED)
	folder_rect.add_child(folder_route)
	
	btn_close_folder = Button.new()
	btn_close_folder.text = "X"
	btn_close_folder.position = Vector2(460, 10)
	btn_close_folder.size = Vector2(30, 30)
	btn_close_folder.pressed.connect(_on_close_folder_pressed)
	folder_rect.add_child(btn_close_folder)

	# --- INÍCIO DA ALTERAÇÃO (CORREÇÃO DO BUG DO BOTÃO) ---
	doc_standard = ColorRect.new()
	doc_standard.color = Color(0.95, 0.95, 0.95)
	doc_standard.size = Vector2(440, 420)
	doc_standard.position = Vector2(20, 40)
	folder_rect.add_child(doc_standard)
	doc_standard.gui_input.connect(_on_doc_input.bind(doc_standard))
	
	# O ScrollContainer agora é filho do doc_standard, respeitando as bordas dele.
	# Tamanho vertical reduzido para não invadir o botão de preparar contrato
	var std_scroll = ScrollContainer.new()
	std_scroll.position = Vector2(10, 10)
	std_scroll.size = Vector2(420, 340) 
	doc_standard.add_child(std_scroll)
	
	std_label = Label.new()
	std_label.custom_minimum_size = Vector2(400, 0)
	std_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	std_label.add_theme_color_override("font_color", Color.BLACK)
	std_label.add_theme_font_size_override("font_size", 14)
	std_scroll.add_child(std_label)
	
	btn_call_std = Button.new()
	btn_call_std.text = "PREPARAR CONTRATO"
	btn_call_std.position = Vector2(20, 360)
	btn_call_std.size = Vector2(400, 40)
	btn_call_std.pressed.connect(_on_call_standard_pressed)
	doc_standard.add_child(btn_call_std)
	# --- FIM DA ALTERAÇÃO ---

	doc_urgent = ColorRect.new()
	doc_urgent.color = Color(0.95, 0.85, 0.85)
	doc_urgent.size = Vector2(440, 420)
	doc_urgent.position = Vector2(40, 50) 
	folder_rect.add_child(doc_urgent)
	doc_urgent.gui_input.connect(_on_doc_input.bind(doc_urgent))
	
	urg_label = Label.new()
	urg_label.position = Vector2(20, 20)
	urg_label.size = Vector2(400, 330)
	urg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	urg_label.add_theme_color_override("font_color", Color.DARK_RED)
	doc_urgent.add_child(urg_label)
	
	btn_call_urg = Button.new()
	btn_call_urg.text = "PREPARAR URGÊNCIA"
	btn_call_urg.position = Vector2(20, 360)
	btn_call_urg.size = Vector2(400, 40)
	btn_call_urg.add_theme_color_override("font_color", Color.INDIAN_RED)
	btn_call_urg.pressed.connect(_on_call_urgent_pressed)
	doc_urgent.add_child(btn_call_urg)
	
	trash_dialog = ColorRect.new()
	trash_dialog.color = Color(0.1, 0.1, 0.15, 0.98)
	trash_dialog.size = Vector2(400, 200)
	trash_dialog.position = Vector2(760, 440)
	trash_dialog.visible = false
	ui_layer.add_child(trash_dialog)
	
	var trash_border = ReferenceRect.new()
	trash_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	trash_border.border_color = Color.INDIAN_RED
	trash_border.border_width = 4
	trash_dialog.add_child(trash_border)
	
	var trash_lbl = Label.new()
	trash_lbl.text = "Excluir Documento?"
	trash_lbl.add_theme_font_size_override("font_size", 28)
	trash_lbl.add_theme_color_override("font_color", Color.WHITE)
	trash_lbl.position = Vector2(0, 40)
	trash_lbl.size = Vector2(400, 40)
	trash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trash_dialog.add_child(trash_lbl)
	
	btn_trash_yes = Button.new()
	btn_trash_yes.text = "Sim"
	btn_trash_yes.size = Vector2(140, 50)
	btn_trash_yes.position = Vector2(40, 110)
	btn_trash_yes.add_theme_color_override("font_color", Color.INDIAN_RED)
	btn_trash_yes.pressed.connect(_on_trash_yes)
	trash_dialog.add_child(btn_trash_yes)
	
	btn_trash_no = Button.new()
	btn_trash_no.text = "Não"
	btn_trash_no.size = Vector2(140, 50)
	btn_trash_no.position = Vector2(220, 110)
	btn_trash_no.pressed.connect(_on_trash_no)
	trash_dialog.add_child(btn_trash_no)





func _process_call() -> void:
	var rid = pending_company_data["route_id"]
	var ctype = pending_company_data["type"]
	var has_route = rid in GameManager.network_connections
	var is_constructing = GameManager.routes_under_construction.get(rid, 0) > 0

	var route_valid = false
	var reason = ""
	
	# === LÓGICA ANTI-SOFTLOCK: ROTA INEXISTENTE OU EM OBRAS ===
	if not has_route or is_constructing:
		GameManager.phone_tokens += 1 # Devolve a ficha
		_update_tokens_visual()
		phone_cutscene.start_rejection_call(pending_company_data["name"], "Sem trilhos, eu não trabalho! Construa a rota inteira primeiro e depois me ligue.")
		folder_rect.visible = false
		return
		
	# === VALIDAÇÃO DE REGRAS ESPECÍFICAS DA CARGA ===
	if has_route:
		var stats = GameManager.network_stats.get(rid, {})
		var max_d = pending_company_data.get("max_dist", 999)
		var curr_d = stats.get("dist", 999)
		var is_long = (ctype == "Expresso" and curr_d > max_d)
		
		if is_long:
			reason = "A nossa carga EXPRESSA tem limite rigoroso de tempo!\nA sua via tem " + str(curr_d) + " km, mas exigimos um trajeto máximo de " + str(max_d) + " km!\nRefaça a rota de forma mais direta!"
		elif ctype == "VIP" and (stats.get("gangs", 0) > 0 or GameManager.active_contracts.size() > 0):
			reason = "VIP exige segurança absoluta e exclusividade na malha!"
		elif ctype == "Ecologico" and stats.get("forests", 0) > 0:
			reason = "Os seus trilhos desmataram a floresta! Não financiamos crimes ambientais!"
		else:
			route_valid = true

	# === LÓGICA ANTI-SOFTLOCK: ROTA INVÁLIDA ===
	if not route_valid:
		GameManager.phone_tokens += 1 # Devolve a ficha
		_update_tokens_visual()
		phone_cutscene.start_rejection_call(pending_company_data["name"], reason)
		var is_daily = "(Diário)" in pending_company_data["name"]
		if not (is_daily and GameManager.current_day == 1):
			GameManager.company_cooldowns[pending_company_data["name"]] = 1 
		folder_rect.visible = false
		return

	# === SE PASSOU EM TUDO, VERIFICA SE A FROTA ESTÁ OCUPADA ===
	var wait_for_fleet = 0
	if GameManager.active_contracts.size() >= GameManager.MAX_CONTRACTS:
		var min_days = 999
		for c in GameManager.active_contracts:
			var d = c.get("days_left", 999)
			if c.has("pending_route_days"): d += c["pending_route_days"]
			if d < min_days: min_days = d
		wait_for_fleet = min_days

	pending_company_data["temp_wait_days"] = wait_for_fleet

	if wait_for_fleet > 0:
		pending_is_risk = true
	else:
		pending_is_risk = false

	var rew = pending_company_data["base_reward"]
	if pending_is_urgent:
		rew = GameManager.daily_urgencies.get(pending_company_data["name"], rew)
		
	if pending_is_risk:
		phone_cutscene.start_risk_call(pending_company_data["name"], pending_company_data["route_name"], rew, wait_for_fleet)
	else:
		phone_cutscene.start_call(pending_company_data["name"], pending_company_data["type"], pending_company_data["cargo"], rew, pending_is_urgent)






func _setup_eod_ui() -> void:
	eod_layer = CanvasLayer.new()
	eod_layer.layer = 280
	add_child(eod_layer)
	
	var eod_bg = ColorRect.new()
	eod_bg.color = Color(0.08, 0.08, 0.08, 0.95)
	eod_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	eod_layer.add_child(eod_bg)
	
	var click_catcher = Control.new()
	click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_catcher.gui_input.connect(_on_eod_input)
	eod_layer.add_child(click_catcher)
	
	var eod_receipt = ColorRect.new()
	eod_receipt.color = Color(0.12, 0.12, 0.12)
	eod_receipt.size = Vector2(500, 800)
	eod_receipt.position = Vector2(710, 100)
	eod_receipt.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	eod_layer.add_child(eod_receipt)
	
	eod_lines_container = VBoxContainer.new()
	eod_lines_container.size = Vector2(440, 700)
	eod_lines_container.position = Vector2(30, 30)
	eod_lines_container.add_theme_constant_override("separation", 10)
	eod_lines_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eod_receipt.add_child(eod_lines_container)
	
	btn_eod_sleep = Button.new()
	btn_eod_sleep.text = "DORMIR E INICIAR PROXIMO DIA"
	btn_eod_sleep.size = Vector2(440, 50)
	btn_eod_sleep.position = Vector2(30, 730)
	btn_eod_sleep.pressed.connect(_on_eod_sleep_pressed)
	eod_receipt.add_child(btn_eod_sleep)
	
	eod_layer.visible = false

func _on_pad_extension_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			_spawn_extension_form()

func _spawn_extension_form() -> void:
	var paper = ColorRect.new()
	paper.color = Color(0.7, 0.75, 0.8) 
	paper.size = Vector2(300, 420)
	paper.pivot_offset = paper.size / 2.0 
	paper.position = Vector2(500 + randf_range(-30, 30), 200 + randf_range(-30, 30))
	paper.rotation_degrees = randf_range(-4, 4)

	var content = Control.new()
	content.name = "content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(content)

	var content_lbl = Label.new()
	content_lbl.add_theme_color_override("font_color", Color.BLACK)
	content_lbl.size = Vector2(260, 380) # Previne vazamento de texto
	content_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_lbl.position = Vector2(20, 20)
	content.add_child(content_lbl)

	paper.set_meta("is_paper", true)
	paper.set_meta("is_extension", true)
	paper.set_meta("selected_idx", -1)
	paper.set_meta("action", "")

	_make_draggable(paper, "paper")

	var s_idx = -1
	for i in range(GameManager.active_contracts.size()):
		var c = GameManager.active_contracts[i]
		if c["days_left"] == 1:
			s_idx = i
			break

	if s_idx != -1:
		var c = GameManager.active_contracts[s_idx]
		var rtype = c.get("renewal_type", "penalty")
		
		paper.set_meta("selected_idx", s_idx)
		paper.set_meta("renewal_type", rtype)
		
		var txt = ""
		if rtype == "penalty":
			var cost = int(c["reward"] * c.get("duration", 5) * 0.3)
			paper.set_meta("cost", cost)
			paper.color = Color(0.95, 0.85, 0.85) # Fundo Vermelho claro
			txt = "NOTIFICAÇÃO DE ATRASO\n\nO cliente está furioso com a via em obras e trens parados. Pague a multa para estender o prazo.\n\nCusto: -$" + str(cost) + "\nPrazo extra: +5 dias"
		elif rtype == "loyalty":
			paper.color = Color(0.85, 0.95, 0.85) # Fundo Verde claro
			txt = "PROPOSTA DE RENOVAÇÃO\n\nServiço perfeito! O cliente quer renovar por mais dias, mas pediu um desconto na diária.\n\nNova Diária: $" + str(int(c.get("reward", 0) * 0.8)) + "\nPrazo: +10 dias\nCusto de Renovação: $0"
		elif rtype == "express_upgrade":
			var new_dist = c.get("new_max_dist", 20)
			paper.set_meta("new_max_dist", new_dist)
			paper.color = Color(0.95, 0.95, 0.8) # Fundo Dourado claro
			txt = "DESAFIO EXPRESSO\n\nQuerem transformar a carga em EXPRESSA! O trajeto atual está muito longo.\n\nEncurte a rota para " + str(new_dist) + " km.\nNova Diária: $" + str(int(c.get("reward", 0) * 1.4)) + "\nPrazo bônus para obras: +5 dias\nCusto: $0"

		content_lbl.text = txt + "\n\nContrato Alvo:\n" + c["company_name"] + " -> " + c.get("route_name", "")
	else:
		content_lbl.text = "REQUERIMENTO DE EXTENSÃO\n\nNenhum contrato vencendo hoje."

	ui_layer.add_child(paper)
	spawned_papers.append(paper)



func _add_ball_visual(paper: ColorRect) -> void:
	var ball_visual = Panel.new()
	var ball_style = StyleBoxFlat.new()
	ball_style.bg_color = Color.WHITE
	ball_style.corner_radius_top_left = 100
	ball_style.corner_radius_top_right = 100
	ball_style.corner_radius_bottom_left = 100
	ball_style.corner_radius_bottom_right = 100
	ball_style.shadow_color = Color(0, 0, 0, 0.4)
	ball_style.shadow_size = 8
	ball_visual.add_theme_stylebox_override("panel", ball_style)
	
	ball_visual.size = Vector2(160, 160)
	ball_visual.position = (paper.size / 2.0) - (ball_visual.size / 2.0)
	ball_visual.name = "ball_visual"
	ball_visual.visible = false
	paper.add_child(ball_visual)



func _on_trash_blueprint_pressed(paper: ColorRect) -> void:
	GameManager.pending_blueprint.clear()
	GameManager.save_game()
	if is_instance_valid(paper):
		var idx = spawned_papers.find(paper)
		if idx != -1:
			spawned_papers.remove_at(idx)
		paper.queue_free()



func _on_dial_draw() -> void:
	var center = dial_rect.size / 2.0
	var radius = 100.0
	
	dial_rect.draw_circle(center, radius, Color(0.15, 0.15, 0.15)) 
	
	var font = ThemeDB.fallback_font
	for i in range(10):
		var angle = HOLE_ANGLES[i]
		var pos = center + Vector2(cos(angle), sin(angle)) * 75.0
		dial_rect.draw_circle(pos, 18.0, Color(0.8, 0.8, 0.8)) 
		dial_rect.draw_string(font, pos + Vector2(-4, 5), str(i), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.BLACK)
		
	dial_rect.draw_arc(center, radius, 0, TAU, 32, Color(0.3, 0.3, 0.3), 4.0)
	for i in range(10):
		var angle = HOLE_ANGLES[i] + dial_current_rot
		var pos = center + Vector2(cos(angle), sin(angle)) * 75.0
		dial_rect.draw_arc(pos, 18.0, 0, TAU, 16, Color(0.3, 0.3, 0.3), 3.0)
		
	var stop_dir = Vector2(cos(STOP_ANGLE), sin(STOP_ANGLE))
	dial_rect.draw_line(center + stop_dir * 40, center + stop_dir * 115, Color.SILVER, 6.0)

func _on_dial_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				var local_pos = event.position - (dial_rect.size / 2.0)
				var dist = local_pos.length()
				if dist > 50 and dist < 110:
					var click_angle = local_pos.angle()
					var closest_num = -1
					var min_diff = 999.0
					
					for i in range(10):
						var h_angle = HOLE_ANGLES[i]
						var diff = abs(_angle_difference(click_angle, h_angle))
						if diff < min_diff:
							min_diff = diff
							closest_num = i
					
					if min_diff < deg_to_rad(25): 
						is_dial_dragging = true
						dialing_number = closest_num
						dial_start_angle = click_angle
						max_rot = STOP_ANGLE - HOLE_ANGLES[closest_num]
						while max_rot < 0: 
							max_rot += TAU
			else:
				if is_dial_dragging:
					is_dial_dragging = false
					if dial_current_rot >= max_rot - deg_to_rad(15):
						_register_dial_digit(dialing_number)
					dialing_number = -1
	else:
		if event is InputEventMouseMotion:
			if is_dial_dragging:
				var current_angle = (event.position - (dial_rect.size / 2.0)).angle()
				var diff = _angle_difference(dial_start_angle, current_angle)
				
				dial_current_rot += diff
				if dial_current_rot < 0.0:
					dial_current_rot = 0.0
				else:
					if dial_current_rot > max_rot:
						dial_current_rot = max_rot
				
				dial_start_angle = current_angle
				dial_rect.queue_redraw()

func _angle_difference(a: float, b: float) -> float:
	var diff = fmod(b - a, TAU)
	if diff < -PI: 
		diff += TAU
	else:
		if diff > PI: 
			diff -= TAU
	return diff

func _register_dial_digit(num: int) -> void:
	current_dialed += str(num)
	_update_phone_display()
	if current_dialed.length() == 7:
		_check_dialed_number()

func _update_phone_display() -> void:
	var text = current_dialed
	if text.length() > 3:
		text = text.insert(3, "-")
	phone_display.text = "VISOR: " + text

func _check_dialed_number() -> void:
	# --- INÍCIO DA ALTERAÇÃO: SISTEMA DE CONSUMO DE FICHAS NO TELEFONE ---
	var dialed_clean = current_dialed
	var target_clean = ""
	
	# Cláusula de guarda: Se o jogador não tiver fichas diárias, cancela e avisa no visor
	if GameManager.phone_tokens <= 0:
		phone_display.text = "SEM FICHAS"
		await get_tree().create_timer(1.0).timeout
		current_dialed = ""
		_update_phone_display()
		return
	
	if not pending_company_data.is_empty():
		target_clean = pending_company_data["phone"].replace("-", "")
	
	if dialed_clean == target_clean:
		phone_display.text = "LIGANDO..."
		# Desconta o recurso e atualiza o estado visual na mesa no mesmo instante
		GameManager.phone_tokens -= 1
		_update_tokens_visual()
		
		await get_tree().create_timer(0.5).timeout
		_process_call()
	else:
		phone_display.text = "NUMERO INVALIDO"
		await get_tree().create_timer(1.0).timeout
	
	current_dialed = ""
	_update_phone_display()
	# --- FIM DA ALTERAÇÃO ---_ready



func _make_draggable(panel: Control, type: String = "panel") -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("drag_type", type)
	panel.gui_input.connect(_on_panel_gui_input.bind(panel))
	if type == "panel" or type == "radio" or type.begins_with("tool"):
		original_transforms[panel] = panel.position

func _on_panel_gui_input(event: InputEvent, panel: Control) -> void:
	var type = panel.get_meta("drag_type")
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				dragged_panel = panel
				drag_offset = panel.get_global_mouse_position() - panel.global_position
				panel.get_parent().move_child(panel, -1) 
				
				if type == "panel" or type == "paper":
					panel.rotation_degrees = 0 
				
				if type == "paper":
					panel.pivot_offset = panel.size / 2.0
					var tw = create_tween().set_parallel(true)
					tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			else:
				if dragged_panel == panel:
					dragged_panel = null
					
					if type.begins_with("tool"):
						var action_pos = Vector2.ZERO
						if type == "tool_pen":
							action_pos = panel.get_global_transform() * Vector2(6, 125)
						else:
							action_pos = panel.get_global_transform() * Vector2(35, 90)
							
						_try_apply_tool(action_pos, type)
						var tw = create_tween()
						if type == "tool_pen":
							tw.tween_property(panel, "position", original_transforms[panel], 0.2)
							tw.parallel().tween_property(panel, "rotation_degrees", -35.0, 0.2)
						else:
							tw.tween_property(panel, "position", original_transforms[panel], 0.2)
					else:
						if type == "radio":
							if GameManager.pending_radio_event:
								phone_cutscene.start_badger_radio()
							panel.rotation_degrees = randf_range(-3.0, 3.0) 
							_clamp_to_screen(panel)
						else:
							if type == "paper":
								panel.rotation_degrees = randf_range(-4.0, 4.0) 
								
								var center = panel.get_global_rect().get_center()
								var outbox_center = outbox_rect.global_position + outbox_rect.size / 2.0
								var trash_center = trash_rect.global_position + trash_rect.size / 2.0
								
								# Verifica se soltou em cima da lixeira
								if center.distance_to(trash_center) < 160:
									trash_target_paper = panel
									trash_dialog.visible = true
									trash_dialog.get_parent().move_child(trash_dialog, -1) # Traz pop-up pra frente
								else:
									if outbox_rect.get_global_rect().grow(100).has_point(center):
										panel.pivot_offset = panel.size / 2.0
										var tw = create_tween().set_parallel(true)
										tw.tween_property(panel, "scale", Vector2(0.60, 0.60), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
										var target_pos = outbox_center - (panel.size / 2.0) + Vector2(randf_range(-10, 10), randf_range(-10, 10))
										tw.tween_property(panel, "global_position", target_pos, 0.2)
									else:
										_clamp_to_screen(panel)
							else:
								if type == "panel":
									panel.rotation_degrees = randf_range(-3.0, 3.0) 
									_clamp_to_screen(panel)
	else:
		if event is InputEventMouseMotion:
			if dragged_panel == panel:
				panel.global_position = panel.get_global_mouse_position() - drag_offset
				if type == "paper":
					# Agora, ao mover o mouse, não amassa mais o papel automaticamente.
					_clamp_to_screen(panel) 
				else:
					_clamp_to_screen(panel)



func _on_trash_yes() -> void:
	trash_dialog.visible = false
	if is_instance_valid(trash_target_paper):
		# Se for uma planta de obras, precisamos limpar do GameManager também
		if trash_target_paper.get_meta("is_blueprint", false):
			GameManager.pending_blueprint.clear()
			GameManager.save_game()
			
		# Remove da lista de papeis spawnados para evitar bugs de save/load
		var idx = spawned_papers.find(trash_target_paper)
		if idx != -1:
			spawned_papers.remove_at(idx)
			
		# Deleta imediatamente do jogo
		trash_target_paper.queue_free()
		
	trash_target_paper = null

func _on_trash_no() -> void:
	trash_dialog.visible = false
	if is_instance_valid(trash_target_paper):
		# Devolve o papel com segurança pra mesa para não ficar em cima da lixeira
		var safe_center = get_viewport_rect().size / 2.0
		trash_target_paper.global_position = safe_center - (trash_target_paper.size / 2.0)
		_clamp_to_screen(trash_target_paper)
	trash_target_paper = null





func _clamp_to_screen(panel: Control) -> void:
	var s = get_viewport_rect().size
	var p = panel.global_position
	var sz = panel.size
	p.x = clamp(p.x, 0, s.x - sz.x)
	p.y = clamp(p.y, 0, s.y - sz.y)
	panel.global_position = p

func _clamp_scaled_paper(panel: Control) -> void:
	var s = get_viewport_rect().size
	var scale = panel.scale.x
	var visual_size = panel.size * scale
	
	var center = panel.global_position + (panel.size / 2.0)
	var half_vis = visual_size / 2.0
	
	center.x = clamp(center.x, half_vis.x, s.x - half_vis.x)
	center.y = clamp(center.y, half_vis.y, s.y - half_vis.y)
	
	panel.global_position = center - (panel.size / 2.0)

func _try_apply_tool(pos: Vector2, tool_type: String) -> void:
	for i in range(spawned_papers.size() - 1, -1, -1):
		var p = spawned_papers[i]
		# CORREÇÃO: Impede que o jogador assine bolinhas de papel amassado!
		if p.get_global_rect().has_point(pos) and p.has_node("content") and not p.get_meta("crumpled", false):
			var content = p.get_node("content")
			
			if tool_type == "tool_pen":
				var hit_checkbox = false
				if p.get_meta("is_extension", false):
					for child in content.get_children():
						if child.has_meta("is_checkbox"):
							if child.get_global_rect().has_point(pos):
								for c2 in content.get_children():
									if c2.has_meta("is_checkbox"):
										c2.get_child(0).get_child(0).visible = false
										
								var mark = child.get_child(0).get_child(0)
								mark.visible = true
								mark.add_theme_color_override("font_color", Color(0.1, 0.1, 0.6))
								
								p.set_meta("selected_idx", child.get_meta("cb_idx"))
								hit_checkbox = true
								break
				
				if hit_checkbox:
					return 
				
				if p.has_meta("node_reject"):
					var old_mark = p.get_meta("node_reject")
					if is_instance_valid(old_mark):
						old_mark.queue_free()
					p.remove_meta("node_reject")
					
				if not p.has_meta("node_approve"):
					var mark = Label.new()
					mark.text = "Ass: Diretor Geral"
					mark.add_theme_font_size_override("font_size", 28)
					mark.add_theme_color_override("font_color", Color(0.1, 0.1, 0.6))
					mark.rotation_degrees = randf_range(-10.0, 10.0)
					mark.position = p.get_local_mouse_position() - Vector2(80, 20)
					content.add_child(mark)
					p.set_meta("node_approve", mark)
					
				p.set_meta("action", "approve")
				
			if tool_type == "tool_reject":
				if p.has_meta("node_approve"):
					var old_mark = p.get_meta("node_approve")
					if is_instance_valid(old_mark):
						old_mark.queue_free()
					p.remove_meta("node_approve")
					
				if not p.has_meta("node_reject"):
					var mark = Label.new()
					mark.text = "[ REJEITADO ]"
					mark.add_theme_font_size_override("font_size", 36)
					mark.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1, 0.8))
					mark.rotation_degrees = randf_range(-15.0, 15.0)
					mark.position = p.get_local_mouse_position() - Vector2(100, 20)
					content.add_child(mark)
					p.set_meta("node_reject", mark)
					
				p.set_meta("action", "reject")
				
			if tool_type == "tool_cia":
				if not p.has_meta("node_cia"):
					var seal = Label.new()
					seal.text = "( SELO DA CIA )"
					seal.add_theme_font_size_override("font_size", 20)
					seal.add_theme_color_override("font_color", Color(0.2, 0.3, 0.5, 0.7))
					seal.rotation_degrees = randf_range(-20.0, 20.0)
					seal.position = p.get_local_mouse_position() - Vector2(80, 15)
					content.add_child(seal)
					p.set_meta("node_cia", seal)
					
			return






func _on_organize_pressed() -> void:
	var tween = create_tween().set_parallel(true)
	for panel in original_transforms.keys():
		if is_instance_valid(panel):
			tween.tween_property(panel, "position", original_transforms[panel], 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(panel, "rotation_degrees", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if panel.get_meta("drag_type") == "tool_pen":
				tween.tween_property(panel, "rotation_degrees", -35.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _setup_cutscene() -> void:
	phone_cutscene = CutsceneDialog.new()
	add_child(phone_cutscene)
	phone_cutscene.contract_accepted.connect(_on_cutscene_accepted)
	phone_cutscene.contract_rejected.connect(_on_cutscene_rejected)
	phone_cutscene.call_closed.connect(_on_cutscene_closed)
	phone_cutscene.cancel_confirmed.connect(_on_cancel_confirmed)
	phone_cutscene.radio_choice_made.connect(_on_radio_choice)
	phone_cutscene.fiscal_choice_made.connect(_on_fiscal_choice)

func _update_diretrizes() -> void:
	var lvl = LevelData.LEVELS[GameManager.current_level]
	var m = lvl["goal"]
	var a = GameManager.money
	
	diretrizes_label.text = "📍 DIRETRIZES DA REGIÃO [" + lvl["name"] + "]  | META: $" + str(m) + "  |  CAIXA: $" + str(a)
	
	var fg = diretrizes_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if a < 0: 
		fg.bg_color = Color(0.8, 0.2, 0.2)
		diretrizes_bar.max_value = 1
		diretrizes_bar.value = 1
	else: 
		fg.bg_color = Color(0.2, 0.6, 0.2)
		diretrizes_bar.max_value = m
		diretrizes_bar.value = a



# --- INÍCIO DA ALTERAÇÃO: SISTEMA DO GUIA REGIONAL (ABAS E CARTÕES) ---
# --- INÍCIO DA ALTERAÇÃO: SISTEMA DO GUIA REGIONAL CORRIGIDO ---
func _load_agenda_contacts() -> void:
	if not is_instance_valid(agenda_rect): return
	
	# Limpa tudo que havia na pasta
	for child in agenda_rect.get_children():
		child.queue_free()
		
	# Estética da Pasta do Guia (Parda/Couro)
	agenda_rect.color = Color(0.85, 0.75, 0.55)
	
	var title = Label.new()
	title.text = "GUIA REGIONAL DE FRETES"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
	title.position = Vector2(20, 15)
	agenda_rect.add_child(title)

	var level_data = LevelData.LEVELS[GameManager.current_level]
	var all_c = []
	if level_data.has("companies"):
		all_c = level_data["companies"].duplicate(true)
		
	# Trava do Tutorial: Adiciona a Prefeitura Local se for o primeiro dia
	if GameManager.current_day == 1 and not GameManager.is_first_route_built:
		var tutorial_contract = {
			"name": "Prefeitura Local (Edital)",
			"type": "Licitação Estatal",
			"region": "Vale do Rio", # Adicionado para aparecer na aba correta
			"phone": "555-0001",
			"cargo": "Materiais de Construcao",
			"route_id": "Estação A-Estação B",
			"route_name": "Estação A <-> Estação B",
			"base_reward": 150,
			"upfront_bonus": 1500,
			"grandpa_note": "Um edital da prefeitura. Eles pagam adiantado para construirmos a primeira via. Pegue este sem pensar duas vezes!"
		}
		all_c.insert(0, tutorial_contract)
		
	# Mapeia dinamicamente todas as regiões que existem no banco de dados
	var regions = []
	for c in all_c:
		var r = c.get("region", "Desconhecida")
		if not regions.has(r):
			regions.append(r)
			
	if current_guide_region == "" and regions.size() > 0:
		current_guide_region = regions[0] # Inicia na primeira aba

	# Desenha as Abas (Botões no topo)
	var tab_x = 20
	for r in regions:
		var btn = Button.new()
		btn.text = r
		btn.position = Vector2(tab_x, 50)
		btn.size = Vector2(100, 30)
		
		# Destaca a aba selecionada em amarelo
		if r == current_guide_region:
			btn.modulate = Color(1.0, 1.0, 0.5)
		if r != current_guide_region:
			btn.modulate = Color(0.8, 0.8, 0.8)
			
		btn.pressed.connect(_on_guide_tab_pressed.bind(r))
		agenda_rect.add_child(btn)
		tab_x += 110

	# Desenha os Cartões de Empresas da aba selecionada
	var card_y = 95
	for c in all_c:
		var c_reg = c.get("region", "Desconhecida")
		if c_reg == current_guide_region:
			var card = Button.new()
			card.position = Vector2(20, card_y)
			card.size = Vector2(360, 110)
			
			var c_style = StyleBoxFlat.new()
			c_style.bg_color = Color(0.95, 0.95, 0.9)
			c_style.border_color = Color(0.6, 0.5, 0.4)
			# CORREÇÃO AQUI: Definindo as bordas individualmente para Godot 4
			c_style.border_width_left = 2
			c_style.border_width_top = 2
			c_style.border_width_right = 2
			c_style.border_width_bottom = 2
			card.add_theme_stylebox_override("normal", c_style)
			
			var h_style = c_style.duplicate()
			h_style.bg_color = Color(1.0, 1.0, 0.95) # Brilho no hover
			card.add_theme_stylebox_override("hover", h_style)
			
			var lbl = Label.new()
			lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.position = Vector2(10, 5)
			lbl.size = Vector2(340, 100)
			
			var txt = "[ " + c["name"] + " ]\n"
			txt += "Rota: " + c.get("route_name", "") + " | Carga: " + c.get("cargo", "") + "\n"
			txt += "Paga: $" + str(c.get("base_reward", 0)) + "/dia | TEL: " + c.get("phone", "") + "\n\n"
			txt += "[i]\"" + c.get("grandpa_note", "Uma empresa comum.") + "\"[/i]" # Lore do Avô
			
			# Usamos RichTextLabel apenas para o itálico na nota do avô
			var rich_lbl = RichTextLabel.new()
			rich_lbl.bbcode_enabled = true
			rich_lbl.text = txt
			rich_lbl.add_theme_color_override("default_color", Color(0.1, 0.1, 0.1))
			rich_lbl.add_theme_font_size_override("normal_font_size", 13)
			rich_lbl.position = Vector2(10, 5)
			rich_lbl.size = Vector2(340, 100)
			rich_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			card.add_child(rich_lbl)
			
			var c_bind = c.duplicate()
			card.pressed.connect(_on_guide_card_pressed.bind(c_bind))
			
			agenda_rect.add_child(card)
			card_y += 120
# --- FIM DA ALTERAÇÃO ---



# --- INÍCIO DA ADIÇÃO: INTERAÇÕES DA PASTA DO GUIA ---
func _on_guide_tab_pressed(region_name: String) -> void:
	current_guide_region = region_name
	_load_agenda_contacts() # Recarrega a pasta inteira mostrando a nova aba

func _on_guide_card_pressed(company_data: Dictionary) -> void:
	# Clicar no cartão no Guia NÃO rasga papel. Apenas avisa o telefone!
	pending_company_data = company_data
	pending_is_urgent = false
	current_dialed = ""
	_update_phone_display()
	
	# Feedback visual rápido no visor do telefone para o jogador saber que o contato foi copiado
	phone_display.text = "CONTATO COPIADO"
	await get_tree().create_timer(1.0).timeout
	_update_phone_display()
# --- FIM DA ADIÇÃO ---




func _render_agenda_page() -> void:
	for child in companies_vbox.get_children():
		child.queue_free()
		
	var items_per_page = 4
	var start_idx = current_agenda_page * items_per_page
	var end_idx = min(start_idx + items_per_page, current_agenda_contacts.size())
	
	for i in range(start_idx, end_idx):
		var c = current_agenda_contacts[i]
		if typeof(c) != TYPE_DICTIONARY:
			continue
			
		var btn = Button.new()
		
		# --- INÍCIO DA ALTERAÇÃO (MAPEAMENTO DE TAGS DO MENU) ---
		var raw_type = c.get("type", "Falso")
		var display_type = raw_type
		
		if raw_type == "Ganha-Pao":
			display_type = "Convencional"
		if raw_type == "Expresso":
			display_type = "Expresso JIT"
		if raw_type == "VIP":
			display_type = "Alto Risco"
		if raw_type == "Ecologico":
			display_type = "Selo ESG"
		if raw_type == "Licitação Estatal":
			display_type = "Subsídio"
			
		if raw_type == "Falso":
			btn.text = c.get("name", "Desconhecido") + "\nTel: " + c.get("phone", "000")
			btn.disabled = true
		if raw_type != "Falso":
			var c_name = c.get("name", "Empresa")
			var txt = c_name + " (" + display_type + ")\n"
			txt += "Tel: " + c.get("phone", "000") + " | Paga: $" + str(c.get("base_reward", 0))
			btn.text = txt
			btn.pressed.connect(_on_company_selected.bind(c))
		# --- FIM DA ALTERAÇÃO ---
			
		btn.custom_minimum_size = Vector2(240, 60)
		companies_vbox.add_child(btn)
		
	lbl_page.text = "Pág. " + str(current_agenda_page + 1)
	btn_prev_page.text = "<- Pág."
	btn_next_page.text = "Pág. ->"



func _on_close_folder_pressed() -> void: 
	folder_rect.visible = false
	selected_company_data = {}
	pending_company_data = {}
	current_dialed = ""
	_update_phone_display()

func _on_call_standard_pressed() -> void: 
	pending_company_data = selected_company_data
	pending_is_urgent = false
	btn_call_std.text = "DISQUE O NUMERO ->"
	if doc_urgent.visible:
		btn_call_urg.text = "PREPARAR URGENCIA"
	current_dialed = ""
	_update_phone_display()

func _on_call_urgent_pressed() -> void: 
	pending_company_data = selected_company_data
	pending_is_urgent = true
	btn_call_urg.text = "DISQUE O NUMERO ->"
	btn_call_std.text = "PREPARAR CONTRATO"
	current_dialed = ""
	_update_phone_display()




func _on_cutscene_accepted(final_reward: int) -> void:
	var is_urg = pending_is_urgent
	var c_data = pending_company_data
	
	if is_urg:
		GameManager.daily_urgencies.erase(c_data["name"]) 
		
	_spawn_proposal_paper(c_data, is_urg, final_reward)
	
	folder_rect.visible = false
	selected_company_data = {}
	pending_company_data = {}
	
	

func _on_cutscene_rejected() -> void:
	var is_daily = "(Diario)" in pending_company_data["name"]
	if not (is_daily and GameManager.current_day == 1):
		GameManager.company_cooldowns[pending_company_data["name"]] = 7
	_load_agenda_contacts()
	folder_rect.visible = false
	pending_company_data = {}

func _on_cutscene_closed() -> void: 
	_load_agenda_contacts()
	folder_rect.visible = false
	pending_company_data = {}

func _on_cancel_dynamic(idx: int) -> void: 
	var c = GameManager.active_contracts[idx]
	if GameManager.routes_under_construction.get(c["route_id"], 0) > 0:
		phone_cutscene.start_rejection_call("FISCALIZAÇÃO", "O trem está retido na zona de obras! Impossível resgatar a carga ou cancelar o contrato agora. Conclua as obras e espere a via liberar!")
		return
	phone_cutscene.start_cancel_warning(c["company_name"], idx)


func _on_cancel_confirmed(idx: int) -> void:
	if idx >= 0 and idx < GameManager.active_contracts.size():
		var c = GameManager.active_contracts[idx]
		var c_name = c["company_name"]
		
		GameManager.cancel_contract(idx)
		
		var is_daily = "(Diario)" in c_name
		if not (is_daily and GameManager.current_day == 1):
			GameManager.company_cooldowns[c_name] = 7
			
		_load_agenda_contacts()

func _on_radio_choice(idx: int) -> void:
	GameManager.pending_radio_event = false
	
	if phone_cutscene.current_mode == "RADIO_DISASTER":
		pass 
	else:
		if idx == 0:
			GameManager.money -= 150
		else:
			if idx == 1:
				if GameManager.active_contracts.size() > 0:
					GameManager.active_contracts[0]["days_left"] -= 2
			else:
				if idx == 2:
					if randf() > 0.5:
						pass 
					else:
						GameManager.money -= 300 
					
	GameManager.save_game()
	_update_report_text()
	_update_diretrizes()
	_update_task_pad()

func _update_task_pad() -> void:
	for child in task_vbox.get_children():
		child.queue_free()
		
	var items_per_page = 3 # Limita para não estourar a tela
	var total_items = GameManager.active_contracts.size()
	var max_pages = 0
	if total_items > 0:
		max_pages = ceil(total_items / float(items_per_page)) - 1
		
	if clipboard_page > max_pages:
		clipboard_page = max_pages
	if clipboard_page < 0:
		clipboard_page = 0
		
	if total_items == 0:
		var lbl = Label.new()
		lbl.text = "Nenhum contrato ativo no momento.\nO pátio está vazio."
		lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
		lbl.add_theme_font_size_override("font_size", 14)
		task_vbox.add_child(lbl)
		return
		
	var start_idx = clipboard_page * items_per_page
	var end_idx = min(start_idx + items_per_page, total_items)
		
	var i = start_idx
	while i < end_idx:
		var c = GameManager.active_contracts[i]
		var hbox = HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# --- NOVO: O TEXTO AGORA É UM BOTÃO INVISÍVEL E CLICÁVEL ---
		var btn_info = Button.new()
		btn_info.flat = true
		btn_info.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_info.custom_minimum_size = Vector2(300, 0)
		btn_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn_info.add_theme_font_size_override("font_size", 12)
		
		var rid = c.get("route_id", "")
		var is_act = GameManager.is_contract_operating(c)
		var cargo_name = c.get("cargo", "Carga Geral")
		var route_name = c.get("route_name", "Desconhecida")
		var days_left = c.get("days_left", 0)
		
		var st = ""
		var t = "T" + str(i + 1) + " - " + c.get("company_name", "Empresa") + "\nCarga: " + cargo_name + " | Rota: " + route_name + "\nStatus: "
		
		# Mantemos a sua lógica original de verificação de erros exata
		if c.has("pending_route_days"):
			st = "AGUARDANDO VIA (" + str(c["pending_route_days"]) + "d p/ falha)"
			btn_info.add_theme_color_override("font_color", Color.DARK_GOLDENROD)
		else:
			if is_act: 
				if c.get("is_urgent", false):
					st = "OPERACIONAL [PAGO À VISTA]"
				else:
					st = "OPERACIONAL (+$" + str(c.get("reward", 0)) + "/dia)"
				btn_info.add_theme_color_override("font_color", Color.DARK_GREEN)
			else:
				btn_info.add_theme_color_override("font_color", Color.INDIAN_RED)
				if GameManager.routes_under_construction.get(rid, 0) > 0:
					st = "EM OBRAS (" + str(GameManager.routes_under_construction[rid]) + "d restantes)"
				else:
					if not (rid in GameManager.network_connections): 
						st = "SEM ROTA FÍSICA"
					else: 
						var stats = GameManager.network_stats.get(rid, {})
						if stats.get("is_broken", false):
							st = "VIA DESTRUÍDA"
						else:
							var tp = c.get("type", "")
							if tp == "Expresso" and stats.get("dist", 999) > c.get("max_dist", 999):
								st = "PARADO (ROTA LONGA)"
							else:
								if tp == "VIP" and GameManager.active_contracts.size() > 1:
									st = "PARADO (FIM DA EXCLUSIVIDADE)"
								else:
									if tp == "VIP" and stats.get("gangs", 0) > 0:
										st = "PARADO (GANGUES NA LINHA)"
									else:
										if tp == "Ecologico" and stats.get("forests", 0) > 0:
											st = "PARADO (CRIME AMBIENTAL)"
										else:
											st = "PARADO (ILEGAL)"
											
		t += st + "\nRestam: " + str(days_left) + "d\n[ CLIQUE PARA REVISAR ]"
		btn_info.text = t
		
		# Feedback visual ao passar o mouse e conexão do clique
		btn_info.add_theme_color_override("font_hover_color", Color.BLACK)
		btn_info.pressed.connect(_on_active_contract_clicked.bind(i))
		hbox.add_child(btn_info)
		
		var b = Button.new()
		b.text = "X"
		b.custom_minimum_size = Vector2(30, 30)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_color_override("font_color", Color.INDIAN_RED)
		b.pressed.connect(_on_cancel_dynamic.bind(i))
		hbox.add_child(b)
		
		task_vbox.add_child(hbox)
		
		var sep = ColorRect.new()
		sep.custom_minimum_size = Vector2(340, 1)
		sep.color = Color(0.75, 0.75, 0.5)
		task_vbox.add_child(sep)
		
		i += 1

	# --- NOVO: CONTROLES DE PAGINAÇÃO NO FUNDO DA PRANCHETA ---
	if total_items > items_per_page:
		var page_hbox = HBoxContainer.new()
		page_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var btn_prev = Button.new()
		btn_prev.text = "<-"
		btn_prev.custom_minimum_size = Vector2(40, 30)
		btn_prev.disabled = (clipboard_page == 0)
		btn_prev.pressed.connect(_on_clipboard_prev_pressed)
		page_hbox.add_child(btn_prev)
		
		var lbl_page_info = Label.new()
		lbl_page_info.text = " Pág " + str(clipboard_page + 1) + "/" + str(max_pages + 1) + " "
		lbl_page_info.add_theme_color_override("font_color", Color.BLACK)
		page_hbox.add_child(lbl_page_info)
		
		var btn_next = Button.new()
		btn_next.text = "->"
		btn_next.custom_minimum_size = Vector2(40, 30)
		btn_next.disabled = (clipboard_page >= max_pages)
		btn_next.pressed.connect(_on_clipboard_next_pressed)
		page_hbox.add_child(btn_next)
		
		task_vbox.add_child(page_hbox)


func _on_company_selected(data: Dictionary) -> void:
	selected_company_data = data
	folder_title.text = "CLIENTE: " + data["name"]
	folder_route.text = "Exige Rota: " + data["route_name"]
	
	if not data.has("weight"): data["weight"] = randi_range(100, 800)
	if not data.has("duration"): data["duration"] = randi_range(5, 10)
	
	# --- INÍCIO DA ALTERAÇÃO (DOCUMENTO SLA E MAPEAMENTO DE TAGS) ---
	var base_type = data.get("type", "Comum")
	var display_type = base_type
	
	if base_type == "Ganha-Pao":
		display_type = "Convencional (Classe C)"
	if base_type == "Expresso":
		display_type = "Expresso JIT (Just-in-Time)"
	if base_type == "VIP":
		display_type = "Transporte de Alto Risco"
	if base_type == "Ecologico":
		display_type = "Certificação Ambiental (ESG)"
	if base_type == "Licitação Estatal":
		display_type = "Subsídio Governamental"
		
	var cargo_name = data.get("cargo", "Carga Geral")
	var route_id_check = data.get("route_id", "")
	var is_built = route_id_check in GameManager.network_connections
	
	var lore_text = "Abastecimento logístico padrão de rotina."
	if "Madeira" in cargo_name or "Ferro" in cargo_name or "Aco" in cargo_name or "Construcao" in cargo_name:
		lore_text = "Material base requisitado com urgência para sustentar a expansão do pólo industrial da região."
	if "Carvao" in cargo_name or "Cimento" in cargo_name:
		lore_text = "Carga pesada essencial para a manutenção ininterrupta das fornalhas e infraestrutura civil civil."
	if "Ouro" in cargo_name or "Suspeita" in cargo_name or "Joias" in cargo_name:
		lore_text = "Ativo de altíssimo valor agregado. Exige discrição, sigilo corporativo e segurança máxima."
	if "Trigo" in cargo_name or "Sementes" in cargo_name or "Fertilizantes" in cargo_name:
		lore_text = "Insumo biológico perecível e sensível, vital para a estabilidade da cadeia alimentar."
		
	var contract_id = "SLA-" + str(randi_range(1000, 9999)) + "-" + ["A", "B", "C", "X"].pick_random()
	
	std_label.text = "[ TERMO DE ACORDO DE NÍVEL DE SERVIÇO (SLA) ]\n"
	std_label.text += "ID do Contrato: " + contract_id + "\n"
	std_label.text += "Classificação: " + display_type + "\n\n"
	
	std_label.text += "OBJETO E JUSTIFICATIVA:\n"
	std_label.text += "Natureza da Carga: " + cargo_name + "\n"
	std_label.text += "Lore/Contexto: " + lore_text + "\n\n"
	
	std_label.text += "DADOS LOGÍSTICOS:\n"
	std_label.text += "Peso Aferido: " + str(data["weight"]) + " kg (Sujeito à capacidade trativa da frota)\n"
	std_label.text += "Rota Exigida: " + data["route_name"] + "\n"
	
	if is_built:
		std_label.text += "Prazo de Implementação: Imediato (Via já mapeada e operacional).\n\n"
	if not is_built:
		std_label.text += "Prazo de Implementação: MÁXIMO DE 3 DIAS para início das operações (Via em construção ou inexistente).\n\n"
		
	var duration_val = data.get("duration", 5)
	var cancel_fine = int((data.get("base_reward", 0) * duration_val) * 0.20)
	if cancel_fine < 100:
		cancel_fine = 100
		
	
	std_label.text += "TERMOS FINANCEIROS:\n"
	std_label.text += "Duração Vigente: " + str(duration_val) + " a " + str(duration_val + 3) + " dias úteis.\n"
	std_label.text += "Tarifa de Frete: $" + str(data["base_reward"]) + ",00 / dia (Pagos mediante confirmação de entrega).\n"
	
	# --- INÍCIO DA ALTERAÇÃO ---
	var upfront = data.get("upfront_bonus", 0)
	if upfront > 0:
		std_label.text += "SUBSÍDIO DE OBRAS: $" + str(upfront) + ",00 (Liberados à vista na assinatura do contrato).\n"
	# --- FIM DA ALTERAÇÃO ---
		
	std_label.text += "Cláusula de Rescisão: Em caso de rompimento unilateral ou falha de infraestrutura, a contratada arcará com multa rescisória fixada em $" + str(cancel_fine) + ",00.\n\n"
	
	std_label.text += "Contato Direto: " + data["phone"]
	# --- FIM DA ALTERAÇÃO ---
	
	btn_call_std.text = "PREPARAR CONTRATO"
	btn_call_std.visible = true 
	
	if GameManager.daily_urgencies.has(data["name"]):
		doc_urgent.visible = true
		
		urg_label.text = "[ TERMO DE ACORDO DE NÍVEL DE SERVIÇO (SLA) ]\n"
		urg_label.text += "Classificação: OPERAÇÃO DE URGÊNCIA MÁXIMA\n\n"
		
		urg_label.text += "OBJETO DA OPERAÇÃO:\n"
		urg_label.text += "Natureza da Carga: " + data["cargo"] + " (" + str(data["weight"]) + " Kg)\n\n"
		
		urg_label.text += "DADOS LOGÍSTICOS & FINANCEIROS:\n"
		urg_label.text += "Prazo de Implementação: IMEDIATO (Máximo de 1 Dia Útil)\n"
		urg_label.text += "Liquidação à Vista: $" + str(GameManager.daily_urgencies[data["name"]]) + ",00 (Garantido no ato da assinatura)\n\n"
		
		urg_label.text += "[ ALERTA DO DEPARTAMENTO JURÍDICO ]\nO não cumprimento deste prazo resultará em multas severas e na suspensão imediata das relações comerciais com o cliente.\n\n"
		
		urg_label.text += "Contato Direto: " + data["phone"]
		btn_call_urg.text = "PREPARAR URGÊNCIA"
	else: 
		doc_urgent.visible = false
		
	folder_rect.visible = true
	folder_rect.get_parent().move_child(folder_rect, -1)
	folder_rect.rotation_degrees = 0
	_clamp_to_screen(folder_rect)


func _spawn_proposal_paper(c_data: Dictionary, is_urg: bool, reward: int) -> void:
	var paper = ColorRect.new()
	
	if is_urg:
		paper.color = Color(0.95, 0.8, 0.8) 
	else:
		paper.color = Color(0.95, 0.95, 0.85) 
		
	paper.size = Vector2(340, 480)
	paper.pivot_offset = paper.size / 2.0 
	paper.position = Vector2(800 + randf_range(-30, 30), 200 + randf_range(-30, 30))
	paper.rotation_degrees = randf_range(-5, 5)

	# --- INÍCIO DA ALTERAÇÃO (CORREÇÃO DO CARIMBO E SCROLL) ---
	
	# O nó 'content' é a camada invisível obrigatória onde a caneta e os carimbos "pintam".
	var content = Control.new()
	content.name = "content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(15, 20)
	scroll.size = paper.size - Vector2(30, 40)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	# A ORDEM IMPORTA: O scroll fica no fundo para rolar o texto, o content fica por cima para segurar os carimbos.
	paper.add_child(scroll)
	paper.add_child(content)

	var text_lbl = Label.new()
	text_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12)) # Tom de tinta de impressora
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.custom_minimum_size = Vector2(scroll.size.x - 15, 0)
	scroll.add_child(text_lbl)

	var comp_name = c_data.get("company_name", c_data.get("name", "Empresa Desconhecida"))
	# --- FIM DA ALTERAÇÃO ---
	var cargo_name = c_data.get("cargo", "Carga Geral")
	var route_name = c_data.get("route_name", "Rota Não Especificada")
	var raw_type = c_data.get("type", "Comum")
	var c_weight = str(c_data.get("weight", 0))

	var display_type = raw_type
	if raw_type == "Ganha-Pao": display_type = "Convencional (Classe C)"
	if raw_type == "Expresso": display_type = "Expresso JIT"
	if raw_type == "VIP": display_type = "Alto Risco"
	if raw_type == "Ecologico": display_type = "Certificação ESG"
	if raw_type == "Licitação Estatal": display_type = "Subsídio Governamental"

	var lore_text = "Abastecimento logístico padrão."
	if "Madeira" in cargo_name or "Ferro" in cargo_name or "Aco" in cargo_name or "Construcao" in cargo_name:
		lore_text = "Insumos para expansão industrial e obras civis."
	if "Carvao" in cargo_name or "Cimento" in cargo_name:
		lore_text = "Carga pesada para manutenção de infraestrutura crítica."
	if "Ouro" in cargo_name or "Suspeita" in cargo_name or "Joias" in cargo_name:
		lore_text = "Ativo de alto valor. Risco de interceptação elevado."
	if "Trigo" in cargo_name or "Sementes" in cargo_name or "Fertilizantes" in cargo_name:
		lore_text = "Insumo biológico sensível para cadeia alimentar."

	var text = "==============================\n"
	text += "   AUTORIZAÇÃO DE DESPACHO\n"
	text += "==============================\n\n"
	text += "CONTRATANTE: " + comp_name + "\n"
	text += "CARGA: " + cargo_name + " (" + c_weight + " Kg)\n"
	text += "CONTEXTO: " + lore_text + "\n"
	text += "ROTA EXIGIDA: " + route_name + "\n\n"
	
	if is_urg:
		text += "[ CLASSIFICAÇÃO: URGÊNCIA MÁXIMA ]\n"
		text += "Nível de Prioridade: Crítica (Risco de Quebra de Cadeia Logística)\n"
		text += "Prazo Limite: IMEDIATO (1 Dia Útil para Conclusão)\n"
		text += "Liquidação Financeira: $" + str(reward) + ",00 (Garantida no Ato do Despacho)\n\n"
		text += "ADVERTÊNCIA: O não cumprimento deste prazo resultará no rompimento das relações institucionais e em multas severas.\n\n"
	if not is_urg:
		text += "[ CLASSIFICAÇÃO: " + display_type + " ]\n"
		text += "Duração Vigente: " + str(c_data.get("duration", 5)) + " a " + str(c_data.get("duration", 10) + 3) + " Dias\n"
		text += "Faturamento Diário: $" + str(reward) + ",00\n"
		
		# --- INÍCIO DA ALTERAÇÃO ---
		var upfront = c_data.get("upfront_bonus", 0)
		if upfront > 0:
			text += "Subvenção Estatal à Vista: $" + str(upfront) + ",00\n"
		text += "\n"
		# --- FIM DA ALTERAÇÃO ---

	text += "CLÁUSULA DE RESPONSABILIDADE:\n"
	text += "A Cia. de Entregas Ferroviárias assume custódia integral sobre a carga (" + c_weight + " Kg). Extravios ou falhas de malha incorrerão em multas contratuais.\n\n"
	
	if pending_is_risk:
		text += "[ ALERTA JURÍDICO ]\nVia inexistente/incompleta. O prazo de implementação máximo é de 3 dias úteis.\n\n"
	if not pending_is_risk:
		text += "Status da Malha: Operacional.\n\n"
		
	text += "ESPAÇO PARA CARIMBO OFICIAL:\n\n\n\n"
	text += "_______________________________\n"
	text += "Assinatura do Despachante Autorizado\n\n"
	text += "(Aguardando validação com carimbo 'SELO CIA' ou 'REJEITAR' para processamento.)"
	
	text_lbl.text = text
	# --- FIM DA ALTERAÇÃO TEXTUAL ---

	paper.set_meta("is_paper", true)
	
	# --- CORREÇÃO GRAVE: REPOSIÇÃO DOS METADADOS VITAIS ---
	paper.set_meta("is_extension", false)
	paper.set_meta("company_data", c_data)
	paper.set_meta("is_urgent", is_urg)
	paper.set_meta("reward", reward)
	paper.set_meta("is_risk", pending_is_risk)
	paper.set_meta("action", "")
	# -------------------------------------------------------

	_make_draggable(paper, "paper")
	
	if has_method("_add_ball_visual"):
		_add_ball_visual(paper)

	ui_layer.add_child(paper)
	spawned_papers.append(paper)
	
	if has_method("_load_agenda_contacts"):
		_load_agenda_contacts()


func _spawn_blueprint_form() -> void:
	var paper = ColorRect.new()
	paper.color = Color(0.65, 0.75, 0.85) 
	paper.size = Vector2(360, 560) 
	paper.pivot_offset = paper.size / 2.0 
	paper.position = Vector2(400 + randf_range(-30, 30), 200 + randf_range(-30, 30))
	paper.rotation_degrees = randf_range(-4, 4)

	var content = Control.new()
	content.name = "content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(content)

	var content_lbl = Label.new()
	content_lbl.add_theme_color_override("font_color", Color.BLACK)
	content_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	var bp = GameManager.pending_blueprint
	
	var page1 = "PROJETO DE ENGENHARIA [Pág 1/2]\n"
	page1 += "=========================\n\n"
	page1 += "TIPO DE OBRA: " + bp.get("proj_type", "Indefinido") + "\n"
	page1 += "ROTA AFETADA:\n" + bp.get("route_description", "Manutenção Geral") + "\n"
	page1 += "PREVISÃO DE ENTREGA: " + str(bp.get("est_days", 1)) + " dias úteis\n\n"
	page1 += "► ORÇAMENTO DA OBRA\n"
	page1 += "Custo Base: $" + str(bp.get("net_cost", 0)) + "\n"
	if bp.get("tax_env", 0) > 0: 
		page1 += "Licença Ambiental: $" + str(bp["tax_env"]) + "\n"
	if bp.get("tax_eng", 0) > 0: 
		page1 += "Licença Engenharia: $" + str(bp["tax_eng"]) + "\n"
	if bp.get("tax_sec", 0) > 0: 
		page1 += "Taxa Seg. Armada: $" + str(bp["tax_sec"]) + "\n"
	page1 += "-------------------------\n"
	page1 += "TOTAL A PAGAR: $" + str(bp.get("total_cost", 0)) + "\n\n"
	
	var page2 = "PROJETO DE ENGENHARIA [Pág 2/2]\n"
	page2 += "=========================\n\n"
	var total_cells = bp.get("dist", 0)
	page2 += "► ESPECIFICAÇÕES TÉCNICAS\n"
	page2 += "Extensão Linear: " + str(total_cells * 15) + " km\n"
	page2 += "Túneis Projetados: " + str(bp.get("tunnels", 0)) + "\n"
	page2 += "Pontes de Sustentação: " + str(bp.get("bridges", 0)) + "\n"
	page2 += "Manutenção Estimada: $" + str(total_cells * 25) + "/dia\n\n"
	page2 += "► RELATÓRIO DE IMPACTO\n"
	page2 += "Zonas Florestais Desmatadas: " + str(bp.get("forests", 0)) + "\n"
	page2 += "Zonas de Conflito Armado: " + str(bp.get("gangs", 0)) + "\n\n"
	page2 += "(Assine e deposite o documento na Bandeja de Saída para aprovar)"
	
	content_lbl.text = page1
	content_lbl.set_meta("page", 1)
	content_lbl.set_meta("page1_text", page1)
	content_lbl.set_meta("page2_text", page2)
	
	content_lbl.size = Vector2(320, 450)
	content_lbl.position = Vector2(20, 20)
	content.add_child(content_lbl)

	var btn_page = Button.new()
	btn_page.text = "[ -> ]"
	btn_page.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2)) 
	btn_page.size = Vector2(80, 40)
	btn_page.position = Vector2(20, 500)
	btn_page.add_theme_font_size_override("font_size", 16)
	btn_page.pressed.connect(_on_blueprint_page_toggle.bind(content_lbl, btn_page))
	content.add_child(btn_page)

	var btn_trash = Button.new()
	btn_trash.text = "[ DESCARTAR ]"
	btn_trash.size = Vector2(160, 40)
	btn_trash.position = Vector2(180, 500)
	btn_trash.add_theme_color_override("font_color", Color.INDIAN_RED)
	btn_trash.add_theme_font_size_override("font_size", 14)
	btn_trash.pressed.connect(_on_trash_blueprint_pressed.bind(paper))
	content.add_child(btn_trash)

	paper.set_meta("is_paper", true)
	paper.set_meta("is_blueprint", true)
	paper.set_meta("action", "")

	_make_draggable(paper, "paper")
	_add_ball_visual(paper)

	ui_layer.add_child(paper)
	spawned_papers.append(paper)


func _on_blueprint_page_toggle(lbl: Label, btn: Button) -> void:
	var p = lbl.get_meta("page")
	if p == 1:
		lbl.text = lbl.get_meta("page2_text")
		lbl.set_meta("page", 2)
		btn.text = "[ Ver Página 1 ]"
	elif p == 2:
		lbl.text = lbl.get_meta("page1_text")
		lbl.set_meta("page", 1)
		btn.text = "[ Ver Página 2 ]"

func _update_report_text() -> void:
	var inc = GameManager.get_daily_income()
	var exp = GameManager.daily_maintenance + GameManager.BASE_COST + GameManager.daily_gang_toll + GameManager.daily_crew_cost + GameManager.daily_lobby_cost + GameManager.daily_parcel_train_cost
	var net = inc - exp
	
	var t = "RELATÓRIO ADMINISTRATIVO\n\nDia: " + str(GameManager.current_day) + "\nCaixa: $" + str(GameManager.money) + "\n\nReceita: +$" + str(inc) + "\nManutenção da Via: -$" + str(GameManager.daily_maintenance) + "\nTaxas e Base: -$" + str(GameManager.BASE_COST)
	
	# NOVO: O Trem aparecendo no relatório da mesa
	t += "\nTrem de Encomendas: -$" + str(GameManager.daily_parcel_train_cost)
	
	if GameManager.daily_crew_cost > 0:
		t += "\nSalários (Equipe): -$" + str(GameManager.daily_crew_cost)
	if GameManager.daily_lobby_cost > 0:
		t += "\nLobby/Estado: -$" + str(GameManager.daily_lobby_cost)
	if GameManager.daily_gang_toll > 0: 
		t += "\nPropinas (Gangues): -$" + str(GameManager.daily_gang_toll)
		
	t += "\n----------------\nLucro: $" + str(net)
	report_label.text = t
	
	# --- NOVO: TRAVA DE EXPEDIENTE (ANTI-SOFTLOCK) ---
	btn_next_day.disabled = false
	if GameManager.day_phase == 1:
		btn_next_day.text = "Aprovar Contratos e Iniciar Turno da Tarde"
		
	if GameManager.day_phase == 2:
		var has_cargo = false
		for train in GameManager.fleet:
			if train["loaded_packages"].size() > 0:
				has_cargo = true
				
		if has_cargo:
			btn_next_day.disabled = true
			btn_next_day.text = "[ VÁ PARA O MAPA DESPACHAR OS TRENS ]"
		if not has_cargo:
			btn_next_day.text = "Processar Saídas e Finalizar Dia"
			
	if GameManager.day_phase == 0:
		btn_next_day.text = "Processar Saídas e Finalizar Dia"

func _on_next_day_pressed() -> void:
	if phone_cutscene and phone_cutscene.visible: return
	if GameManager.pendent_angry_call: return
	
	var has_operating = false
	var has_building = false
	for c in GameManager.active_contracts:
		if GameManager.is_contract_operating(c): has_operating = true
		if GameManager.routes_under_construction.get(c["route_id"], 0) > 0: has_building = true
		
	var income = 0
	var ext_c = 0
	var bp_cost = 0
	var new_c = 0
	var rej_c = 0
	var shark_income = 0

	for p in spawned_papers:
		if not is_instance_valid(p): continue
		
		# 1. Conta rejeições (Se a ação for reject, ignoramos todo o resto)
		if p.has_meta("action") and p.get_meta("action") == "reject":
			rej_c += 1
			continue
			
		# 2. Processa a Extensão de Prazo e Renovações
		if p.has_meta("is_extension") and p.get_meta("is_extension"):
			if p.has_meta("action") and p.get_meta("action") == "approve":
				var s_idx = p.get_meta("selected_idx", -1)
				if s_idx >= 0 and s_idx < GameManager.active_contracts.size():
					var c = GameManager.active_contracts[s_idx]
					var rtype = p.get_meta("renewal_type", "penalty")
					
					if rtype == "penalty":
						var cost = p.get_meta("cost", 0)
						if GameManager.money >= cost:
							GameManager.money -= cost
							c["days_left"] += 5
							c["delayed_days"] = 0
							ext_c += 1
					elif rtype == "loyalty":
						c["days_left"] += 10
						c["reward"] = int(c["reward"] * 0.8)
						c["delayed_days"] = 0
						ext_c += 1
					elif rtype == "express_upgrade":
						var bonus_days = c.get("duration", 5) + 5
						c["days_left"] += bonus_days
						c["reward"] = int(c["reward"] * 1.4)
						c["type"] = "Expresso"
						c["max_dist"] = p.get_meta("new_max_dist", 20)
						c["delayed_days"] = 0
						ext_c += 1
						
					c.erase("renewal_type")
					
		# 3. Processa a Planta de Obras
		elif p.has_meta("is_blueprint") and p.get_meta("is_blueprint"):
			if p.has_meta("action") and p.get_meta("action") == "approve":
				var bp = GameManager.pending_blueprint
				var cd = bp.get("routes_to_cooldown", [])
				
				bp_cost += bp.get("total_cost", 0)
				GameManager.money -= bp.get("total_cost", 0)
				
				for route_id in cd:
					GameManager.company_cooldowns[route_id] = 5
					var base_days = bp.get("est_days", 1) 
					GameManager.routes_under_construction[route_id] = base_days + 1
					
				GameManager.saved_routes.append_array(bp.get("draft_paths", []))
				var keep_routes = []
				for old_r in GameManager.saved_routes:
					var is_del = false
					for del_r in bp.get("deleted_paths", []):
						if _are_routes_equal(old_r, del_r): is_del = true
					if not is_del: keep_routes.append(old_r)
				GameManager.saved_routes = keep_routes
				
				var new_broken = []
				for bt in GameManager.broken_tiles:
					if not bp.get("repair_tiles", []).has(bt): new_broken.append(bt)
				GameManager.broken_tiles = new_broken
				GameManager.pending_blueprint.clear()
		
		# 4. Processa o Contrato do Agiota
		elif p.has_meta("is_shark") and p.get_meta("is_shark"):
			if p.has_meta("action") and p.get_meta("action") == "approve":
				shark_income = 1500
				income += 1500
				GameManager.has_loan_shark = true
				GameManager.loan_shark_days_left = 20
				GameManager.shark_declined = false
			else:
				GameManager.shark_declined = true			
		
		# 5. Processa os Contratos de Carga
		elif p.has_meta("action") and p.get_meta("action") == "approve":
			if p.has_meta("company_data") and typeof(p.get_meta("company_data")) == TYPE_DICTIONARY:
				new_c += 1
				var c_data = p.get_meta("company_data")
				var is_urg = p.get_meta("is_urgent", false)
				var reward = p.get_meta("reward", 0)
				var is_risk = p.get_meta("is_risk", false)
				
				var comp_name = c_data.get("company_name", c_data.get("name", "Empresa Desconhecida"))
				var route_id = c_data.get("route_id", "0")
				var c_type = c_data.get("type", "Comum")
				var cargo_name = c_data.get("cargo", "Carga Geral")
				var duration_est = c_data.get("duration", 5) 
				# --- NOVO: SALVANDO DADOS VITAIS NO CONTRATO B2B ---
				var new_contract = {
					"company_name": comp_name,
					"route_id": route_id,
					"route_name": c_data.get("route_name", "Qualquer Rota"),
					"type": c_type,
					"cargo": cargo_name,
					"weight": float(c_data.get("weight", 400.0)),
					"reward": reward,
					"duration": duration_est
				}
				
				if is_urg:
					new_contract["is_urgent"] = true
					income += reward 
					new_contract["days_left"] = 1
					GameManager.active_contracts.append(new_contract)
				if not is_urg:
					# --- INÍCIO DA ALTERAÇÃO (RECEBENDO O SUBSÍDIO) ---
					income += c_data.get("upfront_bonus", 0)
					# --- FIM DA ALTERAÇÃO ---
					
					new_contract["days_left"] = randi_range(duration_est, duration_est + 5)
					GameManager.active_contracts.append(new_contract)
					
				if is_risk:
					new_contract["pending_route_days"] = c_data.get("temp_wait_days", 3)
					
				GameManager.company_cooldowns[route_id] = 4
				
				
				# --------------------------------------------------

	# === Fim do Processamento dos Papéis ===
	for p in spawned_papers:
		if is_instance_valid(p): p.queue_free()
	spawned_papers.clear()
	
	current_agenda_contacts.clear()
	current_agenda_page = 0
	
	# --- INÍCIO DA ALTERAÇÃO 2 (SOMANDO NO ACUMULADOR) ---
	pending_upfront_income += income # Usa += para não perder o que já tinha
	daily_new_c += new_c
	daily_rej_c += rej_c
	daily_ext_c += ext_c
	daily_bp_cost += bp_cost
	daily_shark_income += shark_income
	daily_upfront_income += income
	# --- FIM DA ALTERAÇÃO 2 ---
	
	# --- NOVO: GERAÇÃO DIÁRIA DE CAIXAS PARA A TARDE (FASE 2) ---
	if GameManager.day_phase == 1:
		GameManager.day_phase = 2
		GameManager.money += pending_upfront_income
		pending_upfront_income = 0
		
		# GERA OS PACOTES B2B DE TODOS OS CONTRATOS ATIVOS
		for c in GameManager.active_contracts:
			if GameManager.is_contract_operating(c):
				var b2b_pkg = {
					"id": randi(),
					"true_category": "Lote B2B",
					"true_item": c.get("cargo", "Carga Geral") + " (" + c.get("company_name", "Empresa") + ")",
					"true_weight": c.get("weight", 400.0),
					"true_stamp": "Selo Azul",
					"is_contraband": false,
					"declared_category": "Lote B2B",
					"declared_item": c.get("cargo", "Carga Geral") + " (" + c.get("company_name", "Empresa") + ")",
					"declared_weight": c.get("weight", 400.0),
					"stamp_used": "Selo Azul",
					"days_in_queue": 0,
					"base_reward": c.get("reward", 0),
					"reward": c.get("reward", 0),
					"destination": c.get("route_name", "Qualquer Rota")
				}
				GameManager.package_queue.append(b2b_pkg)
				
		_update_report_text()
		
		# --- NOVO: DESPEJA O ARMAZÉM NO FIM DA FILA DA ESTEIRA ---
		if GameManager.warehouse.size() > 0:
			GameManager.package_queue.append_array(GameManager.warehouse.duplicate())
			GameManager.warehouse.clear()
		# ---------------------------------------------------------
		
		# Força o jogador a ir para a triagem
		var main_node = get_parent()
		if main_node.has_method("go_to_inspection"):
			main_node.go_to_inspection()
		return
	# ---------------------------------------------
	
	# --- INÍCIO DA ALTERAÇÃO 3 ---
	_start_eod_animation(daily_new_c, daily_rej_c, daily_ext_c, daily_bp_cost, daily_shark_income)
	# --- FIM DA ALTERAÇÃO 3 ---
	
	
	
	
func _on_visibility_changed() -> void:
	if ui_layer: 
		ui_layer.visible = visible
	if visible:
		var active_papers = []
		for p in spawned_papers:
			if is_instance_valid(p):
				active_papers.append(p)
		spawned_papers = active_papers

		_load_agenda_contacts()
		_update_report_text()
		_update_diretrizes()
		_update_task_pad()
		_update_calendar() # FASE 3: Garante que o calendário desenha as datas!
		folder_rect.visible = false 
		
		_on_organize_pressed()
		
		_update_tokens_visual()
		
		# --- INÍCIO DA ALTERAÇÃO 5: Sincroniza ao voltar pra mesa ---
		_on_package_queue_updated(GameManager.package_queue.size())
		# --- FIM DA ALTERAÇÃO 5 ---
		
		var has_bp = false
		var has_tut1 = false
		var has_tut2 = false
		var has_ext_note = false
		
		for p in spawned_papers:
			if p.has_meta("is_blueprint") and p.get_meta("is_blueprint"): has_bp = true
			if p.has_meta("is_tutorial_1"): has_tut1 = true
			if p.has_meta("is_tutorial_2"): has_tut2 = true
			if p.has_meta("is_ext_note"): has_ext_note = true
				
		if not GameManager.pending_blueprint.is_empty() and not has_bp:
			_spawn_blueprint_form()
			
		if GameManager.current_day == 1 and not GameManager.is_first_route_built and not has_tut1:
			_spawn_tutorial_paper(1)
			
		if GameManager.boss_package_intro_done and not has_tut2 and GameManager.current_day <= 3:
			_spawn_tutorial_paper(2)
			
		var needs_extension = false
		for c in GameManager.active_contracts:
			if not c.has("pending_route_days") and c["days_left"] == 1:
				needs_extension = true
				
		if is_instance_valid(pad_extension):
			pad_extension.visible = needs_extension
			
		if needs_extension and not has_ext_note:
			_spawn_extension_warning_note()
		
		if GameManager.broken_tiles.size() > 0:
			GameManager.pending_radio_event = true
		
		if GameManager.pendent_angry_call: 
			GameManager.pendent_angry_call = false
			phone_cutscene.start_angry_call()
		elif not GameManager.pending_fiscal_event.is_empty():
			phone_cutscene.start_fiscal_audit(GameManager.pending_fiscal_event)
		elif GameManager.pending_boss_package_call and not GameManager.boss_package_intro_done:
			GameManager.pending_boss_package_call = false
			GameManager.boss_package_intro_done = true
			phone_cutscene.start_boss_package_call()
		elif GameManager.pending_shark_call and not GameManager.shark_declined and not GameManager.has_loan_shark:
			GameManager.pending_shark_call = false
			if phone_cutscene.has_method("start_loan_shark_call"):
				phone_cutscene.start_loan_shark_call()
		elif not GameManager.intro_played:
			GameManager.intro_played = true
			phone_cutscene.start_boss_intro()




func _are_routes_equal(r1: Array, r2: Array) -> bool:
	if r1.size() != r2.size(): return false
	for i in range(r1.size()):
		if r1[i] != r2[i]: return false
	return true

func _start_eod_animation(new_c: int, rej_c: int, ext_c: int, bp_cost: int, shark_income: int = 0) -> void:
	skip_eod_anim = false
	eod_layer.visible = true
	btn_eod_sleep.visible = false
	
	for child in eod_lines_container.get_children():
		child.queue_free()
		
	var c_light = Color(0.8, 0.8, 0.8)
	var c_gray = Color(0.5, 0.5, 0.5)
	var c_green = Color(0.2, 0.8, 0.2)
	var c_red = Color(0.8, 0.2, 0.2)
	
	_add_eod_line("== BOLETIM DIÁRIO - DIA " + str(GameManager.current_day) + " ==", "", c_light, true)
	_add_eod_line("", "", c_light, false)
	_add_eod_line("[ LOGÍSTICA ]", "", c_gray, false)
	
	var active_count = 0
	for c in GameManager.active_contracts:
		if GameManager.is_contract_operating(c):
			active_count += 1
			
	_add_eod_line("Contratos Operando", str(active_count), c_light, false)
	_add_eod_line("Novos Contratos", str(new_c), c_light, false)
	_add_eod_line("Prazos Estendidos", str(ext_c), c_light, false)
	_add_eod_line("Propostas Rejeitadas", str(rej_c), c_light, false)
	_add_eod_line("Contratos Rompidos", str(GameManager.today_broken_contracts), c_light, false)
	
	if GameManager.today_penalties > 0:
		_add_eod_line("Multas Aplicadas Hoje", "-$" + str(GameManager.today_penalties), c_red, false)
		
	_add_eod_line("", "", c_light, false)
	_add_eod_line("[ FINANÇAS ]", "", c_gray, false)
	# --- INÍCIO DA ALTERAÇÃO 4.A (LENDO O ACUMULADOR DE DINHEIRO) ---
	var contract_income = daily_upfront_income - shark_income
	if contract_income > 0:
		_add_eod_line("Receitas à Vista", "+$" + str(contract_income), c_green, false)
		
	if shark_income > 0:
		_add_eod_line("Empréstimo (Agiota)", "+$" + str(shark_income), c_green, false)
	# --- FIM DA ALTERAÇÃO 4.A ---
		
	var inc = GameManager.get_daily_income()
	if inc > 0:
		_add_eod_line("Receita de Fretes", "+$" + str(inc), c_green, false)
		
	if bp_cost > 0:
		_add_eod_line("Obras e Licenciamentos", "-$" + str(bp_cost), c_red, false)
		
	if GameManager.daily_maintenance > 0:
		_add_eod_line("Manutenção da Via", "-$" + str(GameManager.daily_maintenance), c_red, false)
		
	_add_eod_line("Custos Base da Garagem", "-$" + str(GameManager.BASE_COST), c_red, false)
	
	# NOVO: O Trem aparecendo no Fim de Dia!
	_add_eod_line("Trem de Encomendas", "-$" + str(GameManager.daily_parcel_train_cost), c_red, false)
	
	if GameManager.daily_crew_cost > 0:
		_add_eod_line("Salários da Equipe", "-$" + str(GameManager.daily_crew_cost), c_red, false)
	if GameManager.daily_lobby_cost > 0:
		_add_eod_line("Lobby Governamental", "-$" + str(GameManager.daily_lobby_cost), c_red, false)
	if GameManager.daily_gang_toll > 0:
		_add_eod_line("Extorsão (Gangues)", "-$" + str(GameManager.daily_gang_toll), c_red, false)
		
	if GameManager.has_loan_shark:
		_add_eod_line("Parcela Fixa (Agiota)", "-$150", c_red, false)
		
	_add_eod_line("-----------------------", "---------", c_gray, false)
	
	# NOVO: A matemática visual atualizada
	var final_money = GameManager.money + pending_upfront_income + inc - GameManager.daily_maintenance - GameManager.BASE_COST - GameManager.daily_parcel_train_cost - GameManager.daily_gang_toll - GameManager.daily_crew_cost - GameManager.daily_lobby_cost
	
	if GameManager.has_loan_shark:
		final_money -= 150
		
	var final_color = c_green
	if final_money < 0:
		final_color = c_red
		
	_add_eod_line("SALDO PROJETADO", "$" + str(final_money), final_color, false)
	
	if GameManager.money < 0:
		_add_eod_line("[!] AVISO: SALDO NEGATIVO! [!] ", "", c_red, true)
		_add_eod_line("A empresa falirá em -$2000!", "", c_red, true)
	
	for line in eod_lines_container.get_children():
		line.visible = false
		
	_play_eod_lines()


func _play_eod_lines() -> void:
	for line in eod_lines_container.get_children():
		if not is_instance_valid(line):
			continue
			
		if skip_eod_anim:
			line.visible = true
		else:
			line.visible = true
			await get_tree().create_timer(0.3).timeout
			
	if is_instance_valid(btn_eod_sleep):
		btn_eod_sleep.visible = true

func _add_eod_line(left: String, right: String, color: Color, is_title: bool) -> void:
	var hbox = HBoxContainer.new()
	var lbl_l = Label.new()
	lbl_l.text = left
	lbl_l.add_theme_color_override("font_color", color)
	lbl_l.add_theme_font_size_override("font_size", 22)
	lbl_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if is_title:
		lbl_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	hbox.add_child(lbl_l)
	
	if right != "":
		var lbl_r = Label.new()
		lbl_r.text = right
		lbl_r.add_theme_color_override("font_color", color)
		lbl_r.add_theme_font_size_override("font_size", 22)
		hbox.add_child(lbl_r)

	eod_lines_container.add_child(hbox)
	
	
	
	
# --- INÍCIO: Lógica do Alerta Giratório ---
func _on_package_queue_updated(count: int) -> void:
	if not is_instance_valid(alert_container): return
	
	if count > 0 and GameManager.day_phase == 0:
		alert_container.visible = true
		alert_label.text = "URGENTE: " + str(count) + " CAIXAS NA ESTEIRA!"
	else:
		alert_container.visible = false
# --- FIM: Lógica do Alerta Giratório ---

func _on_eod_sleep_pressed() -> void:
	eod_layer.visible = false
	GameManager.end_day(pending_upfront_income)
	
	pending_upfront_income = 0
	daily_new_c = 0
	daily_rej_c = 0
	daily_ext_c = 0
	daily_bp_cost = 0
	daily_shark_income = 0
	daily_upfront_income = 0
	
	_update_tokens_visual()
	_update_calendar()
	_on_organize_pressed()
	
	# --- INÍCIO DA ALTERAÇÃO: ABRE O JORNAL AO INVÉS DE DEIXAR A MESA LIVRE ---
	_show_newspaper()
	# --- FIM DA ALTERAÇÃO ---

func _on_eod_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				skip_eod_anim = true

func _on_stats_changed(_v) -> void: 
	_update_report_text()
	_update_diretrizes()
	_update_task_pad()

func _on_contracts_updated() -> void: 
	_update_report_text()
	_load_agenda_contacts() 
	_update_task_pad()

func _on_day_changed(_v) -> void: 
	_update_report_text()
	_load_agenda_contacts() 
	_update_task_pad()

func _on_back_map_pressed() -> void: 
	get_parent().go_to_map()


func _on_fiscal_choice(is_bribe: bool, cost: int) -> void:
	GameManager.is_fiscal_calling = false # <--- A TRAVA DO FISCAL É LIBERTADA AQUI
	GameManager.money -= cost
	GameManager.today_penalties += cost # Para aparecer no relatório do dia
	
	# Se for multa oficial, pune também a moral dos clientes
	if not is_bribe:
		var c_name = GameManager.pending_fiscal_event["contract_name"]
		GameManager.company_cooldowns[c_name] = 3
	
	GameManager.pending_fiscal_event.clear()
	GameManager.save_game()
	
	_update_report_text()
	_update_diretrizes()
	_update_task_pad()
	
	
func _spawn_tutorial_paper(type: int) -> void:
	var paper = ColorRect.new()
	paper.color = Color(0.95, 0.95, 0.8)
	paper.size = Vector2(320, 400)
	paper.pivot_offset = paper.size / 2.0
	paper.position = Vector2(500 + randf_range(-20, 20), 300 + randf_range(-20, 20))
	paper.rotation_degrees = randf_range(-3, 3)

	var content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(content)

	var lbl = Label.new()
	lbl.add_theme_color_override("font_color", Color.BLACK)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.position = Vector2(20, 20)
	lbl.size = paper.size - Vector2(40, 40)

	if type == 1:
		# --- INÍCIO DA ALTERAÇÃO: TEXTO DO PAPEL TUTORIAL ---
		lbl.text = "DIRETRIZES DE OPERAÇÃO - DIA 1\n\nBem-vindo à Diretoria.\n\nPASSOS PARA HOJE:\n1. Escolha um cliente em 'Arquivo de Clientes'.\n2. Clique em 'Preparar Contrato' e disque o telefone.\n3. Vá ao Mapa (<-), clique em Modo Obras e ligue as estações Estação A <-> Estação B e clique em Gerar planta.\n4. Na mesa, arraste a Caneta e o Carimbo sobre o Termo e o Projeto para aprovar, coloque os Documentos na bandeja de saída e finalize o dia!"
		# --- FIM DA ALTERAÇÃO ---
		paper.set_meta("is_tutorial_1", true)
		
	# --- INÍCIO DA ALTERAÇÃO: CORREÇÃO ESTRUTURAL DA GODOT ---
	if type == 2:
	# --- FIM DA ALTERAÇÃO ---
		lbl.text = "DIRETRIZES DE TRIAGEM\n\nSua rota está pronta! A partir de agora, pacotes chegarão na Estação de Triagem.\n\n- Vá para a Triagem e chame pacotes.\n- Verifique o peso na balança.\n- Use o Raio-X se desconfiar.\n- Se o peso ou o selo estiverem errados, REJEITE.\n- Cuidado com o Temporizador! O trem parte em breve."
		paper.set_meta("is_tutorial_2", true)

	content.add_child(lbl)
	paper.set_meta("is_paper", true)
	paper.set_meta("action", "")
	_make_draggable(paper, "paper")
	_add_ball_visual(paper)
	ui_layer.add_child(paper)
	spawned_papers.append(paper)





func _spawn_extension_warning_note() -> void:
	var note = ColorRect.new()
	note.color = Color(0.9, 0.5, 0.5)
	note.size = Vector2(220, 150)
	note.position = Vector2(700, 200)
	note.rotation_degrees = -5

	var lbl = Label.new()
	lbl.text = "AVISO DO CHEFE:\nUm dos nossos contratos termina amanhã! Avalie a situação da via e pegue o Formulário de Extensão (no bloco à esquerda) para ver a proposta do cliente."
	lbl.add_theme_color_override("font_color", Color.BLACK)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.position = Vector2(10, 10)
	lbl.size = Vector2(200, 130)
	note.add_child(lbl)

	note.set_meta("is_paper", true)
	note.set_meta("is_ext_note", true)
	note.set_meta("action", "")
	_make_draggable(note, "paper")
	ui_layer.add_child(note)
	spawned_papers.append(note)




# === FASE 3: LÓGICA DO FICHÁRIO E CALENDÁRIO ===

func _on_doc_input(event: InputEvent, doc: ColorRect) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		doc.get_parent().move_child(doc, doc.get_parent().get_child_count() - 1)

func _on_prev_page_pressed() -> void:
	if current_agenda_page > 0:
		current_agenda_page -= 1
		_render_agenda_page()

func _on_next_page_pressed() -> void:
	var max_pages = ceil(current_agenda_contacts.size() / 4.0) - 1
	if current_agenda_page < max_pages:
		current_agenda_page += 1
		_render_agenda_page()

func _update_calendar() -> void:
	for child in calendar_rect.get_children():
		if child.name != "clip": child.queue_free() 
		
	var title = Label.new()
	title.text = "CALENDÁRIO (Dia " + str(GameManager.current_day) + ")"
	title.add_theme_color_override("font_color", Color.BLACK)
	title.add_theme_font_size_override("font_size", 12)
	title.position = Vector2(10, 20)
	calendar_rect.add_child(title)
	
	var grid = GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(10, 45)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	calendar_rect.add_child(grid)
	
	for i in range(1, 16): 
		var day_box = ColorRect.new()
		day_box.custom_minimum_size = Vector2(32, 24)
		day_box.color = Color.WHITE if i != GameManager.current_day else Color(0.9, 0.4, 0.4)
		
		var border = ReferenceRect.new()
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
		border.border_color = Color.BLACK
		border.border_width = 1
		day_box.add_child(border)
		
		var lbl = Label.new()
		lbl.text = str(i)
		lbl.add_theme_color_override("font_color", Color.BLACK)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.position = Vector2(2, 2)
		day_box.add_child(lbl)
		
		var has_event = false
		for c in GameManager.active_contracts:
			if c.has("pending_route_days") and (GameManager.current_day + c["pending_route_days"] == i): has_event = true
			elif not c.has("pending_route_days") and (GameManager.current_day + c["days_left"] == i): has_event = true
		
		for r in GameManager.routes_under_construction.keys():
			var days_left = GameManager.routes_under_construction[r]
			if GameManager.current_day + days_left == i: has_event = true
		
		if has_event and i != GameManager.current_day:
			var ex = Label.new()
			ex.text = "X"
			ex.add_theme_color_override("font_color", Color.RED)
			ex.position = Vector2(12, 4)
			day_box.add_child(ex)
			
		grid.add_child(day_box)



func _spawn_shark_paper() -> void:
	var paper = ColorRect.new()
	paper.color = Color(0.25, 0.25, 0.28) 
	paper.size = Vector2(340, 420)
	paper.pivot_offset = paper.size / 2.0
	paper.position = Vector2(500 + randf_range(-30, 30), 200 + randf_range(-30, 30))
	paper.rotation_degrees = randf_range(-4, 4)

	var border = ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(0.6, 0.2, 0.2) 
	border.border_width = 4
	paper.add_child(border)

	var content = Control.new()
	content.name = "content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(content)

	var text_lbl = Label.new()
	text_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.size = paper.size - Vector2(40, 40)
	text_lbl.position = Vector2(20, 20)
	
	var txt = "CONTRATO EXTRAOFICIAL DE CRÉDITO\n\n"
	txt += "Emissor: Confidencial\n"
	txt += "Beneficiário: Cia. de Entregas Ferroviárias\n\n"
	txt += "TERMOS DO ACORDO:\n"
	txt += "- Adiantamento Imediato: +$1500\n"
	txt += "- Taxa de Cobrança Diária: -$150\n"
	txt += "- Período de Vigência: 20 Dias\n\n"
	txt += "A falta de fundos para arcar com as parcelas diárias não anula este contrato. Cuidado.\n\n"
	txt += "Carimbe [APROVAR] para receber o fundo imediato.\n"
	txt += "Carimbe [REJEITAR] para rasgar a proposta."
	
	text_lbl.text = txt
	content.add_child(text_lbl)

	paper.set_meta("is_paper", true)
	paper.set_meta("is_shark", true)
	paper.set_meta("action", "")

	_make_draggable(paper, "paper")
	ui_layer.add_child(paper)
	spawned_papers.append(paper)


func _on_go_inspection_pressed() -> void:
	var main_node = get_parent()
	if main_node.has_method("go_to_inspection"):
		main_node.go_to_inspection()



# --- NOVO: LÓGICA DO LIVRO DE REGISTROS ---
func _on_open_ledger_pressed() -> void:
	ledger_page = 0
	ledger_book.visible = true
	# Traz o livro para a frente de todos os outros painéis da mesa
	ledger_book.get_parent().move_child(ledger_book, -1)
	_update_ledger_display()
	
func _on_close_ledger_pressed() -> void:
	ledger_book.visible = false
	
func _on_ledger_prev_pressed() -> void:
	if ledger_page > 0:
		ledger_page -= 1
		_update_ledger_display()
		
func _on_ledger_next_pressed() -> void:
	var items_per_page = 4
	var total_items = GameManager.delivery_history.size()
	var max_pages = 0
	if total_items > 0:
		max_pages = ceil(total_items / float(items_per_page)) - 1
		
	if ledger_page < max_pages:
		ledger_page += 1
		_update_ledger_display()
		
func _update_ledger_display() -> void:
	var items_per_page = 4
	var total_items = GameManager.delivery_history.size()
	var max_pages = 0
	if total_items > 0:
		max_pages = ceil(total_items / float(items_per_page)) - 1
	
	if ledger_page > max_pages:
		ledger_page = max_pages
	if ledger_page < 0:
		ledger_page = 0
		
	var is_first_page = (ledger_page == 0)
	var is_last_page = (ledger_page >= max_pages)
	
	btn_ledger_prev.disabled = is_first_page
	btn_ledger_next.disabled = is_last_page
	
	if total_items == 0:
		ledger_content.text = "\n\nNenhuma entrega registrada.\nAs operações logísticas concluídas no mapa aparecerão detalhadas aqui."
		return
		
	var start_idx = ledger_page * items_per_page
	var end_idx = min(start_idx + items_per_page, total_items)
	
	var txt = "Página " + str(ledger_page + 1) + " de " + str(max_pages + 1) + "\n\n"
	
	# Lemos de trás para frente (mostra o mais recente primeiro)
	for i in range(start_idx, end_idx):
		var rev_i = total_items - 1 - i
		var record = GameManager.delivery_history[rev_i]
		
		txt += "[ DIA " + str(record.get("day", 0)) + " ] - Trem: " + record.get("train_name", "Desconhecido") + "\n"
		txt += "Rota Utilizada: " + record.get("route", "N/A") + "\n"
		txt += "Carga Transportada: " + record.get("item", "Carga") + " (" + str(record.get("weight", 0)) + " kg)\n"
		txt += "Receita Líquida: $" + str(record.get("profit", 0)) + "\n"
		txt += "---------------------------------------------------\n"
		
	ledger_content.text = txt
	
	
	
# --- NOVO: FUNÇÕES DE CLIQUE DA PRANCHETA DE OPERAÇÕES ---
func _on_clipboard_prev_pressed() -> void:
	clipboard_page -= 1
	_update_task_pad()

func _on_clipboard_next_pressed() -> void:
	clipboard_page += 1
	_update_task_pad()

func _on_active_contract_clicked(index: int) -> void:
	var c = GameManager.active_contracts[index]
	folder_title.text = "CLIENTE: " + c.get("company_name", "Empresa")
	folder_route.text = "Rota Exigida: " + c.get("route_name", "Qualquer")
	
	# --- INÍCIO DA ALTERAÇÃO (DOCUMENTO DE AUDITORIA B2B) ---
	var base_type = c.get("type", "Comum")
	var display_type = base_type
	if base_type == "Ganha-Pao": display_type = "Convencional (Classe C)"
	if base_type == "Expresso": display_type = "Expresso JIT"
	if base_type == "VIP": display_type = "Alto Risco"
	if base_type == "Ecologico": display_type = "Certificação ESG"
	if base_type == "Licitação Estatal": display_type = "Subsídio Governamental"
	
	var cargo_name = c.get("cargo", "N/A")
	var lore_text = "Abastecimento logístico padrão de rotina."
	if "Madeira" in cargo_name or "Ferro" in cargo_name or "Aco" in cargo_name or "Construcao" in cargo_name:
		lore_text = "Material base requisitado com urgência para sustentar a expansão do pólo industrial da região."
	if "Carvao" in cargo_name or "Cimento" in cargo_name:
		lore_text = "Carga pesada essencial para a manutenção ininterrupta das fornalhas e infraestrutura civil."
	if "Ouro" in cargo_name or "Suspeita" in cargo_name or "Joias" in cargo_name:
		lore_text = "Ativo de altíssimo valor agregado. Exige discrição, sigilo corporativo e segurança máxima."
	if "Trigo" in cargo_name or "Sementes" in cargo_name or "Fertilizantes" in cargo_name:
		lore_text = "Insumo biológico perecível e sensível, vital para a estabilidade da cadeia alimentar."
		
	var txt = "[ AUDITORIA DE CONTRATO VIGENTE ]\n"
	txt += "Classificação: " + display_type + "\n\n"
	
	txt += "OBJETO DO CONTRATO:\n"
	txt += "Carga Aferida: " + cargo_name + " (" + str(c.get("weight", 0)) + " kg)\n"
	txt += "Contexto: " + lore_text + "\n\n"
	
	txt += "STATUS LOGÍSTICO:\n"
	txt += "Rota Designada: " + c.get("route_name", "Qualquer") + "\n"
	
	var is_built = c.get("route_id", "") in GameManager.network_connections
	if is_built:
		txt += "Situação da Malha: [ OPERACIONAL ]\n\n"
	if not is_built:
		txt += "Situação da Malha: [ INEXISTENTE OU EM OBRAS ] (Atenção aos prazos de entrega!)\n\n"
		
	txt += "TERMOS FINANCEIROS & PRAZOS:\n"
	txt += "Vigência Restante: " + str(c.get("days_left", 0)) + " dias úteis.\n"
	
	if c.get("is_urgent", false):
		txt += "Liquidação de Frete: PAGO À VISTA.\n"
	if not c.get("is_urgent", false):
		txt += "Faturamento Diário: $" + str(c.get("reward", 0)) + ",00 / entrega concluída.\n"
		
	var cancel_fine = int((c.get("reward", 0) * c.get("days_left", 0)) * 0.20)
	if cancel_fine < 100: cancel_fine = 100
	if c.get("is_urgent", false): cancel_fine = 500
	
	txt += "\n[ NOTA DO DEPARTAMENTO JURÍDICO ]\n"
	txt += "O cancelamento prematuro deste acordo acarretará multa rescisória estimada em $" + str(cancel_fine) + ",00.\n"
	txt += "Para solicitar o rompimento de forma oficial, feche esta pasta e utilize a Prancheta de Operações (Botão 'X')."
	
	std_label.text = txt
	# --- FIM DA ALTERAÇÃO ---
	
	# Desativa os recursos de assinar, pois já é um contrato vigente!
	doc_urgent.visible = false
	btn_call_std.visible = false
	
	folder_rect.visible = true
	folder_rect.get_parent().move_child(folder_rect, -1) 
	folder_rect.rotation_degrees = 0
	_clamp_to_screen(folder_rect)


func _update_tokens_visual() -> void:
	for i in range(token_visuals.size()):
		if is_instance_valid(token_visuals[i]):
			# Se o Ã­ndice da moeda for menor que as fichas restantes no GameManager, ela continua na mesa
			token_visuals[i].visible = (i < GameManager.phone_tokens)



func _setup_newspaper_ui() -> void:
	newspaper_layer = CanvasLayer.new()
	newspaper_layer.layer = 90 
	newspaper_layer.visible = false
	add_child(newspaper_layer)
	
	newspaper_bg = ColorRect.new()
	newspaper_bg.color = Color(0, 0, 0, 0.7)
	newspaper_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	newspaper_bg.gui_input.connect(_on_newspaper_bg_input)
	newspaper_layer.add_child(newspaper_bg)
	
	newspaper_paper = ColorRect.new()
	newspaper_paper.color = Color(0.9, 0.88, 0.8) 
	newspaper_paper.size = Vector2(800, 600)
	newspaper_paper.position = Vector2(560, 240) 
	newspaper_layer.add_child(newspaper_paper)






func _on_ad_clicked(event: InputEvent, ad_data: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_spawn_ad_clipping(ad_data)
		_hide_newspaper()



func _show_newspaper() -> void:
	is_newspaper_open = true
	# O timer inicia sozinho no game_manager.gd quando a manhã começa, não forçamos mais nada aqui.
	
	for child in newspaper_paper.get_children():
		child.queue_free()
		
	var title = Label.new()
	title.text = "GAZETA FERROVIÁRIA"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	title.position = Vector2(30, 20)
	newspaper_paper.add_child(title)
	
	var subtitle = Label.new()
	title.add_child(subtitle)
	subtitle.text = "Edição do Dia " + str(GameManager.current_day)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	subtitle.position = Vector2(0, 50)
	
	var line_sep = ColorRect.new()
	line_sep.color = Color(0.1, 0.1, 0.1)
	line_sep.size = Vector2(740, 6)
	line_sep.position = Vector2(30, 85)
	newspaper_paper.add_child(line_sep)
	
	var line_sep_thin = ColorRect.new()
	line_sep_thin.color = Color(0.1, 0.1, 0.1)
	line_sep_thin.size = Vector2(740, 2)
	line_sep_thin.position = Vector2(30, 95)
	newspaper_paper.add_child(line_sep_thin)
	
	# === COLUNAS DE TEXTO FALSO (LORE VISUAL) ===
	var col_x = [30, 220] 
	for c_x in col_x:
		var start_y = 120
		for p in range(3): 
			var p_y = start_y + (p * 140)
			var fake_title = ColorRect.new()
			fake_title.color = Color(0.3, 0.3, 0.3)
			fake_title.size = Vector2(randf_range(100, 150), 12)
			fake_title.position = Vector2(c_x, p_y)
			newspaper_paper.add_child(fake_title)
			
			for l in range(6):
				var fake_line = ColorRect.new()
				fake_line.color = Color(0.65, 0.65, 0.65) 
				fake_line.size = Vector2(randf_range(130, 160), 6)
				fake_line.position = Vector2(c_x, p_y + 25 + (l * 14))
				newspaper_paper.add_child(fake_line)
		
	# === CLASSIFICADOS (BOTÕES AMARELOS LIMPOS E EXPANDIDOS) ===
	var ad_y = 120
	
	for ad_data in GameManager.todays_ads:
		var ad_btn = Button.new()
		ad_btn.size = Vector2(360, 140)
		ad_btn.position = Vector2(400, ad_y)
		
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.95, 0.9, 0.6)
		style_normal.border_color = Color(0.8, 0.75, 0.4)
		style_normal.border_width_bottom = 4
		style_normal.border_width_right = 2
		ad_btn.add_theme_stylebox_override("normal", style_normal)
		
		var style_hover = style_normal.duplicate()
		style_hover.bg_color = Color(1.0, 0.95, 0.7)
		ad_btn.add_theme_stylebox_override("hover", style_hover)
		
		var ad_lbl = Label.new()
		ad_lbl.add_theme_color_override("font_color", Color.BLACK)
		ad_lbl.add_theme_font_size_override("font_size", 14)
		ad_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# Layout de texto rico em informações para o jogador não ligar no escuro
		var txt = ">> PRECISAMOS DE FRETE <<\n"
		txt += ad_data.get("name", "Cliente") + " procura composições para escoar " + str(ad_data.get("weight", 0)) + "kg de " + ad_data.get("cargo", "Carga") + ".\n"
		txt += "Rota Exigida: " + ad_data.get("route_name", "Desconhecida") + "\n"
		txt += "Pagamento: $" + str(ad_data.get("base_reward", 0)) + "/dia\n"
		txt += "TEL: " + ad_data.get("phone", "000")
		
		ad_lbl.text = txt
		ad_lbl.position = Vector2(15, 15)
		ad_lbl.size = Vector2(330, 110)
		ad_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE 
		ad_btn.add_child(ad_lbl)
		
		var ad_bind = ad_data.duplicate()
		# Usa _on_ad_pressed para o botão funcionar certinho
		ad_btn.pressed.connect(_on_ad_pressed.bind(ad_bind))
		
		newspaper_paper.add_child(ad_btn)
		ad_y += 160 

	newspaper_layer.visible = true


func _on_newspaper_bg_input(event: InputEvent) -> void:
	# Clicou fora do jornal (fundo escuro)? Fecha o jornal!
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_newspaper()

func _on_ad_pressed(ad_data: Dictionary) -> void:
	# Nova função focada exclusivamente no botão, substituindo o frágil _on_ad_clicked
	_spawn_ad_clipping(ad_data)
	_hide_newspaper()

func _hide_newspaper() -> void:
	if is_newspaper_open:
		is_newspaper_open = false
		newspaper_layer.visible = false

# --- INÍCIO DA CORREÇÃO: RECORTE COM DADOS COMPLETOS ---
func _spawn_ad_clipping(ad_data: Dictionary) -> void:
	var paper = ColorRect.new()
	paper.color = Color(0.95, 0.95, 0.8) 
	# Aumentado o tamanho físico do papel para caber o texto extra
	paper.size = Vector2(260, 140)
	paper.position = Vector2(600 + randf_range(-30, 30), 400 + randf_range(-30, 30))
	paper.rotation_degrees = randf_range(-5, 5)

	var lbl = Label.new()
	lbl.add_theme_color_override("font_color", Color.BLACK)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 14)
	
	# Layout de texto do recorte
	var txt = "RECORTE:\n"
	txt += ad_data["name"] + "\n"
	txt += "Rota: " + ad_data["route_name"] + "\n"
	txt += "Carga: " + str(ad_data.get("weight", 0)) + "kg de " + ad_data["cargo"] + "\n"
	txt += "Paga: $" + str(ad_data["base_reward"]) + "/dia\n"
	txt += "Tel: " + ad_data["phone"]
	
	lbl.text = txt
	lbl.position = Vector2(10, 10)
	lbl.size = paper.size - Vector2(20, 20)
	paper.add_child(lbl)

	paper.set_meta("is_paper", true)
	paper.set_meta("action", "")
	_make_draggable(paper, "paper")
	ui_layer.add_child(paper)
	spawned_papers.append(paper)
	
	pending_company_data = ad_data
	pending_is_urgent = false
	current_dialed = ""
	_update_phone_display()
# --- FIM DA CORREÇÃO ---
