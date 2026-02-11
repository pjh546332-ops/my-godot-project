class_name EnemyDefinition
extends UnitDefinition

## 적 유닛 정의.

enum AIProfile {
	BASIC_MELEE,
	BASIC_CASTER,
	BOSS,
}

@export var ai_profile: AIProfile = AIProfile.BASIC_MELEE
@export var level: int = 1
@export var exp_reward: int = 10
@export var loot_table: Resource
