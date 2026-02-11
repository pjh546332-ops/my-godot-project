class_name SkillDefinition
extends Resource

## 스킬 정의(이름/위력/타겟 타입 등)

enum TargetType {
	SINGLE_ENEMY,
	SINGLE_ALLY,
	SELF,
	ALL_ENEMIES,
	ALL_ALLIES,
}

@export var id: String = ""
@export var display_name: String = ""
@export var power: int = 10
@export var target_type: TargetType = TargetType.SINGLE_ENEMY

