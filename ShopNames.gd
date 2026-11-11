extends RefCounted
## Names for the Kronburg GP's shops, cafés, restaurants and workshops, none twice on a stage. The kits (RheinStadtKit,
## KronburgTownKit, StadtKit) paint every name through `unique(kind, wanted)`: the first shop to ask for a name gets it,
## and any other of that kind gets a new name made from the kind's patterns (a surname, a place, an Italian word, an inn's
## sign), so the same "Café Rheinblick" no longer turned up three times down one street. A name's word (Rheinblick,
## Venezia, Goldenen Anker) is used once a stage too: "Brauhaus Rheinblick" two doors from "Café Rheinblick" read as the
## same café again. A generator runs in a process of its own; it calls `reset` with a salt and its stage's key first, so
## each stage draws its names in a different order, and with them the names the other Kronburg stages hold (REGISTRY)
## are taken too: the four stages are one city, and each had its own Café Rheinblick. `save` (before the level is saved)
## puts this stage's names into the registry, keeping the others'; a stage regenerated later keeps off them.
## Everything fictional.

static var _used := {}
static var _words := {}
static var _surnames := {}
static var _turn := {}
static var _salt := 0
static var _stage := ""
static var _foreign := {}

const REGISTRY := "res://generated/kronburg_shop_names.json"

## Surnames of the Ruhr and the Lower Rhine.
const SURNAMES := ["Brinkmann", "Kötter", "Overkamp", "Lamberti", "Terhorst", "Hülsmann", "Brammertz", "Overbeck", "Löwenkamp",
	"Kemper", "Schulte-Wien", "Hegemann", "Tenbrink", "Wessel", "Kamps", "Pieper", "Hülsbusch", "Ernst", "Overmann", "Kowalski",
	"Szymanski", "Dahlhaus", "Rademacher", "Bergmann", "Niehues", "Hölscher", "Wienand", "Buschhoff", "Ostermann", "Lüdecke",
	"Böckenhoff", "Tiemann", "Wolters", "Hesse", "Krämer", "Vossen", "Jansen", "Hendricks", "van Berk", "Theißen", "Kleinholz",
	"Pohlmann", "Grewe", "Sasse", "Kuhlmann", "Wortmann", "Schürmann", "Elbers", "Lohmann", "Röttger", "Ahlers", "Feldhaus",
	"Wiesmann", "Hagedorn", "Stratmann", "Biermann", "Reckers", "Gerlach", "Nottebohm", "Lückenkötter", "Bruns", "Heimann",
	"Möllers", "Steinhoff", "Kaminski", "Nowak", "Kurzawa", "Pütz", "Stappert", "Witte", "Plum", "Thelen", "Kerkhoff"]
## Places in town a café or a shop is named after.
const PLACES := ["am Markt", "am Ring", "am Dom", "am Stadtpark", "an der Brücke", "am Kanal", "am Tor", "am Brunnen",
	"an der Ecke", "im Hof", "am Rathaus", "am Theater", "an der Post", "am Wall", "am Graben", "am Bahnhof", "an der Mühle",
	"am Kaiserplatz", "an der Linde", "am Schlossberg", "am Hafen", "im Viertel", "am Wasserturm", "an der Zeche"]
## Words for a café's name.
const WORDS := ["Rheinblick", "Mokka", "Sonnenschein", "Sternchen", "Kranz", "Abendrot", "Rosengarten", "Goldstück",
	"Kaffeemühle", "Zuckerdose", "Schwalbe", "Tante Emma", "Kleeblatt", "Morgenrot", "Laterne", "Kachelofen", "Pusteblume",
	"Mohnblume", "Sahnehäubchen", "Taubenschlag"]
## Words for a brewhouse's, a wine bar's or a restaurant's name.
const BRAU := ["Krone", "Lindenhof", "Mühlenhof", "Uferkrone", "Treidelpfad", "Glückauf", "Förderturm", "Kastanie", "Stadtkrone",
	"Weinberg", "Rebstock", "Ankerplatz", "Brückenhof", "Domblick", "Zollhaus", "Fährhaus", "Kaiserhof", "Ratskeller", "Hopfengarten",
	"Malzmühle", "Schlossberg", "Hafenkante"]
