extends RefCounted

# Three independent campaign files and a separate global preferences file.
# Writes are staged, re-read and only then renamed; the last valid previous
# campaign is kept as a backup. No invalid/future file is overwritten.
const VERSION := 1
const Skills = preload("res://skill_tree.gd")
var profile_path := "user://come_to_me_profile.cfg"


func slot_path(slot: int) -> String:
	return profile_path + ".campaign-%d.cfg" % (slot + 1)


func backup_path(slot: int) -> String:
	return slot_path(slot) + ".bak"


func replaced_path(slot: int) -> String:
	return slot_path(slot) + ".replaced.bak"


func read_replaced(slot: int) -> Dictionary:
	if slot < 0 or slot > 2:
		return {"status": "invalid"}
	return _read_slot_path(replaced_path(slot))


func read_slot(slot: int, backup: bool = false) -> Dictionary:
	if slot < 0 or slot > 2:
		return {"status": "invalid"}
	return _read_slot_path(backup_path(slot) if backup else slot_path(slot))


func _read_slot_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": "empty"}
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return {"status": "corrupt"}
	if not file.has_section_key("campaign", "version") or not file.has_section_key("campaign", "data"):
		return {"status": "corrupt"}
	var version: Variant = file.get_value("campaign", "version")
	if typeof(version) != TYPE_INT:
		return {"status": "corrupt"}
	if version > VERSION:
		return {"status": "future"}
	if version != VERSION:
		return {"status": "corrupt"}
	var data: Variant = file.get_value("campaign", "data")
	if not valid_payload(data):
		return {"status": "corrupt"}
	return {"status": "ok", "data": data.duplicate(true), "legacy_sha256": str(file.get_value("campaign", "legacy_sha256", ""))}


func valid_payload(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for field in ["best_score", "rescues", "furthest_floor", "resume_floor", "resume_coins", "resume_charges", "resume_breach_charges", "resume_hearts", "resume_seed"]:
		if typeof(data.get(field)) != TYPE_INT:
			return false
		if field != "resume_seed" and int(data[field]) < 0:
			return false
	if data.furthest_floor < 1 or data.resume_floor < 1 or typeof(data.get("has_resume")) != TYPE_BOOL:
		return false
	if not data.get("floor_stars") is Dictionary or not data.get("resume_powers") is Dictionary or not data.get("resume_history") is Array:
		return false
	if not data.get("resume_facing") is Vector2i or data.resume_facing not in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		return false
	for n in data.resume_history:
		if typeof(n) != TYPE_INT or n < 0 or n > 5:
			return false
	for key in data.floor_stars:
		if not key is String or not key.is_valid_int() or int(key) < 1 or typeof(data.floor_stars[key]) != TYPE_INT or data.floor_stars[key] < 0 or data.floor_stars[key] > 5:
			return false
	var powers: Dictionary = data.resume_powers
	for key in ["speed_turns", "speed_phase", "magnet_turns", "freeze_turns", "blink_charges"]:
		if typeof(powers.get(key)) != TYPE_INT or powers[key] < 0:
			return false
	if powers.speed_phase > 1 or (powers.speed_turns == 0 and powers.speed_phase != 0):
		return false
	var skills = Skills.new()
	if not skills.load_state(data.get("skills")):
		return false
	return data.resume_hearts <= skills.effect("heart_capacity")


func save_slot(slot: int, data: Dictionary, legacy_sha256: String = "") -> Dictionary:
	if slot < 0 or slot > 2 or not valid_payload(data):
		return {"ok": false, "error": "DADOS DE CAMPANHA INVALIDOS"}
	var previous := read_slot(slot)
	if previous.status not in ["empty", "ok"]:
		return {"ok": false, "error": "CAMPANHA DANIFICADA OU DE VERSAO MAIS RECENTE; NAO FOI SUBSTITUIDA"}
	if previous.status == "ok" and previous.data == data and (legacy_sha256.is_empty() or previous.legacy_sha256 == legacy_sha256):
		return {"ok": true}
	var file := ConfigFile.new()
	file.set_value("campaign", "version", VERSION)
	file.set_value("campaign", "data", data)
	if not legacy_sha256.is_empty():
		file.set_value("campaign", "legacy_sha256", legacy_sha256)
	return _save_config(file, slot_path(slot), backup_path(slot), true)


func save_global(file: ConfigFile) -> Dictionary:
	# Global settings and legacy mirror only; no other campaign data is touched.
	return _save_config(file, profile_path, profile_path + ".bak", false)


func backup_legacy() -> Dictionary:
	if not FileAccess.file_exists(profile_path):
		return {"ok": true, "sha256": ""}
	var bytes := FileAccess.get_file_as_bytes(profile_path)
	if FileAccess.get_open_error() != OK or bytes.is_empty():
		return {"ok": false, "error": "NAO FOI POSSIVEL LER O PERFIL ANTIGO"}
	var sha := FileAccess.get_sha256(profile_path)
	var path := profile_path + ".legacy.bak"
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) != sha:
		path = profile_path + ".legacy-" + sha.substr(0, 12) + ".bak"
	if FileAccess.file_exists(path):
		return {"ok": FileAccess.get_sha256(path) == sha, "sha256": sha, "path": path}
	var result := _write_bytes_atomic(path, bytes)
	if not result.ok or FileAccess.get_sha256(path) != sha:
		return {"ok": false, "error": "BACKUP ANTIGO NAO FOI VALIDADO"}
	return {"ok": true, "sha256": sha, "path": path}


