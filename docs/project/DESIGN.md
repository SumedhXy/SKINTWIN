# DESIGN.md - SkinTwin Design System

## Principles
- **Photography-First & Dermoscopic Precision**: UI chrome recedes so high-resolution skin spot photogrammetry and telemetry lead the screen.
- **Single Brand Accent (Action Blue `#2563EB`)**: All interactive CTAs, focus signals, and links use Action Blue. Saturated status badge tints (`Color(0xFF047857)` for Emerald, `Color(0xFFB45309)` for Amber).
- **Tight Display Typography**: Inter / SF Pro Display with negative letter spacing (`-0.6px` to `-0.8px`) on titles, generous 1.4+ leading on body copy.
- **Layered Elevation & Depth**: Offsets with soft blur (`offset: Offset(0, 4-8)`, `blurRadius: 12-20`), subtle hairline borders (`#E2E8F0`), zero-slop clean geometry.
- **Authored Micro-Interactions**: Active scale transforms (`transform: scale(0.97)`), interactive split comparison slider, animated pulse reticles.

## Colors
- **Action Blue (Primary)**: `#2563EB`
- **Primary Dark**: `#1D4ED8`
- **Background Parchment**: `#F8FAFC`
- **Card Surface**: `#FFFFFF`
- **Text Primary**: `#0F172A`
- **Text Muted**: `#64748B`
- **Hairline Border**: `#E2E8F0`
- **Success Emerald**: `#10B981` (Badge text: `#047857`, Badge BG: `#ECFDF5`)
- **Warning Amber**: `#F59E0B` (Badge text: `#B45309`, Badge BG: `#FFFBEB`)

## Components
- **Global Frosted Header**: Sticky white bar with 0.5 scrolled elevation, logo avatar badge, user profile indicator.
- **Hero Telemetry Card**: Deep dark slate gradient (`#0F172A` → `#1E293B`) with ambient glowing blue orb accent and full pill CTAs.
- **Interactive Finder Card**: Dermoscopic preview container, status pill, millimeter geometry readout, dual action buttons.
- **Photogrammetry Viewer**: Interactive dual-mode slider (Side-by-side vs Live overlay slider).
- **Floating Dock Navigation**: Frosted white bar with active tab glow pill & elevated gradient camera action button.
