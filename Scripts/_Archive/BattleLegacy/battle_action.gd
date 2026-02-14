class_name BattleAction
extends RefCounted
## 행동 계획: actor, type(ATTACK/DEFEND), target(공격 시만)

var actor: BattleUnit = null
var type: ActionType = ActionType.DEFEND
var target: BattleUnit = null

enum ActionType { ATTACK, DEFEND }

func _init(p_actor: BattleUnit = null, p_type: ActionType = ActionType.DEFEND, p_target: BattleUnit = null) -> void:
	actor = p_actor
	type = p_type
	target = p_target

static func make_attack(p_actor: BattleUnit, p_target: BattleUnit) -> BattleAction:
	return BattleAction.new(p_actor, ActionType.ATTACK, p_target)

static func make_defend(p_actor: BattleUnit) -> BattleAction:
	return BattleAction.new(p_actor, ActionType.DEFEND, null)
