extends Node
## MVP 전투 씬 루트: BattleManager + 최소 UI 연결

@onready var battle_manager: BattleManager = $BattleManager
@onready var battle_ui: BattleMvpUi = $CanvasLayer/BattleMvpUi

func _ready() -> void:
	if battle_ui and battle_manager:
		battle_ui.setup(battle_manager)
