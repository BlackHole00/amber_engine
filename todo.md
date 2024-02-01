# RoadMap
-[ ] Implement the scheduler:
	-[ ] Finish writing the ae_common standardization
	-[ ] Implement into the engine
-[ ] Modify mod removal system:
	-[ ] allow only mod disabling (not removal, too much to check if has dependences)
	-[ ] think about mod replacing (maybe not)
-[ ] Rewrite the engine:Mod_Manager code:
	-[ ] Less ugly
	-[ ] Check for dependencies
	-[ ] Parallel
-[ ] Make engine:Library_Mod_Loader parallel
-[ ] Implement a caching system in engine
	-[ ] ae_common standard
	-[ ] implementation
-[ ] Implement the folder/ae_mod/zip mod loader
-[ ] Implement a global variables system in engine (something like the Windows registry)
	-[ ] ae_common standard (might remap to json)
	-[ ] implementation
	-[ ] Config stuff migration
-[ ] Implement a windowing manager in a mod (capable of multiple windows)
	-[ ] ae_common standard
	-[ ] implementation
-[ ] Implement webgpu as a mod
	-[ ] windowing mod interfacing
	-[ ] Allow headless usage
-[ ] Implement a renderer (deferred?)
	-[ ] renderer stuff
	-[ ] immediate rendering
		-[ ] implement vendor:microui (or maybe a custom ui)
-[ ] Implement an entity system in a mod

# Engine usages
-[ ] Implement a modelling/texturing tool (as an engine mod, does not need to be used with other tools)
-[ ] Implement a mapping tool (as an engine mod, should work with the same mod set of a game)
	- Basically it should work by having the game files and dropping the tool.so file in the mods
-[ ] Implement a game