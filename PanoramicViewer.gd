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
onready var camera = $Camera
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

func showUsage():
	print(
	"Usage:\n" +
	"\tlibreexplorer {path_to_filename.jpg}\n"
	)
	get_tree().quit()

# Called when the node enters the scene tree for the first time.
func _ready():
	var cla = OS.get_cmdline_args()
	if len(cla) == 1:
		var filename = cla[0].to_lower()
		if filename.ends_with(".jpg") || filename.ends_with(".jpeg"):
			showPanoramicImage(cla[0])
		else:
			showUsage()
	else:
		showUsage()
			
	setZoom(70.0)
	get_tree().get_root().connect("size_changed", self, "on_resize")

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


