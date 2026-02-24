extends Node

const SAVE_PATH = "user://settings.cfg"

# Effect toggles
var crt_enabled: bool = true
var glitch_enabled: bool = true
var glitch_intensity: float = 1.0   # 0.25 = subtle, 0.5 = mild, 1.0 = full, 1.5 = extra
var screen_shake_enabled: bool = true
var screen_shake_intensity: float = 1.0

func _ready():
    load_settings()

func save_settings():
    var cfg = ConfigFile.new()
    cfg.set_value("effects", "crt_enabled", crt_enabled)
    cfg.set_value("effects", "glitch_enabled", glitch_enabled)
    cfg.set_value("effects", "glitch_intensity", glitch_intensity)
    cfg.set_value("effects", "screen_shake_enabled", screen_shake_enabled)
    cfg.set_value("effects", "screen_shake_intensity", screen_shake_intensity)
    cfg.save(SAVE_PATH)

func load_settings():
    var cfg = ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return  # No save file yet, use defaults
    crt_enabled = cfg.get_value("effects", "crt_enabled", true)
    glitch_enabled = cfg.get_value("effects", "glitch_enabled", true)
    glitch_intensity = cfg.get_value("effects", "glitch_intensity", 1.0)
    screen_shake_enabled = cfg.get_value("effects", "screen_shake_enabled", true)
    screen_shake_intensity = cfg.get_value("effects", "screen_shake_intensity", 1.0)