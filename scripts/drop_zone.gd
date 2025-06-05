extends Area2D

# In DropZone.gd (attached to the drop zone Area2D node)
func _on_DropZone_body_exited(body):
	if body.is_in_group("Fruit") and body.has_method("set_drag_allowed"):
		body.set_drag_allowed(false)
