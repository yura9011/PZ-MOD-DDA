# Radiation Overlay Textures

This directory should contain the radiation overlay textures for the ChargedStrike mod.

## Required Textures

Create the following PNG files (recommended size: 1920x1080 or larger):

### 1. radiation_green.png
- **Color**: Green tint (RGB: 0, 255, 0)
- **Purpose**: Displayed during Green radiation events (slow poison, stress)
- **Style**: Semi-transparent overlay with gradient or vignette effect

### 2. radiation_violet.png
- **Color**: Violet/Purple tint (RGB: 128, 0, 255)
- **Purpose**: Displayed during Violet radiation events (hallucinations, panic)
- **Style**: Semi-transparent overlay, can include distortion patterns

### 3. radiation_red.png
- **Color**: Red tint (RGB: 255, 0, 0)
- **Purpose**: Displayed during Red radiation events (fast damage, Stalker spawns)
- **Style**: Semi-transparent overlay with intense/danger feel

## Texture Guidelines

1. **Format**: PNG with alpha channel
2. **Size**: At least 1920x1080 pixels (will be scaled to screen size)
3. **Alpha**: The texture alpha will be controlled by the overlay system (0.0 to 0.4)
4. **Style**: Can be solid color, gradient, vignette, or pattern
5. **Reference**: See N&C's Narcotics mod textures for examples:
   - `media/textures/GUI/Brightness.png`
   - `media/textures/GUI/MDMA2.png`
   - `media/textures/GUI/Overdose.png`

## Quick Start (Solid Color Overlays)

For simple solid color overlays, create a 1920x1080 PNG filled with:
- Green: #00FF00 (fully opaque)
- Violet: #8000FF (fully opaque)
- Red: #FF0000 (fully opaque)

The overlay system will handle transparency via the alpha parameter.

## Testing

After creating the textures, test in-game using the debug console:
```lua
CS_RadiationOverlay.setOverlay("green", 0.4)
CS_RadiationOverlay.setOverlay("violet", 0.4)
CS_RadiationOverlay.setOverlay("red", 0.4)
CS_RadiationOverlay.fadeOut()
```
