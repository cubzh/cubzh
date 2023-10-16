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

Cubzh is an online platform written in C/C++ and Lua, allowing users to create Items, Environments, and Games using cubes paired with Lua scripts. It is inpired by both Roblox and Minecraft. With an easy-to-use scripting environment and free servers for instant multiplayer action, we're aiming to unleash the kind of creativity you see in Roblox. Enforcing cubes as building blocks for all 3D assets makes modeling and collaboration easier.

All features are bundled into one comprehensive cross-platform application, eliminating the need for a separate "studio" app for developers. We would like all users to get a chance to bump into each other, whether they're here as wanderers, players, artists or coders. 

Items can be built using the embedded item editor (or alternative ones):

<p align="center">
<img width=50% alt="" src="misc/img/bird.gif">
</p>

Scripts can be edited from within the app too:

<p align="center">
<img width=50% alt="" src="misc/img/bird2.gif">
</p>

[Cubzh API documentation](https://docs.cu.bzh) is generated from the [lua](https://github.com/cubzh/cubzh/tree/main/lua) folder in that repository.


### Supported platforms

Cubzh runs on **mobile** (iOS, Android), **desktop** (Windows, macOS) & **web browsers** (Chrome, Firefox, Safari, Edge). It's an all-in-one application embedding its execution sandbox, an item editor, a world editor and a code editor.


## Development

Cubzh is in active development, in public Alpha since June 2021.

Most communication among contributors, players, and creators takes place on our [official Discord server](https://cu.bzh/discord).

### Open Source

The main components of Cubzh are now open source (C engine, CLI, Lua modules, `.3zh` file format). Some glue components & server apps are still close source though. We're trying to get rid of moving parts and embedded secrets and will be open sourcing these parts over time.

### Open Distribution

Even though we're officially maintaining native Cubzh clients (iOS, Android, Windows, macOS), we would like creators to be able to distribute their Worlds via custom web domains. We're almost there, please contact us if you're interested in that feature.

### Core Features / Progression

⚠️ Features not listed in any particular order.

| Feature | Progression | Comments |
| ------------- | :-----: | ------------- |
| Cross-Plarform  | ✅ | Supported platforms: iOS, Android, Windows, macOS, web browsers (Chrome & Firefox) |
| Avatars | ✅ | |
| Lua Scripting Environment  | ✅ |Controls, Cameras, Physics/Collisions, Rays, Schedulers, Data Store, Real-time communication, HTTP Client, AI APIs, Sounds, Lights & Shadows, Modules|
| Item Editor  | ✅ | Add/Remove/Replace cubes, Items made out of multiple shapes |
| Wearable Editor  | ✅ | Templated Item Editor, positioning, dedicated gallery |
| File Import / Export | ✅ |.3zh, .vox|
| World Editor  | ⚙️ 20% | work in progress |
| Animation Editor  | ⚙️ 10% | Nothing in place visually, but backend almost in place for animations. |
| Friends | ⚙️ 50% |Friend requests, Profile screens. TODO: online statuses|
| Chat | ⚙️ 50% |Ingame chat console in place though we need a minimized view for it. Async chat groups to be implemented.|
| Marketplace | ⚙️ 10% |  Gallery in place but impossible to sell items yet |
| Localization | 📋| TODO |
| Parties / Matchmaking | 📋| TODO |
| Onboarding / Tutorials | 📋| TODO |
| Home Editor | 📋| TODO (for users to edit their homes, templated World Editor) |


