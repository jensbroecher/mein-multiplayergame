extends RefCounted
## Die Kronburger Brauerei, home of Kronburger Pilsner (Quer durch Kronburg, regenerate_stadtrallye.gd): a historicist
## red-brick brewery of the 1890s standing among the flats of the Hafenviertel, between its last blocks and the
## Hafenstraße, built like the town houses round it rather than a works: the Brauhaus (its tavern on the ground floor
## behind round-arched windows, a balcony over the portal, a volute gable with the brewery's name, its clock, Kronburg's
## arms and a gilded crown), the taller Sudhaus (the brewhouse) with the giant bottle of Kronburger Pilsner standing on a
## stone console in a blue niche on its front, its tower with clocks and a copper cupola, a painted advert on its north
## wall facing the road down from the railway, the gate wing with the carriage gateway into the yard under a stepped
## gable, and the Lagerhaus across the yard. In front of it all the beer garden: gravel, two chestnut trees, beer tables
## under parasols, strings of lights, a brick fence with railings and a gate under an iron arch (BIERGARTEN), barrels and
## crates by the tower's door. Everything fictional: the brewery, its beer, its dates.
##
## Built at LIFE size through StadtKit's PropKit (its materials shared) and grown by the caller (PROP_SCALE 1.6): make a
## kit with `new_kit(scale)`, set its frame, call a builder, `commit(pk, kit)`. The frame: x along the street front, the
## fronts facing +z, y = 0 the ground (the beer garden's floor at SLAB), footings down to FOOT.
##   brewery(pk, kit, labels)       the buildings and the bottle: x W_X0..S_X1 (-27..29), z R_Z1..BOT_Z + BOT_R (-36..3.2),
##                                  the tower's vane at about 34m; brewery_solids()
##   garden(pk, kit, labels, seed)  the beer garden, its fence and the driveway: x -27..29, z -0.5..FENCE_Z + 0.4;
##                                  garden_solids(), garden_people(seed) -> [[position, facing, seated]] (life, kit frame)
## Labels are YardKit's [text, position, outward normal, cap height, colour, board width]. Faces never share a plane:
## trims stand 2.5cm or more proud, panes 2cm.

const PropKit = preload("res://PropKit.gd")
const SK = preload("res://StadtKit.gd")
const T = preload("res://KronburgTownKit.gd")
const RS = preload("res://RheinStadtKit.gd")
const YK = preload("res://YardKit.gd")
const ZK = preload("res://ZechenKit.gd")

const FOOT := -4.0
## The plinth's top: the ground floors' floor.
const PL := 0.9
## The beer garden's gravel.
const SLAB := 0.05

## The Brauhaus: x -M_HW..M_HW, front z = 0, back -M_D; its risalit x -RIS_HW..RIS_HW stands RIS_OUT forward.
const M_HW := 13.0
const M_D := 15.0
const M_G := 5.4
const M_F1 := 9.3
const M_YE := 13.2
const RIS_HW := 4.6
const RIS_OUT := 0.5
const GABLE_H := 7.0
const M_PITCH := 42.0
## The Sudhaus: x S_X0..S_X1, front z S_Z, back S_BACK; its tower x TW_X0..S_X1, z TW_BACK..0.
const S_X0 := 13.0
const S_X1 := 29.0
const S_Z := -0.5
const S_BACK := -15.0
const S_YE := 19.5
const TW_X0 := 24.0
const TW_BACK := -5.0
const TW_TOP := 25.5
## The gate wing: x W_X0..W_X1, front z = 0, back -W_D; the gateway's middle GATE_U along it (x -20).
const W_X0 := -27.0
const W_X1 := -13.0
const W_D := 12.0
const W_YE := 9.6
const GATE_U := 7.0
const GATE_HALF := 2.4
const GATE_SPRING := 3.4
## The Lagerhaus across the yard: front z R_Z0 (toward the yard), back R_Z1.
const R_Z0 := -24.0
const R_Z1 := -36.0
const R_YE := 7.0
## The bottle: its axis at (BOT_X, BOT_Z), standing on its console at BOT_Y.
const BOT_X := 18.5
const BOT_Z := 1.95
const BOT_Y := 3.8
const BOT_H := 13.5
const BOT_R := 1.8
## The beer garden.
const FENCE_Z := 15.0
const DRIVE_X := Vector2(-22.8, -17.2)

const BRICK := Color(0.56, 0.25, 0.17)
const BRICK_DK := Color(0.42, 0.18, 0.13)
const BRICK_LT := Color(0.62, 0.32, 0.22)
const SAND := Color(0.80, 0.72, 0.57)
const SLATE := Color(0.30, 0.31, 0.34)
const ZINC := Color(0.52, 0.54, 0.55)
const WIN := Color(0.93, 0.91, 0.84)
const GLASS := Color(0.07, 0.10, 0.13)
const GREEN := Color(0.10, 0.27, 0.19)
const GOLD := Color(0.92, 0.72, 0.22)
const RED := Color(0.74, 0.10, 0.10)
const IRON := Color(0.10, 0.11, 0.11)
const BOTTLE := Color(0.07, 0.29, 0.14)
const CREAM := Color(0.96, 0.92, 0.80)
const COPPER := Color(0.36, 0.62, 0.52)
const NICHE := Color(0.10, 0.20, 0.46)
const DOOR := Color(0.30, 0.18, 0.10)
const GRAVEL := Color(0.47, 0.43, 0.36)
const CLINKER := Color(0.40, 0.30, 0.26)
const BARK := Color(0.30, 0.25, 0.21)
const LEAF := Color(0.24, 0.42, 0.17)
const HEDGE := Color(0.20, 0.36, 0.16)


static func new_kit(scale: float) -> PropKit:
	var pk: PropKit = SK.new_kit(scale)
	RS._lx = Transform3D.IDENTITY
	return pk


static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	return SK.commit(pk, kit)


# ======================================================================================
#  The buildings
# ======================================================================================

