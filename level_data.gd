extends RefCounted
class_name LevelData

const LEVELS = {
	1: {
		"name": "O Vale do Rio (Tutorial)",
		"budget": 1500,
		"goal": 4000,
		"map_layout": [
			"...............FFFFF................",
			"...............FFFFF................",
			"...............FFFFF................",
			"...............FFFFF..........C.....",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"..A.....RR.....MMMM....B............",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			"........RR.....MMMM.................",
			".......FFFF....MMMM.................",
			".......FFFF....MMMM.................",
			".......FFFF....MMMM.................",
			".......FFFF....MMMM................."
		],
		"companies": [
			{"name": "Serraria do Vale", "type": "Ganha-Pao", "base_reward": 100, "phone": "555-0101", "cargo": "Madeira", "route_id": "Azul-Vermelha", "route_name": "Azul <-> Vermelha"},
			{"name": "Mina de Carvao Sul", "type": "Ganha-Pao", "base_reward": 120, "phone": "555-0202", "cargo": "Carvao Bruto", "route_id": "Azul-Verde", "route_name": "Azul <-> Verde"}
		]
	},
	2: {
		"name": "Planicies Centrais",
		"budget": 2000,
		"goal": 6000,
		"map_layout": [
			"..........FFFFFFFF..................",
			"..........FFFFFFFF...........C......",
			"..........FFFFFFFF..................",
			"..........FFFFFFFF..................",
			"....................................",
			".......MMMMMM.......................",
			".......MMMMMM.......................",
			".......MMMMMM.......................",
			"...A...MMMMMM.......................",
			".......MMMMMM.......................",
			".......MMMMMM.......................",
			".......MMMMMM.......FFFFFFF.........",
			"....................FFFFFFF.........",
			"....................FFFFFFF.........",
			"....................FFFFFFF.........",
			"....................FFFFFFF......B..",
			"....................FFFFFFF.........",
			"....................................",
			"....................................",
			"...................................."
		],
		"gang_layout": [
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"........GGGGGGGGGGGGGGGGGG..........",
			"........GGGGGGGGGGGGGGGGGG..........",
			"........GGGGGGGGGGGGGGGGGG..........",
			"........GGGGGGGGGGGGGGGGGG..........",
			"........GGGGGGGGGGGGGGGGGG..........",
			"........GGGGGGGGGGGGGGGGGG..........",
			"........GGGGGGGGGGGGGGGGGG..........",
			"....................................",
			"...................................."
		],
		"companies": [
			{"name": "Fazenda Trigo Dourado", "type": "Ganha-Pao", "base_reward": 130, "phone": "555-0303", "cargo": "Trigo", "route_id": "Azul-Vermelha", "route_name": "Azul <-> Vermelha"},
			{"name": "Banco Central", "type": "Expresso", "base_reward": 250, "phone": "555-0404", "cargo": "Ouro", "route_id": "Vermelha-Verde", "route_name": "Vermelha <-> Verde", "max_dist": 22},
			{"name": "Sindicato Oculto", "type": "VIP", "base_reward": 500, "phone": "555-0999", "cargo": "Carga Suspeita", "route_id": "Azul-Verde", "route_name": "Azul <-> Verde"},
			{"name": "ONG Caminho Verde", "type": "Ecologico", "base_reward": 200, "phone": "555-7777", "cargo": "Sementes Raras", "route_id": "Vermelha-Verde", "route_name": "Vermelha <-> Verde"}
		]
	}
}
