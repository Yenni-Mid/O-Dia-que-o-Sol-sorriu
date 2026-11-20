extends RefCounted
## Gerador procedural em memória de ícones pixel-art e gradientes retrô para a HUD PS1.
## Todos os recursos são armazenados em cache estático com filtro Nearest (pixel nítido).

static var _cache: Dictionary = {}


static func get_lantern_icon(is_lit: bool) -> ImageTexture:
	var key: String = "lantern_%s" % ("lit" if is_lit else "off")
	if _cache.has(key):
		return _cache[key] as ImageTexture

	var w: int = 20
	var h: int = 26
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var body: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	body.fill(Color(0, 0, 0, 0))

	var c_brass_hi: Color = Color(0.78, 0.56, 0.25)
	var c_brass: Color = Color(0.54, 0.36, 0.16)
	var c_brass_dk: Color = Color(0.32, 0.21, 0.10)
	var c_iron: Color = Color(0.24, 0.20, 0.18)
	var c_glass_off: Color = Color(0.24, 0.28, 0.31)
	var c_glow_edge: Color = Color(0.95, 0.52, 0.12)
	var c_glow_mid: Color = Color(1.0, 0.78, 0.26)
	var c_glow_core: Color = Color(1.0, 0.96, 0.72)

	# Alça arqueada superior
	_rect(body, 6, 2, 8, 1, c_iron)
	_px(body, 5, 3, c_iron)
	_px(body, 14, 3, c_iron)
	_px(body, 4, 4, c_iron)
	_px(body, 15, 4, c_iron)
	_rect(body, 4, 5, 1, 3, c_iron)
	_rect(body, 15, 5, 1, 3, c_iron)

	# Chaminé superior em latão
	_rect(body, 8, 4, 4, 2, c_brass_hi)
	_rect(body, 6, 6, 8, 2, c_brass)
	_rect(body, 5, 8, 10, 2, c_brass_hi)
	_rect(body, 5, 9, 10, 1, c_brass_dk)

	# Vidro e núcleo da chama (ou vidro apagado)
	for y: int in range(10, 19):
		for x: int in range(6, 14):
			if is_lit:
				var dx: float = absf(float(x) - 9.5)
				var dy: float = absf(float(y) - 14.2)
				var d: float = sqrt(dx * dx + dy * dy * 0.7)
				if d < 1.9:
					body.set_pixel(x, y, c_glow_core)
				elif d < 3.4:
					body.set_pixel(x, y, c_glow_mid)
				else:
					body.set_pixel(x, y, c_glow_edge)
			else:
				var shade: float = 1.0 if x < 9 else 0.78
				body.set_pixel(x, y, Color(c_glass_off.r * shade, c_glass_off.g * shade, c_glass_off.b * shade, 1.0))

	# Hastes laterais e aro protetor da gaiola
	_rect(body, 4, 10, 2, 9, c_iron)
	_rect(body, 14, 10, 2, 9, c_iron)
	_rect(body, 6, 13, 8, 1, c_brass_dk)

	# Tanque inferior
	_rect(body, 4, 19, 12, 2, c_brass_hi)
	_rect(body, 3, 21, 14, 3, c_brass)
	_rect(body, 5, 21, 3, 2, c_brass_hi)
	_rect(body, 12, 21, 5, 3, c_brass_dk)
	_rect(body, 4, 24, 12, 1, c_brass_dk)

	_apply_outline(img, body, Color(0.05, 0.03, 0.02, 1.0))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func get_sanity_eye_icon(state: int) -> ImageTexture:
	var st: int = clampi(state, 0, 2)
	var key: String = "eye_%d" % st
	if _cache.has(key):
		return _cache[key] as ImageTexture

	var w: int = 28
	var h: int = 18
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	body.fill(Color(0, 0, 0, 0))

	var c_lid: Color = Color(0.56, 0.45, 0.34)
	var c_lid_dk: Color = Color(0.28, 0.21, 0.16)
	var c_sclera: Color = Color(0.87, 0.82, 0.72) if st == 0 else Color(0.92, 0.78, 0.72)
	var c_vein: Color = Color(0.74, 0.18, 0.16)
	var c_iris: Color = Color(0.32, 0.24, 0.16) if st == 0 else (Color(0.56, 0.26, 0.14) if st == 1 else Color(0.85, 0.22, 0.14))
	var c_pupil: Color = Color(0.05, 0.04, 0.04) if st < 2 else Color(1.0, 0.82, 0.28)

	var cx: float = 13.5
	var cy: float = 8.5
	for y: int in range(2, 16):
		for x: int in range(2, 26):
			var nx: float = (float(x) - cx) / 11.2
			var max_ny: float = maxf(0.0, 1.0 - nx * nx) * 5.6
			var dy: float = absf(float(y) - cy)
			if dy <= max_ny + 1.1:
				if dy > max_ny - 0.1:
					body.set_pixel(x, y, c_lid if float(y) < cy else c_lid_dk)
				else:
					var d_iris: float = sqrt(pow(float(x) - cx, 2.0) + pow(float(y) - cy, 2.0))
					var pupil_r: float = 1.8 if st == 0 else (2.4 if st == 1 else 1.4)
					if d_iris <= pupil_r:
						body.set_pixel(x, y, c_pupil)
					elif d_iris <= 4.3:
						body.set_pixel(x, y, c_iris)
					else:
						var col: Color = c_sclera
						if st >= 1 and absf(nx) > 0.45 and ((x + y * 2) % (4 if st == 1 else 3) == 0):
							col = c_vein
						body.set_pixel(x, y, col)

	if st == 2:
		# Brilho de fenda na pupila em pânico
		_px(body, 13, 8, Color(0.08, 0.02, 0.02))
		_px(body, 14, 9, Color(0.08, 0.02, 0.02))

	_apply_outline(img, body, Color(0.05, 0.03, 0.02, 1.0))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func get_posture_icon(move_state: int) -> ImageTexture:
	var st: int = clampi(move_state, 0, 2)
	var key: String = "posture_%d" % st
	if _cache.has(key):
		return _cache[key] as ImageTexture

	var w: int = 18
	var h: int = 20
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	body.fill(Color(0, 0, 0, 0))

	var fill: Color = Color(0.88, 0.83, 0.72) if st < 2 else Color(1.0, 0.82, 0.44)

	if st == 0:
		# Silhueta agachada (como no esboço)
		_rect(body, 7, 4, 4, 4, fill)
		_rect(body, 6, 8, 5, 5, fill)
		_rect(body, 10, 10, 4, 2, fill)
		_rect(body, 5, 13, 3, 4, fill)
		_rect(body, 9, 13, 4, 2, fill)
		_rect(body, 11, 15, 3, 3, fill)
		_rect(body, 4, 17, 4, 2, fill)
		_rect(body, 11, 17, 4, 2, fill)
	elif st == 1:
		# Em pé / andando
		_rect(body, 7, 2, 4, 4, fill)
		_rect(body, 6, 6, 6, 6, fill)
		_rect(body, 4, 7, 2, 5, fill)
		_rect(body, 12, 7, 2, 5, fill)
		_rect(body, 6, 12, 2, 6, fill)
		_rect(body, 10, 12, 2, 6, fill)
		_rect(body, 5, 17, 3, 2, fill)
		_rect(body, 10, 17, 3, 2, fill)
	else:
		# Correndo inclinado
		_rect(body, 9, 2, 4, 4, fill)
		_rect(body, 7, 6, 5, 6, fill)
		_rect(body, 4, 7, 3, 2, fill)
		_rect(body, 12, 8, 3, 2, fill)
		_rect(body, 5, 12, 3, 4, fill)
		_rect(body, 10, 12, 3, 4, fill)
		_rect(body, 3, 16, 3, 2, fill)
		_rect(body, 12, 16, 4, 2, fill)

	_apply_outline(img, body, Color(0.05, 0.03, 0.02, 1.0))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func get_item_icon(kind: String) -> ImageTexture:
	var key: String = "item_%s" % kind
	if _cache.has(key):
		return _cache[key] as ImageTexture

	var w: int = 14
	var h: int = 14
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	body.fill(Color(0, 0, 0, 0))

	if kind == "bottle":
		var g1: Color = Color(0.56, 0.78, 0.56)
		var g2: Color = Color(0.36, 0.56, 0.38)
		_rect(body, 6, 2, 2, 3, g1)
		_rect(body, 5, 5, 4, 2, g1)
		_rect(body, 4, 7, 6, 5, g2)
		_rect(body, 5, 8, 2, 3, g1)
	elif kind == "bandage":
		var w1: Color = Color(0.92, 0.88, 0.80)
		var cr: Color = Color(0.84, 0.22, 0.20)
		_rect(body, 2, 4, 10, 7, w1)
		_rect(body, 6, 5, 2, 5, cr)
		_rect(body, 5, 6, 4, 3, cr)
	elif kind == "tool":
		var st_c: Color = Color(0.76, 0.78, 0.82)
		var rd_c: Color = Color(0.82, 0.30, 0.22)
		_rect(body, 3, 2, 4, 3, st_c)
		_rect(body, 7, 2, 4, 3, st_c)
		_rect(body, 4, 5, 2, 7, rd_c)
		_rect(body, 8, 5, 2, 7, rd_c)
	elif kind == "key":
		var au: Color = Color(0.95, 0.78, 0.28)
		_rect(body, 2, 4, 5, 5, au)
		_px(body, 4, 6, Color(0, 0, 0, 0))
		_rect(body, 7, 6, 5, 2, au)
		_rect(body, 10, 8, 2, 2, au)
	else:
		var pp: Color = Color(0.86, 0.79, 0.62)
		var ink: Color = Color(0.36, 0.26, 0.16)
		_rect(body, 2, 2, 10, 10, pp)
		_rect(body, 4, 4, 6, 1, ink)
		_rect(body, 4, 7, 4, 1, ink)
		_rect(body, 7, 9, 3, 2, Color(0.78, 0.22, 0.18))

	_apply_outline(img, body, Color(0.05, 0.03, 0.02, 1.0))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func get_bar_gradient(top_col: Color, mid_col: Color, bot_col: Color) -> ImageTexture:
	var key: String = "grad_%s_%s" % [top_col.to_html(false), bot_col.to_html(false)]
	if _cache.has(key):
		return _cache[key] as ImageTexture

	var w: int = 16
	var h: int = 12
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in range(h):
		var t: float = float(y) / float(h - 1)
		var row_col: Color = top_col.lerp(mid_col, t * 2.0) if t < 0.5 else mid_col.lerp(bot_col, (t - 0.5) * 2.0)
		for x: int in range(w):
			var edge_fade: float = 0.88 if (x == 0 or x == w - 1) else 1.0
			img.set_pixel(x, y, Color(row_col.r * edge_fade, row_col.g * edge_fade, row_col.b * edge_fade, 1.0))

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, col)


static func _rect(img: Image, x: int, y: int, rw: int, rh: int, col: Color) -> void:
	for py: int in range(y, y + rh):
		for px: int in range(x, x + rw):
			_px(img, px, py, col)


static func _apply_outline(out_img: Image, src: Image, outline_col: Color) -> void:
	var w: int = src.get_width()
	var h: int = src.get_height()
	for y: int in range(h):
		for x: int in range(w):
			var c: Color = src.get_pixel(x, y)
			if c.a > 0.5:
				out_img.set_pixel(x, y, c)
				continue
			var has_neighbor: bool = false
			for oy: int in [-1, 0, 1]:
				for ox: int in [-1, 0, 1]:
					if ox == 0 and oy == 0:
						continue
					var nx: int = x + ox
					var ny: int = y + oy
					if nx >= 0 and nx < w and ny >= 0 and ny < h and src.get_pixel(nx, ny).a > 0.5:
						has_neighbor = true
						break
				if has_neighbor:
					break
			if has_neighbor:
				out_img.set_pixel(x, y, outline_col)
