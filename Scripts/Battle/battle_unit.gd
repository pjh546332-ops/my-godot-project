class_name BattleUnit
extends RefCounted
## 전투 유닛: name, team, 기본 스탯(str/agi/int/vit) 및 파생 수치, 라운드 상태.

const ReactionTypes = preload("res://Scripts/Reaction/reaction_types.gd")

## 캐릭터/적 공통 정의 + (선택) 아군 성장 데이터
var definition: UnitDefinition = null
var progress: CharacterProgress = null

enum Team { ALLY, ENEMY }

var name: String = ""
var unit_name: String = ""
var team: int = Team.ALLY
var default_reaction: ReactionTypes.Reaction = ReactionTypes.Reaction.NO_REACTION
var reaction_used_this_round: bool = false
## 기본 스탯 (str=strength, agi=agility, int=intelligence, vit=vitality)
var strength: int = 5
var agility: int = 5
var intelligence: int = 5
var vitality: int = 5

var hp: int = 50
var speed: int = 5
var defending: bool = false
var cell: Vector2i = Vector2i(-1, -1)
var visual_node: Node2D = null

func _init(p_name: String = "", p_team: int = Team.ALLY) -> void:
	name = p_name
	unit_name = p_name
	team = p_team
	if team == Team.ALLY:
		strength = 5
		agility = 5
		intelligence = 5
		vitality = 5
	else:
		strength = 3
		agility = 3
		intelligence = 3
		vitality = 3
	hp = max_hp

## 성장/정의 기반 전투 스탯 조회용 헬퍼(getter)
func get_strength() -> int:
	if definition:
		var base := definition.base_strength
		var bonus := (progress.bonus_strength if progress else 0)
		return base + bonus
	return strength


func get_vitality() -> int:
	if definition:
		var base := definition.base_vitality
		var bonus := (progress.bonus_vitality if progress else 0)
		return base + bonus
	return vitality


func get_agility() -> int:
	if definition:
		var base := definition.base_agility
		var bonus := (progress.bonus_agility if progress else 0)
		return base + bonus
	return agility

## 파생: 공격력 = str
var attack: int: get = _get_attack
func _get_attack() -> int: return get_strength()

## 파생: 방어력 = str
var defense: int: get = _get_defense
func _get_defense() -> int: return get_strength()

## 파생: 최대 HP = vit * 10
var max_hp: int: get = _get_max_hp
func _get_max_hp() -> int: return get_vitality() * 10

## 파생: 속도 보정 = agi
var speed_bonus: int: get = _get_speed_bonus
func _get_speed_bonus() -> int: return get_agility()

## 파생: 회피율(%) = agi * 0.7
var evasion_rate: float: get = _get_evasion_rate
func _get_evasion_rate() -> float: return get_agility() * 0.7

func is_ally() -> bool:
	return team == Team.ALLY

func is_enemy() -> bool:
	return team == Team.ENEMY

func take_damage(amount: int) -> void:
	hp = clampi(hp - amount, 0, 99999)

func is_alive() -> bool:
	return hp > 0

func set_highlight(on: bool) -> void:
	if not visual_node:
		return
	if visual_node.has_method("set_highlight"):
		visual_node.set_highlight(on)
