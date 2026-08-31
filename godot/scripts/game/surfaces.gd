class_name Surfaces
extends RefCounted
## The world's materials, generated rather than downloaded.
##
## Every surface here is built from one seamless tile made in code and then
## repeated across whatever it is applied to, with a normal map derived from the
## same tile so the light catches it. Nothing is loaded from disk: a texture
## written as code is readable in a diff, costs nothing in the APK, and can be
## re-tuned by changing a number rather than by re-exporting an image.
##
## Tiles are 256 px. Larger looks no better once it is repeated across a lawn,
## and each one is generated once and shared by every surface that wants it.

const TILE := 256

static var _cache: Dictionary = {}

## Soft, uneven turf. Two scales of noise: broad patches for the mown-in bands
## you see across a lawn, and fine grain for the blades themselves.
static func grass() -> StandardMaterial3D:
	return _make("grass", func() -> StandardMaterial3D:
		var image := Image.create(TILE, TILE, false, Image.FORMAT_RGB8)
		var broad := _noise(4.0, 1)
		var fine := _noise(26.0, 2)
		var blades := _noise(90.0, 3)

		for y in TILE:
			for x in TILE:
				var patch := _sample(broad, x, y)
				var grain := _sample(fine, x, y)
				var blade := _sample(blades, x, y)
				# Green stays dominant; the variation rides on brightness and a
				# little yellow, which is how real turf actually varies.
				var lift := 0.72 + patch * 0.34 + grain * 0.20 + blade * 0.12
				var colour := Color(
					0.16 * lift + grain * 0.05,
					0.44 * lift + patch * 0.06,
					0.14 * lift)
				image.set_pixel(x, y, colour)

		var material := StandardMaterial3D.new()
		material.albedo_texture = _texture(image)
		material.normal_enabled = true
		material.normal_texture = _normal_from(image, 2.6)
		material.normal_scale = 0.8
		material.roughness = 0.95
		material.uv1_scale = Vector3(6, 6, 1)
		return material)

## Brick: staggered courses with mortar between them and a different tone on
## every brick, seamless because a course that runs off the right edge is the
## same course that comes back in on the left.
static func brick(base: Color = Color(0.72, 0.44, 0.34)) -> StandardMaterial3D:
	var key := "brick%s" % base.to_html(false)
	return _make(key, func() -> StandardMaterial3D:
		var image := Image.create(TILE, TILE, false, Image.FORMAT_RGB8)
		var rows := 8
		var courses := 4
		var brick_h := TILE / rows
		var brick_w := TILE / courses
		var mortar := 3
		var grain := _noise(70.0, 4)
		var wear := _noise(9.0, 5)
		var mortar_colour := Color(0.68, 0.66, 0.62)

		for y in TILE:
			var row := y / brick_h
			# Every other course is offset by half a brick.
			var offset := brick_w / 2 if row % 2 == 1 else 0
			var in_row := y % brick_h

			for x in TILE:
				var shifted := (x + offset) % TILE
				var in_brick := shifted % brick_w
				var is_mortar := in_row < mortar or in_brick < mortar

				var colour: Color
				if is_mortar:
					colour = mortar_colour.darkened(0.05 + _sample(grain, x, y) * 0.12)
				else:
					# One tone per brick, so a wall reads as many bricks and not
					# as a photograph of noise.
					var id := row * 31 + (shifted / brick_w) * 17
					var tone := fmod(sin(float(id) * 12.9898) * 43758.5453, 1.0)
					tone = absf(tone)
					colour = base.lerp(base.darkened(0.35), tone * 0.75)
					colour = colour.lightened(_sample(grain, x, y) * 0.10)
					colour = colour.darkened(_sample(wear, x, y) * 0.14)
				image.set_pixel(x, y, colour)

		var material := StandardMaterial3D.new()
		material.albedo_texture = _texture(image)
		material.normal_enabled = true
		material.normal_texture = _normal_from(image, 3.4)
		material.normal_scale = 1.2
		material.roughness = 0.92
		material.uv1_scale = Vector3(2, 2, 1)
		return material)

