---
description: Cubzh
keywords: cubzh, game, mobile, scripting, cube, voxel, world
---

# .cubzh file structure (V5)

### Header

|Bytes|Type|Value|
|-----|----|-----|
|1x6|char|"CUBZH!"|
|4|uint32|version number: 5|
|1|uint8|compression algo|
|4|uint32|compressed size|
|4|uint32|uncompressed size|

### Chunks

|Bytes|Type|Value|
|-----|----|-----|
|1|uint8|chunk identifier|
|4|uint32|chunk size|
|chunk size|DATA|chunk's content|

A chunk can contain anything, including child chunks.

#### Chunk identifiers:

- Preview image

	|Bytes|Type|Value|
	|-----|----|-----|
	|1|uint8|chunk identifier: 1|
	|4|uint32|chunk size: image data size |
	|1|data size|image data|
	
- Palette

	|Bytes|Type|Value|
	|-----|----|-----|
	|1|uint8|chunk identifier: 2|
	|4|uint32|chunk size: 7 + 4 x color count |
	|1|uint8|palette format: 1 (rgba, 4 x uint8 per color)|
	|1|uint8|rows|
	|1|uint8|columns|
	|2|uint16|color count|
	|4 x color count|DATA|colors|
	|1|uint8_t|default color|
	|1|uint8_t|default background color|
	
- Selected color

	|Bytes|Type|Value|
	|-----|----|-----|
	|1|uint8|chunk identifier: 3|
	|4|uint32|chunk size: 1|
	|1|uint8|selected color index|
	
- Selected background color

	|Bytes|Type|Value|
	|-----|----|-----|
	|1|uint8|chunk identifier: 4|
	|4|uint32|chunk size: 1|
	|1|uint8|selected background color index|
	
- Shape

	|Bytes|Type|Value|
	|-----|----|-----|
	|1|uint8|chunk identifier: 5|
	|4|uint32|chunk size: child chunks total size|
	
	- Shape Size

		|Bytes|Type|Value|
		|-----|----|-----|
		|1|uint8|chunk identifier: 6|
		|4|uint32|chunk size: 6 (3 x 2 (uint16))|
		|2|uint16|width|
		|2|uint16|height|
		|2|uint16|depth|
	
	- Shape Blocks

		|Bytes|Type|Value|
		|-----|----|-----|
		|1|uint8|chunk identifier: 7|
		|4|uint32|chunk size: max number of blocks in boundaries x 1 (uint8)|
		|1 x nb blocks|uint8|nb blocks is shape's width x height x depth (includes empty blocks)|
		
	- Shape Name (optional)
		
		The name of the shape.
		
		|Bytes|Type|Value|
		|-----|----|-----|
		|1|uint8|chunk identifier: 12|
		|4|uint32|chunk size: 1 + name len|
		|1|uint8|name len (max: 255)|
		|name len|chars|name|
	
	- Shape Palette (optional)
		
		Custom palette for current shape. Idea for later, not supported in V5.

	- Shape Point (optional)

		Point of interest within shape. Can be used to connect shapes together.
		
		|Bytes|Type|Value|
		|-----|----|-----|
		|1|uint8|chunk identifier: 8|
		|4|uint32|chunk size: 1 + name len + 4 x 3|
		|1|uint8|name len (max: 255)|
		|name len|chars|name|
		|4|float|x|
		|4|float|y|
		|4|float|z|
		
- Camera
	
	Camera position, target & orientation
	
	|Bytes|Type|Value|
	|-----|----|-----|
	|1|uint8|chunk identifier: 9|
	|4|uint32|chunk size: 28|
	|4|float|target x|
	|4|float|target y|
	|4|float|target z|
	|4|float|distance from target|
	|4|float|yaw (right/left)|
	|4|float|pitch (up/down)|
	|4|float|roll|
	
- Rendering options

	General rendering options
	
	|Bytes|Type|Value|
	|-----|----|-----|
	|1|uint8|chunk identifier: 10|
	|4|uint32|chunk size: 3|
	|1|uint8|global illumination enabled (1 or 0)|
	|1|uint8|directional light enabled (1 or 0)|
	|1|uint8|ambient occlusion (1 or 0)|

- Directional light

	Directional light information.
	
	|Bytes|Type|Value|
	|-----|----|-----|
	|1|uint8|chunk identifier: 10|
	|4|uint32|chunk size: 9|
	|1|uint8|locked (1 or 0)|
	|4|float|yaw (right/left)|
	|4|float|pitch (up/down)|
	
- Source metadata

	Can be used to represent raw source metadata. Data that's not being considered by Cubzh when importing from a different file format (like Magicavoxel .vox). We want to keep this to be able to rewrite it if the file gets exported back to its original format. 
	
	Note: one metadata chunk can contain metadata from different sources.
	
	|Bytes|Type|Value|
	|-----|----|-----|
	|1|uint8|chunk identifier: 11|
	|4|uint32|chunk size|
	|chunk size|DATA|chunk's content|
	
	