extends Node3D

func _ready() -> void:
	FieldBuilder.build(self)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.5, 0.6)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAP_ACES
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.5, 0.7, 1.0)
	env.environment = environment
	add_child(env)
