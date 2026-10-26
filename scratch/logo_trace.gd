extends SceneTree
## Traces the logo (images/logo_simple.jpeg) into the shapes the 3D logo is built from: the amber rim's
## silhouette, the navy body inside it, and every letter face, each a polygon with holes in the image's
## own pixels. Run from the project root (headless, about 1 minute):
##   Godot --headless --path . -s res://scratch/logo_trace.gd [-- debug=<dir>]
## It writes generated/logo/logo_shapes.json (read by regenerate_logo.gd), logo_faces.png (the letter faces'
## colours) and logo_gradients.png (the rim's and the navy's colour by height).
##
## The picture is a JPEG, so none of it is taken as it comes: the contours are not the traced pixels but
## straight lines and smooth curves fitted to them (see "Clean contours"), and the colours are not the
## picture's either (see "Clean colours"). Without that the model had wobbling edges, which a bevel and a
## glossy clearcoat only show up, and speckle round the letters.
##
## How the layers come out of the picture (the work is done at half size):
##  - navy is any pixel darker than NAVY_V; everything else is a colour or the background;
##  - the not-navy pixels are flood-filled into regions. One that reaches the image edge is outside, and
##    so is a small one with the background showing in it: the gaps between letters (C-V, V-I) are real
##    holes in the logo, ringed in amber, and enclosed by navy all the same;
##  - the body is what isn't outside (navy and the faces), the rim is the body plus the outside's amber
##    ring (background pixels left out), and each enclosed region of the body is a face.

const SRC := "res://images/logo_simple.jpeg"
const OUT_DIR := "res://generated/logo/"
## The trace runs on the image at 1/SCALE size, then maps its contours back.
const SCALE := 2

const C_BG := 0
const C_NAVY := 1
const C_COL := 2

const NAVY_V := 0.34
## Background and its shadow: bluish (blue the largest channel, red the least), pale, a little saturated.
## The silver of VIBE is bluish too, but its saturation (0.03 to 0.05) is under BG_S_MIN.
const BG_S_MIN := 0.06
const BG_S_MAX := 0.34
const BG_V_MIN := 0.45

## An enclosed region with this many background pixels (and this share of its own) is a gap.
const GAP_BG_PIXELS := 40
const GAP_BG_SHARE := 0.2
## Enclosed regions by size (half-size pixels). Under SPECK_AREA is JPEG noise in the navy (round the V's
## top edge it makes regions of up to 250) and counts as navy. A letter's face is over FACE_AREA (the
## smallest, the I, is 6500). What lies between is the amber rim filling a narrow gap, like the wedge
## between the V and the I, which has only a pinhole of background left in it: outside, like a gap.
const SPECK_AREA := 400
const FACE_AREA := 3000
const MIN_LOOP_AREA := 40.0
## How far the rim's contour is pulled in (half-size pixels, up to 1.5): its edge pixels are half background.
const RIM_ERODE := 0.5
## A face's and the body's edge is where the brightness crosses EDGE_V, the middle between the navy (0.3)
## and the faces and the amber (0.7 and up). The navy test (NAVY_V) alone put it at the faint end of the
## fade of a glowing stroke, where the JPEG noise decides it: the C's tip came out wavy.
const EDGE_V := 0.5
const EDGE_SPAN := 0.4
## How far from the mask's edge (half-size pixels) the brightness replaces the mask.
const EDGE_BAND := 3

## Clean contours (full-size pixels). The traced loop is resampled every SAMPLE; a corner is where it turns
## by CORNER_ANGLE or more over CORNER_K samples either side (a round corner under about 17px radius
## counts, one over doesn't); between corners it is smoothed, then fitted: a straight line if every point is
## within LINE_TOL of it, else cubic Beziers within CURVE_TOL (Schneider's curve fit), and those that come
## out flat become lines. At a corner the two fits' lines are intersected, which gives back the sharp point
## the picture's blur rounded off (a thin flick's tip most of all). Curves are cut into segments that stay
## FLAT_TOL from the true curve.
const SAMPLE := 2.0
const CORNER_K := 4
const CORNER_ANGLE := 0.70
const CORNER_GAP := 5
const SMOOTH_PASSES := 4
const LINE_TOL := 1.6
const CURVE_TOL := 1.2
const FLAT_TOL := 0.12
## Two lines closer to parallel than this (the sine of their angle) aren't intersected.
const SNAP_MIN_SIN := 0.17

## Clean colours. The faces' colours are the picture's with an edge-preserving blur (bilateral: a pixel
## averages with the pixels near it that are close to it in colour, so the blocks and the ringing round
## edges go and the strokes and the horizon lines stay), run only on pixels inside a face so the navy and
## the colour bled across the edge can't mix in. The picture's colours are then spread BLEED pixels past
## each face's edge, so a lookup at its bevel or wall finds the face's colour.
const DENOISE_R := 3
const DENOISE_SIGMA_S := 2.0
const DENOISE_SIGMA_R := 24.0
const DENOISE_PASSES := 2
const BLEED := 20
## The rim and the navy are not taken from the picture at all: only their colour by height, as the median
## of BANDS bands of it.
const BANDS := 24

