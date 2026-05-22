extends Node

signal money_changed(new_amount)
signal day_changed(new_day)
signal maintenance_updated(new_maintenance)
signal contracts_updated() 
signal game_over(is_victory: bool, message: String)

# SINAIS DA TRIAGEM
signal package_queue_updated(count: int)
signal strike_received(total_strikes: int, reason: String)

var pending_fiscal_event: Dictionary = {}
var current_level: int = 1
var highest_unlocked_level: int = 1
var start_in_world_map: bool = true 

var money: int = 1500 :
	set(value):
		money = value
		money_changed.emit(money)

var current_day: int = 1 :
	set(value):
		current_day = value
		day_changed.emit(current_day)

var daily_maintenance: int = 0 :
	set(value):
		daily_maintenance = value
		maintenance_updated.emit(daily_maintenance)
		
		
		

# === VARIÁVEIS DA TRIAGEM E PESAGEM ===
var package_queue: Array = []
var strikes: int = 0
var pendent_strike_warning: String = ""
var package_timer: float = 0.0
const PACKAGE_INTERVAL: float = 20.0 

# === NOVAS VARIÁVEIS (TUTORIAL, AGIOTA E TEMPORIZADOR) ===
var is_first_route_built: bool = false
var first_fiscal_warning_done: bool = false
var shift_time_left: float = 0.0
var shift_active: bool = false

var boss_package_intro_done: bool = false
var pending_boss_package_call: bool = false
var packages_generated_today: int = 0
var has_loan_shark: bool = false
var loan_shark_days_left: int = 0
var pending_shark_call: bool = false
var shark_declined: bool = false
var last_audit_day: int = -99

var daily_gang_toll: int = 0
var daily_crew_cost: int = 0
var daily_lobby_cost: int = 0

var active_contracts: Array = []
const MAX_CONTRACTS: int = 3 
const BASE_COST: int = 25 
var network_connections: Array = []
var network_stats: Dictionary = {} 

var company_cooldowns: Dictionary = {} 
var pendent_angry_call: bool = false 
var daily_generic_companies: Array = [] 
var daily_urgencies: Dictionary = {}

var intro_played: bool = false

const SAVE_PATH = "user://trem_os_save.json"
var saved_routes: Array = []

var today_broken_contracts: int = 0
var today_penalties: int = 0
var pending_radio_event: bool = false

var routes_under_construction: Dictionary = {}

var maint_pct_infra: float = 1.0
var maint_pct_tracks: float = 1.0
var maint_pct_env: float = 1.0
var maint_pct_sec: float = 1.0
var maint_pct_crew: float = 1.0
var maint_pct_lobby: float = 1.0

var ideal_maint_infra: int = 0
var ideal_maint_tracks: int = 0
var ideal_maint_env: int = 0
var ideal_maint_sec: int = 0
var ideal_maint_crew: int = 0
var ideal_maint_lobby: int = 0

var tile_data: Dictionary = {} 
var pending_disaster_check: bool = false
var broken_tiles: Array = []
var pending_blueprint: Dictionary = {}


func _process(delta: float) -> void:
	if current_day > 0 and money > -9999: 
		if money <= -2000:
			trigger_bankruptcy()
			return
			
		if money <= -1500 and not has_loan_shark and not pending_shark_call and not shark_declined:
			pending_shark_call = true
			
		if not is_first_route_built and routes_under_construction.size() > 0:
			is_first_route_built = true
			for k in routes_under_construction.keys():
				routes_under_construction[k] = 1 
				
		if not has_ready_route(): return
		
		if not boss_package_intro_done and not pending_boss_package_call:
			pending_boss_package_call = true
			
		if boss_package_intro_done and not shift_active and packages_generated_today == 0:
			shift_time_left = 120.0 + (get_daily_package_limit() * 10.0) 
			shift_active = true
			for i in range(get_daily_package_limit()):
				_generate_package()
			package_queue_updated.emit(package_queue.size())
			
		if boss_package_intro_done and shift_active:
			shift_time_left -= delta
			if shift_time_left <= 0:
				shift_active = false
				if package_queue.size() > 0:
					if has_method("add_strike"): add_strike("O trem partiu e " + str(package_queue.size()) + " encomendas ficaram na plataforma!")
					package_queue.clear()
					package_queue_updated.emit(0)

