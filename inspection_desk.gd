extends Node2D

var ui_layer: CanvasLayer
var bg_rect: ColorRect
var conveyor: ColorRect

# Elementos da Caixa
var box_visual: ColorRect
var box_stamp: ColorRect
var box_xray_poly: Polygon2D

# Manifesto / Prancheta
var clip_content: Label
var clip_weight: Label
var clip_stamp: Label

# Balança
var scale_needle: ColorRect
var lbl_scale_digital: Label

# Painel de Controle
var btn_lever: Button
var btn_xray: Button
var btn_approve_pkg: Button
var btn_reject_pkg: Button

# --- NOVO: UI DA FROTA ---
var fleet_panel: ColorRect
var fleet_vbox: VBoxContainer

# HUD e Alertas
var lbl_queue_count: Label
var strike_lights: Array = []
var lbl_strike_warning: Label
var btn_go_desk: Button
var overlay_block: ColorRect
var lbl_block: Label

var current_package: Dictionary = {}
var is_xray_on: bool = false

func _ready() -> void:
	_setup_ui()
	GameManager.package_queue_updated.connect(_on_queue_updated)
	GameManager.strike_received.connect(_on_strike_received)
	GameManager.shift_ended.connect(_on_shift_ended)
	visibility_changed.connect(_on_visibility_changed)

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# Fundo da Sala
	bg_rect = ColorRect.new()
	bg_rect.color = Color(0.12, 0.14, 0.16)
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(bg_rect)
	
	# Botão Voltar (Canto Superior Esquerdo)
	btn_go_desk = Button.new()
	btn_go_desk.text = "<- Voltar ao Escritório"
	btn_go_desk.position = Vector2(40, 70)
	btn_go_desk.size = Vector2(250, 50)
	btn_go_desk.pressed.connect(_on_go_desk_pressed)
	ui_layer.add_child(btn_go_desk)
	
	# Contador de Fila
	lbl_queue_count = Label.new()
	lbl_queue_count.text = "FILA: 0 ENCOMENDAS"
	lbl_queue_count.add_theme_font_size_override("font_size", 28)
	lbl_queue_count.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
	lbl_queue_count.position = Vector2(40, 140)
	ui_layer.add_child(lbl_queue_count)
	
	# Painel de Multas (Canto Superior Direito)
	var strike_panel = ColorRect.new()
	strike_panel.color = Color(0.15, 0.15, 0.18)
	strike_panel.size = Vector2(300, 80)
	strike_panel.position = Vector2(1580, 70)
	ui_layer.add_child(strike_panel)
	
	var strike_border = ReferenceRect.new()
	strike_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	strike_border.border_color = Color(0.3, 0.3, 0.3)
	strike_border.border_width = 4
	strike_panel.add_child(strike_border)
	
	for i in range(3):
		var light = ColorRect.new()
		light.color = Color(0.3, 0.3, 0.1)
		light.size = Vector2(30, 30)
		light.position = Vector2(20 + (i * 45), 25)
		strike_panel.add_child(light)
		strike_lights.append(light)
		
	var lbl_multa = Label.new()
	lbl_multa.text = "= MULTA"
	lbl_multa.add_theme_color_override("font_color", Color.WHITE)
	lbl_multa.add_theme_font_size_override("font_size", 24)
	lbl_multa.position = Vector2(170, 25)
	strike_panel.add_child(lbl_multa)
	
	# Balança Analógica (Centro)
	var scale_base = ColorRect.new()
	scale_base.color = Color(0.7, 0.75, 0.7)
	scale_base.size = Vector2(320, 260)
	scale_base.position = Vector2(800, 100)
	ui_layer.add_child(scale_base)
	
	var scale_circle = ColorRect.new()
	scale_circle.color = Color(0.9, 0.9, 0.9)
	scale_circle.size = Vector2(280, 220)
	scale_circle.position = Vector2(20, 20)
	scale_base.add_child(scale_circle)
	
	var scale_center = Vector2(140, 140)
	for i in range(11):
		var angle = lerp(-PI * 0.8, PI * 0.8, i / 10.0)
		var tick = ColorRect.new()
		tick.color = Color.BLACK
		tick.size = Vector2(6, 20)
		tick.pivot_offset = Vector2(3, 10)
		tick.position = (scale_center + Vector2(sin(angle), -cos(angle)) * 100) - tick.pivot_offset
		tick.rotation = angle
		scale_circle.add_child(tick)
		
	scale_needle = ColorRect.new()
	scale_needle.color = Color(0.8, 0.1, 0.1)
	scale_needle.size = Vector2(8, 120)
	scale_needle.pivot_offset = Vector2(4, 100)
	scale_needle.position = scale_center - Vector2(4, 100)
	scale_needle.rotation = -PI * 0.8
	scale_circle.add_child(scale_needle)
	
	lbl_scale_digital = Label.new()
	lbl_scale_digital.text = "0.0 kg"
	lbl_scale_digital.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_scale_digital.add_theme_color_override("font_color", Color.BLACK)
	lbl_scale_digital.add_theme_font_size_override("font_size", 28)
	lbl_scale_digital.position = Vector2(0, 160)
	lbl_scale_digital.size = Vector2(280, 40)
	scale_circle.add_child(lbl_scale_digital)
	
	# Prancheta / Manifesto (Esquerda)
	var clipboard_bg = ColorRect.new()
	clipboard_bg.color = Color(0.85, 0.8, 0.65)
	clipboard_bg.size = Vector2(300, 450)
	clipboard_bg.position = Vector2(200, 150)
	ui_layer.add_child(clipboard_bg)
	
	var clip_metal = ColorRect.new()
	clip_metal.color = Color(0.4, 0.4, 0.45)
	clip_metal.size = Vector2(150, 30)
	clip_metal.position = Vector2(75, 10)
	clipboard_bg.add_child(clip_metal)
	
	var clip_title = Label.new()
	clip_title.text = "MANIFESTO DE CARGA"
	clip_title.add_theme_color_override("font_color", Color.BLACK)
	clip_title.add_theme_font_size_override("font_size", 20)
	clip_title.position = Vector2(20, 60)
	clipboard_bg.add_child(clip_title)
	
	clip_content = Label.new()
	clip_content.add_theme_color_override("font_color", Color.BLACK)
	clip_content.add_theme_font_size_override("font_size", 22)
	clip_content.position = Vector2(20, 120)
	clipboard_bg.add_child(clip_content)
	
	clip_weight = Label.new()
	clip_weight.add_theme_color_override("font_color", Color.BLACK)
	clip_weight.add_theme_font_size_override("font_size", 22)
	clip_weight.position = Vector2(20, 220)
	clipboard_bg.add_child(clip_weight)
	
	clip_stamp = Label.new()
	clip_stamp.add_theme_color_override("font_color", Color.BLACK)
	clip_stamp.add_theme_font_size_override("font_size", 22)
	clip_stamp.position = Vector2(20, 320)
	clipboard_bg.add_child(clip_stamp)

	# Esteira Gigante (Base)
	conveyor = ColorRect.new()
	conveyor.color = Color(0.10, 0.11, 0.12)
	conveyor.size = Vector2(1920, 480)
	conveyor.position = Vector2(0, 600)
	ui_layer.add_child(conveyor)
	
	for i in range(25):
		var roller = ColorRect.new()
		roller.color = Color(0.2, 0.22, 0.25)
		roller.size = Vector2(20, 480)
		roller.position = Vector2(i * 80, 0)
		conveyor.add_child(roller)
		
	# A Caixa de Encomenda
	box_visual = ColorRect.new()
	box_visual.size = Vector2(350, 280)
	box_visual.position = Vector2(-500, 650)
	box_visual.visible = false
	ui_layer.add_child(box_visual)
	
	box_stamp = ColorRect.new()
	box_stamp.size = Vector2(80, 80)
	box_stamp.position = Vector2(240, 30)
	box_visual.add_child(box_stamp)
	
	box_xray_poly = Polygon2D.new()
	box_xray_poly.color = Color(0.05, 0.2, 0.05, 0.9)
	box_xray_poly.visible = false
	box_visual.add_child(box_xray_poly)
	
	# Scanner Arch (Arco do Scanner)
	var scanner_arch = ColorRect.new()
	scanner_arch.color = Color(0.12, 0.12, 0.15, 0.85)
	scanner_arch.size = Vector2(450, 520)
	scanner_arch.position = Vector2(735, 560)
	ui_layer.add_child(scanner_arch)
	
	# Painel de Controle (Direita Inferior)
	var control_panel = ColorRect.new()
	control_panel.color = Color(0.2, 0.22, 0.25)
	control_panel.size = Vector2(450, 380)
	control_panel.position = Vector2(1400, 650)
	ui_layer.add_child(control_panel)
	
	var cp_border = ReferenceRect.new()
	cp_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	cp_border.border_color = Color(0.1, 0.1, 0.12)
	cp_border.border_width = 8
	control_panel.add_child(cp_border)
	
	# Estilos de Botão
	var base_style = StyleBoxFlat.new()
	base_style.border_width_bottom = 12
	base_style.corner_radius_top_left = 20
	base_style.corner_radius_top_right = 20
	base_style.corner_radius_bottom_left = 20
	base_style.corner_radius_bottom_right = 20
	base_style.shadow_color = Color(0, 0, 0, 0.6)
	base_style.shadow_size = 6
	base_style.shadow_offset = Vector2(0, 6)

	var disabled_style = base_style.duplicate()
	disabled_style.bg_color = Color(0.25, 0.25, 0.25)
	disabled_style.border_color = Color(0.4, 0.4, 0.4)
	disabled_style.border_width_bottom = 4
	disabled_style.shadow_size = 0

	# Botão Puxar Alavanca
	btn_lever = Button.new()
	btn_lever.text = "CHAMAR ENCOMENDA"
	btn_lever.size = Vector2(390, 80)
	btn_lever.position = Vector2(30, 30)
	var btn_lever_normal = base_style.duplicate()
	btn_lever_normal.bg_color = Color(0.8, 0.5, 0.1)
	btn_lever.add_theme_stylebox_override("normal", btn_lever_normal)
	btn_lever.add_theme_stylebox_override("disabled", disabled_style)
	btn_lever.add_theme_font_size_override("font_size", 22)
	btn_lever.add_theme_color_override("font_color", Color.WHITE)
	btn_lever.pressed.connect(_on_btn_lever_pressed)
	control_panel.add_child(btn_lever)

	# Botão Raio-X
	btn_xray = Button.new()
	btn_xray.text = "LIGAR RAIO-X (-$15)"
	btn_xray.size = Vector2(390, 80)
	btn_xray.position = Vector2(30, 120)
	var btn_xray_normal = base_style.duplicate()
	btn_xray_normal.bg_color = Color(0.2, 0.45, 0.8)
	btn_xray.add_theme_stylebox_override("normal", btn_xray_normal)
	btn_xray.add_theme_stylebox_override("disabled", disabled_style)
	btn_xray.add_theme_font_size_override("font_size", 22)
	btn_xray.add_theme_color_override("font_color", Color.WHITE)
	btn_xray.pressed.connect(_on_btn_xray_pressed)
	control_panel.add_child(btn_xray)

	# Botão Aprovar
	btn_approve_pkg = Button.new()
	btn_approve_pkg.text = "APROVAR CARGA"
	btn_approve_pkg.size = Vector2(390, 70)
	btn_approve_pkg.position = Vector2(30, 210)
	var btn_app_normal = base_style.duplicate()
	btn_app_normal.bg_color = Color(0.2, 0.65, 0.25)
	btn_approve_pkg.add_theme_stylebox_override("normal", btn_app_normal)
	btn_approve_pkg.add_theme_stylebox_override("disabled", disabled_style)
	btn_approve_pkg.add_theme_font_size_override("font_size", 20)
	btn_approve_pkg.add_theme_color_override("font_color", Color.WHITE)
	btn_approve_pkg.pressed.connect(_on_approve_pkg_pressed)
	control_panel.add_child(btn_approve_pkg)
	
	# Botão Rejeitar
	btn_reject_pkg = Button.new()
	btn_reject_pkg.text = "DEVOLVER (FRAUDE)"
	btn_reject_pkg.size = Vector2(390, 70)
	btn_reject_pkg.position = Vector2(30, 290)
	var btn_rej_normal = base_style.duplicate()
	btn_rej_normal.bg_color = Color(0.8, 0.2, 0.2)
	btn_reject_pkg.add_theme_stylebox_override("normal", btn_rej_normal)
	btn_reject_pkg.add_theme_stylebox_override("disabled", disabled_style)
	btn_reject_pkg.add_theme_font_size_override("font_size", 20)
	btn_reject_pkg.add_theme_color_override("font_color", Color.WHITE)
	btn_reject_pkg.pressed.connect(_on_reject_pkg_pressed)
	control_panel.add_child(btn_reject_pkg)
	
	
	# --- NOVO: PAINEL DE FROTA ---
	fleet_panel = ColorRect.new()
	fleet_panel.color = Color(0.15, 0.18, 0.2, 0.95)
	fleet_panel.size = Vector2(450, 250)
	fleet_panel.position = Vector2(1400, 380) # Fica exatamente em cima do control_panel
	ui_layer.add_child(fleet_panel)
	
	var fp_border = ReferenceRect.new()
	fp_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	fp_border.border_color = Color(0.4, 0.6, 0.8)
	fp_border.border_width = 4
	fleet_panel.add_child(fp_border)
	
	var fp_title = Label.new()
	fp_title.text = "DESTINO DA CARGA"
	fp_title.add_theme_font_size_override("font_size", 20)
	fp_title.position = Vector2(0, 10)
	fp_title.size = Vector2(450, 30)
	fp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fleet_panel.add_child(fp_title)
	
	fleet_vbox = VBoxContainer.new()
	fleet_vbox.position = Vector2(20, 50)
	fleet_vbox.size = Vector2(410, 180)
	fleet_vbox.add_theme_constant_override("separation", 10)
	fleet_panel.add_child(fleet_vbox)
	
	fleet_panel.visible = false
	# -----------------------------
	
	
	

	lbl_strike_warning = Label.new()
	lbl_strike_warning.add_theme_color_override("font_color", Color.RED)
	lbl_strike_warning.add_theme_font_size_override("font_size", 36)
	lbl_strike_warning.size = Vector2(1000, 60)
	lbl_strike_warning.position = Vector2(460, 420)
	lbl_strike_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_strike_warning.visible = false
	ui_layer.add_child(lbl_strike_warning)

	# Tela de Bloqueio do Expediente
	overlay_block = ColorRect.new()
	overlay_block.color = Color(0, 0, 0, 0.85)
	overlay_block.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_block.visible = false
	ui_layer.add_child(overlay_block)
	
	lbl_block = Label.new()
	# --- NOVO: TEXTO ADAPTADO PARA O FIM DO TURNO B2C ---
	lbl_block.text = "TURNO DA MANHÃ ENCERRADO\nVá para a sua mesa no escritório processar os contratos."
	lbl_block.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_block.add_theme_font_size_override("font_size", 48)
	lbl_block.add_theme_color_override("font_color", Color.CRIMSON)
	lbl_block.size = Vector2(1920, 200)
	lbl_block.position = Vector2(0, 400)
	overlay_block.add_child(lbl_block)
	
	var btn_return_desk = Button.new()
	btn_return_desk.text = "VOLTAR AO ESCRITÓRIO"
	btn_return_desk.size = Vector2(400, 80)
	btn_return_desk.position = Vector2(760, 600)
	btn_return_desk.add_theme_font_size_override("font_size", 24)
	btn_return_desk.pressed.connect(_on_go_desk_pressed)
	overlay_block.add_child(btn_return_desk)

	_clear_inspection_desk()