var w := 0
var h := 0
var _debug_dir := ""
## Every half-size pixel's brightness (the largest channel), for placing edges at the middle of a transition.
var _bright := PackedFloat32Array()


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("debug="):
			_debug_dir = arg.substr(6)
	var full := Image.load_from_file(SRC)
	full.convert(Image.FORMAT_RGB8)
	var img := full.duplicate() as Image
	img.resize(full.get_width() / SCALE, full.get_height() / SCALE, Image.INTERPOLATE_BILINEAR)
	w = img.get_width()
	h = img.get_height()
	print("logo %s traced at %dx%d" % [full.get_size(), w, h])

	var cls := _classify(img.get_data())
	var regions := _label_regions(cls)
	var labels: PackedInt32Array = regions["labels"]
	var info: Array = regions["info"]

	# Which regions are outside, which are faces.
	var outside := {}
	var faces: Array[int] = []
	for id in info.size():
		var r: Dictionary = info[id]
		if r["count"] < SPECK_AREA and not r["border"]:
			continue
		var gap: bool = r["bg"] >= GAP_BG_PIXELS and r["bg"] >= GAP_BG_SHARE * r["count"]
		if r["border"] or gap or r["count"] < FACE_AREA:
			outside[id] = true
			print("  region %d: outside (%s), %d px, bbox %s" % [id,
				"edge" if r["border"] else ("gap" if gap else "wedge"), r["count"], r["box"]])
		else:
			faces.append(id)
			print("  region %d: face, %d px, bbox %s" % [id, r["count"], r["box"]])

	var body := PackedByteArray()
	var rim := PackedByteArray()
	body.resize(w * h)
	rim.resize(w * h)
	for i in w * h:
		var l := labels[i]
		if l < 0 or not outside.has(l):
			body[i] = 1
			rim[i] = 1
		elif cls[i] == C_COL:
			rim[i] = 1

	var out := {"size": [full.get_width(), full.get_height()], "rim": [], "body": [], "faces": []}
	var layers: Array = []
	var rim_shapes := _clean_shapes(_trace_shapes(rim, 1, Rect2i(0, 0, w, h), 0.5 + RIM_ERODE / 3.0))
	var body_shapes := _clean_shapes(_trace_shapes(body, 1, Rect2i(0, 0, w, h), 0.5, -1))
	out["rim"] = _shapes_json(rim_shapes)
	out["body"] = _shapes_json(body_shapes)
	layers.append([rim_shapes, Color(1.0, 0.1, 0.1)])
	layers.append([body_shapes, Color(0.1, 1.0, 0.2)])
	var face_clean: Array = []
	for id in faces:
		var r: Dictionary = info[id]
		var shapes := _clean_shapes(_trace_shapes(labels, id, r["box"], 0.5, 1))
		if shapes.is_empty():
			continue
		for s in _shapes_json(shapes):
			s["area"] = r["count"] * SCALE * SCALE
			var c: Vector2 = r["sum"] / float(r["count"])
			s["centre"] = [snappedf((c.x + 0.5) * SCALE, 0.1), snappedf((c.y + 0.5) * SCALE, 0.1)]
			out["faces"].append(s)
		face_clean.append_array(shapes)
	layers.append([face_clean, Color(1.0, 1.0, 1.0)])
	print("traced and cleaned in %.1fs: %d rim shape(s) with %s holes, %d body with %s, %d faces" % [
		(Time.get_ticks_msec() - t0) / 1000.0, rim_shapes.size(), _hole_counts(rim_shapes),
		body_shapes.size(), _hole_counts(body_shapes), out["faces"].size()])

	# Where the logo starts and ends vertically, for the gradients and the shader.
	var y0 := h
	var y1 := 0
	for i in w * h:
		if rim[i] == 1:
			y0 = mini(y0, i / w)
			y1 = maxi(y1, i / w)
	out["y_range"] = [y0 * SCALE, (y1 + 1) * SCALE]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var f := FileAccess.open(OUT_DIR + "logo_shapes.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	_write_gradients(img.get_data(), labels, body, rim, y0, y1)
	print("gradients in %.1fs" % [(Time.get_ticks_msec() - t0) / 1000.0])
	_write_faces(full, labels, faces)
	if _debug_dir != "":
		_write_debug(img, cls, labels, outside, layers)
	print("done in %.1fs" % [(Time.get_ticks_msec() - t0) / 1000.0])
	quit()


## Navy, background or colour for every pixel.
func _classify(data: PackedByteArray) -> PackedByteArray:
	var cls := PackedByteArray()
	cls.resize(w * h)
	_bright.resize(w * h)
	for i in w * h:
		var r := data[i * 3]
		var g := data[i * 3 + 1]
		var b := data[i * 3 + 2]
		var mx := maxi(r, maxi(g, b))
		var mn := mini(r, mini(g, b))
		var v := mx / 255.0
		_bright[i] = v
		if v < NAVY_V:
			cls[i] = C_NAVY
			continue
		var s := float(mx - mn) / float(mx)
		if b == mx and r == mn and s >= BG_S_MIN and s <= BG_S_MAX and v >= BG_V_MIN:
			cls[i] = C_BG
		else:
			cls[i] = C_COL
	return cls


## Flood-fills the not-navy pixels (4-connected) into regions. labels[i] is -1 for navy, else a region id;
## info[id] has its pixel count, background pixel count, whether it reaches the image edge, its bbox and
## the sum of its pixel positions.
func _label_regions(cls: PackedByteArray) -> Dictionary:
	var labels := PackedInt32Array()
	labels.resize(w * h)
	labels.fill(-2)
	for i in w * h:
		if cls[i] == C_NAVY:
			labels[i] = -1
	var info: Array = []
	var stack := PackedInt32Array()
	stack.resize(w * h)
	for start in w * h:
		if labels[start] != -2:
			continue
		var id := info.size()
		var count := 0
		var bg := 0
		var border := false
		var x0 := w
		var y0 := h
		var x1 := 0
		var y1 := 0
		var sum := Vector2.ZERO
		var sp := 0
		stack[0] = start
		sp = 1
		labels[start] = id
		while sp > 0:
			sp -= 1
			var i := stack[sp]
			var x := i % w
			var y := i / w
			count += 1
			if cls[i] == C_BG:
				bg += 1
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				border = true
			x0 = mini(x0, x)
			y0 = mini(y0, y)
			x1 = maxi(x1, x)
			y1 = maxi(y1, y)
			sum += Vector2(x, y)
			if x > 0 and labels[i - 1] == -2:
				labels[i - 1] = id
				stack[sp] = i - 1
				sp += 1
			if x < w - 1 and labels[i + 1] == -2:
				labels[i + 1] = id
				stack[sp] = i + 1
				sp += 1
			if y > 0 and labels[i - w] == -2:
				labels[i - w] = id
				stack[sp] = i - w
				sp += 1
			if y < h - 1 and labels[i + w] == -2:
				labels[i + w] = id
				stack[sp] = i + w
				sp += 1
		info.append({"count": count, "bg": bg, "border": border, "box": Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1), "sum": sum})
	return {"labels": labels, "info": info}


# ---- Tracing -----------------------------------------------------------------------------------------