# NOVA FUNÇÃO DE VALIDAÇÃO GERAL
func has_ready_route() -> bool:
	for rid in network_connections:
		if routes_under_construction.get(rid, 0) <= 0:
			var st = network_stats.get(rid, {})
			if not st.get("is_broken", false):
				return true
	return false


func update_actual_maintenance() -> void:
	var infra_cost = int(ideal_maint_infra * maint_pct_infra)
	var tracks_cost = int(ideal_maint_tracks * maint_pct_tracks)
	var env_cost = int(ideal_maint_env * maint_pct_env)
	
	daily_maintenance = infra_cost + tracks_cost + env_cost
	daily_gang_toll = int(ideal_maint_sec * maint_pct_sec)
	daily_crew_cost = int(ideal_maint_crew * maint_pct_crew)
	daily_lobby_cost = int(ideal_maint_lobby * maint_pct_lobby)

func is_contract_operating(c: Dictionary) -> bool:
	if c.has("pending_route_days"): return false
	var rid = c["route_id"]
	if not (rid in network_connections): return false
	if routes_under_construction.get(rid, 0) > 0: return false
	var st = network_stats.get(rid, {})
	if st.is_empty(): return false
	if st.get("is_broken", false): return false
	var tp = c.get("type", "")
	if tp == "Expresso" and st["dist"] > c.get("max_dist", 999): return false
	if tp == "VIP" and (st["gangs"] > 0 or active_contracts.size() > 1): return false 
	if tp == "Ecologico" and st["forests"] > 0: return false
	return true

func is_contract_route_ready(c: Dictionary) -> bool:
	var rid = c["route_id"]
	if not (rid in network_connections): return false
	if routes_under_construction.get(rid, 0) > 0: return false
	var st = network_stats.get(rid, {})
	if st.is_empty() or st.get("is_broken", false): return false
	var tp = c.get("type", "")
	if tp == "Expresso" and st.get("dist", 999) > c.get("max_dist", 999): return false
	if tp == "VIP" and (st.get("gangs", 0) > 0 or active_contracts.size() > 1): return false
	if tp == "Ecologico" and st.get("forests", 0) > 0: return false
	return true

func get_daily_income() -> int:
	var t = 0
	for c in active_contracts:
		if is_contract_operating(c) and not c.get("is_urgent", false): 
			t += c["reward"]
	return t


func end_day(upfront_income: int = 0) -> void:
	money += upfront_income
	money += get_daily_income()
	money -= daily_maintenance
	money -= BASE_COST
	money -= daily_gang_toll 
	money -= daily_crew_cost
	money -= daily_lobby_cost
	
	if has_loan_shark:
		money -= 150 
		loan_shark_days_left -= 1
		if loan_shark_days_left <= 0:
			has_loan_shark = false 
			
	var new_ruc = {}
	var ruc_keys = routes_under_construction.keys()
	for i in range(ruc_keys.size()):
		var k = ruc_keys[i]
		if routes_under_construction[k] > 1:
			new_ruc[k] = routes_under_construction[k] - 1
	routes_under_construction = new_ruc
	
	var keep = []
	for c in active_contracts:
		var contract_failed = false
		
		if c.has("pending_route_days"):
			var is_ready = is_contract_route_ready(c)
			if is_ready:
				c.erase("pending_route_days")
			else:
				var rid = c["route_id"]
				var is_building = (routes_under_construction.get(rid, 0) > 0)
				
				if not is_building:
					c["pending_route_days"] -= 1
					if c["pending_route_days"] <= 0:
						contract_failed = true
						today_broken_contracts += 1
						var pen = int(c["reward"] * 5)
						if c.get("is_urgent", false): pen = 500
						today_penalties += pen
						money -= pen
						pendent_angry_call = true

		if not contract_failed:
			if not c.has("pending_route_days"):
				
				# --- NOVO: CONTA ATRASOS SE O TREM NÃO RODOU ---
				if not is_contract_operating(c):
					c["delayed_days"] = c.get("delayed_days", 0) + 1
				# -----------------------------------------------
				
				c["days_left"] -= 1
				
				# --- NOVO: GERA O TIPO DE RENOVAÇÃO (NO PENÚLTIMO DIA) ---
				if c["days_left"] == 1:
					var delayed = c.get("delayed_days", 0)
					if delayed > 0:
						c["renewal_type"] = "penalty"
					else:
						if randf() <= 0.7:
							c["renewal_type"] = "loyalty"
						else:
							c["renewal_type"] = "express_upgrade"
							var rid = c["route_id"]
							var stats = network_stats.get(rid, {})
							var current_dist = stats.get("dist", 20)
							var new_dist = int(current_dist * 0.8)
							if new_dist < 2: new_dist = current_dist - 1
							c["new_max_dist"] = new_dist
				# ---------------------------------------------------------
				
				if c["days_left"] > 0: keep.append(c)
			else:
				keep.append(c) 
			
	active_contracts = keep
	
	var new_cd = {}
	for k in company_cooldowns.keys():
		if company_cooldowns[k] > 1: new_cd[k] = company_cooldowns[k] - 1
	company_cooldowns = new_cd
	
	for key in tile_data.keys():
		var data = tile_data[key]
		var h = data["h"]
		var t = data["t"]
		var change = 0.0
		if t == "infra": change = (maint_pct_infra - 0.7) * 0.2
		if t == "tracks": change = (maint_pct_tracks - 0.7) * 0.2
		if t == "env": change = (maint_pct_env - 0.7) * 0.2
		h = clamp(h + change, 0.05, 1.0)
		tile_data[key]["h"] = h
		
	pending_disaster_check = true
	today_broken_contracts = 0
	today_penalties = 0
	pending_radio_event = false
	var has_op_train = false
	for c in active_contracts:
		if is_contract_operating(c): has_op_train = true
			
	if has_op_train and randf() < 0.3:
		pending_radio_event = true
			
	if not pending_radio_event:
		_roll_fiscal_audit()
	
	_generate_daily_generics()
	
	# CORREÇÃO: Limpa o turno à noite para ele iniciar limpo de manhã
	package_queue.clear()
	packages_generated_today = 0
	shift_active = false
	package_queue_updated.emit(0)
	
	contracts_updated.emit()
	current_day += 1
	save_game() 
	
	if money <= -2000: trigger_bankruptcy()
	elif money >= LevelData.LEVELS[current_level]["goal"]: trigger_victory()



