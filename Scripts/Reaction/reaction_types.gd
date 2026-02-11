class_name ReactionTypes
extends RefCounted
## 리액션 타입 상수 (적 공격 직전 선택)

enum Reaction {
	NO_REACTION,  ## 대응하지 않음 (기본 데미지, 리액션 소모 안 함)
	DODGE,        ## 회피 (target.agi*0.7 % 성공 시 0, 실패 시 1.3배)
	GUARD,        ## 방어 (받는 데미지 0.5배, 공격자 데미지 0)
	COUNTER       ## 반격 (공격자에게 target.str*0.8 반사)
}

const DEFAULT_REACTION: Reaction = Reaction.NO_REACTION

static func to_string_id(r: Reaction) -> String:
	match r:
		Reaction.NO_REACTION: return "no_reaction"
		Reaction.DODGE: return "dodge"
		Reaction.GUARD: return "guard"
		Reaction.COUNTER: return "counter"
	return "no_reaction"

## UI 표시용
static func to_display_name(r: Reaction) -> String:
	match r:
		Reaction.NO_REACTION: return "Hold"
		Reaction.DODGE: return "Dodge"
		Reaction.GUARD: return "Guard"
		Reaction.COUNTER: return "Counter"
	return "Hold"
