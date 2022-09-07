# PanoramicViewer - hyperlinked panorama viewer written in Godot GDScript
# 
# Copyright (c) 2022 Edward Flick
#
# This program is part of Libre Explorer.
#
# Libre Explorer is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# Libre Explorer is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Libre Explorer. If not, see <https://www.gnu.org/licenses/>. 

extends Spatial

# Declare member variables here. Examples:
onready var bgSky = $WorldEnvironment.environment.background_sky

var camera

var isVR

var tiltPerSecond = 0.0
var panPerSecond = 0.0


var resetDecayTime = 1.0
var decayTime = resetDecayTime
var horizontalFOV
var vDegreesPerPixel
var hDegreesPerPixel

var camPan = 0.0
var camTilt = 0.0
var curZoom = 70.0

var comfortablePanPerSecond = 7.0

var lastMousePos = null
var mousePos = null
var mousePressed = false

var folderBase = ''
var selectedImage = 0

var images = []

func showUsage():
	print(
	"Usage:\n" +
	"\t libreexplorer {\n" +
	"\t\t path_to_libreexplorer.json |\n" +
	"\t\t path_to_folder_containing_libreexplorer.json |\n" +
	"\t\t path_to_filename.jpg |\n" +
	"\t\t path_to_folder_containing_jpgs |\n" +
	"\t }\n"
	)
	get_tree().quit()

# Called when the node enters the scene tree for the first time.
func _ready():
	var cla = OS.get_cmdline_args()
	# TODO: Add VR condition camera selection
	# 2D display
	camera = $Cameras/Camera
	isVR = false
	
	# Enable selected camera
	camera.current = true
	
	if len(cla) != 1:
		showUsage()
	
	var inPath = cla[0]
	if OS.get_name() in ["Windows", "WinRT"]:
		# Maybe this will work for Windows paths
		var t = ""
		for i in inPath.split("\\"):
			t += "/" + i.replace("/", "\\/")
		inPath = t

	var dir = Directory.new()
	var file = File.new()
	if dir.dir_exists(inPath):
		if dir.open(inPath) == OK:
			folderBase = inPath
			if !folderBase.ends_with('/'):
				folderBase += '/'
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if !dir.current_is_dir():
					tryLoadFile(folderBase + file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
		else:
			print("An error occurred when trying to access the path.\n\n")
			showUsage()
	elif file.file_exists(inPath):
		if !tryLoadFile(inPath):
			showUsage()
	else:
		showUsage()
	
	showPanoramicImage(images[selectedImage])
	
	setZoom(70.0)
	get_tree().get_root().connect("size_changed", self, "on_resize")

func selectImage(afile):
	jumpToImage(images.find(afile))

func jumpToImage(idx):
	selectedImage = max(min(idx, len(images)-1), 0)
	showPanoramicImage(images[selectedImage])

func tryLoadFile(afile):
	var lowerFilename = afile.to_lower()
	if lowerFilename.ends_with(".jpg") || lowerFilename.ends_with(".jpeg"):
		images.append(afile)
		return true
	else:
		return false

func on_resize():
	setZoom(curZoom)

func setZoom(fov):
	fov = max(0, min(90, fov))
	curZoom = fov
	camera.fov = fov
	var vpSize = get_viewport().size
	horizontalFOV = rad2deg(atan(tan(deg2rad(fov))*vpSize[0]/vpSize[1]))
	vDegreesPerPixel = 1.0 * fov/vpSize[1]
	hDegreesPerPixel = 1.0 * horizontalFOV/vpSize[0]
	print("%.2f %.2f" % [hDegreesPerPixel, vDegreesPerPixel])
	

func showPanoramicImage(imageFile):
	var it = ImageTexture.new()
	var i = Image.new()
	i.load(imageFile)
	it.create_from_image(i)
	bgSky.panorama = it

func panTiltCam(pan, tilt):
	camPan += pan
	camPan = fmod(camPan, 360.0)
	camTilt += tilt
	camTilt = min(max(camTilt, -90.0), 90.0)
	camera.transform.basis = Basis(Vector3(0, 1, 0), deg2rad(camPan))
	camera.rotate_object_local(Vector3(1,0,0), deg2rad(camTilt))	

func _input(ev):
	if ev is InputEventKey and !ev.pressed:
		if ev.scancode==KEY_LEFT:
			jumpToImage(selectedImage-1)
		elif ev.scancode==KEY_RIGHT:
			jumpToImage(selectedImage+1)
	
	if ev is InputEventMouseButton:
		if ev.button_index == BUTTON_LEFT:
			mousePressed = ev.pressed
		elif ev.button_index == BUTTON_WHEEL_DOWN:
			if ev.pressed:
				setZoom(curZoom + 1.0)
		elif ev.button_index == BUTTON_WHEEL_UP:
			if ev.pressed:
				setZoom(curZoom - 1.0)
	
	if ev is InputEventMouse:
		if mousePressed:
			mousePos = ev.global_position
			mousePos = Vector2(mousePos[0], mousePos[1])


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if mousePressed:
		if lastMousePos && mousePos:
			var dp = mousePos - lastMousePos
			panTiltCam(hDegreesPerPixel*dp[0], vDegreesPerPixel*dp[1])
			panPerSecond = hDegreesPerPixel*dp[0]/delta
			tiltPerSecond = vDegreesPerPixel*dp[1]/delta
			decayTime = resetDecayTime
		lastMousePos = mousePos
	else:
		lastMousePos = null
		mousePos = null
		decayTime = max(decayTime - delta, 0)
		var decayProgress = 1.0 * decayTime / resetDecayTime
		var thisPan = panPerSecond
		if abs(thisPan) > comfortablePanPerSecond / 10.0:
			if abs(thisPan) > comfortablePanPerSecond:
				thisPan = decayProgress * thisPan + (1.0 - decayProgress) * comfortablePanPerSecond * sign(thisPan)
		else:
			thisPan *= decayProgress
		panTiltCam(thisPan*delta, tiltPerSecond*delta*decayProgress)


