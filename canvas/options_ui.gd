extends Control

@onready var music_bus_index = AudioServer.get_bus_index("Music")
@onready var music_slider_label:Label = $"MarginContainer/VBoxContainer/Sound options/VBoxContainer/Contents/VBoxContainer/HBmusic/ValueLabel"
@onready var sfx_bus_index = AudioServer.get_bus_index("SFX")
@onready var sfx_slider_label:Label = $"MarginContainer/VBoxContainer/Sound options/VBoxContainer/Contents/VBoxContainer/HBsfx/ValueLabel"


func _on_music_slider_value_changed(value: float )->void:
	#print("Raw Slider Value: ", value)
	music_slider_label.text = str(value)
	
	var db_value = linear_to_db(value/100.0)
	AudioServer.set_bus_volume_db(music_bus_index,db_value)
	AudioServer.set_bus_mute(music_bus_index,value<0.01) #mute
		
func _on_sfx_slider_value_changed(value: float)->void:
	sfx_slider_label.text = str(value)
	
	var db_value = linear_to_db(value/100.0)
	AudioServer.set_bus_volume_db(sfx_bus_index,db_value)
	AudioServer.set_bus_mute(sfx_bus_index,value <0.01)
