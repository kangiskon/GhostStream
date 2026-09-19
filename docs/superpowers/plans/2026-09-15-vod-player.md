# GhostStream Movies & Series Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build polished Movies/Series playback on iOS/iPadOS/tvOS with resume, transport controls, media tracks, and episode navigation.

**Architecture:** Extend existing hybrid PlayerView/TVPlayerView rather than replacing Live. Pass series episode context into VOD player; use engine bindings/commands for controls and persist resume in UserDefaults.

**Tech Stack:** SwiftUI, AVFoundation/AVKit, MobileVLCKit, TVVLCKit, UserDefaults

**Spec:** docs/superpowers/specs/2026-09-15-vod-player-design.md

## Global Constraints
- Preserve Live player behavior.
- Use real AVFoundation/VLCKit media tracks.
- Preserve black/purple GhostStream UI.
- Support iOS/iPadOS and tvOS.

---
### Task 1: Regression contract
- [ ] Add failing source-level regression for required VOD features and Series context.
- [ ] Run and verify failure.

### Task 2: iOS VOD controls and engine APIs
- [ ] Add resume, speed, fit/fill, ±10/restart, audio/subtitle selectors.
- [ ] Bind AVPlayer media selection and MobileVLCKit track APIs.
- [ ] Run regression.

### Task 3: Series navigation
- [ ] Pass ordered episodes/current episode into PlayerView.
- [ ] Add season/episode/previous/next/autoplay/info UI.
- [ ] Run regression.

### Task 4: tvOS VOD behavior
- [ ] Add content kind/context and resume/episode navigation to TVPlayerView.
- [ ] Preserve Siri Remote/native AVPlayer controls and VLC fallback.
- [ ] Run regressions.

### Task 5: Package and verification
- [ ] Run all Python regressions.
- [ ] Run project syntax/build checks available in environment.
- [ ] Zip modified project.
