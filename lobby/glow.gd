class_name Glow
extends RefCounted
## Brilho de luz em degraus de pixel (não um gradiente liso), somado à cena.

const SCALE := 3.0
const STEPS := 4


## Sprite com o brilho centrado. `radius` em pixels de sprite; `strength` é o alfa.
static func create(radius: int, color: Color, strength := 0.5) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _texture(radius)
	s.scale = Vector2(SCALE, SCALE)
	s.modulate = Color(color, strength)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.z_as_relative = false
	s.z_index = -8  # em cima do fundo, embaixo de móveis e personagens
	return s


static func _texture(radius: int) -> Texture2D:
	var side := radius * 2
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	for y in side:
		for x in side:
			var d := Vector2(x + 0.5 - radius, (y + 0.5 - radius) * 1.15).length() / radius
			var a := 0.0
			if d < 1.0:
				a = floorf(pow(1.0 - d, 1.6) * STEPS + 0.5) / STEPS
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
