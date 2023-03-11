extends Container
class_name Platform
tool
enum PlatformFlavor {
	Sweet,
	Sour,
	Savory,
	Bitter,
	Salty,
	None
}
enum PlatformType {
	Normal,
	Flavor,
	Ice,
	Electricity	
}


export(PlatformType) var type:int = PlatformType.Normal setget set_type;

export(PlatformFlavor) var flavor setget set_flavor;

export(Array, NodePath) var sprite_paths:Array

var sprites:Array
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if (!Engine.editor_hint):
		for path in sprite_paths:
			sprites.append(get_node(path));
	update_visuals();
	resize_elements();

func resize_elements():
	($Collision/Shape.shape as RectangleShape2D).extents = rect_size/2 - Vector2.ONE * 200;
	$Collision.position = rect_size/2;

func set_flavor(_flavor):
	flavor = _flavor
	if (Engine.editor_hint):
		update_visuals();

func set_type(_type):
	type = _type;
	if (Engine.editor_hint):
		update_visuals();

func shuffle_platform():
	type = rand_range(0, PlatformType.size()-1);
	flavor = rand_range(0, PlatformFlavor.size()-1)
	update_visuals();

func update_visuals():
	print($Normal)
	if (Engine.editor_hint and sprites.size() == 0):
		for path in sprite_paths:
			sprites.append(get_node(path));
	
	for s in sprites:
		s.visible = false;
		
	match (type):
		PlatformType.Normal:
			$Normal.visible = true;
		PlatformType.Ice:
			$Ice.visible = true;
		PlatformType.Electricity:
			$Thunder.visible = true;
		PlatformType.Flavor:
			match (flavor):
				PlatformFlavor.Sweet:
					$Sweet.visible = true;
				PlatformFlavor.Salty:
					$Salty.visible = true;
				PlatformFlavor.Savory:
					$Umami.visible = true;
				PlatformFlavor.Sour:
					$Sour.visible = true;
				#TODO: Add bitter
			


func _on_Platform_focus_entered() -> void:
	resize_elements();


func _on_Platform_resized() -> void:
	resize_elements();
