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
	WorldLook.apply(self)

func _run() -> void:
	# Physics has to tick once before a supplied map has a floor to stand on.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var span := _city.span()
	var middle := _city.centre()

	await _shot("godot-town-aerial",
		middle + Vector3(-span * 0.42, span * 0.34, -span * 0.42),
		middle + Vector3(0, 1.5, 0), 50.0)

	# Head height, looking across the map.
	var eye := _city.spawn_for(0, Session.Team.ALPHA).origin + Vector3(0, 1.0, 0)
	await _shot("godot-town-street", eye, middle + Vector3(0, 2.0, 0), 70.0)

	await _shot("godot-town-corner",
		middle + Vector3(span * 0.16, 6.0, -span * 0.2),
		middle + Vector3(span * 0.02, 1.5, 0), 62.0)

	var stage := middle + Vector3(0, 400.0, 0)
	_spawn_lineup(stage)
	await _shot("godot-agents",
		stage + Vector3(0.3, 1.35, 5.4), stage + Vector3(0, 0.95, 0), 44.0)
	await _shot("godot-weapons",
		stage + Vector3(-0.2, 1.15, 2.4), stage + Vector3(-0.2, 1.05, 0), 34.0)

	# Back to a street view: the overlays are photographed over the world, not
	# over the line-up stage the agents are standing on.
	await _shot("godot-hud-setup",
		middle + Vector3(span * 0.16, 2.0, -span * 0.2),
		middle + Vector3(span * 0.02, 2.0, 0), 70.0)
	DirAccess.remove_absolute("%s/godot-hud-setup.png" % _output_dir)
	await _shoot_ui()

## The roster on a clean plate, well clear of the map so nothing photobombs it.
## The two screens a player actually spends time in. They are photographed the
## same way as the world, from the same build, so what is in docs/screenshots is
## what ships rather than a mock-up of it.
func _shoot_ui() -> void:
	var hud := Hud.new()
	add_child(hud)
	var player := Player.create(_library, Session.agent_id, Session.Team.ALPHA,
		Session.player_id, true)
	add_child(player)
	player.global_transform = _city.spawn_for(0, Session.Team.ALPHA)
	hud.bind(player)
	await _shot_here("godot-hud")
	hud.queue_free()
	player.queue_free()

	var menu := MainMenu.new()
	add_child(menu)
	await _shot_here("godot-menu")
	menu.queue_free()

## A frame from wherever the camera already is — for the overlays, where the
## world behind them only has to be plausible.
func _shot_here(name: String) -> void:
	_camera.current = true
	for i in SETTLE_FRAMES + 4:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_output_dir, name]
	print("[shot] %s -> %s (%d)" % [name, path, image.save_png(path)])

func _spawn_lineup(stage: Vector3) -> void:
	var floor_mesh := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(24, 0.4, 24)
	floor_mesh.mesh = plate
	floor_mesh.position = stage + Vector3(0, -0.2, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.41, 0.39)
	material.roughness = 0.9
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
		var yaw := deg_to_rad(185.0 + (index - 1.5) * 7.0)
		body.place(Transform3D(Basis(Vector3.UP, yaw),
			stage + Vector3(-2.4 + index * 1.6, 0, 0)))
		index += 1

func _shot(name: String, from: Vector3, look_at: Vector3, fov: float) -> void:
	_camera.current = true
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
