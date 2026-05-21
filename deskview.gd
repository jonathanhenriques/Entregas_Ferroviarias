extends Node2D

var ui_layer: CanvasLayer

var agenda_rect: ColorRect
var clipboard_rect: ColorRect
var active_paper_rect: ColorRect
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
var contracts_vbox: VBoxContainer 

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

var current_dialed: String = ""
var pending_company_data: Dictionary = {}
var pending_is_urgent: bool = false
var pending_is_risk: bool = false

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

var tool_pen: ColorRect
var stamp_reject: ColorRect
var stamp_cia: ColorRect

var pad_extension: ColorRect

var eod_layer: CanvasLayer
var eod_lines_container: VBoxContainer
var btn_eod_sleep: Button
var skip_eod_anim: bool = false
var pending_upfront_income: int = 0

var radio_rect: ColorRect
var radio_led: ColorRect

var task_pad_rect: ColorRect
var task_vbox: VBoxContainer

func _ready() -> void:
	_setup_ui()
	_setup_cutscene()
	_setup_eod_ui()
	
	GameManager.money_changed.connect(_on_stats_changed)
	GameManager.maintenance_updated.connect(_on_stats_changed)
	GameManager.contracts_updated.connect(_on_contracts_updated)
	GameManager.day_changed.connect(_on_day_changed)
	
	visibility_changed.connect(_on_visibility_changed)
	
	_load_agenda_contacts()
	_update_report_text()
	_update_active_contracts_text()
	_update_diretrizes() 
	_update_task_pad()