func _on_visibility_changed() -> void:
	if ui_layer:
		ui_layer.visible = visible
	if visible:
		_on_queue_updated(GameManager.package_queue.size())
		
		# --- NOVO: CONTROLE DE BLOQUEIO BASEADO NO TURNO ---
		overlay_block.visible = false
		if not GameManager.shift_active:
			if GameManager.boss_package_intro_done:
				if GameManager.day_phase != 2:
					_on_shift_ended()
		# ---------------------------------------------------
		
		if GameManager.pendent_strike_warning != "":
			_show_strike_warning(GameManager.pendent_strike_warning)
			GameManager.pendent_strike_warning = ""



func _on_go_desk_pressed() -> void:
	var main_node = get_parent()
	if main_node.has_method("go_to_desk"):
		main_node.go_to_desk()

func _clear_inspection_desk() -> void:
	box_visual.visible = false
	is_xray_on = false
	scale_needle.rotation = -PI * 0.8
	lbl_scale_digital.text = "0.0 kg"
	clip_content.text = "Aguardando carga..."
	clip_weight.text = ""
	clip_stamp.text = ""
	btn_approve_pkg.disabled = true
	btn_reject_pkg.disabled = true
	btn_xray.disabled = true
	
	# Esconde o painel novo ao limpar a mesa
	if is_instance_valid(fleet_panel):
		fleet_panel.visible = false
		
	_sync_strike_lights(GameManager.strikes)