func get_daily_package_limit() -> int:
	if current_day <= 2: return 3
	if current_day <= 5: return 5
	return 8

func _generate_package() -> void:
	var categories = ["Cartas", "Perecivel", "Valioso"]
	var cat = categories.pick_random()
	var item = ""
	var base_weight = 0.0
	var true_stamp = ""

	if cat == "Cartas":
		item = "Malote de Cartas"
		base_weight = randf_range(0.1, 1.5)
		true_stamp = "Selo Branco"
	elif cat == "Perecivel":
		item = ["Carne Fresca", "Leite Pasteurizado"].pick_random()
		base_weight = randf_range(10.0, 30.0)
		true_stamp = "Selo Verde"
	elif cat == "Valioso":
		item = "Caixa de Joias"
		base_weight = randf_range(2.0, 8.0)
		true_stamp = "Selo Azul"

	base_weight = snapped(base_weight, 0.1)
	var base_reward = randi_range(30, 70)

	var pkg = {
		"id": randi(),
		"true_category": cat,
		"true_item": item,
		"true_weight": base_weight,
		"true_stamp": true_stamp,
		"is_contraband": false,
		"declared_category": cat,
		"declared_item": item,
		"declared_weight": base_weight,
		"stamp_used": true_stamp,
		"days_in_queue": 0,
		"base_reward": base_reward,
		"reward": base_reward 
	}

	var fraud_chance = 0.35
	if cat == "Cartas": fraud_chance = 0.10
	if current_day <= 3: fraud_chance = 0.0 # Sem fraude no tutorial

	if randf() < fraud_chance:
		var f_type = randi() % 3
		if f_type == 0:
			pkg["true_weight"] = snapped(base_weight + randf_range(10.0, 40.0), 0.1) 
		elif f_type == 1:
			pkg["stamp_used"] = "Selo Branco" 
		elif f_type == 2:
			pkg["is_contraband"] = true 
			pkg["true_weight"] = snapped(base_weight + randf_range(15.0, 25.0), 0.1)

	packages_generated_today += 1
	package_queue.append(pkg)

func add_strike(reason: String) -> void:
	strikes += 1
	strike_received.emit(strikes, reason)
	if strikes >= 3:
		money -= 500
		today_penalties += 500
		strikes = 0
		pendent_strike_warning = "O Ministério dos Transportes aplicou uma multa de $500 devido a repetidas ocorrências no seu posto de triagem!"



