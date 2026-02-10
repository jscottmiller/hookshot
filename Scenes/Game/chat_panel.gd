class_name ChatPanel extends Control

signal chat_message
signal chat_focus_changed

@onready var message_history := %MessageHistory as VBoxContainer
@onready var message_input := %MessageInput as TextEdit

var initial_size: int
var enabled := false


func _ready() -> void:
	initial_size = message_history.size.y


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	
	if message_input.has_focus():
		if Input.is_action_just_pressed("send_message", true):
			get_viewport().set_input_as_handled()
			var message := message_input.text.strip_edges()
			if message:
				emit_signal("chat_message", message)
			emit_signal("chat_focus_changed", false)
			message_input.release_focus()
			message_input.text = ""
			message_input.hide()
	elif Input.is_action_just_pressed("send_message", true):
		message_input.show()
		emit_signal("chat_focus_changed", true)
		message_input.grab_focus()


func enable() -> void:
	enabled = true


func disable() -> void:
	enabled = false


func add_message(message: String) -> void:
	var label := Label.new()
	label.text = message
	
	message_history.add_child(label)
	
	await get_tree().process_frame
	while message_history.size.y > initial_size:
		message_history.remove_child(message_history.get_child(0))
		await get_tree().process_frame
