class_name PitcherAI extends Node

class Decision:
	var pitch_type: PitchTypes.Type
	var target: Vector3
	var accuracy: float

	func _init(pt: PitchTypes.Type, t: Vector3, a: float) -> void:
		pitch_type = pt
		target = t
		accuracy = a

# Pure decision function — testable without scene tree.
# The director calls decide() then request_pitch() exactly once per at-bat.
func decide(balls: int, strikes: int, history: Array) -> Decision:
	var pitch_type := _select_pitch_type(balls, strikes, history)
	var target := _select_target(balls, strikes, pitch_type)
	var accuracy := _accuracy_for(balls, strikes)
	return Decision.new(pitch_type, target, accuracy)

func _select_pitch_type(balls: int, strikes: int, history: Array) -> PitchTypes.Type:
	var candidates: Array = [
		PitchTypes.Type.FASTBALL,
		PitchTypes.Type.CURVEBALL,
		PitchTypes.Type.SLIDER,
		PitchTypes.Type.CHANGEUP,
	]
	if history.size() > 0 and randf() < 0.7:
		candidates.erase(history[history.size() - 1])

	if balls >= 2 and strikes == 0 and randf() < 0.7:
		return PitchTypes.Type.FASTBALL

	if strikes == 2 and balls <= 1 and randf() < 0.6:
		if candidates.size() > 0:
			return candidates[randi() % candidates.size()]
		return PitchTypes.Type.SLIDER

	if candidates.size() == 0:
		return PitchTypes.Type.FASTBALL
	return candidates[randi() % candidates.size()]

func _select_target(balls: int, strikes: int, pitch_type: PitchTypes.Type) -> Vector3:
	if balls >= 3 and strikes == 0:
		return Vector3(0.0, 0.8, 0.0)
	if strikes == 2 and balls <= 1:
		return Vector3(randf_range(-0.3, 0.3), 0.3, 0.0)
	return Vector3(randf_range(-0.25, 0.25), randf_range(0.55, 1.05), 0.0)

func _accuracy_for(balls: int, strikes: int) -> float:
	if balls == 3: return 0.95
	if strikes == 2: return 0.90
	return 0.80