func _on_queue_updated(count: int) -> void:
	lbl_queue_count.text = "FILA: " + str(count) + " ENCOMENDAS"
	
	# --- NOVO: ALAVANCA FUNCIONA NA MANHÃ (COM TEMPO) OU À TARDE (B2B, SEM TEMPO) ---
	var can_pull = false
	if GameManager.shift_active or GameManager.day_phase == 2:
		can_pull = true
		
	if count > 0 and current_package.is_empty() and can_pull:
		btn_lever.disabled = false
	else:
		btn_lever.disabled = true




func _on_shift_ended() -> void:
	overlay_block.visible = true
	btn_lever.disabled = true
	btn_approve_pkg.disabled = true
	btn_reject_pkg.disabled = true
	btn_xray.disabled = true

func _on_btn_lever_pressed() -> void:
	if not current_package.is_empty() or GameManager.package_queue.size() == 0: return
	
	btn_lever.disabled = true
	current_package = GameManager.package_queue.pop_front()
	GameManager.package_queue_updated.emit(GameManager.package_queue.size())
	
	is_xray_on = false
	box_visual.color = Color(0.7, 0.55, 0.4)
	box_xray_poly.visible = false
	btn_xray.disabled = false
	
	clip_content.text = "Declarado:\n" + current_package["declared_item"]
	clip_weight.text = "\nPeso Decl.: " + str(current_package["declared_weight"]) + " kg"
	clip_stamp.text = "\nSelo: " + current_package["stamp_used"]
	
	if current_package["stamp_used"] == "Selo Branco":
		box_stamp.color = Color.WHITE
	else:
		if current_package["stamp_used"] == "Selo Verde":
			box_stamp.color = Color(0.2, 0.8, 0.2)
		else:
			if current_package["stamp_used"] == "Selo Azul":
				box_stamp.color = Color(0.2, 0.2, 0.8)
	
	# Animação: Entra pela esquerda até o centro
	box_visual.position = Vector2(-500, 650)
	box_visual.visible = true
	var tw = create_tween()
	tw.tween_property(box_visual, "position", Vector2(780, 650), 0.5).set_ease(Tween.EASE_OUT)
	
	var target_w = current_package["true_weight"]
	var angle = lerp(-PI * 0.8, PI * 0.8, clamp(target_w / 50.0, 0.0, 1.0))
	tw.parallel().tween_property(scale_needle, "rotation", angle, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	await tw.finished
	lbl_scale_digital.text = str(target_w) + " kg"
	
	# --- NOVO: MOSTRA A FROTA EM VEZ DO BOTÃO APROVAR ---
	btn_approve_pkg.visible = false 
	fleet_panel.visible = true
	_update_fleet_panel()
	
	btn_reject_pkg.disabled = false

func _on_btn_xray_pressed() -> void:
	if current_package.is_empty() or is_xray_on or GameManager.money < 15: return
	
	GameManager.money -= 15
	is_xray_on = true
	btn_xray.disabled = true
	
	box_visual.color = Color(0.1, 0.8, 0.2, 0.85)
	box_stamp.color = Color.TRANSPARENT
	
	var points = PackedVector2Array()
	if current_package.get("is_contraband", false):
		points = PackedVector2Array([Vector2(50, 140), Vector2(200, 140), Vector2(200, 120), Vector2(280, 120), Vector2(280, 140), Vector2(320, 140), Vector2(320, 160), Vector2(150, 160), Vector2(100, 210), Vector2(50, 210)])
	else:
		if current_package.get("true_category", "") == "Cartas":
			points = PackedVector2Array([Vector2(70, 120), Vector2(250, 120), Vector2(250, 210), Vector2(70, 210)])
		else:
			if current_package.get("true_category", "") == "Perecivel":
				points = PackedVector2Array([Vector2(140, 70), Vector2(190, 70), Vector2(190, 140), Vector2(230, 190), Vector2(230, 250), Vector2(100, 250), Vector2(100, 190), Vector2(140, 140)])
			else:
				if current_package.get("true_category", "") == "Valioso":
					points = PackedVector2Array([Vector2(160, 90), Vector2(230, 160), Vector2(160, 230), Vector2(90, 160)])
		
	box_xray_poly.polygon = points
	box_xray_poly.visible = true

func _on_approve_pkg_pressed() -> void:
	_process_decision(true)

func _on_reject_pkg_pressed() -> void:
	_process_decision(false)

func _process_decision(approved: bool) -> void:
	btn_approve_pkg.disabled = true
	btn_reject_pkg.disabled = true
	btn_xray.disabled = true
	
	var is_fraud = current_package.get("is_contraband", false) or current_package["true_weight"] != current_package["declared_weight"] or current_package["stamp_used"] != current_package["true_stamp"]

	if approved:
		if current_package.get("is_contraband", false):
			if not GameManager.first_fiscal_warning_done:
				GameManager.first_fiscal_warning_done = true
				GameManager.pendent_strike_warning = "AVISO OFICIAL: Aprovou carga ilegal. Multa perdoada desta vez!"
				_show_strike_warning(GameManager.pendent_strike_warning)
			else:
				var fine = 1500
				GameManager.pending_fiscal_event = {
					"reason": "CONTRABANDO: O seu posto aprovou carga ilegal oculta! O Raio-X deveria ter sido usado!",
					"fine": fine,
					"can_bribe": (GameManager.maint_pct_lobby >= 0.7),
					"bribe_cost": int(fine * 0.15),
					"contract_name": "Remetente Avulso"
				}
		else:
			if is_fraud:
				if not GameManager.first_fiscal_warning_done:
					GameManager.first_fiscal_warning_done = true
					GameManager.pendent_strike_warning = "AVISO OFICIAL: Aprovou carga com peso ou selo fraudado."
					_show_strike_warning(GameManager.pendent_strike_warning)
				else:
					if GameManager.has_method("add_strike"): GameManager.add_strike("Voce enviou uma carga com fraude!")
			else:
				if GameManager.has_method("process_package_approval"):
					GameManager.process_package_approval(current_package)
	else:
		if not is_fraud:
			if GameManager.has_method("add_strike"): GameManager.add_strike("Voce bloqueou uma carga valida.")
	
	var tw = create_tween()
	if approved:
		tw.tween_property(box_visual, "position", Vector2(1950, 650), 0.5)
	else:
		tw.tween_property(box_visual, "position", Vector2(-500, 650), 0.5)

	await tw.finished
	current_package = {}
	_clear_inspection_desk()
	_on_queue_updated(GameManager.package_queue.size())

func _sync_strike_lights(total: int) -> void:
	for i in range(3):
		if is_instance_valid(strike_lights[i]):
			if i < total:
				strike_lights[i].color = Color(0.9, 0.8, 0.1)
			else:
				strike_lights[i].color = Color(0.3, 0.3, 0.1)

	if total >= 3:
		await get_tree().create_timer(2.0).timeout
		for i in range(3):
			if is_instance_valid(strike_lights[i]):
				strike_lights[i].color = Color(0.3, 0.3, 0.1)

func _show_strike_warning(msg: String) -> void:
	lbl_strike_warning.text = "[!] " + msg
	lbl_strike_warning.visible = true
	var tw = create_tween()
	tw.tween_property(lbl_strike_warning, "modulate:a", 0.0, 0.5).set_delay(4.0)
	await tw.finished
	lbl_strike_warning.visible = false
	lbl_strike_warning.modulate.a = 1.0
	

func _on_strike_received(total: int, reason: String) -> void:
	_sync_strike_lights(total)
	_show_strike_warning(reason)
	
	
# --- NOVO: LÓGICA DE ALOCAÇÃO B2B/B2C ---
func _update_fleet_panel() -> void:
	for child in fleet_vbox.get_children():
		child.queue_free()
		
	# Cria botões dinâmicos lendo a sua frota no GameManager
	for i in range(GameManager.fleet.size()):
		var train = GameManager.fleet[i]
		var btn = Button.new()
		
		# Verifica se a caixa cabe no trem
		var is_full = train["current_weight"] + current_package.get("true_weight", 0) > train["max_weight"]
		var t_text = train["name"] + " (" + str(train["current_weight"]) + "/" + str(train["max_weight"]) + " kg)"
		
		if is_full:
			t_text += " [ EXCESSO ]"
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color.INDIAN_RED)
		if not is_full:
			btn.add_theme_color_override("font_color", Color.WHITE)
			
		btn.text = "EMBARCAR: " + t_text
		btn.custom_minimum_size = Vector2(410, 50)
		btn.pressed.connect(_on_dispatch_to_train.bind(i))
		fleet_vbox.add_child(btn)
		
	# Botão de mandar para o armazém (sempre disponível)
	var btn_wh = Button.new()
	btn_wh.text = "RETER NO ARMAZÉM"
	btn_wh.custom_minimum_size = Vector2(410, 50)
	btn_wh.add_theme_color_override("font_color", Color.GOLDENROD)
	btn_wh.pressed.connect(_on_dispatch_to_warehouse)
	fleet_vbox.add_child(btn_wh)

func _on_dispatch_to_train(train_index: int) -> void:
	fleet_panel.visible = false
	
	# --- NOVO: SOMANDO O PESO E SALVANDO NO TREM ---
	var weight = current_package.get("true_weight", 0.0)
	GameManager.fleet[train_index]["current_weight"] += weight
	GameManager.fleet[train_index]["loaded_packages"].append(current_package.duplicate())
	
	_process_decision(true)
	
func _on_dispatch_to_warehouse() -> void:
	fleet_panel.visible = false
	
	# --- NOVO: SALVANDO A CARGA NO ARMAZÉM ---
	GameManager.warehouse.append(current_package.duplicate())
	
	_process_decision(true)