## Italian words for the ice-cream parlours and the trattorias.
const ITALIAN := ["Bellamonte", "Venezia", "Dolomiti", "Cortina", "Rialto", "San Remo", "Capri", "Portofino", "Firenze",
	"Bella Napoli", "Lago di Garda", "Sorrento", "Amalfi", "Verona", "Milano", "Toscana", "Torino", "Isola Verde", "Da Gino",
	"Sole Mio", "Rimini", "Siena", "Trevi", "Paradiso", "Pinocchio", "Calabria", "Marina", "Gondola"]
## Inn signs ("Zum ...").
const INNS := ["Goldenen Anker", "Alten Fritz", "Schwarzen Ross", "Grünen Baum", "Weißen Lamm", "Roten Hahn", "Krug",
	"Hirschen", "Löwen", "Schiffchen", "Alten Fährhaus", "Steiger", "Kumpel", "Brauhof", "Eck", "Treppchen", "Ritter",
	"Stiefel", "Fässchen", "Postillion"]
## The pharmacies' signs ("...-Apotheke").
const APOTHEKEN := ["Kronen", "Adler", "Löwen", "Stern", "Rosen", "Markt", "Rathaus", "Hirsch", "Einhorn", "Sonnen", "Linden",
	"Engel", "Schwanen", "Brunnen", "Ring", "Park", "Glückauf", "Hafen", "Turm", "Tor"]

## Per kind: patterns, {n} a surname, {p} a place, {w} a café's word, {b} a brewhouse's, {i} an Italian word, {g} an inn's
## sign, {a} a pharmacy's.
const PATTERNS := {
	"cafe": ["Café {n}", "Konditorei {n}", "Café {w}", "Café {p}", "Kaffeehaus {n}", "Café-Konditorei {w}", "Backstube & Café {n}"],
	"eis": ["Eiscafé {i}", "Eisdiele {i}", "Gelateria {i}"],
	"restaurant": ["Gasthaus {n}", "Zum {g}", "Ristorante {i}", "Weinstube {b}", "Trattoria {i}", "Brauhaus {b}", "Bistro {p}",
		"Restaurant {b}", "Gaststätte {n}"],
	"shop": ["Buchhandlung {n}", "Blumen {n}", "Optik {n}", "Feinkost {n}", "Mode {n}", "Schuhhaus {n}", "Uhren & Schmuck {n}",
		"Papeterie {n}", "Drogerie {n}", "Juwelier {n}", "Foto {n}", "Spielwaren {n}", "Haushaltswaren {n}", "Tabakwaren {n}",
		"Reisebüro {n}", "Weinhandel {n}", "Hüte {n}", "Lederwaren {n}", "Radio {n}", "Bettenhaus {n}"],
	"book": ["Buchhandlung {n}", "Antiquariat {n}", "Bücherstube {p}"],
	"pretzel": ["Bäckerei {n}", "Backstube {n}", "Bäckerei {p}"],
	"ox": ["Metzgerei {n}", "Fleischerei {n}", "Landmetzgerei {n}"],
	"apotheke": ["{a}-Apotheke"],
	"garage": ["Kfz {n}", "Reifen {n}", "Autohaus {n}", "Tischlerei {n}", "Motorrad {n}", "Schlosserei {n}", "Lackiererei {n}"],
	"window": ["Atelier {n}", "Studio {n}", "Galerie {n}", "Probenraum {n}"],
	"kiosk": ["Eiskiosk {i}", "Trinkhalle {n}", "Büdchen {p}", "Kiosk {p}"],
	# The Rheinkirmes's stalls (RheinStadtKit.stall), each a showman family's.
	"stall_bratwurst": ["Grillstube {n}", "Imbiss {n}", "Bratwursthaus {n}", "Grillhütte {n}"],
	"stall_mandeln": ["Mandel-Paradies {n}", "Mandelbrennerei {n}", "Süßes von {n}", "Zuckerbäckerei {n}"],
	"stall_lebkuchen": ["Lebkuchen {n}", "Herzerlstand {n}", "Lebkuchenstube {n}"],
	"stall_lose": ["Losbude {n}", "Glücksrad {n}", "Glücksbude {n}"],
	"stall_schiess": ["Schießhalle {n}", "Schießstand {n}", "Schießsport {n}"],
	"stall_crepes": ["Crêperie {n}", "Waffelhaus {n}", "Crêpes {n}"],
	"stall_getraenke": ["Schankwagen {n}", "Ausschank {n}", "Bierwagen {n}"],
}
const KIND_ALIAS := {"cup": "cafe"}


