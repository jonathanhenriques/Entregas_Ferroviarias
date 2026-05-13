extends Node2D

var ui_layer: CanvasLayer

var agenda_rect: ColorRect
var clipboard_rect: ColorRect
var active_paper_rect: ColorRect
var diretrizes_rect: ColorRect
var diretrizes_label: Label
var diretrizes_bar: ProgressBar

var companies_vbox: VBoxContainer

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
var outbox_papers: Array = []

var outbox_rect: ColorRect
var trash_rect: ColorRect
var stamp_approve: ColorRect
var stamp_reject: ColorRect

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
	
	var selo_clip = ColorRect.new()
	selo_clip.color = Color(0.1, 0.1, 0.1)
	selo_clip.size = Vector2(25, 60)
	selo_clip.position = Vector2(0, 0)
	diretrizes_rect.add_child(selo_clip)
	
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

	agenda_rect = ColorRect.new()
	agenda_rect.color = Color(0.85, 0.8, 0.6) 
	agenda_rect.size = Vector2(300, 400)
	agenda_rect.position = Vector2(80, 250)
	ui_layer.add_child(agenda_rect)
	_make_draggable(agenda_rect, "panel")
	
	var lombada = ColorRect.new()
	lombada.color = Color(0.1, 0.1, 0.1) 
	lombada.size = Vector2(30, 400)
	lombada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	agenda_rect.add_child(lombada)
	
	var agenda_title = Label.new()
	agenda_title.text = "ARQUIVO DE CLIENTES"
	agenda_title.add_theme_color_override("font_color", Color.BLACK)
	agenda_title.position = Vector2(50, 20)
	agenda_rect.add_child(agenda_title)
	
	companies_vbox = VBoxContainer.new()
	companies_vbox.position = Vector2(40, 60)
	companies_vbox.size = Vector2(240, 320)
	companies_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	agenda_rect.add_child(companies_vbox)

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
	btn_next_day.text = "Processar Saidas e Finalizar Dia"
	btn_next_day.position = Vector2(20, 340)
	btn_next_day.size = Vector2(310, 40)
	btn_next_day.pressed.connect(_on_next_day_pressed)
	clipboard_rect.add_child(btn_next_day)

	active_paper_rect = ColorRect.new()
	active_paper_rect.color = Color(0.85, 0.9, 0.95) 
	active_paper_rect.size = Vector2(330, 400)
	active_paper_rect.position = Vector2(1450, 250)
	ui_layer.add_child(active_paper_rect)
	_make_draggable(active_paper_rect, "panel")

	var active_title = Label.new()
	active_title.text = "FROTA: 3 LOCOMOTIVAS A CARVAO" 
	active_title.add_theme_color_override("font_color", Color.BLACK)
	active_title.position = Vector2(20, 20)
	active_paper_rect.add_child(active_title)

	contracts_vbox = VBoxContainer.new()
	contracts_vbox.position = Vector2(20, 50)
	contracts_vbox.size = Vector2(290, 330)
	contracts_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_paper_rect.add_child(contracts_vbox)

	folder_rect = ColorRect.new()
	folder_rect.color = Color(0.8, 0.65, 0.4) 
	folder_rect.size = Vector2(440, 480)
	folder_rect.position = Vector2(740, 310) 
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
	btn_close_folder.position = Vector2(400, 10)
	btn_close_folder.size = Vector2(30, 30)
	btn_close_folder.pressed.connect(_on_close_folder_pressed)
	folder_rect.add_child(btn_close_folder)

	doc_standard = ColorRect.new()
	doc_standard.color = Color(0.95, 0.95, 0.95)
	doc_standard.size = Vector2(190, 380)
	doc_standard.position = Vector2(20, 80)
	doc_standard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	folder_rect.add_child(doc_standard)
	
	std_label = Label.new()
	std_label.position = Vector2(10, 10)
	std_label.size = Vector2(170, 300)
	std_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	std_label.add_theme_color_override("font_color", Color.BLACK)
	doc_standard.add_child(std_label)
	
	btn_call_std = Button.new()
	btn_call_std.text = "PREPARAR CONTRATO"
	btn_call_std.position = Vector2(10, 330)
	btn_call_std.size = Vector2(170, 40)
	btn_call_std.pressed.connect(_on_call_standard_pressed)
	doc_standard.add_child(btn_call_std)

	doc_urgent = ColorRect.new()
	doc_urgent.color = Color(0.95, 0.85, 0.85)
	doc_urgent.size = Vector2(190, 380)
	doc_urgent.position = Vector2(230, 80)
	doc_urgent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	folder_rect.add_child(doc_urgent)
	
	urg_label = Label.new()
	urg_label.position = Vector2(10, 10)
	urg_label.size = Vector2(170, 300)
	urg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	urg_label.add_theme_color_override("font_color", Color.DARK_RED)
	doc_urgent.add_child(urg_label)
	
	btn_call_urg = Button.new()
	btn_call_urg.text = "PREPARAR URGENCIA"
	btn_call_urg.position = Vector2(10, 330)
	btn_call_urg.size = Vector2(170, 40)
	btn_call_urg.pressed.connect(_on_call_urgent_pressed)
	doc_urgent.add_child(btn_call_urg)

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

	outbox_rect = ColorRect.new()
	outbox_rect.color = Color(0.15, 0.1, 0.05) 
	outbox_rect.size = Vector2(330, 180)
	outbox_rect.position = Vector2(1450, 40)
	outbox_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(outbox_rect)
	
	var outbox_title = Label.new()
	outbox_title.text = "CAIXA DE SAIDA\n(Enviar por Correio)"
	outbox_title.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	outbox_title.position = Vector2(20, 20)
	outbox_rect.add_child(outbox_title)

	trash_rect = ColorRect.new()
	trash_rect.color = Color(0.1, 0.1, 0.12)
	trash_rect.size = Vector2(120, 120)
	trash_rect.position = Vector2(1750, 920)
	trash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(trash_rect)
	
	var trash_lbl = Label.new()
	trash_lbl.text = "LIXEIRA\n(Rasgar)"
	trash_lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
	trash_lbl.position = Vector2(10, 30)
	trash_rect.add_child(trash_lbl)

	stamp_approve = ColorRect.new()
	stamp_approve.color = Color(0.2, 0.5, 0.2)
	stamp_approve.size = Vector2(80, 100)
	stamp_approve.position = Vector2(800, 850)
	ui_layer.add_child(stamp_approve)
	_make_draggable(stamp_approve, "stamp_approve")
	
	var lbl_a = Label.new()
	lbl_a.text = "APROVAR"
	lbl_a.position = Vector2(5, 40)
	stamp_approve.add_child(lbl_a)

	stamp_reject = ColorRect.new()
	stamp_reject.color = Color(0.6, 0.2, 0.2)
	stamp_reject.size = Vector2(80, 100)
	stamp_reject.position = Vector2(920, 850)
	ui_layer.add_child(stamp_reject)
	_make_draggable(stamp_reject, "stamp_reject")
	
	var lbl_r = Label.new()
	lbl_r.text = "REJEITAR"
	lbl_r.position = Vector2(5, 40)
	stamp_reject.add_child(lbl_r)

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
	radio_lbl.text = "RADIO PTT\nFREQ 104.2"
	radio_lbl.add_theme_color_override("font_color", Color.BLACK)
	radio_lbl.position = Vector2(150, 20)
	radio_rect.add_child(radio_lbl)
	
	radio_led = ColorRect.new()
	radio_led.color = Color(0.2, 0.05, 0.05) 
	radio_led.size = Vector2(20, 20)
	radio_led.position = Vector2(150, 70)
	radio_led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radio_rect.add_child(radio_led)

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
	if type == "panel" or type == "radio" or type.begins_with("stamp"):
		original_transforms[panel] = panel.position

