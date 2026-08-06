# Prokera Filling Pump

Control station for a Prokera filling pump using an Arduino Nano R4, a CL42T stepper driver, a physical press switch, and a Windows graphical control panel.

## Active Version

Active Nano R4 sketch/app label:

`V3-11 Nano R4 Peristaltic filling by G.C.`

Includes:

- Arduino Nano R4 firmware.
- Windows graphical pump control app.
- RUN, PURGE, STOP, Save, Read, and Clear Log controls.
- PURGE app button: fixed 15000 steps using the current speed.
- Physical press switch short press: normal run.
- Physical press switch long press, 3 seconds or more: purge run.
- Restored working Nano R4 pin map: `PUL-` on `D2`, `DIR-` on `A5`.
- CL42T ENA is kept enabled. If ENA causes disable behavior, leave ENA disconnected.
- EEPROM save verification using `EEPROM.put()` / `EEPROM.get()`: the controller prints `OK SAVE` or `ERR SAVE VERIFY` after saving settings.
- The Windows Save button uses one atomic `SET CONFIG <steps> <speed>` command to avoid back-to-back EEPROM writes.
- Standby switch guard: fixed emergency NC mode on `A2`; short press runs on release, press longer than 3 seconds purges while held.
- Longer switch filtering to prevent unintended standby starts from cable noise.
- Silent VBS launcher so the PowerShell console stays hidden.
- Pharmaceutical laboratory style technical manual.

The purge run does not overwrite the normal configured step count.

## Mechanical Model

![Prokera automatic pump mechanical render](docs/technical-manual/assets/pks-auto-pump-render.jpg)

## Contents

- `firmware/Nano_R4_Pump_Control/Nano_R4_Pump_Control.ino` - Arduino Nano R4 firmware.
- `windows-app/Nano_R4_Pump_Control/` - Nano R4 Windows app, launchers, and app README.
- `docs/technical-manual/` - current technical manual document.
- `docs/technical-manual/` - Nano R4 pharmaceutical laboratory style technical manual.
- `docs/technical-manual/assets/configuration-1.step` - STEP mechanical configuration file.

## Default Settings

- Normal run: `32000` steps.
- Purge: `15000` fixed steps.
- Speed: `210 us`.
- USB serial: `115200`.
- Press switch short press: normal run.
- Press switch long press, 3 seconds or more: purge run.
- Switch input guard: released state must be stable for 2 seconds before arming, and press must last at least 350 ms.

## CL42T Common-Anode Wiring

| CL42T | Arduino Nano R4 |
| --- | --- |
| `PUL+` | regulated `5V` |
| `PUL-` | `D2` |
| `DIR+` | regulated `5V` |
| `DIR-` | `A5` |
| `ENA+` | regulated `5V`, optional |
| `ENA-` | `A1`, optional. Leave disconnected if it disables the driver. |
| Press switch | NC contact to `A2`, COM to `GND` |

Do not use 24V directly with Arduino pins. For direct Arduino-to-CL42T wiring, use regulated 5V on `PUL+`, `DIR+`, and `ENA+`.

For long switch cables, add an external `10k` pull-up from `A2` to `5V`. If standby starts still occur, add a `0.1 uF` capacitor from `A2` to `GND`. If the switch is wired to NO instead of NC, swap `SWITCH_RELEASED_LEVEL` and `SWITCH_PRESSED_LEVEL` in the sketch.

## How To Use

1. Open Arduino IDE.
2. Upload `firmware/Nano_R4_Pump_Control/Nano_R4_Pump_Control.ino` to the Arduino Nano R4.
3. Close Arduino IDE Serial Monitor.
4. Connect the Nano R4 by USB.
5. Run `windows-app/Nano_R4_Pump_Control/Run_NanoR4PumpControl_Silent.vbs`.
6. Select the Nano R4 COM port and press `Connect`.
7. Press `Read`, set `Steps` and `Speed us` if needed, then use `RUN`, `PURGE`, or the physical switch.

## Physical Press Switch

- Less than 3 seconds: normal run.
- 3 seconds or more: purge, fixed 15000 steps.
- The action starts when the switch is released.

## Serial Commands

Baudrate: `115200`

```text
GET
SET STEPS 32000
SET SPEED 210
RUN
RUN 32000 210
PURGE
STOP
PING
```