static func brewery(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	RS._lx = Transform3D.IDENTITY
	_brauhaus(pk, kit, labels)
	_sudhaus(pk, kit, labels)
	_tower(pk, kit, labels)
	_gate_wing(pk, kit, labels)
	_lagerhaus(pk, kit)
	_bottle(pk, kit, labels)


static func brewery_solids() -> Array:
	return [
		[Transform3D(Basis(), Vector3(0.0, 6.6, -7.25)), Vector3(M_HW * 2.0, M_YE, M_D + RIS_OUT)],
		[Transform3D(Basis(), Vector3((S_X0 + TW_X0) * 0.5, S_YE * 0.5, (S_Z + S_BACK) * 0.5)), Vector3(TW_X0 - S_X0, S_YE, S_Z - S_BACK)],
		[Transform3D(Basis(), Vector3((TW_X0 + S_X1) * 0.5, TW_TOP * 0.5, S_BACK * 0.5)), Vector3(S_X1 - TW_X0, TW_TOP, -S_BACK)],
		[Transform3D(Basis(), Vector3((W_X0 + W_X1) * 0.5, W_YE * 0.5, -W_D * 0.5)), Vector3(W_X1 - W_X0, W_YE, W_D)],
		[Transform3D(Basis(), Vector3((W_X0 + S_X1) * 0.5, R_YE * 0.5, (R_Z0 + R_Z1) * 0.5)), Vector3(S_X1 - W_X0, R_YE, R_Z0 - R_Z1)],
		[Transform3D(Basis(), Vector3(BOT_X, BOT_Y + BOT_H * 0.5, BOT_Z)), Vector3(BOT_R * 2.0, BOT_H, BOT_R * 2.0)],
		[Transform3D(Basis(), Vector3(BOT_X, 2.0, (S_Z + BOT_Z + BOT_R + 0.12) * 0.5)), Vector3(BOT_R * 2.0 + 0.9, 4.0, BOT_Z + BOT_R + 0.12 - S_Z)],
		# The portal's steps and the tower door's.
		[Transform3D(Basis(), Vector3(0.0, 0.45, RIS_OUT + 0.75)), Vector3(3.6, 0.9, 1.5)],
		[Transform3D(Basis(), Vector3(TW_X0 + 2.5, 0.45, 0.75)), Vector3(2.4, 0.9, 1.5)],
	]


## The Brauhaus: the tavern behind its round-arched windows, two floors of offices and flats over it, the risalit with
## the portal, the balcony and the volute gable; a hipped slate roof with two dormers.
static func _brauhaus(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var L: float = M_HW * 2.0
	var fw := T._wf(Vector3(-M_HW, 0, 0), Vector3(0, 0, 1))
	var rw := T._wf(Vector3(-RIS_HW, 0, RIS_OUT), Vector3(0, 0, 1))
	var RL: float = RIS_HW * 2.0
	var r0: float = M_HW - RIS_HW
	var r1: float = M_HW + RIS_HW
	for seg in [[0.0, r0], [r1, L]]:
		T._rect(pk, kit, "ashlar", fw, seg[0], FOOT, seg[1], PL, 0.0, 0.08, SAND.darkened(0.1))
		T._face(pk, kit, "kbrick", fw, seg[0], PL, seg[1], M_YE, 0.0, BRICK)
	# Pilaster strips at the ends.
	T._rect(pk, kit, "kbrick", fw, 0.005, PL, 0.42, M_YE - 0.75, 0.0, 0.06, BRICK_DK)
	T._rect(pk, kit, "kbrick", fw, L - 0.42, PL, L - 0.005, M_YE - 0.75, 0.0, 0.06, BRICK_DK)
	# The risalit: its plinth, the ground floor's wall round the portal, the wall above, its returns.
	T._rect(pk, kit, "ashlar", rw, -0.06, FOOT, RL + 0.06, PL, 0.0, 0.08, SAND.darkened(0.1))
	var pc: float = RIS_HW
	T._arcade_wall(pk, kit, "kbrick", rw, 0.0, PL, RL, M_G, [[pc, 1.1, 3.6, "round"]], 0.0, 0.0, BRICK)
	T._face(pk, kit, "kbrick", rw, 0.0, M_G, RL, M_YE, 0.0, BRICK)
	for e in [[Vector3(-RIS_HW, 0, 0), Vector3(-1, 0, 0)], [Vector3(RIS_HW, 0, RIS_OUT), Vector3(1, 0, 0)]]:
		var ew := T._wf(e[0], e[1])
		T._rect(pk, kit, "ashlar", ew, 0.0, FOOT, RIS_OUT, PL, 0.0, 0.08, SAND.darkened(0.1))
		T._face(pk, kit, "kbrick", ew, 0.0, PL, RIS_OUT, M_YE, 0.0, BRICK)
	_quoins(pk, kit, rw, 0.0, 1.0, PL, M_YE - 0.8)
	_quoins(pk, kit, rw, RL, -1.0, PL, M_YE - 0.8)
	# The main's corner beside the Sudhaus (set back half a metre) and its side over the gate wing.
	T._face(pk, kit, "kbrick", T._wf(Vector3(M_HW, 0, 0), Vector3(1, 0, 0)), 0.0, FOOT, -S_Z, M_YE, 0.0, BRICK)
	var lw := T._wf(Vector3(-M_HW, 0, -M_D), Vector3(-1, 0, 0))
	T._face(pk, kit, "kbrick", lw, 0.0, W_YE - 0.3, M_D, M_YE, 0.0, BRICK)
	T._rect(pk, kit, "ashlar", lw, -0.06, FOOT, M_D - W_D, PL, 0.0, 0.08, SAND.darkened(0.1))
	T._face(pk, kit, "kbrick", lw, 0.0, PL, M_D - W_D, W_YE - 0.3, 0.0, BRICK)
	_cornice(pk, kit, lw, -0.02, M_D, M_YE)
	# The windows of the side parts: the tavern's round-arched ones, segmental heads above.
	for u in [1.6, 4.2, 6.8, 19.2, 21.8, 24.4]:
		RS._gz_arched_window(pk, kit, fw, u, 1.5, 4.75, 1.6, WIN, SAND)
		_seg_window(pk, kit, fw, u, 6.1, 8.5, 1.3)
		_seg_window(pk, kit, fw, u, 9.8, 11.5, 1.3)
	# The risalit's windows: the tavern's either side of the portal, pediments on the first floor, the balcony door.
	for u in [1.7, RL - 1.7]:
		RS._gz_arched_window(pk, kit, rw, u, 1.5, 4.75, 1.5, WIN, SAND)
		RS._gz_window(pk, kit, rw, u, 6.1, 8.5, 1.3, WIN)
		RS._gz_surround(pk, kit, rw, u, 6.1, 8.5, 1.3, SAND, "seg", true, true, WIN)
	_portal(pk, kit, rw, pc)
	RS._gz_balcony_door(pk, kit, rw, pc, M_G + 0.14, 8.6, 1.5, {"frame": WIN})
	RS._gz_surround(pk, kit, rw, pc, M_G + 0.14, 8.6, 1.5, SAND, "tri", false, false, WIN)
	RS._balcony(pk, kit, rw, pc, M_G, 1.7, 0.95, SAND, true, 0.6)
	for u in [1.7, pc, RL - 1.7]:
		RS._gz_window(pk, kit, rw, u, 9.8, 11.5, 1.3, WIN)
		RS._gz_surround(pk, kit, rw, u, 9.8, 11.5, 1.3, SAND, "key", false, true, WIN)
	# Lanterns either side of the portal.
	for u2 in [pc - 1.68, pc + 1.68]:
		ZK._wall_lantern(pk, kit, rw * Vector3(u2, 3.3, 0.0), Vector3(0, 0, 1))
	# The string course over the tavern, the corbel table and the cornice.
	for wf in [fw, rw]:
		var wl: float = L if wf == fw else RL
		RS._mould(pk, kit, "ashlar", wf, -0.01, wl + 0.01, PackedVector2Array([Vector2(0.0, M_G - 0.2), Vector2(0.1, M_G - 0.2), Vector2(0.15, M_G - 0.1),
				Vector2(0.15, M_G + 0.06), Vector2(0.0, M_G + 0.06)]), SAND)
		_corbel_table(pk, kit, wf, 0.0, wl, M_YE)
		_cornice(pk, kit, wf, -0.02, wl + 0.02, M_YE)
	# Nose signs at both ends of the tavern, seen down the street.
	_nose_sign(pk, kit, labels, fw, 0.75, "Ausschank")
	_nose_sign(pk, kit, labels, fw, L - 0.75, "Ausschank")
	# The volute gable over the risalit.
	_volute_gable(pk, kit, labels, rw, RL)
	# The back toward the yard.
	var bw := T._wf(Vector3(M_HW, 0, -M_D), Vector3(0, 0, -1))
	T._rect(pk, kit, "ashlar", bw, 0.0, FOOT, L, PL, 0.0, 0.08, SAND.darkened(0.1))
	T._face(pk, kit, "kbrick", bw, 0.0, PL, L, M_YE, 0.0, BRICK)
	for u3 in [2.2, 6.6, 11.0, 15.0, 19.4, 23.8]:
		for v in [[2.0, 4.2], [6.2, 8.4], [10.0, 11.8]]:
			_plain_window(pk, kit, bw, u3, v[0], v[1], 1.2)
	_cornice(pk, kit, bw, -0.02, L + 0.02, M_YE)
	# The roof.
	var t: float = tan(deg_to_rad(M_PITCH))
	_hip(pk, kit, Vector3(0, 0, -M_D * 0.5), M_HW, M_D * 0.5, M_YE + 0.18, M_PITCH, 0.4, SLATE)
	for cx in [-8.6, 8.6]:
		_dormer(pk, kit, cx, t, M_YE + 0.26)
	_chimney(pk, kit, Vector3(-6.0, 0, -9.5), M_YE + 7.6)
	_chimney(pk, kit, Vector3(6.0, 0, -9.5), M_YE + 7.6)


## The portal: a round-arched doorway in the risalit, 2.2m wide, its glazed doors set back in a sandstone arch with a
## fanlight, a threshold and steps down to the ground.
static func _portal(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float) -> void:
	var half := 1.1
	var spring := 3.6
	var back := -0.36
	var arch := T._arch(u, spring, half, "round", 14)
	var ol := PackedVector2Array([Vector2(u - half, PL), Vector2(u + half, PL)])
	for i in range(arch.size() - 1, -1, -1):
		ol.append(arch[i])
	T._pface(pk, kit, "painted", wf, ol, back, DOOR)
	T._arch_ring(pk, kit, "ashlar", wf, u, spring, half, "round", 0.34, back - 0.01, 0.1, SAND, PL, 14)
	T._rect(pk, kit, "ashlar", wf, u - 0.18, spring + half - 0.04, u + 0.18, spring + half + 0.5, 0.1, 0.17, SAND.lightened(0.08))
	T._rect(pk, kit, "ashlar", wf, u - half - 0.02, PL - 0.12, u + half + 0.02, PL + 0.02, back - 0.01, 0.06, SAND.darkened(0.04))
	# The fanlight (radiating bars) over a transom, two glazed leaves under it.
	T._pface(pk, kit, "pane", wf, T._arch(u, spring + 0.02, half - 0.1, "round", 12), back + 0.02, GLASS)
	for k in range(1, 6):
		var a: float = PI * float(k) / 6.0
		pk.beam(kit, "painted", wf * Vector3(u, spring + 0.02, back + 0.04), wf * Vector3(u - cos(a) * (half - 0.1), spring + 0.02 + sin(a) * (half - 0.1), back + 0.04),
				0.035, 0.02, DOOR, wf.basis.z)
	T._rect(pk, kit, "painted", wf, u - half, spring - 0.08, u + half, spring + 0.02, back, back + 0.07, DOOR.lightened(0.1))
	for sx in [-1.0, 1.0]:
		var x0: float = u + sx * 0.03
		var x1: float = u + sx * (half - 0.06)
		var lo: float = minf(x0, x1)
		var hi: float = maxf(x0, x1)
		T._rect(pk, kit, "painted", wf, lo, PL + 0.02, hi, spring - 0.08, back, back + 0.04, DOOR.lightened(0.06))
		T._face(pk, kit, "pane", wf, lo + 0.12, PL + 1.2, hi - 0.12, spring - 0.25, back + 0.05, GLASS)
		T._rect(pk, kit, "painted", wf, lo + 0.12, PL + 0.15, hi - 0.12, PL + 1.0, back + 0.04, back + 0.07, DOOR.lightened(0.14))
		pk.tube(kit, "gold", wf * Vector3(u + sx * 0.14, PL + 1.05, back + 0.04), wf * Vector3(u + sx * 0.14, PL + 1.05, back + 0.12), 0.03, 0.035, 8, GOLD)
	T._steps(pk, kit, wf, u, PL, 2.9, 0.0, SAND)


## The volute gable on the risalit (its wall frame `wf`, `w` wide): brick with a sandstone coping, ledges and obelisks
## at its steps, the name on an enamel plaque, the clock, the founding year, Kronburg's arms and the gilded crown on
## top; it reaches 3.5m back into the roof.
static func _volute_gable(pk: PropKit, kit: Dictionary, labels: Array, wf: Transform3D, w: float) -> void:
	var base: float = M_YE + 0.26
	var c: float = w * 0.5
	var ol := _volute_outline(w, base, GABLE_H)
	T._prism(pk, kit, "kbrick", wf, ol, -3.5, 0.0, BRICK, Vector2(0, 1), true)
	# The coping: a sandstone band 22cm wide over the outline (all but its foot) from 60cm back to 10cm in front, slate
	# over the rest of the gable's top back into the roof.
	_coping(pk, kit, wf, ol, 0.22, -0.6, 0.1, SAND)
	_coping(pk, kit, wf, ol, 0.12, -3.6, -0.58, SLATE, "kslate")
	# Ledges across the steps.
	for l in [[1.3, w - 1.3, base + 2.6], [2.6, w - 2.6, base + 5.1]]:
		var y: float = l[2]
		RS._mould(pk, kit, "ashlar", wf, l[0], l[1], PackedVector2Array([Vector2(0.0, y - 0.14), Vector2(0.08, y - 0.14), Vector2(0.13, y - 0.05),
				Vector2(0.13, y + 0.04), Vector2(0.0, y + 0.04)]), SAND)
	# Obelisks on the steps' outer corners.
	for p in [Vector2(0.15, base + 0.9), Vector2(1.45, base + 3.4), Vector2(2.75, base + 5.9)]:
		for side in [p.x, w - p.x]:
			pk.lathe(kit, "paint", wf * Vector3(side, p.y + 0.2, -0.1), [Vector2(0.001, 0.0), Vector2(0.2, 0.0), Vector2(0.2, 0.22), Vector2(0.13, 0.26),
					Vector2(0.1, 0.75), Vector2(0.001, 0.92)], 4, SAND, true, Basis(Vector3.UP, PI * 0.25))
	# The name on a green enamel plaque in a gilded rim.
	T._rect(pk, kit, "enamel", wf, 0.75, base + 0.4, w - 0.75, base + 1.5, 0.0, 0.08, GREEN)
	T._ring_rect(pk, kit, "gold", wf, 0.75, base + 0.4, w - 0.75, base + 1.5, 0.06, 0.08, 0.1, GOLD)
	labels.append(["KRONBURGER BRAUEREI", wf * Vector3(c, base + 0.95, 0.11), Vector3(0, 0, 1), 0.5, GOLD, w - 1.9])
	# The clock in a sandstone ring.
	var cc: Vector3 = wf * Vector3(c, base + 3.3, 0.0)
	pk.tube(kit, "paint", cc, cc + Vector3(0, 0, 0.03), 0.98, 0.98, 24, SAND, true)
	YK.clock_face(pk, kit, cc + Vector3(0, 0, 0.03), Vector3(0, 0, 1), 0.72)
	# The founding year.
	T._rect(pk, kit, "enamel", wf, c - 1.1, base + 4.38, c + 1.1, base + 4.82, 0.0, 0.07, GREEN)
	labels.append(["GEGR. 1887", wf * Vector3(c, base + 4.6, 0.08), Vector3(0, 0, 1), 0.24, GOLD, 2.0])
	# Kronburg's arms and the crown on the apex.
	T._arms(pk, kit, wf, c, base + 5.95, 1.05, 0.02)
	RS._crown(pk, kit, wf * Vector3(c, base + GABLE_H + 0.2, -0.3), 1.5)


## The gable's outline in its wall frame: from its foot (u 0..w at `base`) up two volute stages, each a swelling S-curve
## and a short upright, to a segmental top over the middle (`h` over the foot). Counter-clockwise.
static func _volute_outline(w: float, base: float, h: float) -> PackedVector2Array:
	var c: float = w * 0.5
	var right: Array = [Vector2(0.0, 0.0), Vector2(0.0, 0.9)]
	for k in range(1, 9):
		var t: float = float(k) / 8.0
		var s: float = t * t * (3.0 - 2.0 * t)
		right.append(Vector2(1.3 * s - 0.12 * sin(t * PI), 0.9 + 1.7 * t))
	right.append(Vector2(1.3, 3.4))
	for k in range(1, 9):
		var t2: float = float(k) / 8.0
		var s2: float = t2 * t2 * (3.0 - 2.0 * t2)
		right.append(Vector2(1.3 + 1.3 * s2 - 0.1 * sin(t2 * PI), 3.4 + 1.7 * t2))
	right.append(Vector2(2.6, 5.9))
	var pts := PackedVector2Array()
	for p in right:
		pts.append(Vector2(w - p.x, base + p.y))
	var top := T._arch(c, base + 5.9, c - 2.6, "segment", 10, h - 5.9)
	for i in range(top.size() - 2, 0, -1):
		pts.append(top[i])
	for i in range(right.size() - 1, -1, -1):
		var q: Vector2 = right[i]
		pts.append(Vector2(q.x, base + q.y))
	return pts


## A coping band `w` wide over an outline (a closed counter-clockwise polygon whose first and last points are its foot):
## the outline offset outward by `w` along its mitred normals, the band between, extruded d0..d1.
static func _coping(pk: PropKit, kit: Dictionary, wf: Transform3D, ol: PackedVector2Array, w: float, d0: float, d1: float, col: Color,
		key := "ashlar") -> void:
	var n: int = ol.size()
	var outer := PackedVector2Array()
	for i in range(n):
		var nrm := Vector2.ZERO
		if i > 0:
			var e0: Vector2 = (ol[i] - ol[i - 1]).normalized()
			nrm += Vector2(e0.y, -e0.x)
		if i < n - 1:
			var e1: Vector2 = (ol[i + 1] - ol[i]).normalized()
			nrm += Vector2(e1.y, -e1.x)
		nrm = nrm.normalized()
		var scale := 1.0
		if i > 0 and i < n - 1:
			var e2: Vector2 = (ol[i + 1] - ol[i]).normalized()
			scale = 1.0 / maxf(nrm.dot(Vector2(e2.y, -e2.x)), 0.5)
		outer.append(ol[i] + nrm * w * scale)
	var band := PackedVector2Array()
	for i in range(n):
		band.append(outer[i])
	for i in range(n - 1, -1, -1):
		band.append(ol[i])
	T._prism(pk, kit, key, wf, band, d0, d1, col, Vector2(0, 1), true)


## The Sudhaus: tall round-arched windows in two tiers, the niche the bottle stands in, its console; the north wall with
## its painted advert; a hipped roof.
static func _sudhaus(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var sw := T._wf(Vector3(S_X0, 0, S_Z), Vector3(0, 0, 1))
	var Ls: float = TW_X0 - S_X0
	T._rect(pk, kit, "ashlar", sw, 0.0, FOOT, Ls, PL, 0.0, 0.08, SAND.darkened(0.1))
	T._face(pk, kit, "kbrick", sw, 0.0, PL, Ls, S_YE, 0.0, BRICK)
	T._rect(pk, kit, "kbrick", sw, 0.005, PL, 0.4, S_YE - 0.75, 0.0, 0.06, BRICK_DK)
	for u in [1.35, Ls - 1.35]:
		_tall_window(pk, kit, sw, u, 1.6, 8.4, 1.4)
		_tall_window(pk, kit, sw, u, 10.0, 17.0, 1.4)
	# The niche: a blue enamel panel in a gilt line, framed by a sandstone arch on jambs.
	var ncu: float = BOT_X - S_X0
	var nh := 2.6
	var nsp := 15.0
	var nfoot := 3.0
	var arch := T._arch(ncu, nsp, nh, "round", 18)
	var ol := PackedVector2Array([Vector2(ncu - nh, nfoot), Vector2(ncu + nh, nfoot)])
	for i in range(arch.size() - 1, -1, -1):
		ol.append(arch[i])
	T._pface(pk, kit, "enamel", sw, ol, 0.015, NICHE)
	T._arch_ring(pk, kit, "gold", sw, ncu, nsp, nh - 0.1, "round", 0.08, 0.0, 0.03, GOLD, nfoot, 18)
	T._arch_ring(pk, kit, "ashlar", sw, ncu, nsp, nh, "round", 0.45, 0.0, 0.1, SAND, nfoot, 18)
	T._rect(pk, kit, "ashlar", sw, ncu - 0.26, nsp + nh + 0.18, ncu + 0.26, nsp + nh + 0.78, 0.1, 0.18, SAND.lightened(0.08))
	# String courses between the window tiers, either side of the niche.
	for seg in [[-0.01, ncu - nh - 0.47], [ncu + nh + 0.47, Ls]]:
		RS._mould(pk, kit, "ashlar", sw, seg[0], seg[1], PackedVector2Array([Vector2(0.0, 9.0), Vector2(0.1, 9.0), Vector2(0.15, 9.1), Vector2(0.15, 9.3),
				Vector2(0.0, 9.3)]), SAND)
	# The console the bottle stands on: a corbelled sandstone shelf.
	RS._mould(pk, kit, "ashlar", sw, ncu - BOT_R - 0.45, ncu + BOT_R + 0.45, PackedVector2Array([Vector2(0.0, 1.0), Vector2(0.3, 1.0), Vector2(0.8, 1.7),
			Vector2(2.6, 2.8), Vector2(4.2, 3.3), Vector2(BOT_Z + BOT_R + 0.12 - S_Z, 3.45), Vector2(BOT_Z + BOT_R + 0.12 - S_Z, BOT_Y), Vector2(0.0, BOT_Y)]), SAND)
	_corbel_table(pk, kit, sw, 0.0, Ls, S_YE)
	_cornice(pk, kit, sw, -0.02, Ls, S_YE)
	# The north wall (the tower's too, up to the Sudhaus's eaves): windows low down, the painted advert above them.
	var nw := T._wf(Vector3(S_X1, 0, 0), Vector3(1, 0, 0))
	var Ln: float = -S_BACK
	T._rect(pk, kit, "ashlar", nw, 0.0, FOOT, Ln, PL, 0.0, 0.08, SAND.darkened(0.1))
	T._face(pk, kit, "kbrick", nw, 0.0, PL, Ln, S_YE, 0.0, BRICK)
	for u in [7.6, 10.4, 13.2]:
		_seg_window(pk, kit, nw, u, 2.0, 4.2, 1.2)
		_seg_window(pk, kit, nw, u, 5.6, 7.8, 1.2)
	var a0 := 6.5
	var a1 := 14.0
	var am: float = (a0 + a1) * 0.5
	T._face(pk, kit, "plaster", nw, a0, 9.2, a1, 17.9, 0.012, CREAM)
	T._ring_rect(pk, kit, "plaster", nw, a0, 9.2, a1, 17.9, 0.24, 0.012, 0.022, BOTTLE)
	T._face(pk, kit, "plaster", nw, a0 + 0.5, 12.2, a1 - 0.5, 12.3, 0.02, RED)
	labels.append(["KRONBURGER", nw * Vector3(am, 16.1, 0.03), Vector3(1, 0, 0), 1.0, RED, a1 - a0 - 0.9])
	labels.append(["PILSNER", nw * Vector3(am, 13.7, 0.03), Vector3(1, 0, 0), 1.45, BOTTLE, a1 - a0 - 1.2])
	labels.append(["Das Bier aus der Stadt", nw * Vector3(am, 10.9, 0.03), Vector3(1, 0, 0), 0.42, Color(0.2, 0.18, 0.16), a1 - a0 - 1.0])
	_corbel_table(pk, kit, nw, 0.0, Ln, S_YE)
	_cornice(pk, kit, nw, -0.02, Ln + 0.02, S_YE)
	# Its side over the Brauhaus's roof and its back.
	var lw := T._wf(Vector3(S_X0, 0, S_BACK), Vector3(-1, 0, 0))
	T._face(pk, kit, "kbrick", lw, 0.0, M_YE - 0.6, S_Z - S_BACK, S_YE, 0.0, BRICK)
	for u2 in [3.5, 10.5]:
		_plain_window(pk, kit, lw, u2, 15.4, 17.6, 1.2)
	_cornice(pk, kit, lw, -0.02, S_Z - S_BACK + 0.02, S_YE)
	var bw := T._wf(Vector3(S_X1, 0, S_BACK), Vector3(0, 0, -1))
	T._rect(pk, kit, "ashlar", bw, 0.0, FOOT, S_X1 - S_X0, PL, 0.0, 0.08, SAND.darkened(0.1))
	T._face(pk, kit, "kbrick", bw, 0.0, PL, S_X1 - S_X0, S_YE, 0.0, BRICK)
	for u3 in [3.0, 8.0, 13.0]:
		_plain_window(pk, kit, bw, u3, 3.0, 8.0, 1.4)
		_plain_window(pk, kit, bw, u3, 10.5, 16.5, 1.4)
	_cornice(pk, kit, bw, -0.02, S_X1 - S_X0 + 0.02, S_YE)
	_hip(pk, kit, Vector3((S_X0 + S_X1) * 0.5, 0, (S_Z + S_BACK) * 0.5), (S_X1 - S_X0) * 0.5, (S_Z - S_BACK) * 0.5, S_YE + 0.18, M_PITCH, 0.4, SLATE)


## The tower on the Sudhaus's north-east corner: its door (KONTOR), tall narrow windows, over the Sudhaus's eaves a
## stage with clocks on three sides and louvred openings on all four, a corbel table and cornice, the copper cupola with
## its lantern, onion, gilded ball and vane.
static func _tower(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var Lt: float = S_X1 - TW_X0
	var tw := T._wf(Vector3(TW_X0, 0, 0), Vector3(0, 0, 1))
	T._rect(pk, kit, "ashlar", tw, -0.06, FOOT, Lt, PL, 0.0, 0.08, SAND.darkened(0.1))
	T._face(pk, kit, "kbrick", tw, 0.0, PL, Lt, TW_TOP, 0.0, BRICK)
	_quoins(pk, kit, tw, 0.0, 1.0, PL, S_YE - 0.4)
	_quoins(pk, kit, tw, Lt, -1.0, PL, S_YE - 0.4)
	# Its return on the Sudhaus's front.
	var rr := T._wf(Vector3(TW_X0, 0, S_Z), Vector3(-1, 0, 0))
	T._rect(pk, kit, "ashlar", rr, 0.0, FOOT, -S_Z, PL, 0.0, 0.08, SAND.darkened(0.1))
	T._face(pk, kit, "kbrick", rr, 0.0, PL, -S_Z, S_YE, 0.0, BRICK)
	var mid: float = Lt * 0.5
	T._door(pk, kit, tw, mid, PL, 1.3, 2.4, Color(0.13, 0.28, 0.20), "ashlar", SAND, 0.0, 0.5, false)
	T._rect(pk, kit, "enamel", tw, mid - 0.75, 4.55, mid + 0.75, 4.95, 0.0, 0.06, GREEN)
	labels.append(["KONTOR", tw * Vector3(mid, 4.75, 0.07), Vector3(0, 0, 1), 0.2, GOLD, 1.3])
	_tall_window(pk, kit, tw, mid, 6.4, 9.6, 1.1)
	_tall_window(pk, kit, tw, mid, 11.4, 16.6, 1.1)
	var nw := T._wf(Vector3(S_X1, 0, 0), Vector3(1, 0, 0))
	_tall_window(pk, kit, nw, -TW_BACK * 0.5, 6.4, 9.6, 1.1)
	_tall_window(pk, kit, nw, -TW_BACK * 0.5, 11.4, 16.6, 1.1)
	RS._mould(pk, kit, "ashlar", tw, -0.02, Lt + 0.02, PackedVector2Array([Vector2(0.0, S_YE - 0.34), Vector2(0.1, S_YE - 0.34), Vector2(0.1, S_YE - 0.18),
			Vector2(0.4, S_YE - 0.1), Vector2(0.42, S_YE + 0.1), Vector2(0.0, S_YE + 0.1)]), SAND)
	# The stage over the roofs: its four faces (front, north, back, south).
	var faces: Array = [
		[tw, Lt, true],
		[nw, -TW_BACK, true],
		[T._wf(Vector3(S_X1, 0, TW_BACK), Vector3(0, 0, -1)), Lt, false],
		[T._wf(Vector3(TW_X0, 0, TW_BACK), Vector3(-1, 0, 0)), -TW_BACK, false],
	]
	for f in faces:
		var wf: Transform3D = f[0]
		var fl: float = f[1]
		if wf != tw and wf != nw:
			T._face(pk, kit, "kbrick", wf, 0.0, S_YE, fl, TW_TOP, 0.0, BRICK)
		elif wf == nw:
			T._face(pk, kit, "kbrick", wf, 0.0, S_YE + 0.26, fl, TW_TOP, 0.0, BRICK)
		T._rect(pk, kit, "kbrick", wf, 0.005, S_YE + 0.3, 0.4, TW_TOP - 0.75, 0.0, 0.06, BRICK_DK)
		T._rect(pk, kit, "kbrick", wf, fl - 0.4, S_YE + 0.3, fl - 0.005, TW_TOP - 0.75, 0.0, 0.06, BRICK_DK)
		var fm: float = fl * 0.5
		if f[2]:
			var cc: Vector3 = wf * Vector3(fm, 21.1, 0.0)
			var out: Vector3 = wf.basis.z.normalized()
			pk.tube(kit, "paint", cc, cc + out * 0.03, 1.12, 1.12, 24, SAND, true)
			YK.clock_face(pk, kit, cc + out * 0.03, out, 0.86)
		for sx in [-0.85, 0.85]:
			_louvre(pk, kit, wf, fm + sx, 22.62, 24.25, 0.5)
		RS._mould(pk, kit, "ashlar", wf, fm - 1.5, fm + 1.5, PackedVector2Array([Vector2(0.0, 22.28), Vector2(0.14, 22.28), Vector2(0.14, 22.42),
				Vector2(0.0, 22.42)]), SAND)
		_corbel_table(pk, kit, wf, 0.0, fl, TW_TOP)
		_cornice(pk, kit, wf, -0.55, fl + 0.55, TW_TOP)
	# The cupola: an octagonal copper bell (its flats square to the walls), a glazed lantern, an onion, a gilded ball, a
	# spike and a vane.
	var cc2 := Vector3((TW_X0 + S_X1) * 0.5, TW_TOP + 0.26, TW_BACK * 0.5)
	var rot := Basis(Vector3.UP, PI / 8.0)
	var k8: float = 1.0 / cos(PI / 8.0)
	pk.lathe(kit, "paint", cc2 + Vector3(0, -0.02, 0), [Vector2(0.001, 0.0), Vector2(2.62 * k8, 0.0), Vector2(2.62 * k8, 0.3), Vector2(0.001, 0.3)], 8, SAND, true, rot)
	pk.lathe(kit, "copper", cc2 + Vector3(0, 0.28, 0), [Vector2(2.6 * k8, 0.0), Vector2(2.66 * k8, 0.16), Vector2(2.48 * k8, 0.55), Vector2(2.12 * k8, 1.25),
			Vector2(1.62 * k8, 1.95), Vector2(1.18 * k8, 2.45), Vector2(0.95 * k8, 2.78), Vector2(0.9 * k8, 2.95), Vector2(0.001, 2.96)], 8, COPPER, true, rot)
	var lb: Vector3 = cc2 + Vector3(0, 3.2, 0)
	pk.lathe(kit, "pane", lb + Vector3(0, -0.04, 0), [Vector2(0.001, 0.0), Vector2(0.68 * k8, 0.0), Vector2(0.68 * k8, 1.5), Vector2(0.001, 1.5)], 8, GLASS, true, rot)
	for i in range(8):
		var a: float = TAU * float(i) / 8.0
		var d := Vector3(cos(a), 0, sin(a)) * 0.82
		pk.beam(kit, "copper", lb + d, lb + d + Vector3(0, 1.48, 0), 0.12, 0.12, COPPER.darkened(0.15))
	var ob: Vector3 = lb + Vector3(0, 1.42, 0)
	pk.lathe(kit, "copper", ob, [Vector2(0.001, 0.0), Vector2(1.08 * k8, 0.0), Vector2(1.1 * k8, 0.14), Vector2(0.98 * k8, 0.3), Vector2(1.12 * k8, 0.58),
			Vector2(1.08 * k8, 0.85), Vector2(0.78 * k8, 1.2), Vector2(0.42 * k8, 1.5), Vector2(0.2 * k8, 1.72), Vector2(0.12 * k8, 1.9), Vector2(0.001, 2.0)], 8, COPPER,
			true, rot)
	var top: Vector3 = ob + Vector3(0, 1.95, 0)
	SK._ellipsoid(pk, kit, "gold", top + Vector3(0, 0.3, 0), Vector3.ONE * 0.26, 12, 7, GOLD)
	pk.tube(kit, "steel", top, top + Vector3(0, 2.6, 0), 0.05, 0.025, 6, IRON, true)
	T._prism(pk, kit, "gold", Transform3D(Basis(), top + Vector3(0, 1.75, 0)), PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.1, 0.0), Vector2(1.3, 0.18),
			Vector2(1.1, 0.36), Vector2(0.0, 0.36)]), -0.015, 0.015, GOLD, Vector2(0, 1), true)


## A louvred opening in a tower's stage: dark, its slats sloping out, a sandstone arch on jambs.
static func _louvre(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, top: float, ww: float) -> void:
	var half: float = ww * 0.5
	var spring: float = top - half
	var arch := T._arch(u, spring, half, "round", 10)
	var ol := PackedVector2Array([Vector2(u - half, v0), Vector2(u + half, v0)])
	for i in range(arch.size() - 1, -1, -1):
		ol.append(arch[i])
	T._pface(pk, kit, "pane", wf, ol, 0.015, Color(0.05, 0.05, 0.06))
	var n: int = int((spring - v0) / 0.22)
	for k in range(n):
		var y: float = v0 + 0.12 + float(k) * 0.22
		pk.beam(kit, "painted", wf * Vector3(u - half + 0.02, y, 0.03), wf * Vector3(u + half - 0.02, y, 0.03), 0.12, 0.025, Color(0.16, 0.24, 0.20),
				(wf.basis * Vector3(0, 0.6, 1.0)).normalized())
	T._arch_ring(pk, kit, "ashlar", wf, u, spring, half, "round", 0.16, 0.0, 0.07, SAND, v0, 10)
	T._rect(pk, kit, "ashlar", wf, u - half - 0.16, v0 - 0.14, u + half + 0.16, v0, 0.0, 0.12, SAND)


## The gate wing: two storeys of lighter brick, the carriage gateway with its timber gates under a sandstone arch and the
## yard's name over it, a stepped gable at its outer end, a gable roof against the Brauhaus.
static func _gate_wing(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var Lw: float = W_X1 - W_X0
	var gw := T._wf(Vector3(W_X0, 0, 0), Vector3(0, 0, 1))
	var gl: float = GATE_U - GATE_HALF - 0.42
	var gr: float = GATE_U + GATE_HALF + 0.42
	for seg in [[-0.06, gl], [gr, Lw]]:
		T._rect(pk, kit, "ashlar", gw, seg[0], FOOT, seg[1], PL, 0.0, 0.08, SAND.darkened(0.1))
	T._arcade_wall(pk, kit, "kbrick", gw, 0.0, 0.0, Lw, W_YE, [[GATE_U, GATE_HALF, GATE_SPRING, "round"]], 0.0, 0.0, BRICK_LT)
	T._rect(pk, kit, "kbrick", gw, 0.005, PL, 0.42, W_YE - 0.75, 0.0, 0.06, BRICK)
	# The gateway: the arch on its jambs, the gates set back in it (boards, rails, a wicket), a keystone.
	var back := -0.45
	T._arch_ring(pk, kit, "ashlar", gw, GATE_U, GATE_SPRING, GATE_HALF, "round", 0.42, back - 0.01, 0.1, SAND, 0.0, 16)
	var arch := T._arch(GATE_U, GATE_SPRING, GATE_HALF, "round", 16)
	var ol := PackedVector2Array([Vector2(GATE_U - GATE_HALF, 0.0), Vector2(GATE_U + GATE_HALF, 0.0)])
	for i in range(arch.size() - 1, -1, -1):
		ol.append(arch[i])
	T._pface(pk, kit, "timber", gw, ol, back, Color(0.42, 0.27, 0.15))
	for y in [0.6, 1.9, 3.2]:
		T._rect(pk, kit, "timber", gw, GATE_U - GATE_HALF + 0.05, y, GATE_U + GATE_HALF - 0.05, y + 0.18, back, back + 0.06, Color(0.36, 0.23, 0.13))
	T._rect(pk, kit, "painted", gw, GATE_U - 0.02, 0.05, GATE_U + 0.02, GATE_SPRING + GATE_HALF - 0.05, back, back + 0.07, Color(0.08, 0.06, 0.05))
	T._ring_rect(pk, kit, "timber", gw, GATE_U + 0.5, 0.1, GATE_U + 1.6, 2.2, 0.08, back, back + 0.08, Color(0.30, 0.19, 0.11))
	pk.tube(kit, "gold", gw * Vector3(GATE_U + 0.68, 1.15, back + 0.06), gw * Vector3(GATE_U + 0.68, 1.15, back + 0.14), 0.03, 0.035, 8, GOLD)
	T._rect(pk, kit, "ashlar", gw, GATE_U - 0.24, GATE_SPRING + GATE_HALF + 0.1, GATE_U + 0.24, GATE_SPRING + GATE_HALF + 0.62, 0.1, 0.18, SAND.lightened(0.08))
	# The yard's name over the gateway.
	T._rect(pk, kit, "enamel", gw, GATE_U - 1.9, 6.7, GATE_U + 1.9, 7.35, 0.0, 0.07, GREEN)
	T._ring_rect(pk, kit, "gold", gw, GATE_U - 1.9, 6.7, GATE_U + 1.9, 7.35, 0.05, 0.07, 0.09, GOLD)
	labels.append(["BRAUEREIHOF", gw * Vector3(GATE_U, 7.025, 0.1), Vector3(0, 0, 1), 0.34, GOLD, 3.4])
	# Windows: round-arched beside the gateway, segmental heads upstairs.
	for u in [1.8, Lw - 1.8]:
		RS._gz_arched_window(pk, kit, gw, u, 1.4, 3.9, 1.2, WIN, SAND)
	for u2 in [1.8, 3.9, Lw - 3.9, Lw - 1.8]:
		_seg_window(pk, kit, gw, u2, 6.5, 8.0, 1.1)
	for seg2 in [[-0.01, GATE_U - GATE_HALF - 0.45], [GATE_U + GATE_HALF + 0.45, Lw + 0.01]]:
		RS._mould(pk, kit, "ashlar", gw, seg2[0], seg2[1], PackedVector2Array([Vector2(0.0, 5.0), Vector2(0.1, 5.0), Vector2(0.14, 5.1), Vector2(0.14, 5.26),
				Vector2(0.0, 5.26)]), SAND)
	_corbel_table(pk, kit, gw, 0.0, Lw, W_YE)
	_cornice(pk, kit, gw, -0.02, Lw, W_YE)
	# The outer end: its wall and the stepped gable.
	var ew := T._wf(Vector3(W_X0, 0, -W_D), Vector3(-1, 0, 0))
	T._rect(pk, kit, "ashlar", ew, 0.0, FOOT, W_D + 0.06, PL, 0.0, 0.08, SAND.darkened(0.1))
	T._face(pk, kit, "kbrick", ew, 0.0, PL, W_D, W_YE + 0.26, 0.0, BRICK_LT)
	for u3 in [3.0, W_D - 3.0]:
		_seg_window(pk, kit, ew, u3, 2.0, 4.0, 1.1)
		_seg_window(pk, kit, ew, u3, 6.5, 8.0, 1.1)
	RS._mould(pk, kit, "ashlar", ew, -0.02, W_D + 0.02, PackedVector2Array([Vector2(0.0, W_YE + 0.1), Vector2(0.12, W_YE + 0.1), Vector2(0.16, W_YE + 0.2),
			Vector2(0.16, W_YE + 0.32), Vector2(0.0, W_YE + 0.32)]), SAND)
	var vb: float = W_YE + 0.26
	var hw: float = W_D * 0.5
	var peak: float = vb + 0.9 + 0.85 * 5.0
	# Each step's riser and tread in order: from a step's outer corner up, then in.
	var ol2 := PackedVector2Array([Vector2(0.0, vb)])
	for k in range(5):
		var y0: float = vb + 0.9 + 0.85 * float(k)
		ol2.append(Vector2(float(k), y0))
		ol2.append(Vector2(float(k) + 1.0, y0))
	ol2.append(Vector2(5.0, peak))
	ol2.append(Vector2(W_D - 5.0, peak))
	for k in range(4, -1, -1):
		var y1: float = vb + 0.9 + 0.85 * float(k)
		ol2.append(Vector2(W_D - float(k) - 1.0, y1))
		ol2.append(Vector2(W_D - float(k), y1))
	ol2.append(Vector2(W_D, vb))
	T._prism(pk, kit, "kbrick", ew, ol2, -0.55, 0.0, BRICK_LT, Vector2(0, 1), true)
	for k in range(5):
		var y2: float = vb + 0.9 + 0.85 * float(k)
		for side in [[float(k) - 0.06, float(k) + 1.0], [W_D - float(k) - 1.0, W_D - float(k) + 0.06]]:
			T._rect(pk, kit, "ashlar", ew, side[0], y2 - 0.02, side[1], y2 + 0.12, -0.6, 0.06, SAND)
	T._rect(pk, kit, "ashlar", ew, 4.94, peak - 0.02, W_D - 4.94, peak + 0.14, -0.6, 0.06, SAND)
	pk.lathe(kit, "paint", ew * Vector3(hw, peak + 0.14, -0.27), [Vector2(0.001, 0.0), Vector2(0.24, 0.0), Vector2(0.24, 0.24), Vector2(0.15, 0.3),
			Vector2(0.24, 0.5), Vector2(0.18, 0.66), Vector2(0.001, 0.72)], 10, SAND)
	pk.tube(kit, "paint", ew * Vector3(hw, vb + 2.6, 0.0), ew * Vector3(hw, vb + 2.6, 0.06), 0.62, 0.62, 18, SAND, true)
	pk.tube(kit, "pane", ew * Vector3(hw, vb + 2.6, 0.06), ew * Vector3(hw, vb + 2.6, 0.08), 0.44, 0.44, 18, GLASS, true)
	# The back toward the yard, the roof.
	var bw := T._wf(Vector3(W_X1, 0, -W_D), Vector3(0, 0, -1))
	T._face(pk, kit, "kbrick", bw, 0.0, PL, Lw, W_YE, 0.0, BRICK_LT)
	T._rect(pk, kit, "ashlar", bw, 0.0, FOOT, Lw, PL, 0.0, 0.08, SAND.darkened(0.1))
	for u4 in [2.0, 5.0, 9.0, 12.0]:
		_plain_window(pk, kit, bw, u4, 2.0, 3.8, 1.1)
		_plain_window(pk, kit, bw, u4, 6.4, 8.2, 1.1)
	_cornice(pk, kit, bw, -0.02, Lw + 0.02, W_YE)
	_gable_roof_x(pk, kit, W_X0 + 0.3, W_X1, -W_D * 0.5, W_D * 0.5, W_YE + 0.18, 25.0, 0.4, SLATE)


## The Lagerhaus across the yard: one long brick storehouse with loading doors and small windows, a gable roof.
static func _lagerhaus(pk: PropKit, kit: Dictionary) -> void:
	var L: float = S_X1 - W_X0
	var d: float = R_Z0 - R_Z1
	var fw := T._wf(Vector3(W_X0, 0, R_Z0), Vector3(0, 0, 1))
	var bw := T._wf(Vector3(S_X1, 0, R_Z1), Vector3(0, 0, -1))
	for wf in [fw, bw]:
		T._rect(pk, kit, "ashlar", wf, 0.0, FOOT, L, PL, 0.0, 0.08, SAND.darkened(0.1))
		T._face(pk, kit, "kbrick", wf, 0.0, PL, L, R_YE, 0.0, BRICK_DK)
		_cornice(pk, kit, wf, -0.02, L + 0.02, R_YE)
	for k in range(5):
		var u: float = 5.6 + 11.2 * float(k)
		T._rect(pk, kit, "timber", fw, u - 1.3, PL, u + 1.3, 3.8, 0.0, 0.1, Color(0.30, 0.36, 0.26))
		T._arch_ring(pk, kit, "kbrick", fw, u, 3.8, 1.34, "segment", 0.3, 0.0, 0.06, BRICK, NAN, 8, 0.3)
		for sx in [-3.6, 3.6]:
			_plain_window(pk, kit, fw, u + sx, 1.6, 2.8, 1.0)
		for sx2 in [-3.6, 0.0, 3.6]:
			_plain_window(pk, kit, fw, u + sx2, 4.4, 5.8, 1.0)
			_plain_window(pk, kit, bw, u + sx2, 4.4, 5.8, 1.0)
	for e in [[Vector3(W_X0, 0, R_Z1), Vector3(-1, 0, 0)], [Vector3(S_X1, 0, R_Z0), Vector3(1, 0, 0)]]:
		var ew := T._wf(e[0], e[1])
		T._rect(pk, kit, "ashlar", ew, 0.0, FOOT, d, PL, 0.0, 0.08, SAND.darkened(0.1))
		T._face(pk, kit, "kbrick", ew, 0.0, PL, d, R_YE, 0.0, BRICK_DK)
		var ry: float = R_YE + 0.26 + tan(deg_to_rad(35.0)) * d * 0.5
		T._pface(pk, kit, "kbrick", ew, PackedVector2Array([Vector2(0.0, R_YE), Vector2(d, R_YE), Vector2(d * 0.5, ry)]), 0.0, BRICK_DK)
	_gable_roof_x(pk, kit, W_X0 - 0.35, S_X1 + 0.35, (R_Z0 + R_Z1) * 0.5, d * 0.5, R_YE + 0.18, 35.0, 0.4, SLATE)


## The giant bottle of Kronburger Pilsner on its console in the Sudhaus's niche: green glass, a cream label with the
## name in red and green round its front and a gilded crown, gold foil on the neck, a gold crown cap, held to the wall
## by two iron collars and their stays.
static func _bottle(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var c := Vector3(BOT_X, BOT_Y, BOT_Z)
	var H := BOT_H
	var R := BOT_R
	var prof: Array = [Vector2(0.001, 0.0), Vector2(R - 0.12, 0.0), Vector2(R - 0.03, 0.05), Vector2(R, 0.2), Vector2(R, 0.56 * H),
		Vector2(R * 0.97, 0.6 * H), Vector2(R * 0.86, 0.645 * H), Vector2(R * 0.66, 0.69 * H), Vector2(R * 0.46, 0.735 * H), Vector2(R * 0.35, 0.78 * H),
		Vector2(R * 0.31, 0.82 * H), Vector2(R * 0.3, 0.925 * H), Vector2(R * 0.37, 0.932 * H), Vector2(R * 0.37, 0.955 * H), Vector2(R * 0.32, 0.962 * H),
		Vector2(0.001, 0.962 * H)]
	pk.lathe(kit, "gloss", c, prof, 36, BOTTLE)
	# The label, its gilt edges, the neck's foil and the crown cap (21 crimps).
	var l0: float = 0.17 * H
	var l1: float = 0.49 * H
	pk.lathe(kit, "paint", c, [Vector2(R + 0.003, l0), Vector2(R + 0.03, l0 + 0.01), Vector2(R + 0.03, l1 - 0.01), Vector2(R + 0.003, l1)], 36, CREAM)
	for y in [l0 + 0.12, l1 - 0.12]:
		pk.lathe(kit, "gold", c, [Vector2(R + 0.02, y - 0.06), Vector2(R + 0.045, y - 0.05), Vector2(R + 0.045, y + 0.05), Vector2(R + 0.02, y + 0.06)], 36, GOLD)
	pk.lathe(kit, "gold", c, [Vector2(R * 0.31 + 0.01, 0.83 * H), Vector2(R * 0.31 + 0.035, 0.835 * H), Vector2(R * 0.3 + 0.035, 0.92 * H),
			Vector2(R * 0.37 + 0.02, 0.93 * H)], 24, GOLD)
	pk.lathe(kit, "gold", c, [Vector2(R * 0.4, 0.95 * H), Vector2(R * 0.41, 0.957 * H), Vector2(R * 0.41, 0.972 * H), Vector2(R * 0.37, 0.98 * H),
			Vector2(R * 0.22, 0.984 * H), Vector2(0.001, 0.985 * H)], 21, GOLD, true)
	# The lettering round the label's front, a letter at a time, and a gilded crown over it.
	_wrap_text(labels, "KRONBURGER", c, R + 0.05, 0.385 * H, 0.34, RED)
	_wrap_text(labels, "PILSNER", c, R + 0.05, 0.27 * H, 0.6, BOTTLE)
	_wrap_text(labels, "Brauerei Kronburg  seit 1887", c, R + 0.05, 0.205 * H, 0.15, Color(0.25, 0.2, 0.15))
	RS._crown(pk, kit, c + Vector3(0, 0.432 * H, R + 0.12), 0.6)
	# The collars and their stays back to the wall.
	for ring in [[0.535 * H, R + 0.05], [0.8 * H, R * 0.33 + 0.06]]:
		var y2: float = ring[0]
		var r2: float = ring[1]
		pk.lathe(kit, "metal", c, [Vector2(r2 - 0.04, y2 - 0.14), Vector2(r2, y2 - 0.12), Vector2(r2, y2 + 0.12), Vector2(r2 - 0.04, y2 + 0.14)], 32, IRON)
		for sx in [-1.0, 1.0]:
			var a: float = PI * 0.75 * sx
			var p := c + Vector3(sin(a) * r2, y2, cos(a) * r2)
			var wall := Vector3(c.x + sx * (r2 + 0.3), BOT_Y + y2, S_Z)
			pk.beam(kit, "metal", p, wall, 0.1, 0.1, IRON)
			pk.tube(kit, "metal", wall + Vector3(0, 0, -0.01), wall + Vector3(0, 0, 0.06), 0.16, 0.16, 8, IRON, true)


## Letters of `text` round the front of a cylinder (axis at c, radius r) at height y over c, each a Label3D facing out
## from the axis, centred on the front, `cap` tall.
static func _wrap_text(labels: Array, text: String, c: Vector3, r: float, y: float, cap: float, col: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var px: float = cap / 44.8
	var widths: Array = []
	var total := 0.0
	for i in range(text.length()):
		var w: float = font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * px
		widths.append(w)
		total += w
	var at: float = -total * 0.5
	for i in range(text.length()):
		var w2: float = widths[i]
		var ch: String = text[i]
		if ch != " ":
			var a: float = (at + w2 * 0.5) / r
			var n := Vector3(sin(a), 0, cos(a))
			labels.append([ch, c + Vector3(0, y, 0) + n * r, n, cap, col, 0.0])
		at += w2


# ======================================================================================
#  Facade helpers
# ======================================================================================

## A window under a segmental brick arch with a sandstone keystone and sill.
static func _seg_window(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, v1: float, ww: float) -> void:
	RS._gz_window(pk, kit, wf, u, v0, v1, ww, WIN)
	T._arch_ring(pk, kit, "kbrick", wf, u, v1, ww * 0.5 + 0.04, "segment", 0.3, 0.0, 0.05, BRICK_DK, NAN, 8, 0.26)
	T._rect(pk, kit, "ashlar", wf, u - 0.13, v1 + 0.16, u + 0.13, v1 + 0.62, 0.05, 0.11, SAND)
	T._rect(pk, kit, "ashlar", wf, u - ww * 0.5 - 0.16, v0 - 0.17, u + ww * 0.5 + 0.16, v0 - 0.02, 0.0, 0.13, SAND)


## A plain window (the back walls): glass in a white frame, a brick sill.
static func _plain_window(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, v1: float, ww: float) -> void:
	var x0: float = u - ww * 0.5
	var x1: float = u + ww * 0.5
	T._face(pk, kit, "pane", wf, x0 + 0.03, v0 + 0.03, x1 - 0.03, v1 - 0.03, 0.02, GLASS)
	T._ring_rect(pk, kit, "painted", wf, x0, v0, x1, v1, 0.08, 0.0, 0.06, WIN)
	T._face(pk, kit, "painted", wf, u - 0.035, v0 + 0.08, u + 0.035, v1 - 0.08, 0.045, WIN)
	T._rect(pk, kit, "kbrick", wf, x0 - 0.08, v0 - 0.14, x1 + 0.08, v0, 0.0, 0.1, BRICK_DK)


## A tall round-arched window (the Sudhaus, the tower): glazing bars every 1.2m and a mullion, an arched head with
## radiating bars, a sandstone surround on jambs, a keystone and a sill.
static func _tall_window(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, top: float, ww: float) -> void:
	var half: float = ww * 0.5
	var spring: float = top - half
	T._face(pk, kit, "pane", wf, u - half + 0.03, v0 + 0.03, u + half - 0.03, spring + 0.01, 0.02, GLASS)
	T._pface(pk, kit, "pane", wf, T._arch(u, spring, half - 0.03, "round", 10), 0.02, GLASS)
	T._ring_rect(pk, kit, "painted", wf, u - half, v0, u + half, spring, 0.08, 0.0, 0.06, WIN)
	T._arch_ring(pk, kit, "painted", wf, u, spring, half - 0.08, "round", 0.08, 0.0, 0.06, WIN, NAN, 10)
	T._face(pk, kit, "painted", wf, u - 0.03, v0 + 0.08, u + 0.03, spring + half - 0.08, 0.045, WIN)
	var n: int = maxi(int((spring - v0) / 1.2), 1)
	for k in range(1, n + 1):
		var y: float = lerpf(v0, spring, float(k) / float(n + 1))
		T._face(pk, kit, "painted", wf, u - half + 0.08, y - 0.025, u + half - 0.08, y + 0.025, 0.045, WIN)
	for k2 in range(1, 4):
		var a: float = PI * float(k2) / 4.0
		pk.beam(kit, "painted", wf * Vector3(u, spring, 0.045), wf * Vector3(u - cos(a) * (half - 0.08), spring + sin(a) * (half - 0.08), 0.045), 0.03, 0.02, WIN,
				wf.basis.z)
	T._arch_ring(pk, kit, "ashlar", wf, u, spring, half + 0.01, "round", 0.22, 0.0, 0.07, SAND, v0, 10)
	T._rect(pk, kit, "ashlar", wf, u - 0.13, top + 0.15, u + 0.13, top + 0.42, 0.07, 0.13, SAND.lightened(0.08))
	T._rect(pk, kit, "ashlar", wf, u - half - 0.3, v0 - 0.16, u + half + 0.3, v0, 0.0, 0.14, SAND)


## Sandstone quoins up a wall's edge at u_edge (into the wall along `dir`): courses 0.5m, long and short in turn.
static func _quoins(pk: PropKit, kit: Dictionary, wf: Transform3D, u_edge: float, dir: float, v0: float, v1: float) -> void:
	var v: float = v0
	var k := 0
	while v + 0.46 <= v1:
		var len_q: float = 0.78 if k % 2 == 0 else 0.48
		var a: float = u_edge + dir * 0.005
		var b: float = u_edge + dir * len_q
		T._rect(pk, kit, "ashlar", wf, minf(a, b), v + 0.02, maxf(a, b), v + 0.48, 0.0, 0.05, SAND.darkened(0.03 * float(k % 3)))
		v += 0.5
		k += 1


## A round-arched corbel table (Rundbogenfries) in brick under a cornice at y: little arches 0.62m apart on drops, a
## band over them.
static func _corbel_table(pk: PropKit, kit: Dictionary, wf: Transform3D, u0: float, u1: float, y: float) -> void:
	var vs: float = y - 0.75
	var n: int = maxi(int((u1 - u0 - 0.3) / 0.62), 1)
	var step: float = (u1 - u0 - 0.3) / float(n)
	for k in range(n):
		var cu: float = u0 + 0.15 + step * (float(k) + 0.5)
		T._arch_ring(pk, kit, "kbrick", wf, cu, vs, step * 0.5 - 0.06, "round", 0.06, 0.0, 0.06, BRICK_DK, NAN, 5)
	for k2 in range(n + 1):
		var du: float = u0 + 0.15 + step * float(k2)
		T._rect(pk, kit, "kbrick", wf, du - 0.06, vs - 0.22, du + 0.06, vs + 0.02, 0.0, 0.07, BRICK_DK)
	T._rect(pk, kit, "kbrick", wf, u0 + 0.005, vs + step * 0.5 - 0.02, u1 - 0.005, y - 0.34, 0.0, 0.07, BRICK_DK)


## The main cornice at y: a sandstone profile (its corona 0.7m out, its top 0.26m over y).
static func _cornice(pk: PropKit, kit: Dictionary, wf: Transform3D, u0: float, u1: float, y: float) -> void:
	RS._mould(pk, kit, "ashlar", wf, u0, u1, PackedVector2Array([Vector2(0.0, y - 0.34), Vector2(0.1, y - 0.34), Vector2(0.1, y - 0.18), Vector2(0.58, y - 0.13),
			Vector2(0.6, y + 0.02), Vector2(0.68, y + 0.08), Vector2(0.7, y + 0.2), Vector2(0.62, y + 0.26), Vector2(0.0, y + 0.26)]), SAND)


## A hipped slate roof over x c.x +- hw, z c.z +- hd (hw >= hd), its wall plates at yp: the planes overhang `oh`, zinc
## on the ridge and the hips.
static func _hip(pk: PropKit, kit: Dictionary, c: Vector3, hw: float, hd: float, yp: float, pitch: float, oh: float, col: Color) -> void:
	var t: float = tan(deg_to_rad(pitch))
	var top0: float = yp + 0.08
	var ey: float = top0 - t * oh
	var ry: float = top0 + t * hd
	var ex: float = hw + oh
	var ez: float = hd + oh
	var rx: float = hw - hd
	var e: Array = [c + Vector3(-ex, ey, ez), c + Vector3(ex, ey, ez), c + Vector3(ex, ey, -ez), c + Vector3(-ex, ey, -ez)]
	var rl: Vector3 = c + Vector3(-rx, ry, 0)
	var rr: Vector3 = c + Vector3(rx, ry, 0)
	YK.roof(pk, kit, "kslate", e[0], e[1], rr, rl, col, Vector3(0, 1, t).normalized())
	YK.roof(pk, kit, "kslate", e[2], e[3], rl, rr, col, Vector3(0, 1, -t).normalized())
	YK.gable(pk, kit, "kslate", e[1], e[2], rr, col, Vector3(t, 1, 0).normalized())
	YK.gable(pk, kit, "kslate", e[3], e[0], rl, col, Vector3(-t, 1, 0).normalized())
	var dn := Vector3(0, -0.04, 0)
	pk.tri(kit, "kslate", e[1] + dn, e[2] + dn, rr + dn, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, col.darkened(0.45), -Vector3(t, 1, 0).normalized())
	pk.tri(kit, "kslate", e[3] + dn, e[0] + dn, rl + dn, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, col.darkened(0.45), -Vector3(-t, 1, 0).normalized())
	pk.tube(kit, "metal", rl + Vector3(-0.08, 0.04, 0), rr + Vector3(0.08, 0.04, 0), 0.09, 0.09, 6, ZINC, true)
	for k in range(4):
		var c0: Vector3 = e[k]
		var c1: Vector3 = rr if k == 1 or k == 2 else rl
		pk.tube(kit, "metal", c0 + Vector3(0, 0.04, 0), c1 + Vector3(0, 0.04, 0), 0.07, 0.07, 6, ZINC, true)


## A gable roof along x from x0 to x1 over z zc +- hd, its wall plates at yp, overhanging the eaves by `oh`.
static func _gable_roof_x(pk: PropKit, kit: Dictionary, x0: float, x1: float, zc: float, hd: float, yp: float, pitch: float, oh: float, col: Color) -> void:
	var t: float = tan(deg_to_rad(pitch))
	var top0: float = yp + 0.08
	var ey: float = top0 - t * oh
	var ry: float = top0 + t * hd
	YK.roof(pk, kit, "kslate", Vector3(x0, ey, zc + hd + oh), Vector3(x1, ey, zc + hd + oh), Vector3(x1, ry, zc), Vector3(x0, ry, zc), col,
			Vector3(0, 1, t).normalized())
	YK.roof(pk, kit, "kslate", Vector3(x1, ey, zc - hd - oh), Vector3(x0, ey, zc - hd - oh), Vector3(x0, ry, zc), Vector3(x1, ry, zc), col,
			Vector3(0, 1, -t).normalized())
	pk.tube(kit, "metal", Vector3(x0, ry + 0.04, zc), Vector3(x1, ry + 0.04, zc), 0.09, 0.09, 6, ZINC, true)


## A dormer on the Brauhaus's front slope (y = top0 - t * z behind the wall line z = 0) at x = cx: slate front and cheeks,
## a window, a little gabled roof running back into the slope.
static func _dormer(pk: PropKit, kit: Dictionary, cx: float, t: float, top0: float) -> void:
	var zf := -0.9
	var w := 1.7
	var hw: float = w * 0.5
	var ys: float = top0 - t * zf
	var yt: float = ys + 1.7
	var zt: float = -(yt - top0) / t
	var df := T._wf(Vector3(cx - hw, 0, zf), Vector3(0, 0, 1))
	T._face(pk, kit, "kslate", df, 0.0, ys - 0.3, w, yt, 0.0, SLATE)
	RS._gz_window(pk, kit, df, hw, ys + 0.2, yt - 0.15, w - 0.55, WIN)
	var dz: float = zf - zt
	var rwf := T._wf(Vector3(cx + hw, 0, zf), Vector3(1, 0, 0))
	T._pface(pk, kit, "kslate", rwf, PackedVector2Array([Vector2(0.0, ys - 0.3), Vector2(0.0, yt), Vector2(dz, yt)]), 0.0, SLATE)
	var lwf := T._wf(Vector3(cx - hw, 0, zt), Vector3(-1, 0, 0))
	T._pface(pk, kit, "kslate", lwf, PackedVector2Array([Vector2(dz, ys - 0.3), Vector2(dz, yt), Vector2(0.0, yt)]), 0.0, SLATE)
	var yr: float = yt + 0.6
	var zr: float = -(yr - top0) / t
	var ye: float = yt - 0.06
	var ze: float = -(ye - top0) / t
	var zfr: float = zf + 0.22
	for sx in [-1.0, 1.0]:
		var xe: float = cx + sx * (hw + 0.14)
		var n := Vector3(sx * (yr - ye), hw + 0.14, 0.0).normalized()
		var p0 := Vector3(xe, ye, zfr)
		var p1 := Vector3(xe, ye, ze)
		var p2 := Vector3(cx, yr, zr)
		var p3 := Vector3(cx, yr, zfr)
		if sx > 0.0:
			YK.roof(pk, kit, "kslate", p1, p0, p3, p2, SLATE, n)
		else:
			YK.roof(pk, kit, "kslate", p0, p1, p2, p3, SLATE, n)
	YK.gable(pk, kit, "kslate", Vector3(cx - hw, yt, zf), Vector3(cx + hw, yt, zf), Vector3(cx, yr - 0.04, zf), SLATE, Vector3(0, 0, 1))


static func _chimney(pk: PropKit, kit: Dictionary, c: Vector3, top: float) -> void:
	T._wblock(pk, kit, "kbrick", Vector3(c.x - 0.45, M_YE, c.z - 0.3), Vector3(c.x + 0.45, top, c.z + 0.3), BRICK_DK)
	T._wblock(pk, kit, "ashlar", Vector3(c.x - 0.52, top, c.z - 0.37), Vector3(c.x + 0.52, top + 0.12, c.z + 0.37), SAND)
	for sx in [-0.2, 0.2]:
		pk.tube(kit, "metal", Vector3(c.x + sx, top + 0.1, c.z), Vector3(c.x + sx, top + 0.45, c.z), 0.09, 0.09, 8, Color(0.36, 0.28, 0.24), true)


## A hanging sign on a wrought-iron bracket from the wall at u (v 4.9), its oval board turned along the street, named
## on both faces.
static func _nose_sign(pk: PropKit, kit: Dictionary, labels: Array, wf: Transform3D, u: float, text: String) -> void:
	var out: Vector3 = wf.basis.z.normalized()
	var w0: Vector3 = wf * Vector3(u, 4.95, 0.0)
	pk.tube(kit, "metal", w0 - out * 0.02, w0 + out * 1.75, 0.035, 0.03, 6, IRON, true)
	pk.beam(kit, "metal", wf * Vector3(u, 4.1, 0.0), w0 + out * 1.1, 0.04, 0.04, IRON)
	pk.tube(kit, "metal", w0 - out * 0.02, w0 + out * 0.06, 0.12, 0.12, 8, IRON, true)
	var ctr: Vector3 = w0 + out * 1.0 + Vector3(0, -0.62, 0)
	for sx in [-0.45, 0.45]:
		pk.tube(kit, "metal", w0 + out * (1.0 + sx), ctr + out * sx * 0.9 + Vector3(0, 0.42, 0), 0.012, 0.012, 4, IRON, false)
	var bf := Transform3D(Basis(out, Vector3.UP, out.cross(Vector3.UP)), ctr)
	var oval := PackedVector2Array()
	for k in range(20):
		var a: float = TAU * float(k) / 20.0
		oval.append(Vector2(cos(a) * 0.6, sin(a) * 0.42))
	T._prism(pk, kit, "enamel", bf, oval, -0.025, 0.025, GREEN, Vector2(0, 1), true)
	var rim := PackedVector2Array()
	for k2 in range(20):
		var a2: float = TAU * float(k2) / 20.0
		rim.append(Vector2(cos(a2) * 0.66, sin(a2) * 0.48))
	T._prism(pk, kit, "gold", bf, rim, -0.018, 0.018, GOLD, Vector2(0, 1), true)
	for side in [-1.0, 1.0]:
		var n: Vector3 = (bf.basis.z * side).normalized()
		labels.append([text, ctr + n * 0.03, n, 0.17, GOLD, 1.0])


# ======================================================================================
#  The beer garden
# ======================================================================================

## The beer tables: [centre on the gravel, a parasol over it].
static func _tables() -> Array:
	var out: Array = []
	for tz in [4.0, 11.6]:
		for tx in [-11.8, -9.4, -7.0, -4.7, -2.4, 2.4, 4.7, 7.0, 9.4, 11.8]:
			out.append([Vector3(tx, SLAB, tz), absf(tx) < 8.0])
	for tx2 in [14.6, 22.4]:
		out.append([Vector3(tx2, SLAB, 4.0), true])
	for tx3 in [14.6, 17.0, 19.4, 21.8]:
		out.append([Vector3(tx3, SLAB, 11.6), true])
	return out


const TREES := [Vector3(-9.6, SLAB, 8.0), Vector3(9.6, SLAB, 8.0)]
## The fence's piers along the front (x), the gates between -1.6 and 1.6 and between 24.9 and 27.9.
const PIERS := [-13.0, -9.2, -5.4, -1.6, 1.6, 5.4, 9.2, 13.0, 16.8, 20.6, 24.9, 27.9, 29.0]


static func garden(pk: PropKit, kit: Dictionary, labels: Array, seed_v: int) -> void:
	RS._lx = Transform3D.IDENTITY
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	# The gravel, the paths, the driveway's clinker.
	pk.block(kit, "matte", Vector3(-M_HW + 0.02, -1.0, 0.0), Vector3(S_X1 - 0.02, SLAB, FENCE_Z - 0.18), GRAVEL)
	pk.block(kit, "matte", Vector3(S_X0 + 0.02, -1.0, S_Z + 0.02), Vector3(TW_X0 - 0.02, SLAB, 0.02), GRAVEL)
	T._wblock(pk, kit, "ashlar", Vector3(-1.3, SLAB - 0.1, 1.95), Vector3(1.3, SLAB + 0.025, FENCE_Z - 0.2), SAND.darkened(0.12))
	T._wblock(pk, kit, "kbrick", Vector3(DRIVE_X.x, -1.0, -0.46), Vector3(DRIVE_X.y, SLAB, FENCE_Z + 0.6), CLINKER)
	for kx in [DRIVE_X.x - 0.2, DRIVE_X.y]:
		T._wblock(pk, kit, "ashlar", Vector3(kx, -1.0, 0.0), Vector3(kx + 0.2, SLAB + 0.08, FENCE_Z + 0.6), SAND.darkened(0.15))
	# The fence: brick between piers, a sandstone coping, railings; its returns at both ends.
	for i in range(PIERS.size() - 1):
		var a: float = PIERS[i]
		var b: float = PIERS[i + 1]
		if (a == -1.6 and b == 1.6) or (a == 24.9 and b == 27.9):
			continue
		_fence_run(pk, kit, Vector3(a + 0.3, 0, FENCE_Z), Vector3(b - 0.3, 0, FENCE_Z))
	for x in [-M_HW, S_X1]:
		_fence_run(pk, kit, Vector3(x, 0, 0.35), Vector3(x, 0, 7.2))
		_fence_run(pk, kit, Vector3(x, 0, 7.8), Vector3(x, 0, FENCE_Z - 0.3))
		_pier(pk, kit, Vector3(x, 0, 7.5), 1.8, false)
	for p in PIERS:
		var tall: bool = p == -1.6 or p == 1.6
		_pier(pk, kit, Vector3(p, 0, FENCE_Z), 2.4 if tall else 1.8, p == 24.9 or p == 27.9 or p == -13.0 or p == 29.0)
	# The gate: an iron arch with the BIERGARTEN board, the leaves swung open into the garden.
	_garden_gate(pk, kit, labels)
	for gx in [[24.9, 1.0], [27.9, -1.0]]:
		_gate_leaf(pk, kit, Vector3(float(gx[0]) + float(gx[1]) * 0.3, SLAB, FENCE_Z), float(gx[1]), 1.15, 1.25, deg_to_rad(80.0))
	# The driveway's piers with lanterns, hedges either side of it along the street.
	for dx in [DRIVE_X.x - 0.5, DRIVE_X.y + 0.5]:
		_pier(pk, kit, Vector3(dx, 0, FENCE_Z), 2.1, true)
	T._wblock(pk, kit, "hedge", Vector3(W_X0 + 0.3, -0.5, FENCE_Z - 0.5), Vector3(DRIVE_X.x - 0.9, 1.35, FENCE_Z + 0.45), HEDGE)
	T._wblock(pk, kit, "hedge", Vector3(DRIVE_X.y + 0.9, -0.5, FENCE_Z - 0.5), Vector3(-M_HW - 0.4, 1.35, FENCE_Z + 0.45), HEDGE)
	# The chestnuts.
	for tp in TREES:
		_chestnut(pk, kit, tp, rng)
	# Tables, benches and parasols over every other one (cream and the brewery's green, red and white by the Sudhaus).
	var tables: Array = _tables()
	for i in range(tables.size()):
		var tc: Vector3 = tables[i][0]
		RS._beer_table(pk, kit, tc)
		if tables[i][1] and i % 2 == 0:
			var red: bool = tc.x > S_X0
			RS._parasol(pk, kit, tc, 1.1, CREAM if not red else Color(0.95, 0.94, 0.9), GREEN if not red else RED)
	# Strings of lights from the chestnuts to the facade and to the gate's arch.
	for tp2 in TREES:
		var s: float = signf(tp2.x)
		var hook: Vector3 = tp2 + Vector3(-s * 0.3, 4.1, 0.0)
		_light_string(pk, kit, hook, Vector3(s * 2.4, 5.1, RIS_OUT + 0.05), 0.55)
		_light_string(pk, kit, hook, Vector3(s * 0.6, 3.5, FENCE_Z), 0.5)
		_light_string(pk, kit, hook, Vector3(s * (M_HW - 0.4), 4.6, 0.05), 0.45)
	# The menu board by the gate, barrels, kegs and crates by the tower's door.
	RS._menu_board(pk, kit, labels, Vector3(2.7, SLAB, FENCE_Z - 1.1), "Frisch gezapft!", GREEN)
	for row in range(3):
		for i in range(3 - row):
			_barrel(pk, kit, Vector3(TW_X0 + 1.1 + float(i) * 0.9 + float(row) * 0.45, SLAB + 0.42 + float(row) * 0.72, 8.6))
	for k in range(4):
		_keg(pk, kit, Vector3(S_X1 - 0.6 - float(k % 2) * 0.55, SLAB, 2.6 + float(k >> 1) * 0.55))
	for cx in range(2):
		for cz in range(2):
			for cy in range(4 - cx):
				var c0 := Vector3(S_X1 - 0.65 - float(cx) * 0.42, SLAB + float(cy) * 0.29, 5.0 + float(cz) * 0.32)
				pk.block(kit, "plastic", c0 + Vector3(-0.2, 0.0, -0.15), c0 + Vector3(0.2, 0.28, 0.15), RED if (cx + cz + cy) % 3 != 0 else BOTTLE)


static func garden_solids() -> Array:
	var out: Array = []
	for i in range(PIERS.size() - 1):
		var a: float = PIERS[i]
		var b: float = PIERS[i + 1]
		if (a == -1.6 and b == 1.6) or (a == 24.9 and b == 27.9):
			continue
		out.append([Transform3D(Basis(), Vector3((a + b) * 0.5, 0.8, FENCE_Z)), Vector3(b - a, 1.6, 0.5)])
	for x in [-M_HW, S_X1]:
		out.append([Transform3D(Basis(), Vector3(x, 0.8, FENCE_Z * 0.5)), Vector3(0.5, 1.6, FENCE_Z)])
	for p in [-1.6, 1.6, 24.9, 27.9, DRIVE_X.x - 0.5, DRIVE_X.y + 0.5]:
		out.append([Transform3D(Basis(), Vector3(p, 1.2, FENCE_Z)), Vector3(0.75, 2.4, 0.75)])
	out.append([Transform3D(Basis(), Vector3((W_X0 + DRIVE_X.x - 0.6) * 0.5, 0.65, FENCE_Z)), Vector3(DRIVE_X.x - 0.6 - W_X0, 1.3, 0.95)])
	out.append([Transform3D(Basis(), Vector3((DRIVE_X.y - M_HW + 0.5) * 0.5, 0.65, FENCE_Z)), Vector3(-M_HW - DRIVE_X.y - 0.5, 1.3, 0.95)])
	for tp in TREES:
		out.append([Transform3D(Basis(), tp + Vector3(0, 1.8, 0)), Vector3(0.7, 3.6, 0.7)])
	for tb in _tables():
		out.append([Transform3D(Basis(), (tb[0] as Vector3) + Vector3(0, 0.4, 0)), Vector3(1.6, 0.8, 2.3)])
	out.append([Transform3D(Basis(), Vector3(TW_X0 + 2.0, 1.1, 8.6)), Vector3(3.0, 2.2, 1.0)])
	out.append([Transform3D(Basis(), Vector3(S_X1 - 0.8, 0.6, 3.8)), Vector3(1.4, 1.2, 3.2)])
	return out


## The people in the beer garden: [position (life, kit frame), facing, seated]: on the benches (the seat's top), at the
## gate and by the portal.
static func garden_people(seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v + 17
	var out: Array = []
	for tb in _tables():
		var tc: Vector3 = tb[0]
		for sx in [-1.0, 1.0]:
			for sz in [-0.5, 0.5]:
				if rng.randf() < 0.5:
					continue
				var p: Vector3 = tc + Vector3(sx * 0.6, 0.48, sz + rng.randf_range(-0.08, 0.08))
				out.append([p, Vector3(-sx, 0, rng.randf_range(-0.3, 0.3)).normalized(), true])
	for s in [[Vector3(-0.6, SLAB, FENCE_Z - 1.6), Vector3(0.3, 0, -1)], [Vector3(0.9, SLAB, FENCE_Z - 2.2), Vector3(-0.8, 0, -0.5)],
			[Vector3(3.4, SLAB, FENCE_Z - 2.0), Vector3(-0.4, 0, 1)], [Vector3(-2.2, SLAB, 2.6), Vector3(0.7, 0, 0.6)], [Vector3(2.0, SLAB, 2.9), Vector3(-0.6, 0, 0.7)],
			[Vector3(13.4, SLAB, 7.6), Vector3(-0.2, 0, 1)], [Vector3(23.5, SLAB, 7.0), Vector3(-1, 0, 0.2)]]:
		out.append([s[0], (s[1] as Vector3).normalized(), false])
	return out


static func _fence_run(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3) -> void:
	var lo := Vector3(minf(a.x, b.x), 0, minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), 0, maxf(a.z, b.z))
	var along_x: bool = hi.x - lo.x > hi.z - lo.z
	var th := Vector3(0, 0, 0.2) if along_x else Vector3(0.2, 0, 0)
	var th2 := Vector3(0, 0, 0.25) if along_x else Vector3(0.25, 0, 0)
	T._wblock(pk, kit, "kbrick", lo - th + Vector3(0, -1.0, 0), hi + th + Vector3(0, 0.62, 0), BRICK)
	T._wblock(pk, kit, "ashlar", lo - th2 + Vector3(0, 0.62, 0), hi + th2 + Vector3(0, 0.72, 0), SAND)
	RS._railing(pk, kit, [Vector3(a.x, 0.72, a.z), Vector3(b.x, 0.72, b.z)], 0.8, IRON, 0.13)


static func _pier(pk: PropKit, kit: Dictionary, c: Vector3, h: float, lantern: bool) -> void:
	T._wblock(pk, kit, "kbrick", Vector3(c.x - 0.3, -1.0, c.z - 0.3), Vector3(c.x + 0.3, h, c.z + 0.3), BRICK_DK)
	T._wblock(pk, kit, "ashlar", Vector3(c.x - 0.36, h, c.z - 0.36), Vector3(c.x + 0.36, h + 0.13, c.z + 0.36), SAND)
	if lantern:
		YK.lantern(pk, kit, Vector3(c.x, h + 0.13, c.z), 1.3)
	else:
		pk.lathe(kit, "paint", Vector3(c.x, h + 0.13, c.z), [Vector2(0.001, 0.0), Vector2(0.17, 0.0), Vector2(0.17, 0.08), Vector2(0.1, 0.12), Vector2(0.2, 0.3),
				Vector2(0.16, 0.45), Vector2(0.001, 0.5)], 10, SAND)


## The garden's gate between the piers at x -1.6 and 1.6: a wrought-iron arch over it carrying a green board with
## BIERGARTEN in gold on both faces, the two leaves swung open inward.
static func _garden_gate(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var z: float = FENCE_Z
	var prev_o := Vector3.ZERO
	var prev_i := Vector3.ZERO
	for k in range(13):
		var t: float = float(k) / 12.0
		var x: float = lerpf(-1.32, 1.32, t)
		var lift: float = sin(t * PI)
		var po := Vector3(x, 2.5 + 1.15 * lift, z)
		var pi_ := Vector3(x, 2.5 + 0.75 * lift, z)
		if k > 0:
			pk.tube(kit, "metal", prev_o, po, 0.035, 0.035, 6, IRON, false)
			pk.tube(kit, "metal", prev_i, pi_, 0.028, 0.028, 6, IRON, false)
		if k % 2 == 1:
			pk.tube(kit, "metal", pi_, po, 0.018, 0.018, 4, IRON, false)
		prev_o = po
		prev_i = pi_
	var bf := Transform3D(Basis(), Vector3(0, 2.95, z))
	T._prism(pk, kit, "enamel", bf, PackedVector2Array([Vector2(-1.05, -0.24), Vector2(1.05, -0.24), Vector2(1.05, 0.24), Vector2(-1.05, 0.24)]), -0.025, 0.025,
			GREEN, Vector2(0, 1), true)
	T._prism(pk, kit, "gold", bf, PackedVector2Array([Vector2(-1.1, -0.29), Vector2(1.1, -0.29), Vector2(1.1, 0.29), Vector2(-1.1, 0.29)]), -0.018, 0.018,
			GOLD, Vector2(0, 1), true)
	for side in [-1.0, 1.0]:
		var n := Vector3(0, 0, side)
		labels.append(["BIERGARTEN", Vector3(0, 2.95, z) + n * 0.03, n, 0.24, GOLD, 1.9])
	for sx in [-1.0, 1.0]:
		_gate_leaf(pk, kit, Vector3(sx * 1.3, SLAB, z), -sx, 1.25, 1.5, deg_to_rad(75.0))


## A wrought-iron gate leaf hinged at `hinge`, `w` wide toward `dir` (along x) and `h` tall, swung `open` into the garden.
static func _gate_leaf(pk: PropKit, kit: Dictionary, hinge: Vector3, dir: float, w: float, h: float, open: float) -> void:
	var along := Vector3(dir * cos(open), 0, -sin(open))
	var y0: float = hinge.y + 0.08
	var p0 := Vector3(hinge.x, y0, hinge.z)
	var p1: Vector3 = p0 + along * w
	pk.beam(kit, "metal", p0 + Vector3(0, 0.0, 0), p1, 0.04, 0.04, IRON, Vector3.UP)
	pk.beam(kit, "metal", p0 + Vector3(0, h, 0), p1 + Vector3(0, h - 0.1, 0), 0.04, 0.04, IRON, Vector3.UP)
	var n: int = int(w / 0.13)
	for k in range(n + 1):
		var p: Vector3 = p0.lerp(p1, float(k) / float(n))
		var top: float = h - 0.1 * float(k) / float(n)
		pk.beam(kit, "metal", p, p + Vector3(0, top + 0.08, 0), 0.025 if (k > 0 and k < n) else 0.04, 0.025 if (k > 0 and k < n) else 0.04, IRON)


static func _chestnut(pk: PropKit, kit: Dictionary, c: Vector3, rng: RandomNumberGenerator) -> void:
	var h: float = rng.randf_range(3.2, 3.6)
	pk.tube(kit, "wood", c + Vector3(0, -0.4, 0), c + Vector3(0, h, 0), 0.34, 0.25, 9, BARK, false)
	for k in range(4):
		var a: float = TAU * float(k) / 4.0 + rng.randf() * 0.8
		var e: Vector3 = c + Vector3(cos(a) * 1.7, h + 1.7, sin(a) * 1.7)
		pk.tube(kit, "wood", c + Vector3(0, h - 0.25, 0), e, 0.2, 0.09, 6, BARK, true)
	var crown: Vector3 = c + Vector3(0, h + 3.4, 0)
	SK._crown_lumps(pk, kit, crown, 4.6, LEAF, rng, 8)
	# Its candles of white blossom over the crown.
	for k2 in range(18):
		var a2: float = rng.randf() * TAU
		var el: float = rng.randf_range(-0.2, 0.9)
		var d := Vector3(cos(a2) * cos(el), sin(el), sin(a2) * cos(el))
		var p: Vector3 = crown + Vector3(d.x * 3.6, d.y * 3.0, d.z * 3.6)
		T._blob(pk, kit, "leaf", p, Vector3(0.13, 0.3, 0.13), Color(0.97, 0.95, 0.88))


## A string of lights from a to b sagging `sag`: a cord and bulbs every 55cm.
static func _light_string(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, sag: float) -> void:
	var l: float = a.distance_to(b)
	var segs: int = maxi(int(l / 0.55), 2)
	var pts: Array = RS._sag_pts(a, b, sag, segs)
	for k in range(pts.size() - 1):
		pk.tube(kit, "matte", pts[k], pts[k + 1], 0.012, 0.012, 3, Color(0.12, 0.12, 0.12), false)
	for k2 in range(1, pts.size() - 1):
		pk.lathe(kit, "bulb", (pts[k2] as Vector3) + Vector3(0, -0.06, 0), [Vector2(0.001, -0.07), Vector2(0.055, -0.04), Vector2(0.06, 0.0), Vector2(0.03, 0.05),
				Vector2(0.001, 0.06)], 6, Color(1.0, 0.86, 0.58))


static func _barrel(pk: PropKit, kit: Dictionary, c: Vector3) -> void:
	var ab := Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
	pk.lathe(kit, "wood", c, [Vector2(0.001, -0.55), Vector2(0.34, -0.55), Vector2(0.36, -0.5), Vector2(0.4, -0.25), Vector2(0.42, 0.0), Vector2(0.4, 0.25),
			Vector2(0.36, 0.5), Vector2(0.34, 0.55), Vector2(0.001, 0.55)], 14, Color(0.50, 0.33, 0.18), false, ab)
	for y in [-0.42, -0.16, 0.16, 0.42]:
		var r: float = 0.42 - absf(y) * 0.12 + 0.012
		pk.lathe(kit, "metal", c, [Vector2(r - 0.01, y - 0.035), Vector2(r, y - 0.03), Vector2(r, y + 0.03), Vector2(r - 0.01, y + 0.035)], 14, IRON, false, ab)


static func _keg(pk: PropKit, kit: Dictionary, c: Vector3) -> void:
	pk.lathe(kit, "steel", c, [Vector2(0.001, 0.0), Vector2(0.19, 0.0), Vector2(0.2, 0.05), Vector2(0.2, 0.55), Vector2(0.19, 0.6), Vector2(0.06, 0.62),
			Vector2(0.001, 0.62)], 12, Color(0.72, 0.73, 0.74))
	for y in [0.18, 0.42]:
		pk.lathe(kit, "steel", c, [Vector2(0.2, y - 0.02), Vector2(0.215, y - 0.01), Vector2(0.215, y + 0.01), Vector2(0.2, y + 0.02)], 12, Color(0.6, 0.61, 0.62))
