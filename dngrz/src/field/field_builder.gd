class_name FieldBuilder

static func build(parent: Node3D) -> void:
	_create_ground(parent)
	_create_infield_dirt(parent)
	_create_bases(parent)
	_create_mound(parent)
	_create_outfield_wall(parent)
	_create_foul_lines(parent)

static func _create_ground(parent: Node3D) -> void:
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(300.0, 0.1, 300.0)
	ground.position = Vector3(0.0, -0.05, -80.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 0.15)  # grass green
	ground.material = mat
	parent.add_child(ground)

static func _create_infield_dirt(parent: Node3D) -> void:
	var dirt := CSGBox3D.new()
	dirt.name = "InfieldDirt"
	dirt.size = Vector3(55.0, 0.12, 55.0)
	dirt.position = Vector3(0.0, -0.01, -19.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.45, 0.25)  # dirt brown
	dirt.material = mat
	parent.add_child(dirt)

static func _create_bases(parent: Node3D) -> void:
	var base_positions := {
		"HomePlate": FieldConstants.HOME_PLATE,
		"FirstBase": FieldConstants.FIRST_BASE,
		"SecondBase": FieldConstants.SECOND_BASE,
		"ThirdBase": FieldConstants.THIRD_BASE,
	}
	for base_name in base_positions:
		var base := CSGBox3D.new()
		base.name = base_name
		base.size = Vector3(0.38, 0.06, 0.38)
		base.position = base_positions[base_name] + Vector3(0.0, 0.03, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE
		base.material = mat
		parent.add_child(base)

static func _create_mound(parent: Node3D) -> void:
	var mound := CSGCylinder3D.new()
	mound.name = "Mound"
	mound.radius = 2.75
	mound.height = FieldConstants.MOUND_HEIGHT
	mound.position = Vector3(0.0, FieldConstants.MOUND_HEIGHT / 2.0, -FieldConstants.MOUND_DISTANCE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.4, 0.2)
	mound.material = mat
	parent.add_child(mound)

	# Pitching rubber
	var rubber := CSGBox3D.new()
	rubber.name = "PitchingRubber"
	rubber.size = Vector3(0.61, 0.05, 0.15)
	rubber.position = FieldConstants.MOUND + Vector3(0.0, 0.025, 0.0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color.WHITE
	rubber.material = rmat
	parent.add_child(rubber)

static func _create_outfield_wall(parent: Node3D) -> void:
	var segments := 20
	for i in segments:
		var angle: float = lerp(-PI / 4.0, PI / 4.0, float(i) / float(segments - 1))
		var t: float = absf(float(i) / float(segments - 1) - 0.5) * 2.0
		var dist: float = lerpf(FieldConstants.FENCE_CENTER, FieldConstants.FENCE_CORNERS, t)
		var pos := Vector3(sin(angle) * dist, 1.5, -cos(angle) * dist)

		var wall := CSGBox3D.new()
		wall.name = "Fence_%d" % i
		wall.size = Vector3(dist * PI / float(segments) * 1.1, 3.0, 0.3)
		wall.position = pos
		wall.rotation.y = angle
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.3, 0.15)
		wall.material = mat
		parent.add_child(wall)

static func _create_foul_lines(parent: Node3D) -> void:
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color.WHITE

	var left_line := CSGBox3D.new()
	left_line.name = "LeftFoulLine"
	left_line.size = Vector3(0.08, 0.02, 150.0)
	left_line.position = Vector3(-37.5, 0.01, -75.0)
	left_line.rotation.y = PI / 4.0
	left_line.material = line_mat
	parent.add_child(left_line)

	var right_line := CSGBox3D.new()
	right_line.name = "RightFoulLine"
	right_line.size = Vector3(0.08, 0.02, 150.0)
	right_line.position = Vector3(37.5, 0.01, -75.0)
	right_line.rotation.y = -PI / 4.0
	right_line.material = line_mat
	parent.add_child(right_line)
