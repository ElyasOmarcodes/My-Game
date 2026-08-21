extends Node3D
## Renders the review screenshots.
##
## The sandbox this project is developed in has no GPU and cannot reach the
## asset kits, so the only place the real game can be photographed is CI. This
## scene builds the world exactly as a match would, moves a camera through a few
## fixed viewpoints and writes a PNG at each one.
##
## Run it with:
##   xvfb-run -a godot --path godot --rendering-method gl_compatibility \
##       --rendering-driver opengl3 res://scenes/Shots.tscn

const SEED := 20260821
const SETTLE_FRAMES := 6

var _library: AssetLibrary
var _city: CityBuilder
var _camera: Camera3D
var _output_dir: String

func _ready() -> void:
	_output_dir = OS.get_environment("BOA_SHOT_DIR")
	if _output_dir == "":
		_output_dir = ProjectSettings.globalize_path("res://../docs/screenshots")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	_build_environment()

	_library = AssetLibrary.new(SEED)
	_city = CityBuilder.new()
	add_child(_city)
	_city.build(_library, SEED)

	_camera = Camera3D.new()
	_camera.current = true
	add_child(_camera)

	await _run()
	get_tree().quit()

func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-36, 44, 0)
	light.light_color = Color(1.0, 0.89, 0.76)
	light.light_energy = 1.9
	light.shadow_enabled = true
	add_child(light)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-16, -128, 0)
	fill.light_color = Color(0.62, 0.74, 1.0)
	fill.light_energy = 0.7
	fill.shadow_enabled = false
	add_child(fill)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.10, 0.17, 0.30)
	sky_material.sky_horizon_color = Color(0.32, 0.34, 0.38)
	sky_material.ground_bottom_color = Color(0.04, 0.05, 0.07)
	sky_material.ground_horizon_color = Color(0.18, 0.19, 0.22)
	environment.sky.sky_material = sky_material

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 2.2
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.17, 0.21, 0.29)
	environment.fog_density = 0.004
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES

	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

func _run() -> void:
	var span := _city.span()

	await _shot("godot-town-aerial",
		Vector3(-span * 0.55, span * 0.42, -span * 0.55), Vector3(0, 4, 0), 48.0)

	await _shot("godot-town-street",
		Vector3(-CityBuilder.TILE * 1.5, 2.2, -span * 0.32),
		Vector3(-CityBuilder.TILE * 1.5, 5.0, span * 0.2), 66.0)

	_spawn_lineup()
	await _shot("godot-agents", Vector3(0.4, 1.55, 6.4), Vector3(0, 1.0, 0), 42.0)

func _spawn_lineup() -> void:
	# A clean patch of street to stand the roster on.
	var stage := Vector3(0, 40, 0)
	_camera.position += stage

	var floor_mesh := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(20, 0.4, 20)
	floor_mesh.mesh = plate
	floor_mesh.position = stage + Vector3(0, -0.2, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.09, 0.10, 0.13)
	floor_mesh.material_override = material
	add_child(floor_mesh)

	var index := 0
	for entry in AgentCatalog.AGENTS:
		var body := RemotePlayer.create(_library, {
			"id": "shot-%d" % index,
			"agent": entry["id"],
			"team": Session.Team.ALPHA if index % 2 == 0 else Session.Team.BRAVO,
		})
		add_child(body)
		body.global_position = stage + Vector3(-2.55 + index * 1.7, 0, 0)
		body.rotation_degrees.y = 205 + (index - 1.5) * 6
		index += 1

func _shot(name: String, from: Vector3, look_at: Vector3, fov: float) -> void:
	_camera.fov = fov
	_camera.global_position = from
	_camera.look_at(look_at, Vector3.UP)

	# Give the renderer time to stream in shadows and finish the first frames.
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_output_dir, name]
	var error := image.save_png(path)
	print("[shot] %s -> %s (%d)" % [name, path, error])
