extends Node
## 전역 게임 상태 (autoload). 씬 전환 시에도 유지.
## 전투 결과, 호감도, 플래그 등을 보관.

enum GameMode {
	EXPLORE,
	HUB,
	BATTLE,
	DIALOGUE
}

# ---- 전투 결과 ----
var last_battle_ally_won: bool = false
var last_battle_rounds: int = 0

# ---- 호감도 (캐릭터 ID -> 점수) ----
var affinity: Dictionary = {}

# ---- 플래그 (이벤트/진행도 등) ----
var flags: Dictionary = {}

# ---- 현재 모드 (참고용) ----
var current_mode: GameMode = GameMode.HUB


func set_flag(key: StringName, value: Variant) -> void:
	flags[key] = value


func get_flag(key: StringName, default: Variant = null) -> Variant:
	return flags.get(key, default)


func has_flag(key: StringName) -> bool:
	return flags.has(key)


func set_affinity(character_id: StringName, value: int) -> void:
	affinity[character_id] = value


func get_affinity(character_id: StringName) -> int:
	return affinity.get(character_id, 0)


func add_affinity(character_id: StringName, delta: int) -> void:
	affinity[character_id] = get_affinity(character_id) + delta


func set_battle_result(ally_won: bool, rounds: int) -> void:
	last_battle_ally_won = ally_won
	last_battle_rounds = rounds


func reset_for_new_game() -> void:
	last_battle_ally_won = false
	last_battle_rounds = 0
	affinity.clear()
	flags.clear()
