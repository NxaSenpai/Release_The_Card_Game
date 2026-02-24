extends Node

const SAVE_PATH = "user://settings.cfg"

# Effect toggles
var crt_enabled: bool = true
var glitch_enabled: bool = true
var glitch_intensity: float = 1.0
var screen_shake_enabled: bool = true
var screen_shake_intensity: float = 1.0

# Audio
var music_volume: float = 1.0

# Display
var display_mode: int = 0  # 0 = Windowed, 1 = Fullscreen, 2 = Exclusive Fullscreen
var resolution_index: int = 2  # Default: 1366x768

const RESOLUTIONS: Array[Vector2i] = [
    Vector2i(1152, 648),
    Vector2i(1280, 720),
    Vector2i(1366, 768),
    Vector2i(1600, 900),
    Vector2i(1920, 1080),
    Vector2i(2560, 1440),
    Vector2i(3840, 2160),
]

func _ready():
    load_settings()
    apply_display_settings()

func apply_display_settings():
    match display_mode:
        0:  # Windowed
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
            var res: Vector2i = RESOLUTIONS[clamp(resolution_index, 0, RESOLUTIONS.size() - 1)]
            DisplayServer.window_set_size(res)
            # Center the window on screen
            var screen_size: Vector2i = DisplayServer.screen_get_size()
            var center: Vector2i = (screen_size - res) / 2
            DisplayServer.window_set_position(center)
        1:  # Fullscreen (borderless)
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        2:  # Exclusive Fullscreen
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

    # Update viewport size to match so stretch mode works correctly
    get_tree().root.content_scale_size = Vector2i(1152, 648)

func save_settings():
    var cfg = ConfigFile.new()
    cfg.set_value("effects", "crt_enabled", crt_enabled)
    cfg.set_value("effects", "glitch_enabled", glitch_enabled)
    cfg.set_value("effects", "glitch_intensity", glitch_intensity)
    cfg.set_value("effects", "screen_shake_enabled", screen_shake_enabled)
    cfg.set_value("effects", "screen_shake_intensity", screen_shake_intensity)
    cfg.set_value("audio", "music_volume", music_volume)
    cfg.set_value("display", "display_mode", display_mode)
    cfg.set_value("display", "resolution_index", resolution_index)
    cfg.save(SAVE_PATH)

func load_settings():
    var cfg = ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    crt_enabled = cfg.get_value("effects", "crt_enabled", true)
    glitch_enabled = cfg.get_value("effects", "glitch_enabled", true)
    glitch_intensity = cfg.get_value("effects", "glitch_intensity", 1.0)
    screen_shake_enabled = cfg.get_value("effects", "screen_shake_enabled", true)
    screen_shake_intensity = cfg.get_value("effects", "screen_shake_intensity", 1.0)
    music_volume = cfg.get_value("audio", "music_volume", 1.0)
    display_mode = cfg.get_value("display", "display_mode", 0)
    resolution_index = cfg.get_value("display", "resolution_index", 2)