func _on_panel_gui_input(event: InputEvent, panel: Control) -> void:
	var type = panel.get_meta("drag_type")
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				if event.double_click:
					if type == "paper":
						var current_stamp = panel.get_meta("stamp")
						if current_stamp != "":
							_fold_paper(panel)
				else:
					dragged_panel = panel
					drag_offset = panel.get_global_mouse_position() - panel.global_position
					panel.get_parent().move_child(panel, -1) 
					if type == "panel" or type == "paper":
						panel.rotation_degrees = 0 
			else:
				if dragged_panel == panel:
					dragged_panel = null
					
					if type == "stamp_approve" or type == "stamp_reject":
						_try_stamp_papers(panel.get_global_mouse_position(), type)
						var tw = create_tween()
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
								_clamp_to_screen(panel)
								_try_outbox_paper(panel)
							else:
								if type == "panel":
									panel.rotation_degrees = randf_range(-3.0, 3.0) 
									_clamp_to_screen(panel)
	else:
		if event is InputEventMouseMotion:
			if dragged_panel == panel:
				panel.global_position = panel.get_global_mouse_position() - drag_offset
				_clamp_to_screen(panel)

func _clamp_to_screen(panel: Control) -> void:
	var s = get_viewport_rect().size
	var p = panel.global_position
	var sz = panel.size
	p.x = clamp(p.x, 0, s.x - sz.x)
	p.y = clamp(p.y, 0, s.y - sz.y)
	panel.global_position = p

