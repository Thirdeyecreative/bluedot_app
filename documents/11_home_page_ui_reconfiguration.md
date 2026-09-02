# Home Page UI Reconfiguration Plan

## Objective
Reconfigure the Home Page of the BlueDot app to optimize screen space by significantly reducing the massive camera section (which currently takes 45% of the screen height) and logically reorganizing the content hierarchy.

## The Pragmatic Solutions

### 1. Removing the Vortex Animation
The current 3D `_VortexItem` scrolling effect simulates items being sucked into the top "black hole". 
- **The Problem:** It is computationally heavy and its physics strictly rely on keeping a massive 400px empty space at the top of the screen.
- **The Solution:** We are removing it completely. We will reclaim that 45% of screen space and replace the vortex with highly performant, subtle slide-up stagger animations (`flutter_animate`) that look modern, clean, and function gracefully in a standard list.

### 2. Scanner to Global FAB
Currently, the scanner sits as a giant hero image at the top of the Home Page.
- **The Problem:** It wastes premium top-of-the-fold space and makes scanning inaccessible when browsing other tabs (like the Action Hub or Directory).
- **The Solution:** We are moving the scanner button to a **Floating Action Button (FAB) docked centrally in the Bottom Navigation Bar**. Since scanning is the primary action of the app ("Every Scan Plants a Story"), placing it as a docked global FAB is the most pragmatic UX pattern. It frees up the entire Home Page and makes scanning a 1-tap action from *anywhere*.

## Proposed New Architecture

### 1. Compact App Bar Header
Replace the giant `_ScannerHero` with a standard, compact pinned `SliverAppBar`.
- **Contents:** Eco Icon + "BlueDot" (Left), User XP Pill + Notification Bell (Right).
- **Height:** Standard AppBar height (~kToolbarHeight + SafeArea), styled with the primary blue gradient.

### 2. Reordered Content Feed
The main content will flow naturally from the very top of the screen in a `CustomScrollView`:
1. **Promo Banners** (`PromoBannerCarousel`)
2. **Quick Actions** (`_HomeQuickActions` - Eco Garden, Leaderboard)
3. **Stories & Updates** (`_BlogGrid`)

## Files to Modify

### `lib/features/home/pages/home_page.dart`
- Rebuild `HomePage` to use a `CustomScrollView` with a `SliverAppBar`.
- Remove `_ScannerHero`, `_PulsingScanButton`, `_ArcTagline`, `_HeroArcClipper`, and `_VortexItem`.
- Wrap the remaining content (Banners, Actions, Blogs) in simple `flutter_animate` slide/fade effects.

### `lib/features/navigation/main_navigation.dart`
- Add a `FloatingActionButton` docked to the center of the `Scaffold`.
- Move the `_PulsingScanButton` logic here, scaled down appropriately.
