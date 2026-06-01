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
			# --- INÍCIO DAS MODIFICAÇÕES: INJEÇÃO DAS NOTAS DO AVÔ (GRANDPA'S LORE) ---
			{
				"name": "Serraria do Vale", "region": "Vale do Rio", "type": "Ganha-Pao", "base_reward": 100, 
				"phone": "555-0101", "cargo": "Madeira", "route_id": "Estação A-Estação B", "route_name": "Estação A <-> Estação B",
				"grandpa_note": "A lenha deles é pesada, mas pagam em dia. É o feijão com arroz da nossa ferrovia."
			},
			{
				"name": "Siderúrgica B", "region": "Vale do Rio", "type": "Ganha-Pao", "base_reward": 140, 
				"phone": "555-0102", "cargo": "Bobinas de Aço", "route_id": "Estação B-Estação D", "route_name": "Estação B <-> Estação D",
				"grandpa_note": "Cuidado com o peso do aço nos trilhos. Rota curta, lucro garantido."
			},
			{
				"name": "Fazenda Trigo Dourado", "region": "Planícies", "type": "Ganha-Pao", "base_reward": 130, 
				"phone": "555-0201", "cargo": "Trigo", "route_id": "Estação C-Estação F", "route_name": "Estação C <-> Estação F",
				"grandpa_note": "O pessoal da roça precisa muito de nós na colheita. Tente não atrasar as entregas deles."
			},
			{
				"name": "Refinaria Apex", "region": "Planícies", "type": "VIP", "base_reward": 350, 
				"phone": "555-0202", "cargo": "Combustível", "route_id": "Estação D-Estação F", "route_name": "Estação D <-> Estação F",
				"grandpa_note": "Cliente de alto risco! Carga explosiva, mas o dinheiro que eles pagam sustenta a empresa por dias."
			},
			{
				"name": "Mina de Carvão Sul", "region": "Montanhas", "type": "Ganha-Pao", "base_reward": 120, 
				"phone": "555-0301", "cargo": "Carvão Bruto", "route_id": "Estação A-Estação E", "route_name": "Estação A <-> Estação E",
				"grandpa_note": "Trabalho sujo e rota íngreme. O carvão mancha os vagões, mas a mineração nunca para."
			},
			{
				"name": "Fábrica de Peças", "region": "Montanhas", "type": "Expresso", "base_reward": 250, 
				"phone": "555-0302", "cargo": "Peças Usinadas", "route_id": "Estação E-Estação F", "route_name": "Estação E <-> Estação F", "max_dist": 25,
				"grandpa_note": "Eles são chatos com prazos e distâncias. A rota precisa ser direta e eficiente!"
			}
			# --- FIM DAS MODIFICAÇÕES ---
		]
	}
}
