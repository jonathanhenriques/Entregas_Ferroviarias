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

var active_contracts: Array = []
const MAX_CONTRACTS: int = 3 
const BASE_COST: int = 25 
var network_connections: Array = []
var network_stats: Dictionary = {} 

var company_cooldowns: Dictionary = {} 
var pendent_angry_call: bool = false 
var daily_generic_companies: Array = [] 
var daily_urgencies: Dictionary = {}

func is_contract_operating(c: Dictionary) -> bool:
	var rid = c["route_id"]; if not (rid in network_connections): return false
	var st = network_stats.get(rid, {}); if st.is_empty(): return false
	var tp = c.get("type", "")
	if tp == "Expresso" and st["dist"] > c.get("max_dist", 999): return false
	if tp == "VIP" and (st["gangs"] > 0 or active_contracts.size() > 1): return false 
	if tp == "Ecologico" and st["forests"] > 0: return false
	return true

func get_daily_income() -> int:
	var t = 0
	for c in active_contracts:
		if is_contract_operating(c) and not c.get("is_urgent", false): t += c["reward"]
	return t

func reset_game() -> void:
	var lvl = LevelData.LEVELS[current_level]
	money = lvl["budget"]; current_day = 1; daily_maintenance = 0; daily_gang_toll = 0
	active_contracts.clear(); network_connections.clear(); network_stats.clear()
	company_cooldowns.clear(); daily_urgencies.clear(); pendent_angry_call = false
	_generate_daily_generics()

func end_day() -> void:
	money += get_daily_income(); money -= daily_maintenance; money -= BASE_COST; money -= daily_gang_toll 
	var keep = []
	for c in active_contracts:
		c["days_left"] -= 1
		if c["days_left"] > 0: keep.append(c)
	active_contracts = keep
	var new_cd = {}
	for k in company_cooldowns.keys():
		if company_cooldowns[k] > 1: new_cd[k] = company_cooldowns[k] - 1
	company_cooldowns = new_cd
	_generate_daily_generics(); contracts_updated.emit(); current_day += 1
	if money < 0: trigger_bankruptcy()
	elif money >= LevelData.LEVELS[current_level]["goal"]: trigger_victory()

func _generate_daily_generics() -> void:
	daily_generic_companies.clear()
	var n = ["Comerciante Local", "Fazendeiro Independente", "Cooperativa Agricola"]; var t = ["Ganha-Pao", "Expresso"]; var cg = ["Suprimentos", "Materiais", "Maquinario", "Gado"]
	var r = [{"id": "Azul-Vermelha", "n": "Azul <-> Vermelha"}, {"id": "Azul-Verde", "n": "Azul <-> Verde"}, {"id": "Vermelha-Verde", "n": "Vermelha <-> Verde"}].pick_random()
	var tp = t.pick_random()
	var comp = {"name": n.pick_random() + " (Diario)", "type": tp, "base_reward": randi_range(80, 160), "phone": "555-" + str(randi_range(100, 999)), "cargo": cg.pick_random(), "route_id": r["id"], "route_name": r["n"]}
	if tp == "Expresso": comp["max_dist"] = 35 
	daily_generic_companies.append(comp)
	_roll_daily_urgencies()

func _roll_daily_urgencies() -> void:
	daily_urgencies.clear()
	var comps = LevelData.LEVELS[current_level]["companies"].duplicate(true); comps.append_array(daily_generic_companies)
	for c in comps:
		if randf() < 0.35: daily_urgencies[c["name"]] = int(c["base_reward"] * randf_range(3.0, 5.0))

func cancel_contract(idx: int) -> void:
	if idx >= 0 and idx < active_contracts.size():
		var c = active_contracts[idx]; var p = 0
		if not c.get("is_urgent", false): p = int((c["reward"] * c["days_left"]) * 0.20)
		money -= p; active_contracts.remove_at(idx); contracts_updated.emit()

func trigger_bankruptcy() -> void: game_over.emit(false, "FALENCIA!\nSaldo negativo.")
func trigger_victory() -> void:
	if current_level == highest_unlocked_level and LevelData.LEVELS.has(current_level + 1): highest_unlocked_level += 1
	game_over.emit(true, "VITORIA!\nMeta atingida.")
