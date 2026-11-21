package mods.benchmark;

/** Fixed protocol: identical labels, counts and durations on every machine. */
class CapacityPlan {
	public static function assets():Array<Dynamic>
		return [
			{
				name: "Brute",
				path: "Resources/Art3D/Enemy/Brute/db_emy_brute.swf",
				symbol: "db_emy_brute",
				label: "attack_chop_angE",
				pixels: 145
			},
			{
				name: "Minotaur",
				path: "Resources/Art3D/Enemy/minotaur/db_emy_minotaur.swf",
				symbol: "db_emy_minotaur",
				label: "attack_chargeWithHorns_angE",
				pixels: 210
			},
			{
				name: "Blue Dragon",
				path: "Resources/Art3D/Enemy/dragon/db_emy_dragon.swf",
				symbol: "db_emy_dragon",
				label: "attack_breath_angE",
				pixels: 280
			},
			{
				name: "Berserker",
				path: "Resources/Art3D/Avatar/Berserker/db_char_berserker.swf",
				symbol: "db_char_berserker",
				label: "attack_db_angE",
				pixels: 145
			},
			{
				name: "Lion",
				path: "Resources/Art3D/Enemy/lion/db_emy_lion.swf",
				symbol: "db_emy_lion",
				label: "roar_angE",
				pixels: 155
			},
			{
				name: "Berserk flames",
				path: "Resources/Art2D/FX/db_fx_library.swf",
				symbol: "db_buff_berserk",
				label: null,
				nativeScale: 1
			},
			{
				"name": "Dragon frost breath",
				"path": "Resources/Art2D/Environments/boss/db_prop_boss_dragon.swf",
				"symbol": "db_fx_attack_dragon_frostBreath_angle90",
				"label": null,
				nativeScale: 1
			},
			{
				"name": "Berserker ultimate",
				"path": "Resources/Art2D/FX/db_fx_library.swf",
				"symbol": "db_fx_dbBerserk",
				"label": null,
				nativeScale: 1
			},
			{
				"name": "Sorcerer ultimate",
				"path": "Resources/Art2D/FX/db_fx_library.swf",
				"symbol": "sorcerer_db",
				"label": null,
				nativeScale: 1
			},
			{
				"name": "Ranger ultimate flare",
				"path": "Resources/Art2D/FX/db_fx_library.swf",
				"symbol": "db_fx_whiteFlashFlare",
				"label": null,
				nativeScale: 1
			},
			{
				"name": "Ultimate burst",
				"path": "Resources/Art2D/FX/db_fx_library.swf",
				"symbol": "db_fx_dungeonBusterShort",
				"label": null,
				nativeScale: 1
			},
			{
				"name": "Chef meteor",
				"path": "Resources/Art2D/FX/db_fx_library.swf",
				"symbol": "db_fx_cowMeateor_anim",
				"label": null,
				nativeScale: 0.6
			},
			{
				"name": "Sorcerer ultimate body",
				"path": "Resources/Art3D/Avatar/wizard/db_char_wizard.swf",
				"symbol": "db_char_wizard",
				"label": "attack_db_angE",
				"pixels": 145
			},
			{
				"name": "Ranger ultimate body",
				"path": "Resources/Art3D/Avatar/ranger/db_char_ranger.swf",
				"symbol": "db_char_ranger",
				"label": "attack_db_angE",
				"pixels": 145
			},
			{
				"name": "Battle Chef ultimate body",
				"path": "Resources/Art3D/Avatar/chef/db_char_chef.swf",
				"symbol": "db_char_chef",
				"label": "attack_db_angE",
				"pixels": 145
			},
			{
				name: "Firebomb explosion",
				path: "Resources/Art2D/FX/db_fx_library.swf",
				symbol: "db_fx_FireBombExplosion",
				label: null,
				nativeScale: 1.2
			},
			{
				name: "Firebomb explosion fire",
				path: "Resources/Art2D/FX/db_fx_library.swf",
				symbol: "db_fx_FireBombExplosion_fire",
				label: null,
				nativeScale: 1.2
			},
			{
				name: "Alpha Tiger (Battleheim lion)",
				path: "Resources/Art3D/Enemy/tigerSiberian/db_emy_tigerSiberian.swf",
				symbol: "db_emy_tigerSiberian",
				label: "roar_angE",
				pixels: 190
			},
			{
				name: "Ally Frenzy flames",
				path: "Resources/Art2D/FX/db_fx_library.swf",
				symbol: "db_buff_battlefury",
				label: null,
				nativeScale: 1
			},
			{
				name: "Alpha howl shockwave",
				path: "Resources/Art2D/FX/db_fx_library.swf",
				symbol: "db_fx_whiteShockwave",
				label: null,
				nativeScale: 1
			},
			{
				name: "Alpha howl charge release",
				path: "Resources/Art2D/FX/db_fx_library.swf",
				symbol: "db_fx_charge_release",
				label: null,
				nativeScale: 1
			}
		];

