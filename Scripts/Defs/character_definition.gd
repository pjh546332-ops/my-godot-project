class_name CharacterDefinition
extends UnitDefinition

## 아군 전용 캐릭터 정의.
## 기본 스탯/스프라이트/스킬 등은 UnitDefinition에서 상속.

# 시작 스킬을 따로 들고 싶다면 사용 (없으면 skills 배열만 사용해도 됨)
@export var starting_skills: Array[SkillDefinition] = []
