class_name Scoreboard extends Control

@onready var grid := %GridContainer as GridContainer


func _ready() -> void:
	_clear_children()


func set_data(labels: Array, rows: Array) -> void:
	_clear_children()
	_set_headers(labels, rows)
	_fill_rows(rows)


func _clear_children() -> void:
	for child in grid.get_children():
		child.queue_free()


func _set_headers(labels: Array, rows: Array) -> void:
	if rows.size() == 0:
		return
	
	var first_row = rows[0]
	if first_row.size() != labels.size():
		return
	
	grid.columns = len(labels)
	for i in range(labels.size()):
		var label_text = labels[i]
		var value = first_row[i]
		
		var label := Label.new()
		label.text = label_text
		
		match typeof(value):
			TYPE_INT:
				continue
			TYPE_FLOAT:
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		grid.add_child(label)


func _fill_rows(rows: Array):
	for row in rows:
		if row.size() != grid.columns:
			continue
		for value in row:
			var label := Label.new()
			label.text = str(value)
			
			match typeof(value):
				TYPE_INT:
					continue
				TYPE_FLOAT:
					label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			
			grid.add_child(label)
