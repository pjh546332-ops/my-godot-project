extends Node

## 3D 전투 씬용 간단한 오케스트레이션 스크립트.
## BattleManager에서 유닛 목록을 받아 3D 스테이지에 배치만 수행한다.

@onready var battle_manager: BattleManager = $BattleManager
@onready var stage_3d: Node3D = $World3D/BattleStage3D


func _ready() -> void:
	## BattleManager와 Stage가 모두 _ready 된 뒤에 3D 유닛 배치를 수행하기 위해 지연 호출.
	call_deferred("_setup_3d_units")


func _setup_3d_units() -> void:
	if battle_manager == null:
		return
	if stage_3d == null:
		return
	if stage_3d.has_method("spawn_units_from_manager"):
		stage_3d.spawn_units_from_manager(battle_manager)