## Vertical boards with a gap between them and grain along their length.
static func planks(base: Color = Color(0.58, 0.41, 0.26)) -> StandardMaterial3D:
	var key := "planks%s" % base.to_html(false)
	return _make(key, func() -> StandardMaterial3D:
		var image := Image.create(TILE, TILE, false, Image.FORMAT_RGB8)
		var boards := 6
		var board_w := TILE / boards
		var grain := _noise(140.0, 6)
		var slow := _noise(11.0, 7)

		for x in TILE:
			var index := x / board_w
			var in_board := x % board_w
			var tone := absf(fmod(sin(float(index) * 78.233) * 43758.5453, 1.0))
			for y in TILE:
				var colour := base.lerp(base.darkened(0.30), tone * 0.7)
				# Grain runs along the board, so it is sampled far more finely
				# across the board than along it.
				colour = colour.darkened(_sample(grain, x * 4, y) * 0.16)
				colour = colour.lightened(_sample(slow, x, y) * 0.08)
				if in_board < 2 or in_board > board_w - 3:
					colour = colour.darkened(0.45)
				image.set_pixel(x, y, colour)

		var material := StandardMaterial3D.new()
		material.albedo_texture = _texture(image)
		material.normal_enabled = true
		material.normal_texture = _normal_from(image, 2.2)
		material.normal_scale = 0.9
		material.roughness = 0.88
		material.uv1_scale = Vector3(2, 2, 1)
		return material)

## Worn asphalt, for the roads.
static func asphalt() -> StandardMaterial3D:
	return _make("asphalt", func() -> StandardMaterial3D:
		var image := Image.create(TILE, TILE, false, Image.FORMAT_RGB8)
		var chips := _noise(120.0, 8)
		var patches := _noise(7.0, 9)
		for y in TILE:
			for x in TILE:
				var value := 0.19 + _sample(chips, x, y) * 0.13 \
					+ _sample(patches, x, y) * 0.06
				image.set_pixel(x, y, Color(value, value * 1.01, value * 1.05))

		var material := StandardMaterial3D.new()
		material.albedo_texture = _texture(image)
		material.normal_enabled = true
		material.normal_texture = _normal_from(image, 1.6)
		material.normal_scale = 0.5
		material.roughness = 0.97
		material.uv1_scale = Vector3(14, 14, 1)
		return material)

## Dry ground between the blocks.
static func dirt() -> StandardMaterial3D:
	return _make("dirt", func() -> StandardMaterial3D:
		var image := Image.create(TILE, TILE, false, Image.FORMAT_RGB8)
		var coarse := _noise(6.0, 10)
		var fine := _noise(64.0, 11)
		for y in TILE:
			for x in TILE:
				var lift := 0.78 + _sample(coarse, x, y) * 0.32 \
					+ _sample(fine, x, y) * 0.16
				image.set_pixel(x, y, Color(0.46 * lift, 0.40 * lift, 0.31 * lift))

		var material := StandardMaterial3D.new()
		material.albedo_texture = _texture(image)
		material.normal_enabled = true
		material.normal_texture = _normal_from(image, 2.0)
		material.normal_scale = 0.6
		material.roughness = 0.98
		material.uv1_scale = Vector3(30, 30, 1)
		return material)

# --- the machinery ------------------------------------------------------------

static func _make(key: String, build: Callable) -> StandardMaterial3D:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]

## A seamless noise field. Seamless matters: a tile with a visible edge repeated
## across a lawn is a grid, and a grid is the one thing grass never looks like.
static func _noise(frequency: float, seed_value: int) -> Image:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_value
	noise.frequency = frequency / float(TILE)
	noise.fractal_octaves = 3

	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = TILE
	texture.height = TILE
	texture.seamless = true
	texture.generate_mipmaps = false
	# NoiseTexture2D builds on a thread; the image is what is wanted, now.
	return noise.get_seamless_image(TILE, TILE, false, false)

static func _sample(field: Image, x: int, y: int) -> float:
	return field.get_pixel(posmod(x, TILE), posmod(y, TILE)).r

## A normal map read off the albedo's own brightness. Cheaper than authoring a
## second tile and always in register with the first.
static func _normal_from(albedo: Image, strength: float) -> ImageTexture:
	var normals := Image.create(TILE, TILE, false, Image.FORMAT_RGB8)
	for y in TILE:
		for x in TILE:
			var left := _luma(albedo, x - 1, y)
			var right := _luma(albedo, x + 1, y)
			var up := _luma(albedo, x, y - 1)
			var down := _luma(albedo, x, y + 1)
			var slope := Vector3((left - right) * strength,
				(up - down) * strength, 1.0).normalized()
			normals.set_pixel(x, y, Color(
				slope.x * 0.5 + 0.5, slope.y * 0.5 + 0.5, slope.z * 0.5 + 0.5))
	return ImageTexture.create_from_image(normals)

static func _luma(image: Image, x: int, y: int) -> float:
	var colour := image.get_pixel(posmod(x, TILE), posmod(y, TILE))
	return colour.r * 0.3 + colour.g * 0.59 + colour.b * 0.11

static func _texture(image: Image) -> ImageTexture:
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