## The shapes (outer loop plus the holes inside it) of the pixels of `grid` equal to `id` within `box`:
## each an Array [outer, holes] of raw loops, in full-size pixel coordinates.
func _trace_shapes(grid, id: int, box: Rect2i, iso: float, soft := 0) -> Array:
	var loops := _trace_loops(grid, id, box, iso, soft)
	# Nesting: a loop inside an odd number of others is a hole.
	var depth: Array[int] = []
	for i in loops.size():
		var d := 0
		for j in loops.size():
			if i != j and Geometry2D.is_point_in_polygon(loops[i][0], loops[j]):
				d += 1
		depth.append(d)
	var shapes := []
	for i in loops.size():
		if depth[i] % 2 == 0:
			shapes.append([loops[i], []])
	for i in loops.size():
		if depth[i] % 2 == 1:
			# The smallest outer loop that holds it.
			var best := -1
			var best_area := INF
			for s in shapes.size():
				if Geometry2D.is_point_in_polygon(loops[i][0], shapes[s][0]):
					var a := absf(_area(shapes[s][0]))
					if a < best_area:
						best_area = a
						best = s
			if best >= 0:
				shapes[best][1].append(loops[i])
	return shapes


## Marching squares on the 3x3-blurred inside mask, loops joined through shared cell edges. The blur turns
## the mask's stair steps into a ramp, so the crossing lands where the true edge was, not on a pixel
## boundary. `soft` +1 (a bright region on dark, a face) or -1 (a dark one on bright, the body) replaces
## the mask within EDGE_BAND of its edge by the brightness, so the edge lies at EDGE_V.
func _trace_loops(grid, id: int, box: Rect2i, iso: float, soft := 0) -> Array:
	var gw := box.size.x + 4
	var gh := box.size.y + 4
	var f := PackedFloat32Array()
	f.resize(gw * gh)
	for y in box.size.y:
		var row := (box.position.y + y) * w + box.position.x
		var frow := (y + 2) * gw + 2
		for x in box.size.x:
			if grid[row + x] == id:
				f[frow + x] = 1.0
	if soft != 0:
		f = _soften_edges(f, grid, box, gw, gh, soft)
	var tmp := PackedFloat32Array()
	tmp.resize(gw * gh)
	for y in range(0, gh):
		for x in range(1, gw - 1):
			tmp[y * gw + x] = (f[y * gw + x - 1] + f[y * gw + x] + f[y * gw + x + 1]) / 3.0
	for y in range(1, gh - 1):
		for x in range(1, gw - 1):
			f[y * gw + x] = (tmp[(y - 1) * gw + x] + tmp[y * gw + x] + tmp[(y + 1) * gw + x]) / 3.0

	var adj := {}
	var pts := {}
	for cy in range(1, gh - 2):
		for cx in range(1, gw - 2):
			var a := f[cy * gw + cx]
			var b := f[cy * gw + cx + 1]
			var c := f[(cy + 1) * gw + cx + 1]
			var d := f[(cy + 1) * gw + cx]
			var kase := (8 if a >= iso else 0) | (4 if b >= iso else 0) | (2 if c >= iso else 0) | (1 if d >= iso else 0)
			if kase == 0 or kase == 15:
				continue
			# Edge keys: horizontal edge from (x, y) is (y * gw + x) * 2, vertical is that + 1.
			var top := (cy * gw + cx) * 2
			var bottom := ((cy + 1) * gw + cx) * 2
			var left := (cy * gw + cx) * 2 + 1
			var right := (cy * gw + cx + 1) * 2 + 1
			var segs: Array = []
			match kase:
				1, 14: segs = [[left, bottom]]
				2, 13: segs = [[bottom, right]]
				3, 12: segs = [[left, right]]
				4, 11: segs = [[top, right]]
				6, 9: segs = [[top, bottom]]
				7, 8: segs = [[left, top]]
				5:
					if (a + b + c + d) * 0.25 >= iso:
						segs = [[left, top], [bottom, right]]
					else:
						segs = [[top, right], [left, bottom]]
				10:
					if (a + b + c + d) * 0.25 >= iso:
						segs = [[top, right], [left, bottom]]
					else:
						segs = [[left, top], [bottom, right]]
			for s in segs:
				for k in 2:
					var key: int = s[k]
					if not pts.has(key):
						pts[key] = _edge_point(f, gw, key, iso)
					if adj.has(key):
						adj[key].append(s[1 - k])
					else:
						adj[key] = [s[1 - k]]

	var loops := []
	var seen := {}
	for start in adj.keys():
		if seen.has(start):
			continue
		var poly := PackedVector2Array()
		var prev := -1
		var cur: int = start
		while not seen.has(cur):
			seen[cur] = true
			var p: Vector2 = pts[cur]
			# Back to image pixels: the grid is padded by 2 and a pixel's centre is half a pixel in.
			poly.append(Vector2(p.x - 2.0 + box.position.x + 0.5, p.y - 2.0 + box.position.y + 0.5) * float(SCALE))
			var nb: Array = adj[cur]
			var nxt: int = nb[0] if nb[0] != prev else nb[1]
			if nb.size() < 2:
				break
			prev = cur
			cur = nxt
		if poly.size() >= 4 and absf(_area(poly)) >= MIN_LOOP_AREA * SCALE * SCALE:
			loops.append(poly)
	return loops


## The mask `f` with the brightness in place of it within EDGE_BAND pixels of its edge.
func _soften_edges(f: PackedFloat32Array, grid, box: Rect2i, gw: int, gh: int, soft: int) -> PackedFloat32Array:
	var near := PackedByteArray()
	near.resize(gw * gh)
	for y in range(1, gh - 1):
		for x in range(1, gw - 1):
			var i := y * gw + x
			var v := f[i]
			if f[i - 1] != v or f[i + 1] != v or f[i - gw] != v or f[i + gw] != v:
				near[i] = 1
	# Spread the edge pixels out to a band (a square window: it only has to be wide enough).
	var wide := PackedByteArray()
	wide.resize(gw * gh)
	for y in range(EDGE_BAND, gh - EDGE_BAND):
		for x in range(EDGE_BAND, gw - EDGE_BAND):
			if near[y * gw + x] == 0:
				continue
			for dy in range(-EDGE_BAND, EDGE_BAND + 1):
				for dx in range(-EDGE_BAND, EDGE_BAND + 1):
					wide[(y + dy) * gw + x + dx] = 1
	var out := f.duplicate()
	for y in box.size.y:
		var row := (box.position.y + y) * w + box.position.x
		var frow := (y + 2) * gw + 2
		for x in box.size.x:
			if wide[frow + x] == 1:
				var v := _bright[row + x]
				out[frow + x] = clampf((v - (EDGE_V - EDGE_SPAN * 0.5)) / EDGE_SPAN if soft > 0 \
						else ((EDGE_V + EDGE_SPAN * 0.5) - v) / EDGE_SPAN, 0.0, 1.0)
	return out


