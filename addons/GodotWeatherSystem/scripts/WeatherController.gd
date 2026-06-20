@tool
extends Node
class_name WeatherController

enum SeasonType { SUMMER, WINTER }
enum WeatherType { FINE, CLOUDED, RAIN, HEAVY_RAIN, SNOW, HEAVY_SNOW }

@export_group("Simplified Configuration")
@export var time_progression_enabled: bool = false:
	set(val):
		time_progression_enabled = val
		if not time_progression_enabled:
			timeOfDay = time_of_day_hours * 3600.0
		_update_weather_system()

@export_range(0.0, 24.0) var time_of_day_hours: float = 15.0:
	set(val):
		time_of_day_hours = val
		startTime = val * 3600.0
		timeOfDay = startTime
		_update_weather_system()

@export var selected_season: SeasonType = SeasonType.SUMMER:
	set(val):
		selected_season = val
		_update_season_and_weather_from_enums()

@export var selected_weather: WeatherType = WeatherType.FINE:
	set(val):
		selected_weather = val
		_update_season_and_weather_from_enums()

@export_group("Advanced Addon Variables (Managed automatically)")
@export var worldEnvironment: WorldEnvironment:
	set(val):
		worldEnvironment = val
		_update_weather_system()
@export var directionalLight: DirectionalLight3D:
	set(val):
		directionalLight = val
		_update_weather_system()
@export var seasons: Array[SeasonResource]
@export var dayDuration: float = 86400.0
@export var timeSpeedMultiplier: float = 100.0
@export var startTime: float = 54000.0
@export var startSeason: int = 0
@export var startWeather: int = 0

signal on_season_change(season: SeasonResource)
signal on_weather_change(weather: WeatherResource)

var timeOfDay: float = 0.0
var currentSeasonIndex: int = 0
var currentWeatherIndex: int = 0
var nextWeatherIndex: int = 0
var currentWeatherLength: float = 0.0
var currentWeatherTime: float = 0.0
var currentSeasonLength: float = 0.0
var currentSeasonTime: float = 0.0
var particleSystem: GPUParticles3D

func _ready():
	if not worldEnvironment:
		if not Engine.is_editor_hint():
			push_error("WeatherController: worldEnvironment is not assigned!")
	if not directionalLight:
		if not Engine.is_editor_hint():
			push_error("WeatherController: directionalLight is not assigned!")
	
	_update_season_and_weather_from_enums()
	currentSeasonTime += startTime
	timeOfDay = startTime

func _update_season_and_weather_from_enums():
	var season_path = ""
	match selected_season:
		SeasonType.SUMMER:
			season_path = "res://addons/GodotWeatherSystem/seasons/summer.tres"
		SeasonType.WINTER:
			season_path = "res://addons/GodotWeatherSystem/seasons/winter.tres"
	
	var season_res = load(season_path)
	if season_res:
		season_res = season_res.duplicate()
		seasons = [season_res] as Array[SeasonResource]
		
	var weather_path = ""
	match selected_weather:
		WeatherType.FINE:
			weather_path = "res://addons/GodotWeatherSystem/weather/fine.tres"
		WeatherType.CLOUDED:
			weather_path = "res://addons/GodotWeatherSystem/weather/clouded.tres"
		WeatherType.RAIN:
			weather_path = "res://addons/GodotWeatherSystem/weather/rain.tres"
		WeatherType.HEAVY_RAIN:
			weather_path = "res://addons/GodotWeatherSystem/weather/heavy_rain.tres"
		WeatherType.SNOW:
			weather_path = "res://addons/GodotWeatherSystem/weather/snow.tres"
		WeatherType.HEAVY_SNOW:
			weather_path = "res://addons/GodotWeatherSystem/weather/heavy_snow.tres"
			
	var weather_res = load(weather_path)
	if weather_res and seasons.size() > 0:
		var occ = WeatherOccurrenceResource.new()
		occ.weather = weather_res
		occ.probabilityRatio = 1.0
		seasons[0].weathers = [occ] as Array[WeatherOccurrenceResource]
		
		# Reset weather status
		set_season(0, 0)
	
	_update_weather_system()

func set_season(season_index: int, weather_index: int = -1):
	if seasons.size() == 0:
		return
	currentSeasonIndex = season_index
	currentSeasonLength = seasons[season_index].durationInDays * dayDuration
	currentSeasonTime = 0.0

	if weather_index != -1:
		set_weather(weather_index)
	else:
		set_random_weather()

	on_season_change.emit(seasons[currentSeasonIndex])

func set_random_weather():
	var season = seasons[currentSeasonIndex]
	var total = 0.0
	for occurrence in season.weathers:
		total += occurrence.probabilityRatio
	
	var rand = randf() * total
	var current_total = 0.0
	var weather_index = 0
	for occurrence in season.weathers:
		current_total += occurrence.probabilityRatio
		if rand <= current_total:
			break
		weather_index += 1
	
	set_weather(weather_index)