func archive_before_new(slot: int) -> Dictionary:
	if read_slot(slot).status != "ok":
		return {"ok": false, "error": "CAMPANHA ANTERIOR NAO E VALIDA"}
	var path := replaced_path(slot)
	if FileAccess.file_exists(path):
		var old := FileAccess.get_file_as_bytes(path)
		if FileAccess.get_open_error() != OK:
			return {"ok": false, "error": "FALHA AO LER BACKUP ANTERIOR"}
		var digest := FileAccess.get_sha256(path)
		var archive := path + "." + digest.substr(0, 12)
		if not FileAccess.file_exists(archive):
			var saved := _write_bytes_atomic(archive, old)
			if not saved.ok or FileAccess.get_sha256(archive) != digest:
				return {"ok": false, "error": "FALHA AO PRESERVAR BACKUP ANTERIOR"}
	var bytes := FileAccess.get_file_as_bytes(slot_path(slot))
	if FileAccess.get_open_error() != OK:
		return {"ok": false, "error": "FALHA AO LER A CAMPANHA ANTERIOR"}
	var result := _write_bytes_atomic(path, bytes)
	if not result.ok or read_replaced(slot).status != "ok":
		return {"ok": false, "error": "FALHA AO VALIDAR BACKUP ANTES DE SUBSTITUIR"}
	return {"ok": true}


func restore_slot(slot: int, kind: String = "checkpoint") -> Dictionary:
	var backup := read_replaced(slot) if kind == "replaced" else read_slot(slot, true)
	if backup.status != "ok":
		return {"ok": false, "error": "NAO EXISTE BACKUP VALIDO PARA ESTA CAMPANHA"}
	var path := slot_path(slot)
	if FileAccess.file_exists(path):
		# Preserve even the corrupt or newer file, before explicit restore.
		var old_bytes := FileAccess.get_file_as_bytes(path)
		if FileAccess.get_open_error() != OK:
			return {"ok": false, "error": "NAO FOI POSSIVEL PRESERVAR A CAMPANHA ATUAL"}
		var digest := FileAccess.get_sha256(path)
		var archive := path + ".before-restore-" + digest.substr(0, 12) + ".bak"
		if not FileAccess.file_exists(archive):
			var archive_result := _write_bytes_atomic(archive, old_bytes)
			if not archive_result.ok or FileAccess.get_sha256(archive) != digest:
				return {"ok": false, "error": "NAO FOI POSSIVEL ARQUIVAR A CAMPANHA ATUAL"}
	# Do not rotate the backup to the corrupt file. Stage and verify its exact bytes.
	var source := replaced_path(slot) if kind == "replaced" else backup_path(slot)
	var bytes := FileAccess.get_file_as_bytes(source)
	if FileAccess.get_open_error() != OK:
		return {"ok": false, "error": "NAO FOI POSSIVEL LER O BACKUP"}
	var result := _write_bytes_atomic(path, bytes)
	if not result.ok:
		return result
	if read_slot(slot).status != "ok":
		return {"ok": false, "error": "A RELEITURA DO BACKUP RESTAURADO FALHOU"}
	return {"ok": true}