## Where the iso line crosses the grid edge `key`.
func _edge_point(f: PackedFloat32Array, gw: int, key: int, iso: float) -> Vector2:
	var vertical := (key & 1) == 1
	var i := key >> 1
	var x := i % gw
	var y := i / gw
	var p0 := f[i]
	var p1 := f[i + gw] if vertical else f[i + 1]
	var t := 0.5 if p1 == p0 else clampf((iso - p0) / (p1 - p0), 0.0, 1.0)
	return Vector2(x, y + t) if vertical else Vector2(x + t, y)


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


# ---- Clean contours ----------------------------------------------------------------------------------

## Shapes of raw loops as shapes of clean ones: [{"outer": loop, "holes": [loop, ...]}, ...] where a loop is
## {"pts": PackedVector2Array, "corner": PackedByteArray}.
func _clean_shapes(shapes: Array) -> Array:
	var out := []
	for s in shapes:
		var holes := []
		for hole in s[1]:
			holes.append(_vectorize(hole))
		out.append({"outer": _vectorize(s[0]), "holes": holes})
	return out


## A raw loop as straight lines and smooth curves joined at the corners it really has. Returns {"pts": a
## closed polyline with no repeated end point, "corner": 1 where a vertex is a corner}.
func _vectorize(raw: PackedVector2Array) -> Dictionary:
	var pts := _resample_closed(raw, SAMPLE)
	var n := pts.size()
	var flags := PackedByteArray()
	flags.resize(n)
	if n < 12:
		flags.fill(1)
		return {"pts": pts, "corner": flags}
	var corners := _detect_corners(pts)
	var sampled := pts
	pts = _smooth_loop(pts, corners)

	# Break the loop into segments: at its corners, or if it has none at three smooth points.
	var breaks: Array[int] = corners.duplicate()
	var smooth_breaks := false
	if breaks.is_empty():
		breaks = [0, n / 3, 2 * n / 3]
		smooth_breaks = true
	var nb := breaks.size()
	var prims: Array = []
	for s in nb:
		var i0 := breaks[s]
		var i1 := breaks[(s + 1) % nb]
		var seg := _slice_cyclic(pts, i0, i1)
		var d_start: Vector2
		var d_end: Vector2
		if smooth_breaks:
			d_start = _central_dir(pts, i0)
			d_end = _central_dir(pts, i1)
		else:
			d_start = _chord_dir(seg, 2, mini(8, seg.size() - 1))
			d_end = _chord_dir(seg, maxi(seg.size() - 9, 0), seg.size() - 3)
		prims.append(_fit_segment(seg, d_start, d_end))
	if not smooth_breaks:
		for s in nb:
			var before: Array = prims[(s - 1 + nb) % nb]
			var after: Array = prims[s]
			_snap_corner(before[before.size() - 1], after[0])

	# The polyline: every primitive's start, and a curve's points between. A segment's first vertex is a
	# corner if it began at one.
	var out := PackedVector2Array()
	var corner := PackedByteArray()
	for s in nb:
		var first := true
		for p in prims[s]:
			var start_corner := 1 if (first and not smooth_breaks) else 0
			first = false
			out.append(_prim_start(p))
			corner.append(start_corner)
			if not p["line"]:
				var bz: PackedVector2Array = p["p"]
				var m := _curve_steps(bz)
				for k in range(1, m):
					out.append(_bezier(bz, float(k) / float(m)))
					corner.append(0)
	# Repeated points (a primitive that collapsed to nothing) would give the mesh zero-length edges.
	var clean := PackedVector2Array()
	var clean_corner := PackedByteArray()
	for i in out.size():
		if not clean.is_empty() and clean[clean.size() - 1].distance_to(out[i]) < 0.05:
			if corner[i] == 1:
				clean_corner[clean_corner.size() - 1] = 1
			continue
		clean.append(out[i])
		clean_corner.append(corner[i])
	if clean.size() > 2 and clean[0].distance_to(clean[clean.size() - 1]) < 0.05:
		clean.remove_at(clean.size() - 1)
		clean_corner.remove_at(clean_corner.size() - 1)
	_report_fit(sampled, clean)
	return {"pts": clean, "corner": clean_corner}


## The loop resampled at even spacing.
func _resample_closed(poly: PackedVector2Array, step: float) -> PackedVector2Array:
	var n := poly.size()
	var cum := PackedFloat32Array()
	cum.resize(n + 1)
	for i in n:
		cum[i + 1] = cum[i] + poly[i].distance_to(poly[(i + 1) % n])
	var total := cum[n]
	var m := maxi(int(round(total / step)), 8)
	var out := PackedVector2Array()
	out.resize(m)
	var j := 0
	for k in m:
		var s := total * float(k) / float(m)
		while j < n - 1 and cum[j + 1] < s:
			j += 1
		var seg := cum[j + 1] - cum[j]
		var t := 0.0 if seg <= 0.0 else (s - cum[j]) / seg
		out[k] = poly[j].lerp(poly[(j + 1) % n], t)
	return out


## Indices of the samples where the loop turns sharply: the turn over the window is at least CORNER_ANGLE
## and the largest within it; of two corners nearer than CORNER_GAP, the sharper.
func _detect_corners(pts: PackedVector2Array) -> Array[int]:
	var n := pts.size()
	var turn := PackedFloat32Array()
	turn.resize(n)
	for i in n:
		var a := pts[i] - pts[posmod(i - CORNER_K, n)]
		var b := pts[posmod(i + CORNER_K, n)] - pts[i]
		turn[i] = absf(a.angle_to(b))
	var found: Array[int] = []
	for i in n:
		if turn[i] < CORNER_ANGLE:
			continue
		var best := true
		for d in range(-CORNER_K, CORNER_K + 1):
			if d == 0:
				continue
			var t := turn[posmod(i + d, n)]
			if t > turn[i] or (t == turn[i] and d < 0):
				best = false
				break
		if best:
			found.append(i)
	var merged := true
	while merged and found.size() > 1:
		merged = false
		for k in found.size():
			var a_i := found[k]
			var b_i := found[(k + 1) % found.size()]
			if (b_i - a_i + n) % n < CORNER_GAP and found.size() > 1:
				found.remove_at(k if turn[a_i] < turn[b_i] else (k + 1) % found.size())
				merged = true
				break
	found.sort()
	return found


