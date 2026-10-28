package components

import ui "ui:."

// The backend maps the mouse into the UI's logical coordinate space. Widgets
// reuse that mapping instead of re-deriving the scale.
@(private)
mouse_pos :: proc() -> ui.Vec2 {
	return ui.ctx.callbacks.get_mouse_pos()
}

@(private)
point_in_rect :: proc(pos, size, point: ui.Vec2) -> bool {
	return point.x >= pos.x &&
	       point.y >= pos.y &&
	       point.x <= pos.x + size.x &&
	       point.y <= pos.y + size.y
}