func _roll_fiscal_audit() -> void:
	if current_day - last_audit_day < 3: return 
	if randf() > 0.3: return 
	
	var running_contracts = []
	for c in active_contracts:
		if is_contract_operating(c): running_contracts.append(c)
	if running_contracts.is_empty(): return
	
	var target = running_contracts.pick_random()
	var rid = target["route_id"]
	var has_violation = false
	var violation_reason = ""
	var fine = 0
	
	if maint_pct_infra < 0.5 or maint_pct_tracks < 0.5 or maint_pct_env < 0.5:
		has_violation = true
		violation_reason = "NEGLIGÊNCIA: O seu Orçamento de Manutenção está muito baixo. Os nossos fiscais relatam trilhos soltos e infraestrutura perigosa na sua malha!"
		fine = 800
	else:
		if target.get("type", "") == "VIP":
			var stats = network_stats.get(rid, {})
			if stats.get("gangs", 0) > 0:
				has_violation = true
				violation_reason = "RISCO DE ESTADO: Detectamos um trem VIP cruzando território dominado por gangues. Isto é um absurdo de segurança!"
				fine = 1500

	if has_violation:
		last_audit_day = current_day 
		var can_bribe = (maint_pct_lobby >= 0.7)
		var bribe_cost = int(fine * 0.15) 
		pending_fiscal_event = {
			"reason": violation_reason, "fine": fine,
			"can_bribe": can_bribe, "bribe_cost": bribe_cost,
			"contract_name": target["company_name"]
		}




# FASE 1: A Nova Punição Inteligente (Custo de Frete) que ligaremos na Fase 4
func process_package_approval(pkg: Dictionary) -> void:
	var cost_per_kg = 0.5 # A empresa gasta 50 centavos por cada Kg real despachado
	var net_profit = pkg["base_reward"] - (pkg["true_weight"] * cost_per_kg)
	money += int(net_profit)

# FASE 1: Lógica do Agiota
func accept_loan_shark() -> void:
	has_loan_shark = true
	loan_shark_days_left = 20
	# Limpa o saldo negativo atual (ex: -1500 vira 0) e adiciona +1500 para respirar
	money += abs(money) + 1500 

func reject_loan_shark() -> void:
	shark_declined = true



func _generate_daily_generics() -> void:
	daily_generic_companies.clear()
	var bases = ["Siderurgica", "Agropecuaria", "Mineracao", "Industrias Quimicas", "Logistica", "Construtora"]
	var suffixes = ["Vale do Aco", "Nova Safra", "Atlas", "Apex", "Global", "Horizonte"]
	var t = ["Ganha-Pao", "Expresso"]
	var cg = ["Bobinas de Aco", "Fertilizantes", "Minerio de Ferro", "Pecas Usinadas", "Cimento", "Madeira Bruta"]
	var possible_routes = [
		{"id": "Azul-Vermelha", "n": "Azul <-> Vermelha"}, 
		{"id": "Azul-Verde", "n": "Azul <-> Verde"}, 
		{"id": "Vermelha-Verde", "n": "Vermelha <-> Verde"}
	]
	var r = possible_routes.pick_random()
	var tp = t.pick_random()
	
	var daily_costs = daily_maintenance + BASE_COST + daily_crew_cost + daily_lobby_cost + daily_gang_toll
	var min_reward = int(daily_costs * 0.8) 
	if min_reward < 80: min_reward = 80
	
	var comp = {
		"name": bases.pick_random() + " " + suffixes.pick_random() + " (Diario)", 
		"type": tp, 
		"base_reward": randi_range(min_reward, min_reward + 80), 
		"phone": "555-" + str(randi_range(1000, 9999)), 
		"cargo": cg.pick_random(),
		"weight": randi_range(500, 15000),
		"duration": randi_range(5, 10),
		"route_id": r["id"], 
		"route_name": r["n"]
	}
	if tp == "Expresso": comp["max_dist"] = 35 
	daily_generic_companies.append(comp)
	_roll_daily_urgencies()


func _roll_daily_urgencies() -> void:
	daily_urgencies.clear()
	var comps = LevelData.LEVELS[current_level]["companies"].duplicate(true)
	comps.append_array(daily_generic_companies)
	for c in comps:
		if randf() < 0.35: daily_urgencies[c["name"]] = int(c["base_reward"] * randf_range(3.0, 5.0))

func cancel_contract(idx: int) -> void:
	if idx >= 0 and idx < active_contracts.size():
		var c = active_contracts[idx]
		var p = 0
		if not c.get("is_urgent", false): p = int((c["reward"] * c["days_left"]) * 0.20)
		money -= p
		today_penalties += p
		today_broken_contracts += 1
		active_contracts.remove_at(idx)
		contracts_updated.emit()
		save_game()

