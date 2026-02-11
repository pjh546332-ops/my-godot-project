class_name EnemyCatalog
extends Node

## 적 정의 로더/팩토리.
## - EnemyDefinition(.tres) 로드
## - BattleUnit 생성

const DEF_DIR := "res://Data/Enemies"

var _definitions: Dictionary = {}  ## id -> EnemyDefinition


func _ready() -> void:
	_load_definitions()


func _load_definitions() -> void:
	var dir := DirAccess.open(DEF_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue
		if not name.ends_with(".tres"):
			continue
		var res := load(DEF_DIR + "/" + name)
		if res is EnemyDefinition and res.id != "":
			_definitions[res.id] = res
	dir.list_dir_end()


func get_enemy_def(id: String) -> EnemyDefinition:
	return _definitions.get(id, null)


func make_enemy_unit(id: String) -> BattleUnit:
	var def := get_enemy_def(id)
	if def == null:
		# 정의가 없으면 디버그용 기본 적 유닛으로 대체
		var fallback := BattleUnit.new(id, BattleUnit.Team.ENEMY)
		return fallback

	var u := BattleUnit.new(id, BattleUnit.Team.ENEMY)
	u.definition = def
	u.progress = null
	u.team = BattleUnit.Team.ENEMY

	u.unit_name = def.display_name if def.display_name != "" else id

	u.strength = def.base_strength
	u.vitality = def.base_vitality
	u.agility = def.base_agility
	u.intelligence = u.strength

	u.hp = u.max_hp
	return u

