class_name DummyTextureC
var script_class = "tool"

class DummyTextureL1 extends Object:
    var _image: Image
    var _dummy2

    func _init(image).() -> void:
        self._image = image
        self._dummy2 = DummyTextureL2.new(self._image)
        printraw("FOKLE: ")
        print(self._image)

    func GetHeight() -> int:
        return _image.get_height()
    
    func GetWidth() -> int:
        return _image.get_width()

    func get_data():
        print("GETDATA1 CALLED")
        return _dummy2

    func free() -> void:
        self._dummy2.free()
        .free()

class DummyTextureL2 extends Object:
    var _image: Image

    func _init(image).():
        self._image = image

    func GetData():
        return self._image.save_png_to_buffer()