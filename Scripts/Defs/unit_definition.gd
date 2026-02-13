class_name UnitDefinition
extends Resource

## 공통 유닛 정의(아군/적 공통 베이스)

@export var id: String = ""
@export var display_name: String = ""

@export var base_strength: int = 5
@export var base_vitality: int = 5
@export var base_agility: int = 5

@export var sprite_3d: Texture2D
@export var portrait: Texture2D
## 유닛 기본 색감(Sprite3D.modulate). 아군/적 타입별 구분용.
@export var tint: Color = Color(1.0, 1.0, 1.0, 1.0)

@export var skills: Array[SkillDefinition] = []
@export var passive_script: Script
