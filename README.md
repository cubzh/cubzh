<picture>
  <source media="(prefers-color-scheme: dark)" srcset="misc/logo_and_name_light.svg">
  <source media="(prefers-color-scheme: light)" srcset="misc/logo_and_name_dark.svg">
<p align="center">
  <img width=50% alt="" src="misc/logo_and_name_dark.svg">
</p>
</picture>

![CI](https://github.com/cubzh/cubzh/actions/workflows/ci.yml/badge.svg?branch=main)
[![Join the chat at https://cu.bzh/discord](https://img.shields.io/discord/355905150528913409?color=%237289DA&label=cubzh&logo=discord&logoColor=white)](https://cu.bzh/discord)

## What is Cubzh?

Cubzh is a **User Generated Social Universe**, an online platform where all items, avatars, games, and experiences are made by users from the community.

It's a limitless building environment inspired by Roblox, but designed to be as welcoming and accessible as Minecraft.

### Cubzh is for all kinds of creators:

- Hobbyists, Experts, Beginners...
- Developers, Artists, Avatar designers, Home builders, Decorators, etc.
- For those going solo as well as for those seeking collaboration.

### Why cubes?

- We see this as the easiest and most intuitive way to build 3D objects.
- Thus, it enables more users to become creators.
- Same system as in Minecraft while not limited to terrain modeling.
- **Cross-compatibility**: objects naturally look great within very different experiences.

Items can be built within the default embedded item editor or alternative ones found on the platform. It's also possible to use third-party apps like [MagicaVoxel](https://ephtracy.github.io/index.html?page=mv_main) and import *.vox* files.

<p align="center">
	<img width=50% alt="" src="misc/img/bird.gif">
</p>

### Fully scriptable

Developers can script right from within Cubzh, on all platforms (yes, including mobile):

<p align="center">
<img width=50% alt="" src="misc/img/bird2.gif">
</p>

- All experiences in Cubzh are scripted in [Lua](https://www.lua.org).
- Developers can script both client and server sides. (Cubzh provides a free scalable server infrastructure for real-time multiplayer)
- Cubzh system APIs are documented here: [docs.cu.bzh/reference](https://docs.cu.bzh/reference)
- Higher-level APIs are available in the form of open-source [modules](https://docs.cu.bzh/modules), hosted on GitHub. Here's how you can import them:

	```lua
	Modules = {
		fire = "github.com/aduermael/modzh/fire"
	}

	Client.OnStart = function()
		Player:SetParent(World)
		Camera:SetModeThirdPerson()
	
		f = fire:create()
		f:SetParent(Player)
		-- now Player is on fire
	end
	```
	<p align="center">
		<img width=50% alt="" src="misc/img/fire.gif">
	</p>
	
- [Cubzh API documentation](https://docs.cu.bzh) is generated from the [lua](https://github.com/cubzh/cubzh/tree/main/lua) folder in that repository.
	

### Lightweight, All-In-One & Cross-Platform

All features are bundled into one comprehensive cross-platform application; there's no separate "studio" app for creators.

Cubzh runs on its own in-house C/C++ engine, using the [BGFX](https://github.com/bkaradzic/bgfx) library for cross-platform rendering.

## Supported platforms

- iOS / iPadOS
- Android
- Windows
- macOS
- Web Browsers (Chrome, Firefox, Safari, Edge)

## Development

Cubzh is in active development and still considered in Alpha.

Most communication among contributors, players, and creators takes place on the [official Discord server](https://cu.bzh/discord).

## Open Source

- The main components of Cubzh are open source (C engine, CLI, Lua modules, `.3zh` [voxel file format](https://github.com/cubzh/cubzh/blob/main/cubzh-file-format-3zh.txt)).
- It's not yet possible to build the app itself; we're actively working on open-sourcing missing parts to allow it.
- The goal is for Cubzh to become an engine anyone could fork to deploy their own custom User Generated Content platform.

Please help Cubzh with a ⭐️!

<p align="center">
	<img width=600 src="https://api.star-history.com/svg?repos=cubzh/cubzh&type=Date)](https://star-history.com/#cubzh/cubzh&Date"/>
</p>
