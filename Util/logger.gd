class_name Logger extends Node

@export var label: String

enum LogLevel {
	TRACE,
	WARN,
	ERROR,
	ANNOUNCE,
	SILENT
}


func log(level: LogLevel, message: String, params: Array = []) -> void:
	if level < Globals.minimum_log_level or level == LogLevel.SILENT:
		return
	
	var level_string := "silent"
	match level:
		LogLevel.TRACE:
			level_string = "trace"
		LogLevel.WARN:
			level_string = "warn"
		LogLevel.ERROR:
			level_string = "error"
		LogLevel.ANNOUNCE:
			level_string = "announce"
		
	
	var prefix := "[{0}] - {1}({2}) - {3}".format([
		"%0.3f" % Time.get_unix_time_from_system(),
		label,
		multiplayer.get_unique_id(),
		level_string,
	])
	
	var formatted_message = message.format(params)
	
	var line := "{0}: {1}".format([prefix, formatted_message])
	
	printerr(line)


func trace(message: String, params: Array = []) -> void:
	self.log(LogLevel.TRACE, message, params)


func warn(message: String, params: Array = []) -> void:
	self.log(LogLevel.WARN, message, params)


func error(message: String, params: Array = []) -> void:
	self.log(LogLevel.ERROR, message, params)


func announce(message: String, params: Array = []) -> void:
	self.log(LogLevel.ANNOUNCE, message, params)
