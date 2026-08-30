class_name WorldLook
extends RefCounted
## The lighting and sky the game is seen through.
##
## The match scene and the screenshot scene both build their world in code, and
## when each kept its own copy of the lighting they drifted apart — the shots
## stopped being evidence of what the game looks like. There is one copy now.

## Clear afternoon. The first builds were lit for night and every CC0 kit came
## out a flat navy blue, which read as untextured rather than as evening.
static func apply(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	root.add_child(sun)

	# A dim sky-coloured bounce so the shadowed side of a wall keeps its colour.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, -140, 0)
	fill.light_color = Color(0.72, 0.82, 1.0)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	root.add_child(fill)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.24, 0.45, 0.78)
	sky_material.sky_horizon_color = Color(0.76, 0.84, 0.92)
	sky_material.sky_energy_multiplier = 1.0
	sky_material.ground_bottom_color = Color(0.32, 0.30, 0.27)
	sky_material.ground_horizon_color = Color(0.62, 0.60, 0.56)
	environment.sky.sky_material = sky_material

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.85
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.70, 0.78, 0.88)
	environment.fog_density = 0.0012
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 4.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.25

	var world := WorldEnvironment.new()
	world.environment = environment
	root.add_child(world)
