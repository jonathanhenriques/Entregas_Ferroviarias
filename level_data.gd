extends RefCounted
class_name LevelData

const LEVELS = {
	1: {
		"name": "O Vale do Rio",
		"budget": 1500,
		"goal": 4000,
		"map_layout": [
			"............................................................",
			"............................................................",
			"......................FFFFFFFF..............................",
			"......................FFFFFFFF...........C..................",
			".............E........FFFFFFFF..............................",
			"......................FFFFFFFF..............................",
			"............................................................",
			"...................MMMMMM...................................",
			"...................MMMMMM...................................",
			"...................MMMMMM...................................",
			"...............A...MMMMMM...................................",
			"...................MMMMMM................F..................",
			"...................MMMMMM...................................",
			"...................MMMMMM.......FFFFFFF.....................",
			"................................FFFFFFF.....................",
			"................................FFFFFFF.....................",
			"................................FFFFFFF.....................",
			"................................FFFFFFF......B..............",
			"......................................................D.....",
			"............................................................",
			"............................................................"
		],
		"companies": [
			# --- INÍCIO DA ADIÇÃO: EMPRESAS POPULANDO O GUIA REGIONAL ---
			# Adicionamos a tag "region" e espalhamos empresas de A a F para o Guia fazer sentido
			{"name": "Serraria do Vale", "region": "Vale do Rio", "type": "Ganha-Pao", "base_reward": 100, "phone": "555-0101", "cargo": "Madeira", "route_id": "Estação A-Estação B", "route_name": "Estação A <-> Estação B"},
			{"name": "Siderúrgica B", "region": "Vale do Rio", "type": "Ganha-Pao", "base_reward": 140, "phone": "555-0102", "cargo": "Bobinas de Aço", "route_id": "Estação B-Estação D", "route_name": "Estação B <-> Estação D"},
			
			{"name": "Fazenda Trigo Dourado", "region": "Planícies", "type": "Ganha-Pao", "base_reward": 130, "phone": "555-0201", "cargo": "Trigo", "route_id": "Estação C-Estação F", "route_name": "Estação C <-> Estação F"},
			{"name": "Refinaria Apex", "region": "Planícies", "type": "VIP", "base_reward": 350, "phone": "555-0202", "cargo": "Combustível", "route_id": "Estação D-Estação F", "route_name": "Estação D <-> Estação F"},
			
			{"name": "Mina de Carvão Sul", "region": "Montanhas", "type": "Ganha-Pao", "base_reward": 120, "phone": "555-0301", "cargo": "Carvão Bruto", "route_id": "Estação A-Estação E", "route_name": "Estação A <-> Estação E"},
			{"name": "Fábrica de Peças", "region": "Montanhas", "type": "Expresso", "base_reward": 250, "phone": "555-0302", "cargo": "Peças Usinadas", "route_id": "Estação E-Estação F", "route_name": "Estação E <-> Estação F", "max_dist": 25}
			# --- FIM DA ADIÇÃO ---
		]
	}
}
