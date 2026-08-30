class_name StancePose
extends RefCounted
## Bends the agent's skeleton into a crouch or down into a prone position.
##
## The rig ships Idle, Walk and Run and nothing else, so there is no crouch clip
## to play — and lowering the camera alone, which is what the game did before,
## left the body standing bolt upright while the player believed they were
## behind cover. This poses the bones instead: hips and knees fold for a crouch,
## and the whole body pitches down onto its front for prone.
##
## Bone names differ between rigs (`mixamorig:LeftUpLeg`, `Hips`, `thigh.L`), so
## every bone is found by what its name contains rather than by an exact match.

enum { STAND, CROUCH, PRONE }

## degrees, applied on top of whatever the animation is doing
const CROUCH_POSE := {
	"hips": Vector3(-18, 0, 0),
	"spine": Vector3(16, 0, 0),
	"upleg": Vector3(-62, 0, 0),
	"leg": Vector3(74, 0, 0),
	"foot": Vector3(-16, 0, 0),
}
const PRONE_POSE := {
	"hips": Vector3(-8, 0, 0),
	"spine": Vector3(6, 0, 0),
	"upleg": Vector3(-10, 0, 0),
	"leg": Vector3(14, 0, 0),
	"foot": Vector3(-6, 0, 0),
}

const BLEND_SPEED := 7.0

var _skeleton: Skeleton3D
var _bones: Dictionary = {}           # role -> Array[int]
var _rest: Dictionary = {}            # bone index -> Quaternion
var _blend := 0.0                     # 0 standing, 1 fully in the pose
var _target := 0.0
var _pose: Dictionary = CROUCH_POSE

func _init(model: Node3D) -> void:
	if model == null:
		return
	for node in model.find_children("*", "Skeleton3D", true, false):
		_skeleton = node as Skeleton3D
		if _skeleton != null:
			break
	if _skeleton == null:
		return
	_map_bones()

func _map_bones() -> void:
	for i in _skeleton.get_bone_count():
		var name := _skeleton.get_bone_name(i).to_lower()
		var role := ""
		# Order matters: "upleg" and "leg" both contain "leg", and a foot is not
		# a leg however the rig spells it.
		if name.find("foot") != -1 or name.find("ankle") != -1:
			role = "foot"
		elif name.find("upleg") != -1 or name.find("thigh") != -1 \
				or name.find("upperleg") != -1:
			role = "upleg"
		elif name.find("leg") != -1 or name.find("shin") != -1 \
				or name.find("calf") != -1 or name.find("knee") != -1:
			role = "leg"
		elif name.find("spine") != -1 or name.find("chest") != -1:
			role = "spine"
		elif name.find("hips") != -1 or name.find("pelvis") != -1:
			role = "hips"
		if role == "":
			continue
		if not _bones.has(role):
			_bones[role] = []
		_bones[role].append(i)
		_rest[i] = _skeleton.get_bone_pose_rotation(i)

func ready() -> bool:
	return _skeleton != null and not _bones.is_empty()

func set_stance(stance: int) -> void:
	match stance:
		CROUCH:
			_pose = CROUCH_POSE
			_target = 1.0
		PRONE:
			_pose = PRONE_POSE
			_target = 1.0
		_:
			_target = 0.0

## Eased every frame so the agent folds into cover rather than snapping into it.
func advance(delta: float) -> void:
	if not ready():
		return
	if is_equal_approx(_blend, _target):
		return
	_blend = lerpf(_blend, _target, 1.0 - exp(-BLEND_SPEED * delta))
	_apply()

func _apply() -> void:
	for role in _bones:
		var offset: Vector3 = _pose.get(role, Vector3.ZERO) * _blend
		var rotation := Quaternion.from_euler(Vector3(
			deg_to_rad(offset.x), deg_to_rad(offset.y), deg_to_rad(offset.z)))
		for index in _bones[role]:
			var rest: Quaternion = _rest[index]
			_skeleton.set_bone_pose_rotation(index, rest * rotation)
