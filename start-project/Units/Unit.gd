# Represents a unit on the game board.
# The board manages the Unit's position inside the game grid.
# The unit itself is only a visual representation that moves smoothly in the game world.
# We use the tool mode so the `skin` and `skin_offset` below update in the editor.
tool
class_name Unit
extends Path2D

# Emitted when the unit reached the end of a path along which it was walking.
# We'll use this to notify the game board that a unit reached its destination and we can let the
# player select another unit.
signal walk_finished


# Preload the `Grid.tres` resource you created in the previous part.
export var grid: Resource = preload("res://Grid.tres")
# Distance to which the unit can walk in cells.
# We'll use this to limit the cells the unit can move to.
export var move_range := 6
# Texture representing the unit.
# With the `tool` mode, assigning a new texture to this property in the inspector will update the
# unit's sprite instantly. See `set_skin()` below.
export var skin: Texture setget set_skin
# Our unit's skin is just a sprite in this demo and depending on its size, we need to offset it so
# the sprite aligns with the shadow.
export var skin_offset := Vector2.ZERO setget set_skin_offset
# The unit's move speed in pixels, when it's moving along a path.
export var move_speed := 600.0

# Coordinates of the grid's cell the unit is on.
var cell := Vector2.ZERO setget set_cell
# Toggles the "selected" animation on the unit.
var is_selected := false setget set_is_selected

# Through its setter function, the `_is_walking` property toggles processing for this unit.
# See `_set_is_walking()` at the bottom of this code snippet.
var _is_walking := false setget _set_is_walking

onready var _sprite: Sprite = $PathFollow2D/Sprite
onready var _anim_player: AnimationPlayer = $AnimationPlayer
onready var _path_follow: PathFollow2D = $PathFollow2D


func _ready() -> void:
    # We'll use the `_process()` callback to move the unit along a path. Unless it has a path to
    # walk, we don't want it to update every frame. See `walk_along()` below.
    set_process(false)

    # The following lines initialize the `cell` property and snap the unit to the cell's center on the map.
    self.cell = grid.calculate_grid_coordinates(position)
    position = grid.calculate_map_position(cell)

    if not Engine.editor_hint:
        # We create the curve resource here because creating it in the editor prevents us from
        # moving the unit.
        curve = Curve2D.new()


# When active, moves the unit along its `curve` with the help of the PathFollow2D node.
func _process(delta: float) -> void:
    # Every frame, the `PathFollow2D.offset` property moves the sprites along the `curve`.
    # The great thing about this is it moves an exact number of pixels taking turns into account.
    _path_follow.offset += move_speed * delta

    # When we increase the `offset` above, the `unit_offset` also updates. It represents how far you
    # are along the `curve` in percent, where a value of `1.0` means you reached the end.
    # When that is the case, the unit is done moving.
    if _path_follow.unit_offset >= 1.0:
        # Setting `_is_walking` to `false` also turns off processing.
        self._is_walking = false
        # Below, we reset the offset to `0.0`, which snaps the sprites back to the Unit node's
        # position, we position the node to the center of the target grid cell, and we clear the
        # curve.
        # In the process loop, we only moved the sprite, and not the unit itself. The following
        # lines move the unit in a way that's transparent to the player.
        _path_follow.offset = 0.0
        position = grid.calculate_map_position(cell)
        curve.clear_points()
        # Finally, we emit a signal. We'll use this one with the game board.
        emit_signal("walk_finished")


# When changing the `cell`'s value, we don't want to allow coordinates outside the grid, so we clamp
# them.
func set_cell(value: Vector2) -> void:
    cell = grid.clamp(value)


# The `is_selected` property toggles playback of the "selected" animation.
func set_is_selected(value: bool) -> void:
    is_selected = value
    if is_selected:
        _anim_player.play("selected")
    else:
        _anim_player.play("idle")


# Both setters below manipulate the unit's Sprite node.
# Here, we update the sprite's texture.
func set_skin(value: Texture) -> void:
    skin = value
    # Setter functions are called during the node's `_init()` callback, before they entered the
    # tree. At that point in time, the `_sprite` variable is `null`. If so, we have to wait to
    # update the sprite's properties.
    if not _sprite:
        # The yield keyword allows us to wait until the unit node's `_ready()` callback ended.
        yield(self, "ready")
    _sprite.texture = value


func set_skin_offset(value: Vector2) -> void:
    skin_offset = value
    if not _sprite:
        yield(self, "ready")
    _sprite.position = value


func _set_is_walking(value: bool) -> void:
    _is_walking = value
    set_process(_is_walking)


# Starts walking along the `path`.
# `path` is an array of grid coordinates that the function converts to map coordinates.
func walk_along(path: PoolVector2Array) -> void:
    if path.empty():
        return

    # This code converts the `path` to points on the `curve`. That property comes from the `Path2D`
    # class the Unit extends.
    curve.add_point(Vector2.ZERO)
    for point in path:
        curve.add_point(grid.calculate_map_position(point) - position)
    # We instantly change the unit's cell to the target position. You could also do that when it
    # reaches the end of the path, using `grid.calculate_grid_coordinates()`, instead.
    # I did it here because we have the coordinates provided by the `path` argument.
    # The cell itself represents the grid coordinates the unit will stand on.
    cell = path[-1]
    # The `_is_walking` property triggers the move animation and turns on `_process()`. See
    # `_set_is_walking()` below.
    self._is_walking = true