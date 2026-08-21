class_name RemotePlayer
extends Node3D
## Another player's agent, driven by the 20 Hz transform stream.
##
## Snapshots arrive every 50 ms, which would look like a slideshow drawn
## directly, so the body eases towards the newest one each frame.

const POSITION_SMOOTHING := 12.0
const ROTATION_SMOOTHING := 14.0

var player_id: String = ""
var agent: Dictionary = {}

var _target_position := Vector3.ZERO
var _target_yaw := 0.0
var _animation: AnimationPlayer
var _last_position := Vector3.ZERO

static func create(library: AssetLibrary, entry: Dictionary) -> RemotePlayer:
	var body := RemotePlayer.new()
	body.player_id = String(entry.get("id", ""))
	body.agent = AgentCatalog.agent(String(entry.get("agent", "vanguard")))
	body.set_meta("library", library)
	body.set_meta("team", int(entry.get("team", Session.Team.ALPHA)))
	return body

func _ready() -> void:
	var library: AssetLibrary = get_meta("library")
	var scene: PackedScene = null
	if library and library.has("characters"):
		scene = library.find("characters", String(agent.get("model_hint", "")))
		if scene == null:
			scene = library.pick("characters", AgentCatalog.agent_index(agent["id"]))

	if scene:
		var instance: Node = scene.instantiate()
		add_child(instance)
		_animation = _find_animation_player(instance)
	else:
		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.height = 1.8
		capsule.radius = 0.35
		mesh.mesh = capsule
		mesh.position.y = 0.9
		var material := StandardMaterial3D.new()
		material.albedo_color = agent.get("accent", Color.CYAN)
		mesh.material_override = material
		add_child(mesh)

	# A body the local weapon can actually hit.
	var area := StaticBody3D.new()
	area.collision_layer = 2
	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.height = 1.8
	capsule_shape.radius = 0.4
	shape.shape = capsule_shape
	shape.position.y = 0.9
	area.add_child(shape)
	add_child(area)

	_target_position = global_position

func _process(delta: float) -> void:
	if has_meta("target_position"):
		_target_position = get_meta("target_position")
		_target_yaw = get_meta("target_yaw")

	var travelled := global_position.distance_to(_target_position)
	global_position = global_position.lerp(_target_position, 1.0 - exp(-POSITION_SMOOTHING * delta))
	rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-ROTATION_SMOOTHING * delta))

	_drive_animation(travelled / maxf(delta, 0.0001))

func _drive_animation(speed: float) -> void:
	if _animation == null:
		return
	var wanted := "Idle" if speed < 0.5 else ("Run" if speed > 7.0 else "Walk")
	for name in _animation.get_animation_list():
		if String(name).to_lower().find(wanted.to_lower()) != -1:
			if _animation.current_animation != name:
				_animation.play(name)
			return

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