func _try_stamp_papers(stamp_pos: Vector2, stamp_type: String) -> void:
	for i in range(spawned_papers.size() - 1, -1, -1):
		var p = spawned_papers[i]
		if p.get_global_rect().has_point(stamp_pos):
			if p.get_meta("is_folded"):
				return
				
			var current_stamp = p.get_meta("stamp")
			if current_stamp == "":
				p.set_meta("stamp", stamp_type)
				
				var mark = Label.new()
				if stamp_type == "stamp_approve":
					mark.text = "[ APROVADO ]"
					mark.add_theme_color_override("font_color", Color(0.1, 0.6, 0.1, 0.8))
				else:
					mark.text = "[ REJEITADO ]"
					mark.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1, 0.8))
				
				mark.add_theme_font_size_override("font_size", 36)
				mark.rotation_degrees = randf_range(-15.0, 15.0)
				mark.position = p.get_local_mouse_position() - Vector2(100, 20)
				p.add_child(mark)
			return 

func _fold_paper(paper: Control) -> void:
	if paper.get_meta("is_folded"):
		return
		
	paper.set_meta("is_folded", true)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(paper, "size", Vector2(180, 110), 0.2)
	tween.tween_property(paper, "color", Color(0.85, 0.75, 0.6), 0.2) 
	
	for child in paper.get_children():
		child.visible = false
		
	var seal_bg = ColorRect.new()
	seal_bg.color = Color(0.1, 0.1, 0.1, 0.1)
	seal_bg.size = Vector2(160, 90)
	seal_bg.position = Vector2(10, 10)
	paper.add_child(seal_bg)
		
	var seal = Label.new()
	var s = paper.get_meta("stamp")
	if s == "stamp_approve":
		seal.text = "[ APROVADO ]\nLacrado"
		seal.add_theme_color_override("font_color", Color(0.1, 0.5, 0.1))
	else:
		seal.text = "[ REJEITADO ]\nLacrado"
		seal.add_theme_color_override("font_color", Color(0.6, 0.1, 0.1))
		
	seal.add_theme_font_size_override("font_size", 20)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.position = Vector2(10, 25)
	seal.size = Vector2(160, 60)
	paper.add_child(seal)

func _try_outbox_paper(paper: Control) -> void:
	var center = paper.global_position + (paper.size / 2.0)
	if outbox_rect.get_global_rect().has_point(center):
		if paper.get_meta("is_folded"):
			spawned_papers.erase(paper)
			outbox_papers.append(paper)
			
			var tween = create_tween().set_parallel(true)
			var offset = outbox_papers.size() * 5
			var target_pos = outbox_rect.global_position + Vector2(30 + offset, 40 - offset)
			tween.tween_property(paper, "global_position", target_pos, 0.2)
			tween.tween_property(paper, "rotation_degrees", randf_range(-3.0, 3.0), 0.2)
			
			paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		if trash_rect.get_global_rect().has_point(center):
			spawned_papers.erase(paper)
			paper.queue_free()
			_load_agenda_contacts()