func trigger_bankruptcy() -> void: game_over.emit(false, "FALÊNCIA!\nSaldo negativo.")


func trigger_victory() -> void:
	if current_level == highest_unlocked_level and LevelData.LEVELS.has(current_level + 1): highest_unlocked_level += 1
	game_over.emit(true, "VITÓRIA!\nMeta atingida.")

func has_save() -> bool: return FileAccess.file_exists(SAVE_PATH)


func reset_game() -> void:
	var lvl = LevelData.LEVELS[current_level]
	money = lvl["budget"]
	current_day = 1
	daily_maintenance = 0
	daily_gang_toll = 0
	daily_crew_cost = 0
	daily_lobby_cost = 0
	active_contracts.clear()
	network_connections.clear()
	network_stats.clear()
	company_cooldowns.clear()
	daily_urgencies.clear()
	saved_routes.clear()
	routes_under_construction.clear()
	pendent_angry_call = false
	intro_played = false 
	today_broken_contracts = 0
	today_penalties = 0
	pending_radio_event = false
	
	maint_pct_infra = 1.0
	maint_pct_tracks = 1.0
	maint_pct_env = 1.0
	maint_pct_sec = 1.0
	maint_pct_crew = 1.0
	maint_pct_lobby = 1.0
	
	tile_data.clear()
	broken_tiles.clear()
	pending_disaster_check = false
	pending_blueprint.clear()
	pending_fiscal_event.clear()
	
	package_queue.clear()
	strikes = 0
	pendent_strike_warning = ""
	package_timer = 0.0
	
	# Reset Fase 1 e Temporizador
	packages_generated_today = 0
	has_loan_shark = false
	loan_shark_days_left = 0
	pending_shark_call = false
	shark_declined = false
	last_audit_day = -99
	boss_package_intro_done = false
	pending_boss_package_call = false
	
	is_first_route_built = false
	first_fiscal_warning_done = false
	shift_time_left = 0.0
	shift_active = false
	
	_generate_daily_generics()
	save_game()

