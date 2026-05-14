extends Node

signal money_changed(new_amount)
signal day_changed(new_day)
signal maintenance_updated(new_maintenance)
signal contracts_updated() 
signal game_over(is_victory: bool, message: String)

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

# =======================================
# NOVO: SAÚDE INDIVIDUAL POR TILE (IDADE)
# =======================================
var tile_data: Dictionary = {} 
var pending_disaster_check: bool = false
var broken_tiles: Array = []

func update_actual_maintenance() -> void:
	var infra_cost = int(ideal_maint_infra * maint_pct_infra)
	var tracks_cost = int(ideal_maint_tracks * maint_pct_tracks)
	var env_cost = int(ideal_maint_env * maint_pct_env)
	
	daily_maintenance = infra_cost + tracks_cost + env_cost
	daily_gang_toll = int(ideal_maint_sec * maint_pct_sec)
	daily_crew_cost = int(ideal_maint_crew * maint_pct_crew)
	daily_lobby_cost = int(ideal_maint_lobby * maint_pct_lobby)

func is_contract_operating(c: Dictionary) -> bool:
	if c.has("pending_route_days"):
		return false
		
	var rid = c["route_id"]
	if not (rid in network_connections): 
		return false
		
	if routes_under_construction.get(rid, 0) > 0:
		return false
	
	var st = network_stats.get(rid, {})
	if st.is_empty(): 
		return false
		
	if st.get("is_broken", false):
		return false
	
	var tp = c.get("type", "")
	
	if tp == "Expresso" and st["dist"] > c.get("max_dist", 999): 
		return false
	
	if tp == "VIP" and (st["gangs"] > 0 or active_contracts.size() > 1): 
		return false 
		
	if tp == "Ecologico" and st["forests"] > 0: 
		return false
		
	return true

func is_contract_route_ready(c: Dictionary) -> bool:
	var rid = c["route_id"]
	var has_route = rid in network_connections
	if not has_route:
		return false

	if routes_under_construction.get(rid, 0) > 0:
		return false

	var st = network_stats.get(rid, {})
	if st.is_empty():
		return false
		
	if st.get("is_broken", false):
		return false

	var tp = c.get("type", "")
	if tp == "Expresso":
		if st.get("dist", 999) > c.get("max_dist", 999):
			return false
	if tp == "VIP":
		if st.get("gangs", 0) > 0:
			return false
		if active_contracts.size() > 1:
			return false
	if tp == "Ecologico":
		if st.get("forests", 0) > 0:
			return false

	return true

func get_daily_income() -> int:
	var t = 0
	for c in active_contracts:
		if is_contract_operating(c) and not c.get("is_urgent", false): 
			t += c["reward"]
	return t

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
	
	_generate_daily_generics()
	save_game()

func end_day(upfront_income: int = 0) -> void:
	money += upfront_income
	money += get_daily_income()
	money -= daily_maintenance
	money -= BASE_COST
	money -= daily_gang_toll 
	money -= daily_crew_cost
	money -= daily_lobby_cost
	
	var keep = []
	for c in active_contracts:
		var contract_failed = false
		
		if c.has("pending_route_days"):
			var is_ready = is_contract_route_ready(c)
			if is_ready:
				c.erase("pending_route_days")
			if not is_ready:
				c["pending_route_days"] -= 1
				if c["pending_route_days"] <= 0:
					contract_failed = true
					today_broken_contracts += 1
					var pen = int(c["reward"] * 5)
					if c.get("is_urgent", false):
						pen = 500
					today_penalties += pen
					money -= pen
					pendent_angry_call = true

		if not contract_failed:
			if not c.has("pending_route_days"):
				c["days_left"] -= 1
				if c["days_left"] > 0:
					keep.append(c)
			if c.has("pending_route_days"):
				keep.append(c)
			
	active_contracts = keep
	
	var new_cd = {}
	for k in company_cooldowns.keys():
		if company_cooldowns[k] > 1: 
			new_cd[k] = company_cooldowns[k] - 1
			
	company_cooldowns = new_cd
	
	var new_ruc = {}
	var ruc_keys = routes_under_construction.keys()
	for i in range(ruc_keys.size()):
		var k = ruc_keys[i]
		if routes_under_construction[k] > 1:
			new_ruc[k] = routes_under_construction[k] - 1
	routes_under_construction = new_ruc
	
	# NOVO: O desgaste diário agora é aplicado bloco a bloco!
	for key in tile_data.keys():
		var data = tile_data[key]
		var h = data["h"]
		var t = data["t"]
		var change = 0.0
		
		if t == "infra":
			change = (maint_pct_infra - 0.7) * 0.2
		if t == "tracks":
			change = (maint_pct_tracks - 0.7) * 0.2
		if t == "env":
			change = (maint_pct_env - 0.7) * 0.2
			
		h = clamp(h + change, 0.05, 1.0)
		tile_data[key]["h"] = h
		
	pending_disaster_check = true
	
	today_broken_contracts = 0
	today_penalties = 0
	
	pending_radio_event = false
	var has_op_train = false
	for c in active_contracts:
		if is_contract_operating(c):
			has_op_train = true
			
	if has_op_train:
		if randf() < 0.3:
			pending_radio_event = true
	
	_generate_daily_generics()
	contracts_updated.emit()
	current_day += 1
	
	save_game() 
	
	if money < 0: 
		trigger_bankruptcy()
	else:
		if money >= LevelData.LEVELS[current_level]["goal"]: 
			trigger_victory()

