class_name AllyRoster
extends Node

## 아군 캐릭터 전체를 관리하는 로스터.
## - CharacterDefinition(.tres) 로드
## - CharacterProgress(.tres 또는 메모리) 보관
## - 전투용 BattleUnit 생성/초기화

const DEF_DIR := "res://Data/Allies"
const PROGRESS_DIR := "res://Data/Progress"

var _definitions: Dictionary = {}   ## id -> CharacterDefinition
var _progress: Dictionary = {}      ## id -> CharacterProgress


func _ready() -> void:
	_load_definitions()
	_load_progress()


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
		if res is CharacterDefinition and res.id != "":
			_definitions[res.id] = res
	dir.list_dir_end()


func _load_progress() -> void:
	var dir := DirAccess.open(PROGRESS_DIR)
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
		var res := load(PROGRESS_DIR + "/" + name)
		if res is CharacterProgress and res.character_id != "":
			_progress[res.character_id] = res
	dir.list_dir_end()


func get_definition(character_id: String) -> CharacterDefinition:
	return _definitions.get(character_id, null)


## 로스터에 등록된 아군 ID 목록 (캐릭터 북 등에서 사용)
func get_roster_ally_ids() -> Array:
	var ids: Array = []
	for k in _definitions.keys():
		ids.append(k)
	return ids


func get_progress(character_id: String) -> CharacterProgress:
	if _progress.has(character_id):
		return _progress[character_id]
	# 진행 데이터가 없으면 새로 생성(메모리 상에만 유지, 추후 세이브로 교체)
	var p := CharacterProgress.new()
	p.character_id = character_id
	_progress[character_id] = p
	return p


func make_battle_unit(character_id: String) -> BattleUnit:
	var def := get_definition(character_id)
	if def == null:
		# 정의가 없으면 기존 디버그용 기본 유닛으로 대체
		var fallback := BattleUnit.new(character_id, BattleUnit.Team.ALLY)
		return fallback

	var prog := get_progress(character_id)
	var u := BattleUnit.new(character_id, BattleUnit.Team.ALLY)
	u.definition = def
	u.progress = prog
	u.team = BattleUnit.Team.ALLY

	# 전투용 스냅샷 스탯 계산
	u.unit_name = def.display_name if def.display_name != "" else character_id
	# 필드 값은 getter에서 다시 계산되므로 여기선 초기화 의미로만 사용
	u.strength = def.base_strength + prog.bonus_strength
	u.vitality = def.base_vitality + prog.bonus_vitality
	u.agility = def.base_agility + prog.bonus_agility
	u.intelligence = u.strength

	u.hp = u.max_hp
	return u


## 전투 보상 경험치를 각 캐릭터 Progress에 반영
## rewards 예: { "ALLY_ERICH": 30, "ALLY_LINA": 20 }
func grant_battle_rewards(rewards: Dictionary) -> void:
	for id in rewards.keys():
		var amount := int(rewards[id])
		var prog := get_progress(id)
		if prog:
			prog.add_exp(amount)