## The loop smoothed with a [1 2 1] filter, corners held in place.
func _smooth_loop(pts: PackedVector2Array, corners: Array[int]) -> PackedVector2Array:
	var n := pts.size()
	var pinned := PackedByteArray()
	pinned.resize(n)
	for c in corners:
		pinned[c] = 1
	var cur := pts
	for pass_i in SMOOTH_PASSES:
		var nxt := cur.duplicate()
		for i in n:
			if pinned[i] == 1:
				continue
			nxt[i] = (cur[posmod(i - 1, n)] + cur[i] * 2.0 + cur[(i + 1) % n]) * 0.25
		cur = nxt
	return cur


## Samples i0 to i1 of a closed loop, inclusive, going round past the end if i1 is not after i0.
func _slice_cyclic(pts: PackedVector2Array, i0: int, i1: int) -> PackedVector2Array:
	var n := pts.size()
	var out := PackedVector2Array()
	var count := (i1 - i0 + n) % n
	if count == 0:
		count = n
	for k in count + 1:
		out.append(pts[(i0 + k) % n])
	return out


func _chord_dir(seg: PackedVector2Array, a: int, b: int) -> Vector2:
	a = clampi(a, 0, seg.size() - 1)
	b = clampi(b, 0, seg.size() - 1)
	if a == b:
		a = 0
		b = seg.size() - 1
	return (seg[b] - seg[a]).normalized()


func _central_dir(pts: PackedVector2Array, i: int) -> Vector2:
	var n := pts.size()
	return (pts[posmod(i + 3, n)] - pts[posmod(i - 3, n)]).normalized()


## One segment of a contour as primitives: [{"line": true, "o", "d", "a", "b"} (anchor, direction, ends) or
## {"line": false, "p": 4 control points}], each starting where the last ended. `d_start` and `d_end` are
## the way the segment leaves its first point and arrives at its last.
func _fit_segment(seg: PackedVector2Array, d_start: Vector2, d_end: Vector2) -> Array:
	var n := seg.size()
	if n < 3:
		return [_line_prim(seg[0], seg[n - 1])]
	var fit := _fit_line(seg)
	if fit["dev"] <= LINE_TOL:
		var o: Vector2 = fit["o"]
		var d: Vector2 = fit["d"]
		return [{"line": true, "o": o, "d": d, "a": o + d * (seg[0] - o).dot(d), "b": o + d * (seg[n - 1] - o).dot(d)}]
	var beziers: Array = []
	_fit_cubic(seg, 0, n - 1, d_start, -d_end, CURVE_TOL * CURVE_TOL, beziers)
	var out: Array = []
	for bz in beziers:
		var chord: Vector2 = bz[3] - bz[0]
		var flat := chord.length() > 0.001
		if flat:
			var cd := chord.normalized()
			flat = absf((bz[1] - bz[0]).cross(cd)) <= 0.5 and absf((bz[2] - bz[0]).cross(cd)) <= 0.5
		out.append(_line_prim(bz[0], bz[3]) if flat else {"line": false, "p": bz})
	return out


func _line_prim(a: Vector2, b: Vector2) -> Dictionary:
	return {"line": true, "o": a, "d": (b - a).normalized(), "a": a, "b": b}


## The best line through the points (total least squares), pointing from the first toward the last, and the
## furthest any point is from it.
func _fit_line(seg: PackedVector2Array) -> Dictionary:
	var c := Vector2.ZERO
	for p in seg:
		c += p
	c /= float(seg.size())
	var sxx := 0.0
	var sxy := 0.0
	var syy := 0.0
	for p in seg:
		var q := p - c
		sxx += q.x * q.x
		sxy += q.x * q.y
		syy += q.y * q.y
	var ang := 0.5 * atan2(2.0 * sxy, sxx - syy)
	var d := Vector2(cos(ang), sin(ang))
	if d.dot(seg[seg.size() - 1] - seg[0]) < 0.0:
		d = -d
	var dev := 0.0
	for p in seg:
		dev = maxf(dev, absf((p - c).cross(d)))
	return {"o": c, "d": d, "dev": dev}


# Schneider, "An Algorithm for Automatically Fitting Digitized Curves" (Graphics Gems). `t1` is the way the
# curve leaves its first point, `t2` the way it leaves its last, back along itself; `err` is a squared
# distance. Appends cubic Beziers to `out`.
func _fit_cubic(d: PackedVector2Array, first: int, last: int, t1: Vector2, t2: Vector2, err: float, out: Array) -> void:
	if last - first == 1:
		var dist := d[first].distance_to(d[last]) / 3.0
		out.append(PackedVector2Array([d[first], d[first] + t1 * dist, d[last] + t2 * dist, d[last]]))
		return
	var u := _chord_params(d, first, last)
	var bez := _gen_bezier(d, first, last, u, t1, t2)
	var e := _max_error(d, first, last, bez, u)
	if e.x < err:
		out.append(bez)
		return
	if e.x < err * 16.0:
		for it in 4:
			var u2 := _reparam(d, first, last, u, bez)
			bez = _gen_bezier(d, first, last, u2, t1, t2)
			e = _max_error(d, first, last, bez, u2)
			if e.x < err:
				out.append(bez)
				return
			u = u2
	var split := int(e.y)
	var tc := _center_tangent(d, split)
	_fit_cubic(d, first, split, t1, tc, err, out)
	_fit_cubic(d, split, last, -tc, t2, err, out)


func _chord_params(d: PackedVector2Array, first: int, last: int) -> PackedFloat32Array:
	var u := PackedFloat32Array()
	u.resize(last - first + 1)
	for i in range(first + 1, last + 1):
		u[i - first] = u[i - first - 1] + d[i].distance_to(d[i - 1])
	var total := u[last - first]
	for i in range(1, last - first + 1):
		u[i] = u[i] / total if total > 0.0 else float(i) / float(last - first)
	return u