func set_weather(weather_index: int):
	if seasons.size() == 0:
		return
	var season = seasons[currentSeasonIndex]
	if season.weathers.size() == 0:
		return

	currentWeatherIndex = weather_index
	nextWeatherIndex = randi() % season.weathers.size()
	var weather = season.weathers[currentWeatherIndex].weather
	currentWeatherLength = lerp(weather.minDuration, weather.maxDuration, randf())
	currentWeatherTime = 0.0

	if particleSystem:
		particleSystem.queue_free()
		particleSystem = null
	
	if weather.precipitation and weather.precipitation.particles:
		particleSystem = weather.precipitation.particles.instantiate()
		add_child(particleSystem)

func _process(delta):
	if not worldEnvironment or seasons.size() == 0:
		return

	if not Engine.is_editor_hint() and time_progression_enabled:
		timeOfDay = fmod(timeOfDay + delta * timeSpeedMultiplier, dayDuration)
		currentWeatherTime += delta * timeSpeedMultiplier
		currentSeasonTime += delta * timeSpeedMultiplier

		if currentWeatherTime >= currentWeatherLength:
			set_weather(nextWeatherIndex)
		
		var season = seasons[currentSeasonIndex]
		var next_season_index = (currentSeasonIndex + 1) % seasons.size()
		var next_season = seasons[next_season_index]
		
		if currentSeasonTime >= currentSeasonLength:
			set_season(next_season_index)
	else:
		timeOfDay = time_of_day_hours * 3600.0

	_update_weather_system()

func _update_weather_system():
	if not worldEnvironment or seasons.size() == 0:
		return
		
	var t_time = timeOfDay / dayDuration

	var season = seasons[currentSeasonIndex]
	var day_night_factor = 1.0 - season.dayNightCycleCurve.sample(t_time)
	
	var sky_day = season.skyColourDaytime
	var sky_night = season.skyColourNight
	
	var current_sky_colour = sky_day.skyColour.lerp(sky_night.skyColour, day_night_factor)
	var current_horizon_colour = sky_day.horizonColour.lerp(sky_night.horizonColour, day_night_factor)
	var current_ground_colour = sky_day.groundColour.lerp(sky_night.groundColour, day_night_factor)
	var current_cloud_brightness = lerp(sky_day.cloudBrightness, sky_night.cloudBrightness, day_night_factor)

	if season.weathers.size() == 0:
		return
	var weather = season.weathers[currentWeatherIndex].weather
	
	var current_fog_density = weather.fogDensity
	var current_cloud_speed = weather.cloudSpeed
	var current_small_cloud = weather.smallCloudCover
	var current_large_cloud = weather.largeCloudCover
	var current_cloud_inner = weather.cloudInnerColour * current_cloud_brightness
	var current_cloud_outer = weather.cloudOuterColour * current_cloud_brightness

	# Update Environment
	var sky_mat = worldEnvironment.environment.sky.sky_material as ShaderMaterial
	if sky_mat:
		sky_mat.set_shader_parameter("small_cloud_cover", current_small_cloud)
		sky_mat.set_shader_parameter("large_cloud_cover", current_large_cloud)
		sky_mat.set_shader_parameter("cloud_speed", current_cloud_speed)
		sky_mat.set_shader_parameter("cloud_shape_change_speed", current_cloud_speed)
		sky_mat.set_shader_parameter("cloud_inner_colour", current_cloud_inner)
		sky_mat.set_shader_parameter("cloud_outer_colour", current_cloud_outer)
		sky_mat.set_shader_parameter("sky_top_color", current_sky_colour)
		sky_mat.set_shader_parameter("sky_horizon_color", current_horizon_colour)
		sky_mat.set_shader_parameter("ground_horizon_color", current_horizon_colour)
		sky_mat.set_shader_parameter("ground_bottom_color", current_ground_colour)

	worldEnvironment.environment.volumetric_fog_enabled = false
	worldEnvironment.environment.volumetric_fog_density = current_fog_density * 0.5

	if particleSystem and is_inside_tree():
		var amount_ratio = weather.precipitation.amountRatio if weather.precipitation else 0.0
		particleSystem.amount_ratio = amount_ratio
		var vp = get_viewport()
		if vp:
			var cam = vp.get_camera_3d()
			if cam:
				particleSystem.global_position = cam.global_position + Vector3.UP * 10.0


	if directionalLight:
		var sun_angle = (timeOfDay / dayDuration) * PI * 2.0 + PI * 0.5
		directionalLight.global_rotation.x = sun_angle
		directionalLight.light_energy = 1.0 - day_night_factor
	
	worldEnvironment.environment.ambient_light_sky_contribution = 1.0 - day_night_factor
