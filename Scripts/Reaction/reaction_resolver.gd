class_name ReactionResolver
extends RefCounted
## 리액션 적용: 입력(attacker, target, base_damage, reaction) → damage_to_target, damage_to_attacker

static func resolve(
	attacker: BattleUnit,
	target: BattleUnit,
	base_damage: int,
	reaction: ReactionTypes.Reaction
) -> Dictionary:
	## 반환: { "damage_to_target": int, "damage_to_attacker": int }
	var damage_to_target := base_damage
	var damage_to_attacker := 0

	if reaction == ReactionTypes.Reaction.COUNTER:
		damage_to_attacker = int(target.strength * 0.8)
		damage_to_target = base_damage

	elif reaction == ReactionTypes.Reaction.DODGE:
		var success_chance: float = target.agility * 0.7
		var roll := randf_range(0.0, 100.0)
		if roll < success_chance:
			damage_to_target = 0
		else:
			damage_to_target = int(base_damage * 1.3)

	elif reaction == ReactionTypes.Reaction.GUARD:
		damage_to_target = int(base_damage * 0.5)
		damage_to_attacker = 0

	else:
		# NO_REACTION: 기본 피격만, reaction_used_this_round 변경 안 함
		damage_to_target = base_damage
		damage_to_attacker = 0

	return {
		"damage_to_target": damage_to_target,
		"damage_to_attacker": damage_to_attacker
	}