func _save_config(file: ConfigFile, path: String, backup: String, validate_campaign: bool) -> Dictionary:
	var temp := path + ".tmp-" + str(Time.get_ticks_usec())
	var error := file.save(temp)
	if error != OK:
		return {"ok": false, "error": "FALHA AO PREPARAR O FICHEIRO (%d)" % error}
	var verified := ConfigFile.new()
	if verified.load(temp) != OK or (validate_campaign and (not verified.has_section_key("campaign", "data") or not valid_payload(verified.get_value("campaign", "data")))):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		return {"ok": false, "error": "FALHA AO VERIFICAR O FICHEIRO TEMPORARIO"}
	for section in file.get_sections():
		for key in file.get_section_keys(section):
			if not verified.has_section_key(section, key) or verified.get_value(section, key) != file.get_value(section, key):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
				return {"ok": false, "error": "FALHA AO COMPARAR O FICHEIRO TEMPORARIO"}
	var bytes := FileAccess.get_file_as_bytes(temp)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	if FileAccess.get_open_error() != OK or bytes.is_empty():
		return {"ok": false, "error": "FALHA AO LER O FICHEIRO TEMPORARIO"}
	if FileAccess.file_exists(path):
		var original := FileAccess.get_file_as_bytes(path)
		if FileAccess.get_open_error() != OK:
			return {"ok": false, "error": "FALHA AO LER O ULTIMO FICHEIRO"}
		var result := _write_bytes_atomic(backup, original)
		if not result.ok:
			return {"ok": false, "error": "FALHA AO CRIAR BACKUP; ORIGINAL INTACTO"}
	return _write_bytes_atomic(path, bytes)


func _write_bytes_atomic(path: String, bytes: PackedByteArray) -> Dictionary:
	var temp := path + ".tmp-" + str(Time.get_ticks_usec())
	var output := FileAccess.open(temp, FileAccess.WRITE)
	if output == null:
		return {"ok": false, "error": "FALHA AO CRIAR TEMPORARIO (%d)" % FileAccess.get_open_error()}
	output.store_buffer(bytes)
	output.flush()
	var error := output.get_error()
	output.close()
	if error != OK or FileAccess.get_file_as_bytes(temp) != bytes:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		return {"ok": false, "error": "FALHA AO VERIFICAR OS BYTES GUARDADOS"}
	# Godot rename replaces the target where supported; on failure leave the old
	# target and backup intact rather than deleting either to force replacement.
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path))
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		return {"ok": false, "error": "FALHA AO SUBSTITUIR FICHEIRO (%d)" % error}
	return {"ok": true}


func global_backup_available() -> bool:
	var backup := profile_path + ".bak"
	if not FileAccess.file_exists(backup):
		return false
	var file := ConfigFile.new()
	return file.load(backup) == OK and int(file.get_value("meta", "version", 0)) <= 2


func restore_global() -> Dictionary:
	if not global_backup_available():
		return {"ok": false, "error": "NAO EXISTE BACKUP GLOBAL VALIDO"}
	if FileAccess.file_exists(profile_path):
		var old_bytes := FileAccess.get_file_as_bytes(profile_path)
		if FileAccess.get_open_error() != OK:
			return {"ok": false, "error": "NAO FOI POSSIVEL PRESERVAR O PERFIL ATUAL"}
		var digest := FileAccess.get_sha256(profile_path)
		var archive := profile_path + ".before-restore-" + digest.substr(0, 12) + ".bak"
		if not FileAccess.file_exists(archive):
			var saved := _write_bytes_atomic(archive, old_bytes)
			if not saved.ok or FileAccess.get_sha256(archive) != digest:
				return {"ok": false, "error": "NAO FOI POSSIVEL ARQUIVAR O PERFIL ATUAL"}
	var bytes := FileAccess.get_file_as_bytes(profile_path + ".bak")
	if FileAccess.get_open_error() != OK:
		return {"ok": false, "error": "NAO FOI POSSIVEL LER O BACKUP GLOBAL"}
	return _write_bytes_atomic(profile_path, bytes)