func _on_organize_pressed() -> void:
	var tween = create_tween().set_parallel(true)
	for panel in original_transforms.keys():
		if is_instance_valid(panel):
			tween.tween_property(panel, "position", original_transforms[panel], 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(panel, "rotation_degrees", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _setup_cutscene() -> void:
	phone_cutscene = CutsceneDialog.new()
	add_child(phone_cutscene)
	phone_cutscene.contract_accepted.connect(_on_cutscene_accepted)
	phone_cutscene.contract_rejected.connect(_on_cutscene_rejected)
	phone_cutscene.call_closed.connect(_on_cutscene_closed)
	phone_cutscene.cancel_confirmed.connect(_on_cancel_confirmed)
	phone_cutscene.radio_choice_made.connect(_on_radio_choice)

func _update_diretrizes() -> void:
	var lvl = LevelData.LEVELS[GameManager.current_level]
	var m = lvl["goal"]
	var a = GameManager.money
	
	diretrizes_label.text = "📌 DIRETRIZES DA REGIAO [" + lvl["name"] + "]  |  META: $" + str(m) + "  |  CAIXA: $" + str(a)
	
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
	for child in companies_vbox.get_children(): 
		child.queue_free()
		
	var companies = LevelData.LEVELS[GameManager.current_level]["companies"].duplicate(true)
	companies.append_array(GameManager.daily_generic_companies)
	
	for i in range(companies.size()):
		var c_data = companies[i]
		var c_name = c_data["name"]
		var btn = Button.new()
		
		var is_daily = "(Diario)" in c_name
		if GameManager.company_cooldowns.has(c_name) and GameManager.company_cooldowns[c_name] > 0 and not (is_daily and GameManager.current_day == 1):
			btn.text = c_name + " (" + str(GameManager.company_cooldowns[c_name]) + "d)"
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color.INDIAN_RED)
		else:
			var has_active = false
			for contract in GameManager.active_contracts:
				if contract.has("company_name") and contract["company_name"] == c_name: 
					has_active = true
					
			var has_pending = false
			for p in spawned_papers:
				if is_instance_valid(p) and p.has_meta("company_data") and p.get_meta("company_data")["name"] == c_name:
					has_pending = true
			for p in outbox_papers:
				if is_instance_valid(p) and p.has_meta("company_data") and p.get_meta("company_data")["name"] == c_name:
					has_pending = true
					
			if has_active: 
				btn.text = c_name + " (EM CURSO)"
				btn.disabled = true
				btn.add_theme_color_override("font_color", Color.DIM_GRAY)
			else:
				if has_pending:
					btn.text = c_name + " (AGUARDANDO)"
					btn.disabled = true
					btn.add_theme_color_override("font_color", Color.DIM_GRAY)
				else:
					if GameManager.daily_urgencies.has(c_name): 
						btn.text = c_name + " [!]"
						btn.add_theme_color_override("font_color", Color.DARK_RED)
					else: 
						btn.text = c_name
					btn.pressed.connect(_on_company_selected.bind(c_data))
				
		btn.custom_minimum_size = Vector2(200, 30)
		companies_vbox.add_child(btn)

func _on_company_selected(data: Dictionary) -> void:
	selected_company_data = data
	folder_title.text = "CLIENTE: " + data["name"]
	folder_route.text = "Exige Rota: " + data["route_name"]
	
	std_label.text = "CONTRATO PADRAO\n\nCarga: " + data["cargo"] + "\n\nDuracao: 5-10 dias\nPagamento: ~$" + str(data["base_reward"]) + "\n\nTEL: " + data["phone"]
	btn_call_std.text = "PREPARAR CONTRATO"
	
	if GameManager.daily_urgencies.has(data["name"]):
		doc_urgent.visible = true
		urg_label.text = "[!] URGENDA HOJE\n\nPAGAMENTO A VISTA:\n$" + str(GameManager.daily_urgencies[data["name"]]) + "\n\nOcupa trem por 1 dia."
		btn_call_urg.text = "PREPARAR URGENCIA"
	else: 
		doc_urgent.visible = false
		
	folder_rect.visible = true
	folder_rect.get_parent().move_child(folder_rect, -1)
	folder_rect.rotation_degrees = 0
	_clamp_to_screen(folder_rect)

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
			var is_long = (ctype == "Expresso" and stats.get("dist", 999) > pending_company_data.get("max_dist", 999))
			if is_long:
				reason = "Rota longa!"
			if not is_long:
				var is_vip_bad = (ctype == "VIP" and (stats.get("gangs", 0) > 0 or GameManager.active_contracts.size() > 0))
				if is_vip_bad:
					reason = "VIP exige seguranca/exclusividade!"
				if not is_vip_bad:
					var is_eco_bad = (ctype == "Ecologico" and stats.get("forests", 0) > 0)
					if is_eco_bad:
						reason = "Crime ambiental!"
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

func _spawn_proposal_paper(c_data: Dictionary, is_urg: bool, reward: int) -> void:
	var paper = ColorRect.new()
	
	if is_urg:
		paper.color = Color(0.95, 0.8, 0.8) 
		paper.size = Vector2(280, 350)
	else:
		paper.color = Color(0.95, 0.95, 0.85) 
		paper.size = Vector2(300, 450)

	paper.position = Vector2(800 + randf_range(-30, 30), 200 + randf_range(-30, 30))
	paper.rotation_degrees = randf_range(-5, 5)

	var content = Label.new()
	content.add_theme_color_override("font_color", Color.BLACK)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.size = paper.size - Vector2(40, 40)
	content.position = Vector2(20, 20)

	var text = "TERMO DE TRANSPORTE\n\n"
	text += "Empresa: " + c_data["name"] + "\n"
	text += "Carga: " + c_data["cargo"] + "\n"
	text += "Rota Exigida: " + c_data["route_name"] + "\n\n"
	
	if is_urg:
		text += "[ URGENCIA MAXIMA ]\nPagamento a vista: $" + str(reward) + "\nValidade: 1 dia\n"
	else:
		text += "Contrato Padrao (5-10 dias)\nPagamento Diario: $" + str(reward) + "\n"

	var flav = "Termos padrao de logistica se aplicam. A Cia de Entregas Ferroviarias responsabiliza-se pela carga a partir do embarque."
	text += "\nNota: " + flav + "\n\n"
	
	if pending_is_risk:
		text += "[ATENCAO: CONTRATO DE RISCO]\nVia inexistente ou em obras.\nPrazo estrito: 3 dias para iniciar a operacao."
	else:
		text += "(Aguardando Parecer da Gestao...)"
	
	content.text = text
	paper.add_child(content)

	paper.set_meta("is_paper", true)
	paper.set_meta("company_data", c_data)
	paper.set_meta("is_urgent", is_urg)
	paper.set_meta("reward", reward)
	paper.set_meta("stamp", "") 
	paper.set_meta("is_folded", false) 
	paper.set_meta("is_risk", pending_is_risk)

	_make_draggable(paper, "paper")
	ui_layer.add_child(paper)
	spawned_papers.append(paper)
	
	_load_agenda_contacts()

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
		phone_cutscene.start_rejection_call("FISCALIZACAO", "O comboio esta retido na zona de obras! Impossivel resgatar a carga ou cancelar o contrato agora. Conclua as obras e espere a via libertar!")
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

func _update_task_pad() -> void:
	for child in task_vbox.get_children():
		child.queue_free()
		
	var has_tasks = false
	
	for c in GameManager.active_contracts:
		if c.has("pending_route_days"):
			var l = Label.new()
			l.text = "[ ] Via p/ " + c["route_name"] + " (" + str(c["pending_route_days"]) + "d)"
			l.add_theme_color_override("font_color", Color(0.7, 0.1, 0.1))
			l.add_theme_font_size_override("font_size", 14)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(260, 0)
			task_vbox.add_child(l)
			has_tasks = true
			
	for k in GameManager.routes_under_construction.keys():
		var d = GameManager.routes_under_construction[k]
		if d > 0:
			var l = Label.new()
			l.text = "[ ] Aguardar Obras na Via (" + str(d) + "d)"
			l.add_theme_color_override("font_color", Color(0.2, 0.2, 0.6))
			l.add_theme_font_size_override("font_size", 14)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(260, 0)
			task_vbox.add_child(l)
			has_tasks = true
			break 
			
	if GameManager.money < 0:
		var l = Label.new()
		l.text = "[!] SALDO NEGATIVO! Gerar receita URGENTE!"
		l.add_theme_color_override("font_color", Color.RED)
		l.add_theme_font_size_override("font_size", 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(260, 0)
		task_vbox.add_child(l)
		has_tasks = true
		
	if not has_tasks:
		var l = Label.new()
		l.text = "Tudo em ordem. Tome um cafe."
		l.add_theme_color_override("font_color", Color.DIM_GRAY)
		l.add_theme_font_size_override("font_size", 14)
		task_vbox.add_child(l)

func _update_active_contracts_text() -> void:
	for child in contracts_vbox.get_children(): 
		child.queue_free()
		
	if GameManager.active_contracts.size() == 0:
		var l = Label.new()
		l.text = "\nPatio vazio."
		l.add_theme_color_override("font_color", Color.DIM_GRAY)
		contracts_vbox.add_child(l)
	else:
		var i = 0
		for c in GameManager.active_contracts:
			var hbox = HBoxContainer.new()
			var is_act = GameManager.is_contract_operating(c)
			var st = ""
			var cl = Label.new()
			
			if c.has("pending_route_days"):
				st = "[AGUARDANDO VIA: " + str(c["pending_route_days"]) + "d]"
				cl.add_theme_color_override("font_color", Color.DARK_GOLDENROD)
			else:
				if is_act: 
					if c.get("is_urgent", false):
						st = "[PAGO]"
					else:
						st = "(+$" + str(c["reward"]) + ")"
					cl.add_theme_color_override("font_color", Color.DARK_SLATE_GRAY)
				else:
					cl.add_theme_color_override("font_color", Color.INDIAN_RED)
					if GameManager.routes_under_construction.get(c["route_id"], 0) > 0:
						st = "[OBRAS: " + str(GameManager.routes_under_construction[c["route_id"]]) + "d]"
					else:
						if not (c["route_id"] in GameManager.network_connections): 
							st = "[SEM ROTA]"
						else: 
							var tp = c.get("type", "")
							var stats = GameManager.network_stats.get(c["route_id"], {})
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
									
			cl.text = "T" + str(i + 1) + ": " + c["cargo"] + "\n" + c["route_name"] + " " + st + "\n" + str(c["days_left"]) + "d"
			cl.custom_minimum_size = Vector2(230, 0)
			hbox.add_child(cl)
			
			var b = Button.new()
			b.text = "X"
			b.pressed.connect(_on_cancel_dynamic.bind(i))
			hbox.add_child(b)
			contracts_vbox.add_child(hbox)
			i += 1

# NOVO: Injeta as despesas de Equipa e Lobby no Resumo Financeiro da Mesa
func _update_report_text() -> void:
	var inc = GameManager.get_daily_income()
	var exp = GameManager.daily_maintenance + GameManager.BASE_COST + GameManager.daily_gang_toll + GameManager.daily_crew_cost + GameManager.daily_lobby_cost
	var net = inc - exp
	
	var t = "RELATORIO ADMINISTRATIVO\n\nDia: " + str(GameManager.current_day) + "\nCaixa: $" + str(GameManager.money) + "\n\nReceita: +$" + str(inc) + "\nManutencao Via: -$" + str(GameManager.daily_maintenance) + "\nTaxas e Base: -$" + str(GameManager.BASE_COST)
	
	if GameManager.daily_crew_cost > 0:
		t += "\nSalarios (Equipa): -$" + str(GameManager.daily_crew_cost)
	if GameManager.daily_lobby_cost > 0:
		t += "\nLobby/Estado: -$" + str(GameManager.daily_lobby_cost)
	if GameManager.daily_gang_toll > 0: 
		t += "\nPropinas (Gangues): -$" + str(GameManager.daily_gang_toll)
		
	t += "\n----------------\nLucro: $" + str(net)
	report_label.text = t
	
	btn_next_day.disabled = false
	btn_next_day.text = "Processar Saidas e Finalizar Dia"

func _on_next_day_pressed() -> void: 
	var new_c_count = 0
	var rej_c_count = 0
	pending_upfront_income = 0
	
	for paper in outbox_papers:
		if is_instance_valid(paper):
			var stamp = paper.get_meta("stamp")
			var c_data = paper.get_meta("company_data")
			var is_urg = paper.get_meta("is_urgent")
			var rew = paper.get_meta("reward")
			var is_risk = paper.get_meta("is_risk")
			
			if stamp == "stamp_approve":
				new_c_count += 1
				
				var new_c = {"company_name": c_data["name"], "type": c_data["type"], "cargo": c_data["cargo"], "route_id": c_data["route_id"], "route_name": c_data["route_name"], "reward": rew, "days_left": randi_range(5, 10), "is_urgent": false}
				if is_urg:
					pending_upfront_income += rew
					new_c["cargo"] = "[URG] " + c_data["cargo"]
					new_c["reward"] = 0
					new_c["days_left"] = 1
					new_c["is_urgent"] = true
					
				if c_data.has("max_dist"): 
					new_c["max_dist"] = c_data["max_dist"]
					
				if is_risk:
					new_c["pending_route_days"] = 3
					
				GameManager.active_contracts.append(new_c)
			else:
				if stamp == "stamp_reject":
					rej_c_count += 1
					GameManager.company_cooldowns[c_data["name"]] = 3
			
			paper.queue_free()
			
	outbox_papers.clear()
	GameManager.contracts_updated.emit()
	
	_start_eod_animation(new_c_count, rej_c_count)

# NOVO: Injeta as despesas de Equipa e Lobby na impressao do Recibo Diário
func _start_eod_animation(new_c: int, rej_c: int) -> void:
	skip_eod_anim = false
	eod_layer.visible = true
	btn_eod_sleep.visible = false
	
	for child in eod_lines_container.get_children():
		child.queue_free()
		
	var c_light = Color(0.8, 0.8, 0.8)
	var c_gray = Color(0.5, 0.5, 0.5)
	var c_green = Color(0.2, 0.8, 0.2)
	var c_red = Color(0.8, 0.2, 0.2)
	
	_add_eod_line("== BOLETIM DIARIO - DIA " + str(GameManager.current_day) + " ==", "", c_light, true)
	_add_eod_line("", "", c_light, false)
	_add_eod_line("[ LOGISTICA ]", "", c_gray, false)
	
	var active_count = 0
	for c in GameManager.active_contracts:
		if GameManager.is_contract_operating(c):
			active_count += 1
			
	_add_eod_line("Entregas Operando", str(active_count), c_light, false)
	_add_eod_line("Contratos Fechados", str(new_c), c_light, false)
	_add_eod_line("Propostas Rejeitadas", str(rej_c), c_light, false)
	_add_eod_line("Contratos Rompidos", str(GameManager.today_broken_contracts), c_light, false)
	
	if GameManager.today_penalties > 0:
		_add_eod_line("Multas Aplicadas Hoje", "-$" + str(GameManager.today_penalties), c_red, false)
		
	_add_eod_line("", "", c_light, false)
	_add_eod_line("[ FINANCAS ]", "", c_gray, false)
	_add_eod_line("Saldo Inicial", "$" + str(GameManager.money), c_light, false)
	
	if pending_upfront_income > 0:
		_add_eod_line("Receitas a Vista", "+$" + str(pending_upfront_income), c_green, false)
		
	var inc = GameManager.get_daily_income()
	if inc > 0:
		_add_eod_line("Receita de Fretes", "+$" + str(inc), c_green, false)
		
	if GameManager.daily_maintenance > 0:
		_add_eod_line("Manutencao da Via", "-$" + str(GameManager.daily_maintenance), c_red, false)
		
	_add_eod_line("Custos Base da Garagem", "-$" + str(GameManager.BASE_COST), c_red, false)
	
	if GameManager.daily_crew_cost > 0:
		_add_eod_line("Salarios da Equipa", "-$" + str(GameManager.daily_crew_cost), c_red, false)
	if GameManager.daily_lobby_cost > 0:
		_add_eod_line("Lobby Governamental", "-$" + str(GameManager.daily_lobby_cost), c_red, false)
	if GameManager.daily_gang_toll > 0:
		_add_eod_line("Extorsao (Gangues)", "-$" + str(GameManager.daily_gang_toll), c_red, false)
		
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
	
	if _v == 1:
		for p in spawned_papers:
			if is_instance_valid(p):
				p.queue_free()
		spawned_papers.clear()
		for p in outbox_papers:
			if is_instance_valid(p):
				p.queue_free()
		outbox_papers.clear()

func _on_visibility_changed() -> void:
	if ui_layer: 
		ui_layer.visible = visible
	if visible:
		_load_agenda_contacts()
		_update_report_text()
		_update_diretrizes()
		_update_task_pad()
		folder_rect.visible = false 
		
		_on_organize_pressed()
		
		if GameManager.pendent_angry_call: 
			GameManager.pendent_angry_call = false
			phone_cutscene.start_angry_call()
		else:
			if not GameManager.intro_played:
				GameManager.intro_played = true
				phone_cutscene.start_boss_intro()

func _on_back_map_pressed() -> void: 
	get_parent().go_to_map()