func save_game() -> void:
	var data = {
		"packages_generated_today": packages_generated_today,
		"has_loan_shark": has_loan_shark,
		"loan_shark_days_left": loan_shark_days_left,
		"pending_shark_call": pending_shark_call,
		"shark_declined": shark_declined,
		"last_audit_day": last_audit_day,
		"boss_package_intro_done": boss_package_intro_done,
		"pending_boss_package_call": pending_boss_package_call,
		
		"is_first_route_built": is_first_route_built,
		"first_fiscal_warning_done": first_fiscal_warning_done,
		"shift_time_left": shift_time_left,
		"shift_active": shift_active,
		
		"money": money, "current_day": current_day,
		"daily_maintenance": daily_maintenance, "daily_gang_toll": daily_gang_toll,
		"daily_crew_cost": daily_crew_cost, "daily_lobby_cost": daily_lobby_cost,
		"active_contracts": active_contracts, "company_cooldowns": company_cooldowns,
		"intro_played": intro_played, "pending_radio_event": pending_radio_event,
		"pending_fiscal_event": pending_fiscal_event, "routes_under_construction": routes_under_construction,
		"saved_routes": _routes_to_array(saved_routes), "current_level": current_level,
		"highest_unlocked_level": highest_unlocked_level, "maint_pct_infra": maint_pct_infra,
		"maint_pct_tracks": maint_pct_tracks, "maint_pct_env": maint_pct_env,
		"maint_pct_sec": maint_pct_sec, "maint_pct_crew": maint_pct_crew,
		"maint_pct_lobby": maint_pct_lobby, "tile_data": tile_data,
		"broken_tiles": _vec_array_to_dict_array(broken_tiles),
		"pending_blueprint": _serialize_blueprint(pending_blueprint),
		"package_queue": package_queue, "strikes": strikes,
		"pendent_strike_warning": pendent_strike_warning
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func load_game() -> bool:
	if not has_save(): return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if data:
		packages_generated_today = data.get("packages_generated_today", 0)
		has_loan_shark = data.get("has_loan_shark", false)
		loan_shark_days_left = data.get("loan_shark_days_left", 0)
		pending_shark_call = data.get("pending_shark_call", false)
		shark_declined = data.get("shark_declined", false)
		last_audit_day = data.get("last_audit_day", -99)
		boss_package_intro_done = data.get("boss_package_intro_done", false)
		pending_boss_package_call = data.get("pending_boss_package_call", false)
		
		is_first_route_built = data.get("is_first_route_built", false)
		first_fiscal_warning_done = data.get("first_fiscal_warning_done", false)
		shift_time_left = data.get("shift_time_left", 0.0)
		shift_active = data.get("shift_active", false)
		
		money = data.get("money", 1500)
		current_day = data.get("current_day", 1)
		daily_maintenance = data.get("daily_maintenance", 0)
		daily_gang_toll = data.get("daily_gang_toll", 0)
		daily_crew_cost = data.get("daily_crew_cost", 0)
		daily_lobby_cost = data.get("daily_lobby_cost", 0)
		active_contracts = data.get("active_contracts", [])
		company_cooldowns = data.get("company_cooldowns", {})
		intro_played = data.get("intro_played", false)
		pending_radio_event = data.get("pending_radio_event", false)
		pending_fiscal_event = data.get("pending_fiscal_event", {})
		routes_under_construction = data.get("routes_under_construction", {})
		saved_routes = _array_to_routes(data.get("saved_routes", []))
		current_level = data.get("current_level", 1)
		highest_unlocked_level = data.get("highest_unlocked_level", 1)
		maint_pct_infra = data.get("maint_pct_infra", 1.0)
		maint_pct_tracks = data.get("maint_pct_tracks", 1.0)
		maint_pct_env = data.get("maint_pct_env", 1.0)
		maint_pct_sec = data.get("maint_pct_sec", 1.0)
		maint_pct_crew = data.get("maint_pct_crew", 1.0)
		maint_pct_lobby = data.get("maint_pct_lobby", 1.0)
		tile_data = data.get("tile_data", {})
		broken_tiles = _dict_array_to_vec_array(data.get("broken_tiles", []))
		pending_blueprint = _deserialize_blueprint(data.get("pending_blueprint", {}))
		package_queue = data.get("package_queue", [])
		strikes = data.get("strikes", 0)
		pendent_strike_warning = data.get("pendent_strike_warning", "")
		
		today_broken_contracts = 0
		today_penalties = 0
		_generate_daily_generics()
		
		money_changed.emit(money)
		day_changed.emit(current_day)
		maintenance_updated.emit(daily_maintenance)
		contracts_updated.emit()
		return true
	return false

func _routes_to_array(routes: Array) -> Array:
	var arr = []
	for route in routes:
		var r_arr = []
		for cell in route: r_arr.append({"x": cell.x, "y": cell.y})
		arr.append(r_arr)
	return arr

func _array_to_routes(arr: Array) -> Array:
	var routes = []
	for r_arr in arr:
		var route = []
		for cell_dict in r_arr: route.append(Vector2i(cell_dict["x"], cell_dict["y"]))
		routes.append(route)
	return routes

func _vec_array_to_dict_array(arr: Array) -> Array:
	var res = []
	for v in arr: res.append({"x": v.x, "y": v.y})
	return res

func _dict_array_to_vec_array(arr: Array) -> Array:
	var res = []
	for d in arr: res.append(Vector2i(d["x"], d["y"]))
	return res

func _serialize_blueprint(bp: Dictionary) -> Dictionary:
	if bp.is_empty(): return {}
	return {
		"draft_paths": _routes_to_array(bp["draft_paths"]), "deleted_paths": _routes_to_array(bp["deleted_paths"]),
		"repair_tiles": _vec_array_to_dict_array(bp["repair_tiles"]), "net_cost": bp["net_cost"],
		"tax_env": bp["tax_env"], "tax_eng": bp["tax_eng"], "tax_sec": bp["tax_sec"],
		"total_cost": bp["total_cost"], "routes_to_cooldown": bp.get("routes_to_cooldown", [])
	}

func _deserialize_blueprint(data: Dictionary) -> Dictionary:
	if data.is_empty(): return {}
	return {
		"draft_paths": _array_to_routes(data["draft_paths"]), "deleted_paths": _array_to_routes(data["deleted_paths"]),
		"repair_tiles": _dict_array_to_vec_array(data["repair_tiles"]), "net_cost": data["net_cost"],
		"tax_env": data["tax_env"], "tax_eng": data["tax_eng"], "tax_sec": data["tax_sec"],
		"total_cost": data["total_cost"], "routes_to_cooldown": data.get("routes_to_cooldown", [])
	}
