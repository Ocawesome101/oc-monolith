# Monolith

Monolith is a monolithic, multitasking, multiuser, multiscreen operating system for the OpenComputers Minecraft mod. Documentation is mostly available in the DOCS.md files placed in the various directories. If any docs are missing, please raise an issue or let me know through Discord or IRC (Ocawesome101#5343 or Ocawesome101 in #oc on EsperNet).

Documentation is available online [here](https://oz-craft.pickardayune.com/man).

Current LOC: 9681

## Installation
To install Monolith to any empty hard disk, run the following commands in the OpenOS shell. You will need an internet card.
```
cd /home
wget https://raw.githubusercontent.com/ocawesome101/oc-monolith/master/installer.lua
./installer.lua
```

Note that the installation process assumes the current root filesystem is mounted as writable. The Monolith installer will refuse to install to the root filesystem.

## Pre-built releases

The latest pre-built release will be downloaded through the installer. At any time, you may upgrade with `mpm install ocawesome101/oc-monolith/base`.

## Building

To build Monolith, you'll need Lua 5.3, `git`, `make`, and probably a Linux or macOS system (alternatively, you can download the latest prebuilt release in CPIO form from `release.cpio` in the repo). Clone this repository (`git clone https://github.com/ocawesome101/oc-monolith`), `cd` to it, and run `make`. Copy all files in `build` to the root of your OpenComputers drive.

## Project status

The following is a (hopefully up-to-date) representation of what I want to get done, and what I have gotten done, towards completing Monolith.

- [ ] Monolith
  - [X] Kernel
    - [X] Base
    - [X] Logger (`kernel.logger`)
    - [X] `component`
    - [X] Users (`kernel.users`)
    - [X] Modules (`kernel.module`)
    - [X] Filesystem management (`kernel.filesystem`)
    - [X] `computer`
    - [X] Userspace sandbox (`kernel.sandbox`)
    - [X] Scheduler (`kernel.thread`)
    - [X] Load init
  - [X] InitMe init system
    - [X] Base
    - [X] `package`
    - [X] `io`
    - [X] Service management (`initsvc`)
    - [X] Script management (`scripts`, not directly user-facing)
  - [ ] Services
    - [X] `getty`
    - [X] `mountd`
    - [X] `devfs`
    - [ ] `procfs`
    - [X] Minitel daemon
    - [ ] GERTi daemon
  - [ ] Libraries
    - [X] `buffer`
    - [X] `class` (may remove)
    - [X] `config`
    - [X] `shell`
    - [X] `sha3`
    - [X] `serialization`
    - [X] `sh`
    - [X] `text`
    - [X] `time`
    - [X] `users`
    - [X] `vt100`
    - [X] `protect`
    - [X] `cp.copy`
    - [X] `event`
    - [X] `uuid`
    - [X] `internet`
    - [ ] `net`
      - [ ] `minitel`
      - [ ] `GERTi`
    - [X] `filesystem`
    - [X] `signals`
    - [X] `thread`
    - [X] `module`
    - [X] `modules`
    - [X] `kinfo`
  - [X] SH
    - [X] Base
    - [X] Builtins
    - [X] Basic commands
  - [ ] MonoUI
    - [ ] Base
    - [ ] Window management
    - [ ] Apps
      - [ ] Settings
      - [ ] Terminal
  - [X] Memory optimization - `/lib/full` + `package.delay`
  - [X] Editors
    - [X] Library (`/lib/editor.lua`)
    - [X] Line editor (`/bin/ed.lua`)
    - [X] Fullscreen editor (`/bin/fled.lua`)
    - [X] Visual editor (`/bin/vled.lua`)
