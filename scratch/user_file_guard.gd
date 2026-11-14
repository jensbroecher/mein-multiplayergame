extends RefCounted
## Keeps the player's own files (records, trophies, settings, ghosts) safe while a test overwrites them.
##
## `protect(tag, paths)` copies each user:// file to user://test_backups/<tag>/ on disk before the test touches it (a file
## that doesn't exist gets an ".absent" marker, so restoring removes what the test made), and first puts back whatever an
## interrupted run of that tag left there. `restore(tag)` puts the copies back and deletes them. So a test that is killed
## half way loses nothing: its copies stay on disk and the next run (or `restore`) puts them back. Backups held in memory,
## as the tests used to, were lost with the process, and with them the player's lap records.
##   const Guard = preload("res://scratch/user_file_guard.gd")
##   Guard.protect("ghost_test", ["user://lap_records.cfg", ...])  ...  Guard.restore("ghost_test")
## `res://scratch/user_file_guard_restore.gd` (`-s`, headless, `-- [tag ...]`) restores every tag's (or the named) copies.

const ROOT := "user://test_backups/"


static func _dir(tag: String) -> String:
	return ROOT + tag + "/"


static func _name(path: String) -> String:
	return path.trim_prefix("user://").replace("/", "__")


static func _path(name: String) -> String:
	return "user://" + name.replace("__", "/")


static func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p)


## Copy `paths` aside for `tag`, after restoring any copies an interrupted run left.
static func protect(tag: String, paths: Array) -> void:
	if restore(tag) > 0:
		print("[UserFileGuard] %s: put back the files an interrupted run had left aside" % tag)
	var d := _dir(tag)
	DirAccess.make_dir_recursive_absolute(_abs(d))
	for p in paths:
		var n := _name(str(p))
		if FileAccess.file_exists(p):
			var err := DirAccess.copy_absolute(_abs(p), _abs(d + n))
			if err != OK:
				push_error("UserFileGuard: can't copy %s aside (%d): stopping" % [p, err])
				OS.crash("UserFileGuard: refusing to run a test that can't back up " + str(p))
		else:
			var f := FileAccess.open(d + n + ".absent", FileAccess.WRITE)
			if f:
				f.close()


## Put `tag`'s copies back (and remove files that hadn't existed); returns how many files it put back or removed.
static func restore(tag: String) -> int:
	var d := _dir(tag)
	if not DirAccess.dir_exists_absolute(_abs(d)):
		return 0
	var count := 0
	for n in DirAccess.get_files_at(_abs(d)):
		if n.ends_with(".absent"):
			var target := _path(n.trim_suffix(".absent"))
			if FileAccess.file_exists(target):
				DirAccess.remove_absolute(_abs(target))
		else:
			var target := _path(n)
			DirAccess.make_dir_recursive_absolute(_abs(target.get_base_dir()))
			if DirAccess.copy_absolute(_abs(d + n), _abs(target)) != OK:
				push_error("UserFileGuard: can't put back %s: its copy stays in %s" % [target, _abs(d)])
				continue
		DirAccess.remove_absolute(_abs(d + n))
		count += 1
	if DirAccess.get_files_at(_abs(d)).is_empty():
		DirAccess.remove_absolute(_abs(d))
		if DirAccess.get_directories_at(_abs(ROOT)).is_empty() and DirAccess.get_files_at(_abs(ROOT)).is_empty():
			DirAccess.remove_absolute(_abs(ROOT))
	return count


## Every tag that has copies waiting.
static func pending() -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(_abs(ROOT)):
		return PackedStringArray()
	return DirAccess.get_directories_at(_abs(ROOT))