	public static function heroes():Array<Dynamic>
		return [
			{
				"name": "Berserker",
				"path": "Resources/Art3D/Avatar/Berserker/db_char_berserker.swf",
				"symbol": "db_char_berserker",
				"label": "idle_angE",
				"pixels": 145
			},
			{
				"name": "Ranger",
				"path": "Resources/Art3D/Avatar/ranger/db_char_ranger.swf",
				"symbol": "db_char_ranger",
				"label": "idle_angE",
				"pixels": 145
			},
			{
				"name": "Sorcerer",
				"path": "Resources/Art3D/Avatar/wizard/db_char_wizard.swf",
				"symbol": "db_char_wizard",
				"label": "idle_angE",
				"pixels": 145
			},
			{
				"name": "Battle Chef",
				"path": "Resources/Art3D/Avatar/chef/db_char_chef.swf",
				"symbol": "db_char_chef",
				"label": "idle_angE",
				"pixels": 145
			},
			{
				"name": "Vampire Hunter",
				"path": "Resources/Art3D/Avatar/vampireHunter/db_char_vampireHunter.swf",
				"symbol": "db_char_vampireHunter",
				"label": "idle_angE",
				"pixels": 162
			},
			{
				"name": "Ghost Samurai",
				"path": "Resources/Art3D/Avatar/ghostSamurai/db_char_ghostSamurai.swf",
				"symbol": "db_char_ghostSamurai",
				"label": "idle_angE",
				"pixels": 196
			},
			{
				"name": "Pyromancer",
				"path": "Resources/Art3D/Avatar/pyromancerMage/db_char_pyromancerMage.swf",
				"symbol": "db_char_pyromancerMage",
				"label": "idle_angE",
				"pixels": 162
			},
			{
				"name": "Dragon Knight",
				"path": "Resources/Art3D/Avatar/dragonKnight/db_char_dragonKnight.swf",
				"symbol": "db_char_dragonKnight",
				"label": "idle_angE",
				"pixels": 145
			}
		];

	public static inline final ROUND_MS = 4000;
	public static inline final WARMUP_MS = 250;
	public static inline final MAX_MS = 60000;

	public static function assetIndex(kind:Int, n:Int):Int {
		if (kind == -2)
			return 17 + n % 4;
		if (kind == -3)
			return n % 2 == 0 ? 2 : 6;
		if (kind == -4)
			return [3, 7, 5, 10, 12, 8, 13, 9, 14, 11][n % 10];
		if (kind == -5)
			return 15 + n % 2;
		return kind < 0 ? n % 21 : kind;
	}

	public static function requires(kind:Int, index:Int):Bool {
		if (kind >= 0)
			return kind == index;
		for (n in 0...42)
			if (assetIndex(kind, n) == index)
				return true;
		return false;
	}

	public static function rounds():Array<Dynamic>
		return [
			{name: "Four-hero room baseline", count: 0, kind: 0},
			{name: "Dragon mouth and breath", count: 2, kind: -3},
			{name: "Lion Fury / Ally Frenzy", count: 12, kind: -2},
			{name: "Isolated: Firebomb explosion", count: 16, kind: 15},
			{name: "Isolated: Berserker ultimate", count: 16, kind: 7},
			{name: "Isolated: Sorcerer ultimate", count: 16, kind: 8},
			{name: "Isolated: Ranger flare", count: 16, kind: 9},
			{name: "Isolated: Ultimate burst", count: 16, kind: 10},
			{name: "Isolated: Chef meteor", count: 16, kind: 11},
			{name: "Hero ultimates together", count: 40, kind: -4},
			{name: "Heavy ultimate effects", count: 120, kind: -4},
			{name: "Extreme mixed finale", count: 160, kind: -1}
		];
}