func _process(delta: float) -> void:
	if not visible: return
	
	if not is_dial_dragging:
		if dial_current_rot > 0.0:
			dial_current_rot -= delta * 5.0 
			if dial_current_rot < 0.0:
				dial_current_rot = 0.0
			dial_rect.queue_redraw()

	if GameManager.pending_radio_event:
		var time = float(Time.get_ticks_msec()) / 1000.0
		if sin(time * 10.0) > 0:
			radio_led.color = Color.RED
		else:
			radio_led.color = Color.DARK_RED
	else:
		radio_led.color = Color(0.2, 0.05, 0.05)

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
	btn_organize.position = Vector2(40, 100)
	btn_organize.size = Vector2(180, 40)
	btn_organize.pressed.connect(_on_organize_pressed)
	ui_layer.add_child(btn_organize)

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
	
	var trash_lbl = Label.new()
	trash_lbl.text = "LIXEIRA"
	trash_lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
	trash_lbl.position = Vector2(0, 100)
	trash_lbl.size = Vector2(220, 30)
	trash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trash_rect.add_child(trash_lbl)

	var tool_y = 120

	tool_pen = ColorRect.new()
	tool_pen.color = Color(0.8, 0.8, 0.85) 
	tool_pen.size = Vector2(12, 110)
	tool_pen.position = Vector2(500, tool_y)
	tool_pen.rotation_degrees = -35.0
	ui_layer.add_child(tool_pen)
	_make_draggable(tool_pen, "tool_pen")
	
	var pen_tip = Polygon2D.new()
	pen_tip.color = Color(0.2, 0.2, 0.2)
	pen_tip.polygon = PackedVector2Array([
		Vector2(0, 110), Vector2(12, 110), Vector2(6, 125)
	])
	tool_pen.add_child(pen_tip)

	stamp_reject = ColorRect.new()
	stamp_reject.color = Color(0.6, 0.2, 0.2)
	stamp_reject.size = Vector2(70, 90)
	stamp_reject.position = Vector2(600, tool_y)
	ui_layer.add_child(stamp_reject)
	_make_draggable(stamp_reject, "tool_reject")
	
	var lbl_r = Label.new()
	lbl_r.text = "REJEITAR"
	lbl_r.add_theme_font_size_override("font_size", 12)
	lbl_r.position = Vector2(5, 40)
	stamp_reject.add_child(lbl_r)

	stamp_cia = ColorRect.new()
	stamp_cia.color = Color(0.2, 0.3, 0.5)
	stamp_cia.size = Vector2(70, 90)
	stamp_cia.position = Vector2(720, tool_y)
	ui_layer.add_child(stamp_cia)
	_make_draggable(stamp_cia, "tool_cia")
	
	var lbl_cia = Label.new()
	lbl_cia.text = "SELO CIA"
	lbl_cia.add_theme_font_size_override("font_size", 12)
	lbl_cia.position = Vector2(5, 40)
	stamp_cia.add_child(lbl_cia)

	pad_extension = ColorRect.new()
	pad_extension.color = Color(0.35, 0.4, 0.45)
	pad_extension.size = Vector2(140, 180)
	pad_extension.position = Vector2(40, 600)
	pad_extension.visible = false 
	ui_layer.add_child(pad_extension)
	
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

	# --- PASTA DE CLIENTES LARGURA 400 ---
	agenda_rect = ColorRect.new()
	agenda_rect.color = Color(0.85, 0.8, 0.6) 
	agenda_rect.size = Vector2(400, 520) 
	agenda_rect.position = Vector2(50, 200)
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
	btn_next_page.position = Vector2(280, 460)
	btn_next_page.pressed.connect(_on_next_page_pressed)
	agenda_rect.add_child(btn_next_page)

	# --- PRANCHETA PRINCIPAL ---
	clipboard_rect = ColorRect.new()
	clipboard_rect.color = Color(0.95, 0.95, 0.9) 
	clipboard_rect.size = Vector2(350, 400)
	clipboard_rect.position = Vector2(1000, 250)
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

	# --- PASTA DA FROTA LARGURA 400 ---
	active_paper_rect = ColorRect.new()
	active_paper_rect.color = Color(0.85, 0.9, 0.95) 
	active_paper_rect.size = Vector2(400, 520) 
	active_paper_rect.position = Vector2(1450, 450) 
	ui_layer.add_child(active_paper_rect)
	_make_draggable(active_paper_rect, "panel")

	var active_title = Label.new()
	active_title.text = "FROTA E CONTRATOS ATIVOS" 
	active_title.add_theme_color_override("font_color", Color.BLACK)
	active_title.position = Vector2(20, 20)
	active_paper_rect.add_child(active_title)

	contracts_vbox = VBoxContainer.new()
	contracts_vbox.position = Vector2(20, 50)
	contracts_vbox.size = Vector2(360, 450) 
	contracts_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_paper_rect.add_child(contracts_vbox)

	# --- PASTA DO CONTRATO LARGURA 500 ---
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

	doc_standard = ColorRect.new()
	doc_standard.color = Color(0.95, 0.95, 0.95)
	doc_standard.size = Vector2(440, 420)
	doc_standard.position = Vector2(20, 40)
	folder_rect.add_child(doc_standard)
	doc_standard.gui_input.connect(_on_doc_input.bind(doc_standard))
	
	std_label = Label.new()
	std_label.position = Vector2(20, 20)
	std_label.size = Vector2(400, 330)
	std_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	std_label.add_theme_color_override("font_color", Color.BLACK)
	doc_standard.add_child(std_label)
	
	btn_call_std = Button.new()
	btn_call_std.text = "PREPARAR CONTRATO"
	btn_call_std.position = Vector2(20, 360)
	btn_call_std.size = Vector2(400, 40)
	btn_call_std.pressed.connect(_on_call_standard_pressed)
	doc_standard.add_child(btn_call_std)

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

	# --- TELEFONE ---
	phone_rect = ColorRect.new()
	phone_rect.color = Color(0.1, 0.25, 0.15) 
	phone_rect.size = Vector2(340, 260) 
	phone_rect.position = Vector2(350, 700)
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

	# --- RÁDIO ---
	radio_rect = ColorRect.new()
	radio_rect.color = Color(0.6, 0.6, 0.65) 
	radio_rect.size = Vector2(250, 120)
	radio_rect.position = Vector2(60, 800)
	ui_layer.add_child(radio_rect)
	_make_draggable(radio_rect, "radio")
	
	var radio_speaker = ColorRect.new()
	radio_speaker.color = Color(0.15, 0.15, 0.15)
	radio_speaker.size = Vector2(120, 80)
	radio_speaker.position = Vector2(20, 20)
	radio_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radio_rect.add_child(radio_speaker)
	
	var radio_lbl = Label.new()
	radio_lbl.text = "RÁDIO PTT\nFREQ 104.2"
	radio_lbl.add_theme_color_override("font_color", Color.BLACK)
	radio_lbl.position = Vector2(150, 20)
	radio_rect.add_child(radio_lbl)
	
	radio_led = ColorRect.new()
	radio_led.color = Color(0.2, 0.05, 0.05) 
	radio_led.size = Vector2(20, 20)
	radio_led.position = Vector2(150, 70)
	radio_led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radio_rect.add_child(radio_led)

	# --- BLOCO DE TAREFAS ---
	task_pad_rect = ColorRect.new()
	task_pad_rect.color = Color(0.95, 0.92, 0.65)
	task_pad_rect.size = Vector2(280, 280)
	task_pad_rect.position = Vector2(1080, 680)
	ui_layer.add_child(task_pad_rect)
	_make_draggable(task_pad_rect, "panel")

	var pad_clip = ColorRect.new()
	pad_clip.color = Color(0.7, 0.2, 0.2) 
	pad_clip.size = Vector2(280, 20)
	task_pad_rect.add_child(pad_clip)

	var task_title = Label.new()
	task_title.text = "TAREFAS PENDENTES"
	task_title.add_theme_color_override("font_color", Color.BLACK)
	task_title.position = Vector2(10, 25)
	task_pad_rect.add_child(task_title)

	task_vbox = VBoxContainer.new()
	task_vbox.position = Vector2(10, 50)
	task_vbox.size = Vector2(260, 220)
	task_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_pad_rect.add_child(task_vbox)

	# --- CALENDÁRIO ---
	calendar_rect = ColorRect.new()
	calendar_rect.color = Color(0.9, 0.9, 0.9)
	calendar_rect.size = Vector2(220, 160)
	calendar_rect.position = Vector2(100, 620)
	ui_layer.add_child(calendar_rect)
	_make_draggable(calendar_rect, "panel")
	
	var cal_clip = ColorRect.new()
	cal_clip.name = "clip"
	cal_clip.color = Color(0.2, 0.2, 0.2)
	cal_clip.size = Vector2(100, 15)
	cal_clip.position = Vector2(60, 0)
	calendar_rect.add_child(cal_clip)

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
	content_lbl.text = "REQUERIMENTO DE EXTENSÃO\n\nSolicito +3 dias de prazo.\nCiente da multa de -30% no valor.\n\nContrato Alvo:"
	content_lbl.position = Vector2(20, 20)
	content.add_child(content_lbl)

	paper.set_meta("is_paper", true)
	paper.set_meta("is_extension", true)
	paper.set_meta("selected_idx", -1)
	paper.set_meta("action", "")

	_make_draggable(paper, "paper")

	if GameManager.active_contracts.size() == 0:
		var lbl_empty = Label.new()
		lbl_empty.text = "(Nenhum contrato ativo)"
		lbl_empty.add_theme_color_override("font_color", Color.DIM_GRAY)
		lbl_empty.position = Vector2(20, 180)
		content.add_child(lbl_empty)
	else:
		for i in range(GameManager.active_contracts.size()):
			var c = GameManager.active_contracts[i]
			
			var cb_bg = ColorRect.new()
			cb_bg.color = Color.BLACK
			cb_bg.size = Vector2(32, 32)
			cb_bg.position = Vector2(20, 180 + (i * 50))
			cb_bg.set_meta("is_checkbox", true)
			cb_bg.set_meta("cb_idx", i)

			var cb_fg = ColorRect.new()
			cb_fg.color = Color.WHITE
			cb_fg.size = Vector2(28, 28)
			cb_fg.position = Vector2(2, 2)
			cb_bg.add_child(cb_fg)

			var cb_mark = Label.new()
			cb_mark.text = "X"
			cb_mark.add_theme_color_override("font_color", Color.BLACK)
			cb_mark.add_theme_font_size_override("font_size", 30)
			cb_mark.position = Vector2(4, -8)
			cb_mark.visible = false
			cb_fg.add_child(cb_mark)

			var lbl = Label.new()
			lbl.text = "T" + str(i+1) + " - " + c["company_name"]
			lbl.add_theme_color_override("font_color", Color.BLACK)
			lbl.position = Vector2(65, 184 + (i * 50))
			content.add_child(lbl)

			cb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(cb_bg)

	_add_ball_visual(paper)

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
	var dialed_clean = current_dialed
	var target_clean = ""
	
	if not pending_company_data.is_empty():
		target_clean = pending_company_data["phone"].replace("-", "")
	
	if dialed_clean == target_clean:
		phone_display.text = "LIGANDO..."
		await get_tree().create_timer(0.5).timeout
		_process_call()
	else:
		phone_display.text = "NUMERO INVALIDO"
		await get_tree().create_timer(1.0).timeout
	
	current_dialed = ""
	_update_phone_display()

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
					if panel.get_meta("crumpled", false):
						tw.tween_property(panel, "scale", Vector2(0.6, 0.6), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					else:
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
								
								if panel.get_meta("crumpled", false):
									_clamp_scaled_paper(panel)
									
								elif center.distance_to(trash_center) < 160:
									panel.pivot_offset = panel.size / 2.0
									var tw = create_tween().set_parallel(true)
									tw.tween_property(panel, "scale", Vector2(0.5, 0.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
									tw.tween_property(panel, "rotation_degrees", 0.0, 0.2) 
									tw.tween_property(panel, "global_position", trash_center - (panel.size / 2.0), 0.2)
									
									if not panel.get_meta("crumpled", false):
										panel.set_meta("crumpled", true)
										
										# CORREÇÃO: Remove a identidade de Planta ao amassar
										if panel.get_meta("is_blueprint", false):
											panel.set_meta("is_blueprint", false)
											GameManager.pending_blueprint.clear()
											GameManager.save_game()
												
									panel.self_modulate.a = 0.0 
									if panel.has_node("content"):
										panel.get_node("content").visible = false
									if panel.has_node("ball_visual"):
										panel.get_node("ball_visual").visible = true
										
								elif outbox_rect.get_global_rect().grow(100).has_point(center):
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
					_clamp_scaled_paper(panel)
					
					if not panel.get_meta("crumpled", false):
						var center = panel.get_global_rect().get_center()
						var trash_center = trash_rect.global_position + trash_rect.size / 2.0
						
						if center.distance_to(trash_center) < 160:
							panel.set_meta("crumpled", true)
							panel.pivot_offset = panel.size / 2.0
							
							# CORREÇÃO: Também remove identidade no movimento (Drag over trash)
							if panel.get_meta("is_blueprint", false):
								panel.set_meta("is_blueprint", false)
								GameManager.pending_blueprint.clear()
								GameManager.save_game()
							
							var tw = create_tween().set_parallel(true)
							tw.tween_property(panel, "scale", Vector2(0.5, 0.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
							tw.tween_property(panel, "rotation_degrees", randf_range(0, 360), 0.2) 
							
							panel.self_modulate.a = 0.0 
							if panel.has_node("content"):
								panel.get_node("content").visible = false
							if panel.has_node("ball_visual"):
								panel.get_node("ball_visual").visible = true
				else:
					_clamp_to_screen(panel)



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



func _load_agenda_contacts() -> void:
	if current_agenda_contacts.is_empty():
		var all_c = []
		
		# Filtra apenas dicionários válidos para evitar crashes
		for c in GameManager.daily_generic_companies: 
			if typeof(c) == TYPE_DICTIONARY: all_c.append(c)
		for c in GameManager.daily_urgencies: 
			if typeof(c) == TYPE_DICTIONARY: all_c.append(c)
			
		# SOLUÇÃO GAME DESIGN: Contrato Garantido no Dia 1
		if GameManager.current_day == 1 and not GameManager.is_first_route_built:
			var tutorial_contract = {
				"name": "Prefeitura Local (Tutorial)",
				"type": "Ganha-Pao",
				"phone": "555-0001",
				"cargo": "Materiais de Construcao",
				"route_id": "Azul-Vermelha",
				"route_name": "Azul <-> Vermelha",
				"base_reward": 150
			}
			all_c.append(tutorial_contract)
		
		var fakes = ["Madeireira Sul", "Minas de Carvao", "Tecelagem Fina", "Armazens Gerais", "Importadora X", "Silos do Porto", "Fazenda Velha", "Aco & Ferro Ltda"]
		for i in range(12): 
			all_c.append({
				"name": fakes.pick_random() + " (Inativo)",
				"type": "Falso",
				"phone": "555-" + str(randi_range(1000, 9999)),
				"cargo": "N/A", "route_name": "N/A", "base_reward": 0
			})
			
		all_c.shuffle()
		
		# Garante que o contrato do Tutorial fique na primeira página (índice 0)
		if GameManager.current_day == 1 and not GameManager.is_first_route_built:
			for i in range(all_c.size()):
				if all_c[i].get("name") == "Prefeitura Local (Tutorial)":
					var temp = all_c[0]
					all_c[0] = all_c[i]
					all_c[i] = temp
					break
					
		current_agenda_contacts = all_c
		current_agenda_page = 0
		
	_render_agenda_page()




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
		
		if c.get("type", "Falso") == "Falso":
			btn.text = c.get("name", "Desconhecido") + "\nTel: " + c.get("phone", "000")
			btn.disabled = true
		else:
			var txt = c.get("name", "Empresa") + " (" + c.get("type", "") + ")\n"
			txt += "Tel: " + c.get("phone", "000") + " | Paga: $" + str(c.get("base_reward", 0))
			btn.text = txt
			btn.pressed.connect(_on_company_selected.bind(c))
			
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

func _process_call() -> void:
	if GameManager.active_contracts.size() >= GameManager.MAX_CONTRACTS:
		phone_cutscene.start_rejection_call(pending_company_data["name"], "A frota esta lotada!")
		folder_rect.visible = false
		pending_company_data = {}
		return
		
	var rid = pending_company_data["route_id"]
	var ctype = pending_company_data["type"]
	var has_route = rid in GameManager.network_connections
	var is_constructing = GameManager.routes_under_construction.get(rid, 0) > 0

	var route_valid = false
	var reason = ""
	
	if has_route:
		if not is_constructing:
			var stats = GameManager.network_stats.get(rid, {})
			
			var max_d = pending_company_data.get("max_dist", 999)
			var curr_d = stats.get("dist", 999)
			var is_long = (ctype == "Expresso" and curr_d > max_d)
			
			if is_long:
				# CORREÇÃO: O cliente agora diz os tamanhos exatos!
				reason = "A nossa carga EXPRESSA tem limite rigoroso de tempo!\nA sua via tem " + str(curr_d) + " km, mas exigimos um trajeto maximo de " + str(max_d) + " km!\nRefaca a rota de forma mais direta!"
			
			if not is_long:
				var is_vip_bad = (ctype == "VIP" and (stats.get("gangs", 0) > 0 or GameManager.active_contracts.size() > 0))
				if is_vip_bad:
					reason = "VIP exige seguranca absoluta e exclusividade na malha!"
				if not is_vip_bad:
					var is_eco_bad = (ctype == "Ecologico" and stats.get("forests", 0) > 0)
					if is_eco_bad:
						reason = "Os seus trilhos desmataram a floresta! Nao financiamos crimes ambientais!"
					if not is_eco_bad:
						route_valid = true

	var can_do_risk = false
	if not has_route:
		can_do_risk = true
	if has_route:
		if is_constructing:
			can_do_risk = true

	if can_do_risk:
		pending_is_risk = true
		var rew = pending_company_data["base_reward"]
		if pending_is_urgent:
			rew = GameManager.daily_urgencies.get(pending_company_data["name"], rew)
		phone_cutscene.start_risk_call(pending_company_data["name"], pending_company_data["route_name"], rew)

	if not can_do_risk:
		pending_is_risk = false
		if not route_valid:
			phone_cutscene.start_rejection_call(pending_company_data["name"], reason)
			var is_daily = "(Diario)" in pending_company_data["name"]
			if not (is_daily and GameManager.current_day == 1):
				GameManager.company_cooldowns[pending_company_data["name"]] = 1 
			folder_rect.visible = false
		if route_valid:
			var rew = pending_company_data["base_reward"]
			if pending_is_urgent:
				rew = GameManager.daily_urgencies.get(pending_company_data["name"], rew)
			phone_cutscene.start_call(pending_company_data["name"], pending_company_data["type"], pending_company_data["cargo"], rew, pending_is_urgent)



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
			
		_update_active_contracts_text()
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
	_update_active_contracts_text()
	_update_task_pad()

func _update_task_pad() -> void:
	for child in task_vbox.get_children():
		child.queue_free()
		
	if GameManager.active_contracts.size() == 0:
		var lbl = Label.new()
		lbl.text = "Nenhum contrato ativo no momento."
		lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
		lbl.add_theme_font_size_override("font_size", 12)
		task_vbox.add_child(lbl)
		return
		
	for c in GameManager.active_contracts:
		var lbl = Label.new()
		var rid = c["route_id"]
		var t = "- " + c["company_name"] + "\n  Status: "
		
		if c.has("pending_route_days"):
			var is_building = (GameManager.routes_under_construction.get(rid, 0) > 0)
			if is_building:
				t += "EM OBRAS (" + str(GameManager.routes_under_construction[rid]) + "d restantes)"
				lbl.add_theme_color_override("font_color", Color.DARK_GOLDENROD)
			else:
				t += "ROTA INEXISTENTE (" + str(c["pending_route_days"]) + "d p/ falha)"
				lbl.add_theme_color_override("font_color", Color.DARK_RED)
		else:
			var stats = GameManager.network_stats.get(rid, {})
			if stats.get("is_broken", false):
				t += "INTERROMPIDO (Falha na Via)"
				lbl.add_theme_color_override("font_color", Color.CRIMSON)
			else:
				t += "OPERACIONAL (" + str(c["days_left"]) + "d restantes)"
				lbl.add_theme_color_override("font_color", Color.DARK_GREEN)
				
		lbl.text = t
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		task_vbox.add_child(lbl)



func _update_active_contracts_text() -> void:
	for child in contracts_vbox.get_children(): 
		child.queue_free()
		
	if GameManager.active_contracts.size() == 0:
		var l = Label.new()
		l.text = "\nPátio vazio."
		l.add_theme_color_override("font_color", Color.DIM_GRAY)
		contracts_vbox.add_child(l)
	else:
		var i = 0
		for c in GameManager.active_contracts:
			var hbox = HBoxContainer.new()
			var is_act = GameManager.is_contract_operating(c)
			var st = ""
			var cl = Label.new()
			
			var cargo_name = c.get("cargo", "Carga Geral")
			var route_name = c.get("route_name", "Desconhecida")
			var days_left = c.get("days_left", 0)
			
			if c.has("pending_route_days"):
				st = "[AGUARDANDO VIA: " + str(c["pending_route_days"]) + "d]"
				cl.add_theme_color_override("font_color", Color.DARK_GOLDENROD)
			else:
				if is_act: 
					if c.get("is_urgent", false):
						st = "[PAGO]"
					else:
						st = "(+$" + str(c.get("reward", 0)) + ")"
					cl.add_theme_color_override("font_color", Color.DARK_SLATE_GRAY)
				else:
					cl.add_theme_color_override("font_color", Color.INDIAN_RED)
					var rid = c.get("route_id", "")
					if GameManager.routes_under_construction.get(rid, 0) > 0:
						st = "[OBRAS: " + str(GameManager.routes_under_construction[rid]) + "d]"
					else:
						if not (rid in GameManager.network_connections): 
							st = "[SEM ROTA]"
						else: 
							var stats = GameManager.network_stats.get(rid, {})
							if stats.get("is_broken", false):
								st = "[VIA DESTRUÍDA]"
							else:
								var tp = c.get("type", "")
								if tp == "Expresso" and stats.get("dist", 999) > c.get("max_dist", 999):
									st = "[PARADO: ROTA LONGA]"
								else:
									if tp == "VIP" and GameManager.active_contracts.size() > 1:
										st = "[PARADO: FIM EXCLUSIVIDADE]"
									else:
										if tp == "VIP" and stats.get("gangs", 0) > 0:
											st = "[PARADO: GANGUES NA LINHA]"
										else:
											if tp == "Ecologico" and stats.get("forests", 0) > 0:
												st = "[PARADO: CRIME AMBIENTAL]"
											else:
												st = "[PARADO: ILEGAL]"
									
			cl.text = "T" + str(i + 1) + ": " + cargo_name + "\n" + route_name + " " + st + "\n" + str(days_left) + "d"
			# ALARGADO PARA NÃO VAZAR
			cl.custom_minimum_size = Vector2(300, 0) 
			hbox.add_child(cl)
			
			var b = Button.new()
			b.text = "X"
			b.pressed.connect(_on_cancel_dynamic.bind(i))
			hbox.add_child(b)
			contracts_vbox.add_child(hbox)
			i += 1


func _on_company_selected(data: Dictionary) -> void:
	selected_company_data = data
	folder_title.text = "CLIENTE: " + data["name"]
	folder_route.text = "Exige Rota: " + data["route_name"]
	
	if not data.has("weight"): data["weight"] = randi_range(1000, 15000)
	if not data.has("duration"): data["duration"] = randi_range(5, 10)
	
	std_label.text = "[ CONTRATO PADRÃO ]\n\n"
	std_label.text += "Carga: " + data["cargo"] + " (" + str(data["weight"]) + " Kg)\n"
	std_label.text += "Duração Prevista: " + str(data["duration"]) + " a " + str(data["duration"] + 3) + " dias\n"
	std_label.text += "Pagamento Diário: $" + str(data["base_reward"]) + "\n\n"
	std_label.text += "Contato: " + data["phone"]
	
	btn_call_std.text = "PREPARAR CONTRATO"
	
	if GameManager.daily_urgencies.has(data["name"]):
		doc_urgent.visible = true
		urg_label.text = "[!] URGÊNCIA HOJE\n\n"
		urg_label.text += "Carga: " + data["cargo"] + " (" + str(data["weight"]) + " Kg)\n"
		urg_label.text += "Prazo Máximo: 1 dia\n"
		urg_label.text += "PAGAMENTO À VISTA: $" + str(GameManager.daily_urgencies[data["name"]]) + "\n\n"
		urg_label.text += "Contato: " + data["phone"]
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

	var content = Control.new()
	content.name = "content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(content)

	var text_lbl = Label.new()
	text_lbl.add_theme_color_override("font_color", Color.BLACK)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.size = paper.size - Vector2(40, 40)
	text_lbl.position = Vector2(20, 20)

	var text = "TERMO OFICIAL DE TRANSPORTE\n\n"
	text += "CONTRATANTE: " + c_data["name"] + "\n"
	text += "CARGA: " + c_data["cargo"] + " (" + str(c_data.get("weight", 0)) + " Kg)\n"
	text += "ROTA EXIGIDA: " + c_data["route_name"] + "\n\n"
	
	if is_urg:
		text += "[ OPERAÇÃO DE URGÊNCIA MÁXIMA ]\n"
		text += "Duração da Operação: 1 Dia\n"
		text += "Pagamento à Vista: $" + str(reward) + "\n\n"
	if not is_urg:
		text += "[ CONTRATO PADRÃO " + c_data["type"] + " ]\n"
		text += "Duração Estimada: " + str(c_data.get("duration", 5)) + " a " + str(c_data.get("duration", 10) + 3) + " Dias\n"
		text += "Pagamento Diário: $" + str(reward) + "\n\n"

	text += "CLÁUSULA ÚNICA: A Cia. de Entregas Ferroviárias assume responsabilidade integral sobre o estado da carga (" + str(c_data.get("weight", 0)) + " Kg) durante todo o trajeto.\n\n"
	
	if pending_is_risk:
		text += "[ ATENÇÃO: CONTRATO DE RISCO ]\nVia inexistente ou em obras. Prazo estrito: 3 dias para iniciar operação."
	else:
		text += "(Aguarde validação manual para Enviar)"
	
	text_lbl.text = text
	content.add_child(text_lbl)

	paper.set_meta("is_paper", true)
	paper.set_meta("is_extension", false)
	paper.set_meta("company_data", c_data)
	paper.set_meta("is_urgent", is_urg)
	paper.set_meta("reward", reward)
	paper.set_meta("is_risk", pending_is_risk)
	paper.set_meta("action", "")

	_make_draggable(paper, "paper")
	_add_ball_visual(paper)

	ui_layer.add_child(paper)
	spawned_papers.append(paper)
	
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
		btn.text = "[ <- ]"
	elif p == 2:
		lbl.text = lbl.get_meta("page1_text")
		lbl.set_meta("page", 1)
		btn.text = "[ -> ]"

func _update_report_text() -> void:
	var inc = GameManager.get_daily_income()
	var exp = GameManager.daily_maintenance + GameManager.BASE_COST + GameManager.daily_gang_toll + GameManager.daily_crew_cost + GameManager.daily_lobby_cost
	var net = inc - exp
	
	var t = "RELATÓRIO ADMINISTRATIVO\n\nDia: " + str(GameManager.current_day) + "\nCaixa: $" + str(GameManager.money) + "\n\nReceita: +$" + str(inc) + "\nManutenção da Via: -$" + str(GameManager.daily_maintenance) + "\nTaxas e Base: -$" + str(GameManager.BASE_COST)
	
	if GameManager.daily_crew_cost > 0:
		t += "\nSalários (Equipe): -$" + str(GameManager.daily_crew_cost)
	if GameManager.daily_lobby_cost > 0:
		t += "\nLobby/Estado: -$" + str(GameManager.daily_lobby_cost)
	if GameManager.daily_gang_toll > 0: 
		t += "\nPropinas (Gangues): -$" + str(GameManager.daily_gang_toll)
		
	t += "\n----------------\nLucro: $" + str(net)
	report_label.text = t
	
	btn_next_day.disabled = false
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

	for p in spawned_papers:
		if not is_instance_valid(p): continue
		
		# Conta rejeições
		if p.has_meta("action") and p.get_meta("action") == "reject":
			rej_c += 1
			
		# Processa a Extensão de Prazo
		if p.has_meta("is_extension") and p.get_meta("is_extension"):
			if p.has_meta("action") and p.get_meta("action") == "approve":
				ext_c += 1
				var s_idx = p.get_meta("selected_idx", -1)
				if s_idx >= 0 and s_idx < GameManager.active_contracts.size():
					GameManager.active_contracts[s_idx]["days_left"] += 3
					GameManager.money -= 200 
					
		# Processa a Planta de Obras
		elif p.has_meta("is_blueprint") and p.get_meta("is_blueprint"):
			if p.has_meta("action") and p.get_meta("action") == "approve":
				var bp = GameManager.pending_blueprint
				var cd = bp.get("routes_to_cooldown", [])
				var r_desc = bp.get("route_description", "")
				
				bp_cost += bp.get("total_cost", 0)
				GameManager.money -= bp.get("total_cost", 0)
				
				for route_id in cd:
					GameManager.company_cooldowns[route_id] = 5
					var base_days = 3
					if r_desc.find("Azul") != -1 and r_desc.find("Vermelha") != -1: base_days = 2
					GameManager.routes_under_construction[route_id] = base_days
					
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
				
		# Processa os Contratos de Carga
		elif p.has_meta("action") and p.get_meta("action") == "approve":
			new_c += 1
			var c_data = p.get_meta("company_data")
			var is_urg = p.get_meta("is_urgent")
			var reward = p.get_meta("reward")
			var is_risk = p.get_meta("is_risk")
			
			var new_contract = {
				"company_name": c_data["name"],
				"route_id": c_data["route_id"],
				"type": c_data["type"],
				"reward": reward
			}
			
			if is_urg:
				new_contract["is_urgent"] = true
				income += reward 
				new_contract["days_left"] = 1
				GameManager.active_contracts.append(new_contract)
			else:
				new_contract["days_left"] = randi_range(5, 10)
				GameManager.active_contracts.append(new_contract)
				
			if is_risk:
				new_contract["pending_route_days"] = 3
				
			GameManager.company_cooldowns[c_data["route_id"]] = 4

	for p in spawned_papers:
		if is_instance_valid(p): p.queue_free()
	spawned_papers.clear()
	
	current_agenda_contacts.clear()
	current_agenda_page = 0
	
	# Restaura a chamada do Painel de Resumo!
	pending_upfront_income = income
	_start_eod_animation(new_c, rej_c, ext_c, bp_cost)
	
	
	
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

func _start_eod_animation(new_c: int, rej_c: int, ext_c: int, bp_cost: int) -> void:
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
			
	_add_eod_line("Entregas Operando", str(active_count), c_light, false)
	_add_eod_line("Contratos Fechados", str(new_c), c_light, false)
	_add_eod_line("Prazos Estendidos", str(ext_c), c_light, false)
	_add_eod_line("Propostas Rejeitadas", str(rej_c), c_light, false)
	_add_eod_line("Contratos Rompidos", str(GameManager.today_broken_contracts), c_light, false)
	
	if GameManager.today_penalties > 0:
		_add_eod_line("Multas Aplicadas Hoje", "-$" + str(GameManager.today_penalties), c_red, false)
		
	_add_eod_line("", "", c_light, false)
	_add_eod_line("[ FINANÇAS ]", "", c_gray, false)
	_add_eod_line("Saldo Inicial", "$" + str(GameManager.money + bp_cost), c_light, false)
	
	if pending_upfront_income > 0:
		_add_eod_line("Receitas à Vista", "+$" + str(pending_upfront_income), c_green, false)
		
	var inc = GameManager.get_daily_income()
	if inc > 0:
		_add_eod_line("Receita de Fretes", "+$" + str(inc), c_green, false)
		
	if bp_cost > 0:
		_add_eod_line("Obras e Licenciamentos", "-$" + str(bp_cost), c_red, false)
		
	if GameManager.daily_maintenance > 0:
		_add_eod_line("Manutenção da Via", "-$" + str(GameManager.daily_maintenance), c_red, false)
		
	_add_eod_line("Custos Base da Garagem", "-$" + str(GameManager.BASE_COST), c_red, false)
	
	if GameManager.daily_crew_cost > 0:
		_add_eod_line("Salários da Equipe", "-$" + str(GameManager.daily_crew_cost), c_red, false)
	if GameManager.daily_lobby_cost > 0:
		_add_eod_line("Lobby Governamental", "-$" + str(GameManager.daily_lobby_cost), c_red, false)
	if GameManager.daily_gang_toll > 0:
		_add_eod_line("Extorsão (Gangues)", "-$" + str(GameManager.daily_gang_toll), c_red, false)
		
	_add_eod_line("-----------------------", "---------", c_gray, false)
	
	var final_money = GameManager.money + pending_upfront_income + inc - GameManager.daily_maintenance - GameManager.BASE_COST - GameManager.daily_gang_toll - GameManager.daily_crew_cost - GameManager.daily_lobby_cost
	var final_color = c_green
	if final_money < 0:
		final_color = c_red
		
	_add_eod_line("SALDO PROJETADO", "$" + str(final_money), final_color, false)
	
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

func _on_eod_sleep_pressed() -> void:
	eod_layer.visible = false
	GameManager.end_day(pending_upfront_income)
	_update_calendar()
	_on_organize_pressed()




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
	_update_active_contracts_text()
	_load_agenda_contacts() 
	_update_task_pad()

func _on_day_changed(_v) -> void: 
	_update_report_text()
	_update_active_contracts_text()
	_load_agenda_contacts() 
	_update_task_pad()

func _on_back_map_pressed() -> void: 
	get_parent().go_to_map()


func _on_fiscal_choice(is_bribe: bool, cost: int) -> void:
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
	_update_active_contracts_text()
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
		lbl.text = "DIRETRIZES DE OPERAÇÃO - DIA 1\n\nBem-vindo à Diretoria.\n\nPASSOS PARA HOJE:\n1. Abra o 'Arquivo de Clientes'.\n2. Clique em 'Preparar Contrato' para a Rota Azul <-> Vermelha.\n3. Arraste a Caneta e o Carimbo para aprovar e mova o papel para a Bandeja de Saída.\n4. Vá ao Mapa (<-), clique em Modo Obras e ligue as duas estações.\n5. Clique em Gerar Planta, assine a planta na mesa e finalize o dia!"
		paper.set_meta("is_tutorial_1", true)
	elif type == 2:
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
	lbl.text = "AVISO DO CHEFE:\nUm dos nossos contratos vence amanhã! Se não renovarmos, o cliente vai nos processar. Use o Formulário de Extensão (O bloco à esquerda)!"
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
