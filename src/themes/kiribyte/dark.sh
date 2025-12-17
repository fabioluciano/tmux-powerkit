#!/usr/bin/env bash
# Tokyo Night Pastel Theme - PowerKit Semantic Color Mapping
# This file maps Tokyo Night Pastel colors to universal PowerKit semantic names
# that can be used across different themes consistently.

# Populate the global THEME_COLORS array for PowerKit compatibility
declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"
    
    # Background Colors
    [background]="#2a2b3d"           # Main background (pastel base)
    [background-alt]="#252631"       # Alternative/darker background
    [surface]="#3b3f5c"              # Surface/card background
    [overlay]="#4d5270"              # Overlay/modal background
    
    # Text Colors  
    [text]="#ffffff"                 # Primary text (pure white for contrast)
    [text-muted]="#8a8fb5"           # Muted/comment text (soft gray-lavender)
    [text-disabled]="#6d7187"        # Disabled text (muted gray)
    
    # Border Colors
    [border]="#4d5270"               # Default border
    [border-subtle]="#8a91ad"        # Subtle border (lighter)
    [border-strong]="#9ba3c4"        # Strong border (more visible)
    
    # Semantic Colors (PowerKit Standard)
    [accent]="#d4c5ff"               # Main accent color (lavender pastel)
    [primary]="#b8a3e8"              # Primary brand color (purple pastel)
    [secondary]="#687aa3"            # Secondary color (blue-gray pastel)
    [secondary-strong]="#3e4962"     # Strong secondary (40% darker)
    
    # Status Colors (PowerKit Standard)
    [success]="#a9c98c"              # Success state (mint green pastel, 5% mais escuro)
    [warning]="#e3caa6"              # Warning (13% lighter)
    [error]="#ff6b85"                # Error state (rose pastel)
    [info]="#ade5ff"                 # Informational state (baby blue pastel)
    
    # Interactive States
    [hover]="#313342"                # Hover state (subtle dark)
    [active]="#7d96c2"               # Active state (10% mais clara que secondary)
    [focus]="#a4c5ff"                # Focus state (sky blue pastel)
    [disabled]="#8a8fb5"             # Disabled state (muted)
    
    # Additional Variants
    [success-subtle]="#bad0b1"       # Subtle success (18.9% lighter)
    [success-strong]="#5e6e59"       # Strong success (44.2% darker)
    [warning-strong]="#7e705c"       # Strong warning (44.2% darker)
    [error-strong]="#785959"         # Strong error (44.2% darker)
    [info-subtle]="#b1dfdf"          # Subtle info (18.9% lighter)
    [info-strong]="#597878"          # Strong info (44.2% darker)
    [error-subtle]="#dfb1b1"         # Subtle error (18.9% lighter)
    [warning-subtle]="#e8d4b6"       # Subtle warning (18.9% lighter)
    
    # System Colors
    [white]="#ffffff"                # Pure white
    [black]="#000000"                # Pure black
)

# Export for PowerKit compatibility
export THEME_COLORS