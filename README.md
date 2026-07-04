# Landro-Longshot-Randomized-Code-Automation

Generate, manage, and automatically enter random codes for Landro Longshot.

Automate repetitive code workflows for Landro Longshot with configurable NPC menu navigation, random code generation, and automatic code entry assistance.

---

# Features

* Generate unique random codes automatically
* Configurable code length (5–50 characters)
* Configurable NPC menu navigation through a simple UI
* Assisted code entry workflow
* View current, next, and previously used codes
* Copy current and previous codes directly from the addon interface
* Persistent settings (saved between reloads and logins)
* Start / Stop controls
* Draggable window with ESC support
* Minimap button access
* Localization support

---

# How To Use

## Step 1

Open the addon through the minimap button.

## Step 2

Configure the addon.

### Number of Codes

Choose how many random codes should be generated and processed.

### Code Length

Choose the length of each generated random code.

Supported range:

**5–50 characters**

The default value is:

**25 characters**

### NPC Menu Configuration

The addon automatically navigates through configured Landro Longshot menu entries before opening the code input window.

The menu configuration works as follows:

#### Menu Entry 1

The first dialog selection.

For Landro Longshot this is usually:

`Actions`

#### Menu Entry 2

The second dialog selection.

#### Menu Entry 3

The final dialog option before the code input window appears.

You do not need to enter the complete menu text.

Entering a partial text match is sufficient.

### Example Configuration

```
Menu Entry 1: Actions
Menu Entry 2: Fire
Menu Entry 3: Spectral Tiger
```

The addon automatically navigates through these configured dialog entries in sequence.

## Step 3

Press **Start**

## Step 4

Talk to **Landro Longshot**

The addon will then:

* Navigate through configured menu entries
* Generate unique random codes
* Automatically insert the generated code
* Display workflow progress
* Allow copying the current and previously generated codes

## Step 5

After each completed code attempt:

Talk to Landro Longshot again to continue with the next iteration.

The addon requires manual re-interaction with Landro Longshot between iterations.

---

# Code Generation

Generated code length is configurable between **5** and **50** characters.

Default:

**25 characters**

---

# Status Information

The addon displays:

* Current status
* Current progress
* Current code index
* Next generated code
* Previously used code
* Copy buttons for current and previous codes
* Current required action

---

# Notes

This addon is designed to reduce repetitive manual interaction during repeated Landro Longshot code workflows while still requiring player interaction between iterations.

The addon window can be closed using the ESC key.

The copy window automatically selects the displayed code, allowing it to be copied immediately using **CTRL+C**.