func _gen_bezier(d: PackedVector2Array, first: int, last: int, u: PackedFloat32Array, t1: Vector2, t2: Vector2) -> PackedVector2Array:
	var p0 := d[first]
	var p3 := d[last]
	var c00 := 0.0
	var c01 := 0.0
	var c11 := 0.0
	var x0 := 0.0
	var x1 := 0.0
	for i in u.size():
		var t := u[i]
		var m := 1.0 - t
		var b0 := m * m * m
		var b1 := 3.0 * t * m * m
		var b2 := 3.0 * t * t * m
		var b3 := t * t * t
		var a0 := t1 * b1
		var a1 := t2 * b2
		c00 += a0.dot(a0)
		c01 += a0.dot(a1)
		c11 += a1.dot(a1)
		var tmp := d[first + i] - (p0 * (b0 + b1) + p3 * (b2 + b3))
		x0 += a0.dot(tmp)
		x1 += a1.dot(tmp)
	var det := c00 * c11 - c01 * c01
	var alpha_l := 0.0
	var alpha_r := 0.0
	if absf(det) > 1e-12:
		alpha_l = (x0 * c11 - x1 * c01) / det
		alpha_r = (c00 * x1 - c01 * x0) / det
	var seg_len := p0.distance_to(p3)
	if alpha_l < 1e-6 * seg_len or alpha_r < 1e-6 * seg_len:
		alpha_l = seg_len / 3.0
		alpha_r = alpha_l
	return PackedVector2Array([p0, p0 + t1 * alpha_l, p3 + t2 * alpha_r, p3])


## Newton-Raphson step of every point's parameter toward its closest point on the curve.
func _reparam(d: PackedVector2Array, first: int, last: int, u: PackedFloat32Array, bez: PackedVector2Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(u.size())
	for i in u.size():
		var t := u[i]
		var diff := _bezier(bez, t) - d[first + i]
		var m := 1.0 - t
		var q1 := ((bez[1] - bez[0]) * (m * m) + (bez[2] - bez[1]) * (2.0 * m * t) + (bez[3] - bez[2]) * (t * t)) * 3.0
		var q2 := ((bez[2] - bez[1] * 2.0 + bez[0]) * m + (bez[3] - bez[2] * 2.0 + bez[1]) * t) * 6.0
		var den := q1.dot(q1) + diff.dot(q2)
		out[i] = t if absf(den) < 1e-12 else clampf(t - diff.dot(q1) / den, 0.0, 1.0)
	return out


## Largest squared distance from a point to its place on the curve (x), and which point it is (y).
func _max_error(d: PackedVector2Array, first: int, last: int, bez: PackedVector2Array, u: PackedFloat32Array) -> Vector2:
	var worst := 0.0
	var at := (last - first + 1) / 2 + first
	for i in range(first + 1, last):
		var dist := _bezier(bez, u[i - first]).distance_squared_to(d[i])
		if dist >= worst:
			worst = dist
			at = i
	return Vector2(worst, at)


func _center_tangent(d: PackedVector2Array, centre: int) -> Vector2:
	return ((d[centre - 1] - d[centre]) + (d[centre] - d[centre + 1])).normalized()


func _bezier(bz: PackedVector2Array, t: float) -> Vector2:
	var m := 1.0 - t
	return bz[0] * (m * m * m) + bz[1] * (3.0 * t * m * m) + bz[2] * (3.0 * t * t * m) + bz[3] * (t * t * t)


## How many steps keep a curve's chords within FLAT_TOL of it.
func _curve_steps(bz: PackedVector2Array) -> int:
	var m := maxf((bz[0] - bz[1] * 2.0 + bz[2]).length(), (bz[1] - bz[2] * 2.0 + bz[3]).length())
	return clampi(int(ceil(sqrt(0.75 * m / FLAT_TOL))), 2, 80)


func _prim_start(p: Dictionary) -> Vector2:
	return p["a"] if p["line"] else (p["p"] as PackedVector2Array)[0]


func _prim_end(p: Dictionary) -> Vector2:
	return p["b"] if p["line"] else (p["p"] as PackedVector2Array)[3]


## The way a primitive leaves its start, and arrives at its end.
func _prim_start_dir(p: Dictionary) -> Vector2:
	if p["line"]:
		return p["d"]
	var bz: PackedVector2Array = p["p"]
	var v := bz[1] - bz[0]
	return (v if v.length_squared() > 1e-8 else bz[2] - bz[0]).normalized()


func _prim_end_dir(p: Dictionary) -> Vector2:
	if p["line"]:
		return p["d"]
	var bz: PackedVector2Array = p["p"]
	var v := bz[3] - bz[2]
	return (v if v.length_squared() > 1e-8 else bz[3] - bz[1]).normalized()


## Moves the corner between two primitives to where their lines meet (a line is its fitted line, a curve
## its tangent at the end), if that is near enough. The picture's blur rounds a corner off by a pixel or two
## and a thin spike's tip by many; the interior angle says how far it can have been.
func _snap_corner(x: Dictionary, y: Dictionary) -> void:
	var at := (_prim_end(x) + _prim_start(y)) * 0.5
	var dx := _prim_end_dir(x)
	var dy := _prim_start_dir(y)
	var cross := dx.cross(dy)
	if absf(cross) < SNAP_MIN_SIN:
		return
	var ox: Vector2 = x["o"] if x["line"] else _prim_end(x)
	var oy: Vector2 = y["o"] if y["line"] else _prim_start(y)
	var hit := ox + dx * ((oy - ox).cross(dy) / cross)
	var interior := PI - absf(dx.angle_to(dy))
	var reach := clampf(4.0 / maxf(sin(interior * 0.5), 0.12), 3.0, 18.0)
	if hit.distance_to(at) > reach:
		return
	if x["line"]:
		x["b"] = hit
	else:
		var bz: PackedVector2Array = x["p"]
		bz[2] += hit - bz[3]
		bz[3] = hit
		x["p"] = bz
	if y["line"]:
		y["a"] = hit
	else:
		var bz2: PackedVector2Array = y["p"]
		bz2[1] += hit - bz2[0]
		bz2[0] = hit
		y["p"] = bz2


## Prints how far the clean polyline strays from the traced samples (a fit that goes wrong shows here).
func _report_fit(samples: PackedVector2Array, clean: PackedVector2Array) -> void:
	var worst := 0.0
	var sum := 0.0
	for p in samples:
		var best := INF
		for i in clean.size():
			best = minf(best, _dist_to_segment(p, clean[i], clean[(i + 1) % clean.size()]))
		worst = maxf(worst, best)
		sum += best
	if worst > 4.0:
		print("    loop of %d samples -> %d vertices: strays %.1fpx at most, %.2fpx on average" % [
			samples.size(), clean.size(), worst, sum / samples.size()])


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 == 0.0:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0))


