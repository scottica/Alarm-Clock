# Interrupt-Driven Alarm Clock (8051 Assembly)

## 📌 Overview
An embedded alarm clock system developed entirely in 8051 Assembly for the N76E003 microcontroller. Originally built as a design project for the UBC Electrical and Biomedical Engineering Design Studio (ELEC291/ELEC292), this system leverages hardware interrupts to maintain highly accurate timekeeping while simultaneously handling user inputs, LCD updates, and audio generation.

## ✨ Key Features
* **Precise Hardware Interrupts (ISRs):** The system's core timing relies on Timer 2, configured to trigger an Interrupt Service Routine (ISR) exactly every 1 millisecond. A secondary interrupt on Timer 0 is used to generate a 2kHz square wave for the speaker output.
* **Interactive LCD UI:** Displays the current time and active alarm settings in a 12-hour format with AM/PM indicators. The clock and alarm times are fully settable using hardware pushbuttons.
* **State Machine & Input Debouncing:** Features a multi-mode state machine allowing the user to seamlessly toggle between "Run," "Set Time," and "Set Alarm" modes, with programmed software debouncing to handle mechanical switch noise.
* **BCD Arithmetic:** Utilizes Binary-Coded Decimal (BCD) arithmetic (`da a` instructions) to efficiently increment seconds, minutes, and hours, rolling over accurately at the 60 and 12-hour marks.
* **Custom Morse Code Generator (Bonus Feature):** Beyond standard alarm tones, I engineered a custom lookup table and timing logic to translate the alarm trigger into a dynamic Morse code playback. When the alarm triggers, the speaker spells out the current time in Morse code, followed by a hidden message ("GIVE ME A GOOD MARK")!

## ⚙️ Technical Implementation
* **Language:** 8051 Assembly
* **Hardware:** N76E003 Microcontroller system, 16x2 Character LCD (4-bit mode), Pushbuttons, Mini Speaker.
* **Registers & Logic:** Extensive use of bit-addressable memory (`dbit`) for system flags (e.g., `Update_LCD`, `ALM_TRIGGERED`) to optimize RAM usage, alongside stack operations (`push`, `pop`) to protect the accumulator and Program Status Word (PSW) during asynchronous interrupts.

## 🚀 Usage
1. Compile the `AlarmClock.asm` file using the A51 assembler (CrossIDE).
2. Flash the compiled hex code to the N76E003 microcontroller.
3. **Controls:**
   * **Mode Button (P1.1):** Toggles between standard clock view, setting the time, and setting the alarm.
   * **Hour/Min/Sec Buttons:** Increments the respective time values when in a "Set" mode.
   * **Sec Button (P3.0) in Run Mode:** Toggles the alarm ON or OFF.
   * **Bonus Button (P1.5):** Manually triggers the Morse Code playback sequence.