## Start a stage's names afresh; `salt` varies the order the names are drawn in.
static func reset(salt := 0, stage := "") -> void:
	_used.clear()
	_words.clear()
	_surnames.clear()
	_turn.clear()
	_foreign.clear()
	_salt = salt
	_stage = stage
	if stage.is_empty() or not FileAccess.file_exists(REGISTRY):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	if not (data is Dictionary):
		return
	for st in data.keys():
		if String(st) == stage:
			continue
		for nm in data[st]:
			_used[String(nm)] = true
			_foreign[String(nm)] = true
			for w in _name_words(String(nm)):
				_words[w] = true


## Writes this stage's names into REGISTRY beside the other stages' (sorted, so a regeneration that names the same shops
## leaves the file as it was).
static func save() -> void:
	if _stage.is_empty():
		return
	var data := {}
	if FileAccess.file_exists(REGISTRY):
		var d = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
		if d is Dictionary:
			data = d
	var mine: Array = []
	for nm in _used.keys():
		if not _foreign.has(nm):
			mine.append(nm)
	mine.sort()
	data[_stage] = mine
	var f := FileAccess.open(REGISTRY, FileAccess.WRITE)
	if f == null:
		push_warning("ShopNames: can't write %s" % REGISTRY)
		return
	f.store_string(JSON.stringify(data, "\t", true) + "\n")
	print("  shop names: %d on this stage, %d on the others" % [mine.size(), _foreign.size()])


## A name for a shop of `kind`: `wanted` if no shop on this stage has it yet (and it isn't empty), else a new one.
static func unique(kind: String, wanted := "") -> String:
	if not wanted.is_empty() and not _used.has(wanted):
		var own: Array = _name_words(wanted)
		var free := true
		for w in own:
			if _words.has(w):
				free = false
		if free:
			_used[wanted] = true
			for w2 in own:
				_words[w2] = true
			for sn in SURNAMES:
				if wanted.contains(String(sn)):
					_surnames[sn] = true
			return wanted
	var k: String = KIND_ALIAS.get(kind, kind)
	var pats: Array = PATTERNS.get(k, PATTERNS["shop"])
	# Each kind starts its draw somewhere of its own: from 0, the first of every kind had the same surname.
	var turn: int = int(_turn.get(k, absi(hash(k)) % 1009))
	for attempt in range(4000):
		var t: int = turn + attempt
		var pat: String = pats[(t + _salt) % pats.size()]
		var parts := {
			"n": _pick(SURNAMES, t, 7), "p": _pick(PLACES, t, 5), "w": _pick(WORDS, t, 11), "b": _pick(BRAU, t, 13), "i": _pick(ITALIAN, t, 13),
			"g": _pick(INNS, t, 3), "a": _pick(APOTHEKEN, t, 17),
		}
		var nm: String = pat.format(parts)
		if _used.has(nm):
			continue
		# Its word (not the surname or the place, which may repeat in a town) must be new on this stage, while there are
		# words left (after 2000 tries only the name must be).
		var fresh := true
		for key in ["w", "b", "i", "g"]:
			if pat.contains("{%s}" % key) and _words.has(parts[key]):
				fresh = false
		if not fresh and attempt < 2000:
			continue
		# A surname not on the stage yet if one is soon found (a town has a few families twice, not one on every shop).
		if pat.contains("{n}") and _surnames.has(parts["n"]) and attempt < 200:
			continue
		_used[nm] = true
		for key2 in ["w", "b", "i", "g"]:
			if pat.contains("{%s}" % key2):
				_words[parts[key2]] = true
		if pat.contains("{n}"):
			_surnames[parts["n"]] = true
		_turn[k] = t + 1
		return nm
	return wanted


## The words of the lists above a name holds (a hand-picked name's too, so no later name repeats them).
static func _name_words(nm: String) -> Array:
	var out: Array = []
	for list in [WORDS, BRAU, ITALIAN, INNS]:
		for w in list:
			if nm.contains(String(w)):
				out.append(w)
	return out


static func _pick(list: Array, t: int, stride: int) -> String:
	return list[(t * stride + _salt * 31 + t / list.size()) % list.size()]
