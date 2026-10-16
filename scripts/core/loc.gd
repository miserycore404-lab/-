extends Node
## Localization. UI strings are registered with TranslationServer so every
## Control and Label3D translates itself (and re-translates live when the
## language changes). Story text is authored inline as {ru, en} pairs and
## resolved through `pick()`.

signal language_changed(lang: String)

const Strings := preload("res://scripts/data/strings.gd")

const LANGUAGES := ["ru", "en"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for lang in LANGUAGES:
		var t := Translation.new()
		t.locale = lang
		var table: Dictionary = Strings.RU if lang == "ru" else Strings.EN
		for key in table:
			t.add_message(key, table[key])
		TranslationServer.add_translation(t)
	TranslationServer.set_locale(lang())
	Settings.changed.connect(_on_setting)


func _on_setting(key: String) -> void:
	if key == "language":
		TranslationServer.set_locale(lang())
		language_changed.emit(lang())


func lang() -> String:
	return Settings.get_value("language", "en")


func is_ru() -> bool:
	return lang() == "ru"


## Resolve a {ru: "...", en: "..."} dictionary (or plain string / key).
func pick(v: Variant) -> String:
	if v is Dictionary:
		return v.get(lang(), v.get("en", ""))
	if v is Array:
		if v.is_empty():
			return ""
		return v[0] if is_ru() or v.size() < 2 else v[1]
	if v is String:
		return TranslationServer.translate(v)
	return str(v)


func t(key: String) -> String:
	return TranslationServer.translate(key)