func _hole_counts(shapes: Array) -> Array:
	var counts := []
	for s in shapes:
		counts.append(s["holes"].size())
	return counts


## [{"outer": {"p": [x, y, ...], "c": [corner indices]}, "holes": [...]}, ...], full-size pixels.
func _shapes_json(shapes: Array) -> Array:
	var out := []
	for s in shapes:
		var holes := []
		for hole in s["holes"]:
			holes.append(_loop_json(hole))
		out.append({"outer": _loop_json(s["outer"]), "holes": holes})
	return out


func _loop_json(loop: Dictionary) -> Dictionary:
	var pts: PackedVector2Array = loop["pts"]
	var corner: PackedByteArray = loop["corner"]
	var flat := []
	var corners := []
	for i in pts.size():
		flat.append(snappedf(pts[i].x, 0.01))
		flat.append(snappedf(pts[i].y, 0.01))
		if corner[i] == 1:
			corners.append(i)
	return {"p": flat, "c": corners}


# ---- Clean colours -----------------------------------------------------------------------------------

## The colour of the rim and of the navy by height, as the median of BANDS bands of the picture (so no
## speckle), into logo_gradients.png: 256 wide, the rim on the top row and the navy under it, from the top
## of the logo to its bottom.
func _write_gradients(data: PackedByteArray, labels: PackedInt32Array, body: PackedByteArray,
		rim: PackedByteArray, y0: int, y1: int) -> void:
	var hist := PackedInt32Array()
	hist.resize(2 * BANDS * 3 * 256)
	var span := float(y1 - y0 + 1)
	for i in w * h:
		var kind := -1
		if body[i] == 1 and labels[i] == -1:
			kind = 1
		elif rim[i] == 1 and body[i] == 0:
			kind = 0
		if kind < 0:
			continue
		var band := clampi(int(float(i / w - y0) / span * BANDS), 0, BANDS - 1)
		var base := ((kind * BANDS + band) * 3) * 256
		hist[base + data[i * 3]] += 1
		hist[base + 256 + data[i * 3 + 1]] += 1
		hist[base + 512 + data[i * 3 + 2]] += 1
	var img := Image.create(256, 2, false, Image.FORMAT_RGB8)
	for kind in 2:
		var cols: Array[Color] = []
		for band in BANDS:
			var base := ((kind * BANDS + band) * 3) * 256
			var c := Color.BLACK
			var ok := true
			for ch in 3:
				var total := 0
				for v in 256:
					total += hist[base + ch * 256 + v]
				if total < 150:
					ok = false
					break
				var half := total / 2
				var acc := 0
				for v in 256:
					acc += hist[base + ch * 256 + v]
					if acc >= half:
						c[ch] = v / 255.0
						break
			cols.append(c if ok else Color(-1, 0, 0))
		# Bands with too few pixels take the nearest one that has some.
		for band in BANDS:
			if cols[band].r < 0.0:
				for step in BANDS:
					var lo := band - step
					var hi := band + step
					if lo >= 0 and cols[lo].r >= 0.0:
						cols[band] = cols[lo]
						break
					if hi < BANDS and cols[hi].r >= 0.0:
						cols[band] = cols[hi]
						break
		# A band far from the average of its neighbours (the rim's mid bands take in the shaded gap rings) is
		# replaced by it.
		for band in range(1, BANDS - 1):
			var mid := (cols[band - 1] + cols[band + 1]) * 0.5
			if Vector3(cols[band].r - mid.r, cols[band].g - mid.g, cols[band].b - mid.b).length() > 0.12:
				cols[band] = mid
		# The end bands have one neighbour: the logo's last row is mostly the edge's dark fringe.
		for pair in [[0, 1], [BANDS - 1, BANDS - 2]]:
			var e: Color = cols[pair[0]]
			var nb: Color = cols[pair[1]]
			if Vector3(e.r - nb.r, e.g - nb.g, e.b - nb.b).length() > 0.12:
				cols[pair[0]] = nb
		for band in BANDS:
			print("  %s band %2d: rgb(%3d,%3d,%3d)" % ["navy" if kind == 1 else "rim ", band,
				round(cols[band].r * 255), round(cols[band].g * 255), round(cols[band].b * 255)])
		# A little smoothing across the bands, then a line between their centres.
		for pass_i in 2:
			var sm := cols.duplicate()
			for band in range(1, BANDS - 1):
				sm[band] = (cols[band - 1] + cols[band] * 2.0 + cols[band + 1]) * 0.25
			cols = sm
		for x in 256:
			var t := (float(x) / 255.0) * float(BANDS) - 0.5
			var b0 := clampi(int(floor(t)), 0, BANDS - 1)
			var b1 := mini(b0 + 1, BANDS - 1)
			img.set_pixel(x, kind, cols[b0].lerp(cols[b1], clampf(t - float(b0), 0.0, 1.0)))
	img.save_png(OUT_DIR + "logo_gradients.png")
	_write_import("logo_gradients.png", false)


