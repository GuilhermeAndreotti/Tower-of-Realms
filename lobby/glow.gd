class_name Brilho
extends RefCounted
## Brilho de luz em degraus de pixel (não um gradiente liso), somado à cena.

const ESCALA := 3.0
const DEGRAUS := 4


## Sprite com o brilho centrado. `raio` em pixels de sprite; `forca` é o alfa.
static func criar(raio: int, cor: Color, forca := 0.5) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _textura(raio)
	s.scale = Vector2(ESCALA, ESCALA)
	s.modulate = Color(cor, forca)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.z_as_relative = false
	s.z_index = -8  # em cima do fundo, embaixo de móveis e personagens
	return s


static func _textura(raio: int) -> Texture2D:
	var lado := raio * 2
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	for y in lado:
		for x in lado:
			var d := Vector2(x + 0.5 - raio, (y + 0.5 - raio) * 1.15).length() / raio
			var a := 0.0
			if d < 1.0:
				a = floorf(pow(1.0 - d, 1.6) * DEGRAUS + 0.5) / DEGRAUS
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