func _generate_daily_generics() -> void:
	daily_generic_companies.clear()
	var n = ["Comerciante Local", "Fazendeiro Independente", "Cooperativa Agricola"]
	var t = ["Ganha-Pao", "Expresso"]
	var cg = ["Suprimentos", "Materiais", "Maquinario", "Gado"]
	
	var possible_routes = [
		{"id": "Azul-Vermelha", "n": "Azul <-> Vermelha"}, 
		{"id": "Azul-Verde", "n": "Azul <-> Verde"}, 
		{"id": "Vermelha-Verde", "n": "Vermelha <-> Verde"}
	]
	var r = possible_routes.pick_random()
	var tp = t.pick_random()
	
	var comp = {
		"name": n.pick_random() + " (Diario)", 
		"type": tp, 
		"base_reward": randi_range(80, 160), 
		"phone": "555-" + str(randi_range(1000, 9999)), 
		"cargo": cg.pick_random(), 
		"route_id": r["id"], 
		"route_name": r["n"]
	}
	
	if tp == "Expresso": 
		comp["max_dist"] = 35 
		
	daily_generic_companies.append(comp)
	_roll_daily_urgencies()

func _roll_daily_urgencies() -> void:
	daily_urgencies.clear()
	var comps = LevelData.LEVELS[current_level]["companies"].duplicate(true)
	comps.append_array(daily_generic_companies)
	
	for c in comps:
		if randf() < 0.35: 
			daily_urgencies[c["name"]] = int(c["base_reward"] * randf_range(3.0, 5.0))

func cancel_contract(idx: int) -> void:
	if idx >= 0 and idx < active_contracts.size():
		var c = active_contracts[idx]
		var p = 0
		if not c.get("is_urgent", false): 
			p = int((c["reward"] * c["days_left"]) * 0.20)
		money -= p
		
		today_penalties += p
		today_broken_contracts += 1
		
		active_contracts.remove_at(idx)
		contracts_updated.emit()
		save_game()

func trigger_bankruptcy() -> void: 
	game_over.emit(false, "FALENCIA!\nSaldo negativo.")

func trigger_victory() -> void:
	if current_level == highest_unlocked_level and LevelData.LEVELS.has(current_level + 1): 
		highest_unlocked_level += 1
	game_over.emit(true, "VITORIA!\nMeta atingida.")

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var data = {
		"money": money,
		"current_day": current_day,
		"daily_maintenance": daily_maintenance,
		"daily_gang_toll": daily_gang_toll,
		"daily_crew_cost": daily_crew_cost,
		"daily_lobby_cost": daily_lobby_cost,
		"active_contracts": active_contracts,
		"company_cooldowns": company_cooldowns,
		"intro_played": intro_played,
		"pending_radio_event": pending_radio_event,
		"routes_under_construction": routes_under_construction,
		"saved_routes": _routes_to_array(saved_routes),
		"current_level": current_level,
		"highest_unlocked_level": highest_unlocked_level,
		"maint_pct_infra": maint_pct_infra,
		"maint_pct_tracks": maint_pct_tracks,
		"maint_pct_env": maint_pct_env,
		"maint_pct_sec": maint_pct_sec,
		"maint_pct_crew": maint_pct_crew,
		"maint_pct_lobby": maint_pct_lobby,
		"tile_data": tile_data,
		"broken_tiles": _vec_array_to_dict_array(broken_tiles)
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func load_game() -> bool:
	if not has_save():
		return false
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if data:
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
		for cell in route:
			r_arr.append({"x": cell.x, "y": cell.y})
		arr.append(r_arr)
	return arr

func _array_to_routes(arr: Array) -> Array:
	var routes = []
	for r_arr in arr:
		var route = []
		for cell_dict in r_arr:
			route.append(Vector2i(cell_dict["x"], cell_dict["y"]))
		routes.append(route)
	return routes

func _vec_array_to_dict_array(arr: Array) -> Array:
	var res = []
	for v in arr:
		res.append({"x": v.x, "y": v.y})
	return res

func _dict_array_to_vec_array(arr: Array) -> Array:
	var res = []
	for d in arr:
		res.append(Vector2i(d["x"], d["y"]))
	return res