## The faces' colours, at full size: the picture's with the bilateral blur (inside each face only), spread
## BLEED pixels past the edge, and any pixel still without a colour taking its row's nearest.
func _write_faces(full: Image, labels: PackedInt32Array, faces: Array[int]) -> void:
	var t0 := Time.get_ticks_msec()
	var fw := full.get_width()
	var fh := full.get_height()
	var src := full.get_data()
	var face_set := {}
	for id in faces:
		face_set[id] = true
	# Inside a face by at least a half-size pixel, at full size.
	var valid := PackedByteArray()
	valid.resize(fw * fh)
	var count := 0
	for y in fh:
		var hy := y / SCALE
		for x in fw:
			var hx := x / SCALE
			if hx < 1 or hy < 1 or hx > w - 2 or hy > h - 2:
				continue
			var i := hy * w + hx
			var l := labels[i]
			if l >= 0 and face_set.has(l) and labels[i - 1] == l and labels[i + 1] == l \
					and labels[i - w] == l and labels[i + w] == l:
				valid[y * fw + x] = 1
				count += 1
	print("  %d face pixels at full size" % count)

	# The bilateral blur, a few passes.
	var spatial := PackedFloat32Array()
	var side := DENOISE_R * 2 + 1
	spatial.resize(side * side)
	for dy in side:
		for dx in side:
			var ox := dx - DENOISE_R
			var oy := dy - DENOISE_R
			spatial[dy * side + dx] = exp(-float(ox * ox + oy * oy) / (2.0 * DENOISE_SIGMA_S * DENOISE_SIGMA_S))
	var range_w := PackedFloat32Array()
	range_w.resize(3 * 255 * 255 + 1)
	for d2 in range_w.size():
		range_w[d2] = exp(-float(d2) / (2.0 * DENOISE_SIGMA_R * DENOISE_SIGMA_R))
	var cur := src
	for pass_i in DENOISE_PASSES:
		var nxt := cur.duplicate()
		for y in range(DENOISE_R, fh - DENOISE_R):
			for x in range(DENOISE_R, fw - DENOISE_R):
				var i := y * fw + x
				if valid[i] == 0:
					continue
				var r0 := cur[i * 3]
				var g0 := cur[i * 3 + 1]
				var b0 := cur[i * 3 + 2]
				var sr := 0.0
				var sg := 0.0
				var sb := 0.0
				var sw := 0.0
				for dy in side:
					var row := (y + dy - DENOISE_R) * fw + x - DENOISE_R
					for dx in side:
						var j := row + dx
						if valid[j] == 0:
							continue
						var r := cur[j * 3]
						var g := cur[j * 3 + 1]
						var b := cur[j * 3 + 2]
						var dr := r - r0
						var dg := g - g0
						var db := b - b0
						var wt := spatial[dy * side + dx] * range_w[dr * dr + dg * dg + db * db]
						sr += r * wt
						sg += g * wt
						sb += b * wt
						sw += wt
				nxt[i * 3] = int(round(sr / sw))
				nxt[i * 3 + 1] = int(round(sg / sw))
				nxt[i * 3 + 2] = int(round(sb / sw))
		cur = nxt
		print("  blur pass %d done, %.1fs" % [pass_i + 1, (Time.get_ticks_msec() - t0) / 1000.0])

	# Spread the colours outward from the face pixels, a ring at a time.
	var have := valid.duplicate()
	var frontier := PackedInt32Array()
	for y in range(1, fh - 1):
		for x in range(1, fw - 1):
			var i := y * fw + x
			if have[i] == 1 and (have[i - 1] == 0 or have[i + 1] == 0 or have[i - fw] == 0 or have[i + fw] == 0):
				frontier.append(i)
	for ring in BLEED:
		var next_frontier := PackedInt32Array()
		for i in frontier:
			var x := i % fw
			for off in [-1, 1, -fw, fw]:
				var j: int = i + off
				if j < 0 or j >= fw * fh or have[j] == 1:
					continue
				if (off == -1 and x == 0) or (off == 1 and x == fw - 1):
					continue
				have[j] = 1
				cur[j * 3] = cur[i * 3]
				cur[j * 3 + 1] = cur[i * 3 + 1]
				cur[j * 3 + 2] = cur[i * 3 + 2]
				next_frontier.append(j)
		frontier = next_frontier
	# What is left is far from any face: its row's nearest colour (the far mip levels reach it).
	for y in fh:
		var last := -1
		for x in fw:
			var i := y * fw + x
			if have[i] == 1:
				last = i
			elif last >= 0:
				cur[i * 3] = cur[last * 3]
				cur[i * 3 + 1] = cur[last * 3 + 1]
				cur[i * 3 + 2] = cur[last * 3 + 2]
				have[i] = 2
		last = -1
		for x in range(fw - 1, -1, -1):
			var i := y * fw + x
			if have[i] == 1 or have[i] == 2:
				last = i
			elif last >= 0:
				cur[i * 3] = cur[last * 3]
				cur[i * 3 + 1] = cur[last * 3 + 1]
				cur[i * 3 + 2] = cur[last * 3 + 2]
	Image.create_from_data(fw, fh, false, Image.FORMAT_RGB8, cur).save_png(OUT_DIR + "logo_faces.png")
	_write_import("logo_faces.png", true)
	print("  faces texture in %.1fs" % [(Time.get_ticks_msec() - t0) / 1000.0])


## The texture's import settings, if it has none yet (one that has keeps its uid): lossless, because the
## faces' gradients band under VRAM compression, and the faces' with mipmaps (a lookup at an angle).
func _write_import(file: String, mipmaps: bool) -> void:
	var path := OUT_DIR + file + ".import"
	if FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("""[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="%s"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=%s
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
""" % [OUT_DIR + file, "true" if mipmaps else "false"])
	f.close()


# ---- Debug -------------------------------------------------------------------------------------------

func _write_debug(img: Image, cls: PackedByteArray, labels: PackedInt32Array, outside: Dictionary, layers: Array) -> void:
	DirAccess.make_dir_recursive_absolute(_debug_dir)
	var classes := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var i := y * w + x
			var l := labels[i]
			var c := Color(0.05, 0.1, 0.3)
			if l >= 0:
				if outside.has(l):
					c = Color(0.85, 0.85, 0.85) if cls[i] == C_BG else Color(0.95, 0.7, 0.25)
				else:
					var hsh := fposmod(float(l) * 0.618034, 1.0)
					c = Color.from_hsv(hsh, 0.55, 0.95)
			classes.set_pixel(x, y, c)
	classes.save_png(_debug_dir.path_join("classes.png"))
	# The clean contours over the picture at twice the size, corners marked.
	var over := img.duplicate() as Image
	over.resize(w * 2, h * 2, Image.INTERPOLATE_BILINEAR)
	for layer in layers:
		for s in layer[0]:
			_draw_loop(over, s["outer"], layer[1])
			for hole in s["holes"]:
				_draw_loop(over, hole, layer[1].lightened(0.3))
	over.save_png(_debug_dir.path_join("contours.png"))


func _draw_loop(img: Image, loop: Dictionary, col: Color) -> void:
	var poly: PackedVector2Array = loop["pts"]
	var corner: PackedByteArray = loop["corner"]
	var zoom := float(img.get_width()) / float(w)
	for i in poly.size():
		var a := poly[i] / float(SCALE) * zoom
		var b := poly[(i + 1) % poly.size()] / float(SCALE) * zoom
		var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
		for k in steps + 1:
			var p := a.lerp(b, float(k) / float(steps))
			_dot(img, p, col, 0)
		if corner[i] == 1:
			_dot(img, a, Color(1, 1, 0), 2)


func _dot(img: Image, p: Vector2, col: Color, r: int) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var px := int(p.x) + dx
			var py := int(p.y) + dy
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, col)
