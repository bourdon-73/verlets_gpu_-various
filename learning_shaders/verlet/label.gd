extends Label

# Configuration
@export var update_interval: float = 0.5  # How often to update the display (in seconds)
@export var smooth_factor: float = 0.1    # Smoothing factor (0-1); lower = smoother
@export var show_min_max: bool = true     # Whether to show min/max FPS values
@export var display_precision: int = 1    # Decimal places for FPS display
@export var warning_threshold: int = 30   # FPS below this will be shown in yellow
@export var critical_threshold: int = 20  # FPS below this will be shown in red
@export var auto_hide: bool = false       # Automatically hide when FPS is stable
@export var auto_hide_delay: float = 3.0  # Seconds before hiding when stable


@export var residence : Node2D 
# Variables
var _fps_sum: float = 0
var _fps_count: int = 0
var _update_timer: float = 0
var _current_fps: float = 0
var _min_fps: float = INF
var _max_fps: float = 0
var _last_change_time: float = 0
var _hide_timer: float = 0
var _previous_fps: float = 0
var _is_stable: bool = false

func _ready() -> void:
	# Set initial appearance
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text = "FPS: ..."
	
	# Optional: Make the label semi-transparent
	modulate.a = 0.8
#
#func _process(delta: float) -> void:
#
	## Calculate instantaneous FPS
	#var instant_fps :float = 1.0 / delta if delta > 0 else 0
	#
	## Add to accumulators
	#_fps_sum += instant_fps
	#_fps_count += 1
	#
	## Update min/max values
	#_min_fps = min(_min_fps, instant_fps)
	#_max_fps = max(_max_fps, instant_fps)
	#
	## Update timer
	#_update_timer += delta
	#
	## Check if it's time to update the display
	#if _update_timer >= update_interval:
		## Calculate average FPS over the interval
		#var avg_fps :float= _fps_sum / _fps_count if _fps_count > 0 else 0
		#
		## Apply smoothing if we have a previous value
		#if _current_fps > 0:
			#_current_fps = lerp(_current_fps, avg_fps, smooth_factor)
		#else:
			#_current_fps = avg_fps
		#
		## Format the displayed text
		#var display_text :String = "FPS: %.*f" % [display_precision, _current_fps] #+ "\n yes"
		#
		## Add min/max if enabled
		#if show_min_max:
			#display_text += " (Min: %.*f | Max: %.*f)" % [
				#display_precision, _min_fps,
				#display_precision, _max_fps
			#]
		#
		## Set text color based on performance
		#if _current_fps <= critical_threshold:
			#add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Red
		#elif _current_fps <= warning_threshold:
			#add_theme_color_override("font_color", Color(1, 0.9, 0.2))  # Yellow
		#else:
			#add_theme_color_override("font_color", Color(0.7, 1, 0.7))  # Light green
		#
		## Update the label
		##if residence:
		##text = display_text + " spawned : "+ str(residence.spawned)
		##text = str(_current_fps) + " spawned : "+ str(residence.spawned)
		#text = str(Engine.get_frames_per_second()) #+ " spawned : "+ str(residence.spawned)
		##if residence:
			##text = display_text
#
		## Check for stability (for auto-hide feature)
		#var fps_change :float= abs(_current_fps - _previous_fps)
		#if fps_change > 3.0:  # Threshold for "significant" change
			#_last_change_time = 0
			#_is_stable = false
			#visible = true
		#else:
			#_last_change_time += _update_timer
			#
			#if _last_change_time >= auto_hide_delay:
				#_is_stable = true
			#
		#_previous_fps = _current_fps
		#
		## Reset accumulators
		#_fps_sum = 0
		#_fps_count = 0
		#_update_timer = 0
	#
	## Handle auto-hide
	#if auto_hide and _is_stable:
		#_hide_timer += delta
		#if _hide_timer >= auto_hide_delay:
			#modulate.a = max(0.1, modulate.a - (delta * 0.5))  # Fade out
			#if modulate.a <= 0.1:
				#visible = false
	#else:
		#_hide_timer = 0
		#modulate.a = min(0.8, modulate.a + (delta * 2.0))  # Fade in
		#
	## Reset min/max every few seconds to ensure they reflect recent performance
	#if Engine.get_frames_drawn() % 300 == 0:  # Reset roughly every 5 seconds at 60 FPS
		#_min_fps = INF
		#_max_fps = 0

	#text =  " fps : " + str(Engine.get_frames_per_second()) + " count : " + str(residence.spawned)
# Option to toggle visibility with a keypress
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Change to your preferred key
		visible = !visible
		_is_stable = false
		modulate.a = 0.8
