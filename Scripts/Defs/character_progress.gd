class_name CharacterProgress
extends Resource

## 캐릭터 성장/영구 데이터(Resource 기반, 추후 세이브로 교체)

@export var character_id: String = ""  ## CharacterDefinition.id 와 매칭

@export var level: int = 1
@export var exp: int = 0

@export var bonus_strength: int = 0
@export var bonus_vitality: int = 0
@export var bonus_agility: int = 0


func add_exp(amount: int) -> void:
	if amount <= 0:
		return
	exp += amount
	while exp >= exp_to_next(level):
		exp -= exp_to_next(level)
		level_up()


func exp_to_next(lv: int) -> int:
	## 매우 단순한 경험치 곡선: 10, 15, 20, ...
	return 10 + max(lv - 1, 0) * 5


func level_up() -> void:
	level += 1
	## 임시: 레벨업 시 보너스 스탯 자동 증가
	bonus_strength += 1
	bonus_vitality += 2
	bonus_agility += 1
