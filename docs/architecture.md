# Social Memory Architectures

This document outlines the System Architecture for **Social Memory** (aka **Social Brain**), a private intelligence assistant for your social life.

## 1. High-Level Architectural Pattern
The application follows modern Android **MVVM (Model-View-ViewModel)** architecture and Clean Architecture principles:

```
┌────────────────────────────────────────────────────────┐
│                        VIEW LAYER                      │
│      Jetpack Compose UI (MainAppContainer / Screens)   │
└───────────────────────────┬────────────────────────────┘
                            │ (Observes UI States)
                            ▼
┌────────────────────────────────────────────────────────┐
│                     VIEWMODEL LAYER                    │
│      AppViewModel (StateFlows / Screen Navigation)     │
└───────────────────────────┬────────────────────────────┘
                            │ (Dispatches Write & Queries)
                            ▼
┌────────────────────────────────────────────────────────┐
│                    REPOSITORY LAYER                    │
│      AppRepository (Facade to DAO & Gemini APIs)       │
└─────────────┬───────────────────────────────┬──────────┘
              │                               │
              ▼                               ▼
┌───────────────────────────┐   ┌────────────────────────┐
│     PERSISTENCE (LOCAL)   │   │     REMOTE AI CLIENT   │
│      SQLite / Room DB     │   │      GeminiClient      │
└───────────────────────────┘   └────────────────────────┘
```

### Components
1. **View Layer (Jetpack Compose)**: Built entirely upon Jetpack Compose, implementing responsive, adaptive layouts, and adhering strictly to Material Design 3 (M3). It showcases custom interactive components such as:
   - **Chronological Social Calendar Heatmap**: Computes start-to-end alignments for any given month, rendering custom calendar grids with dynamic alpha-shaded Teal density grids tracking daily totals:
     * *0 items*: Neutral background.
     * *1 item*: Subtle Teal tint (15% opacity).
     * *2 items*: Medium Teal tint (35% opacity).
     * *3 items*: Dark Teal tint (60% opacity) with white text.
     * *4+ items*: Solid primary Teal highlight with white text.
   - **Dynamic Month Picker**: An custom dialog showing the full 12-month layout and year controls for instant calendar travel.
   - **Interactive Callback Checklist**: Unified inside the same view to display events and due-dated tasks with fast-toggle checkbox state controls.
2. **ViewModel (AppViewModel)**: Ingests hot database Flows from the repository, exposes immutable `StateFlow` structures, maintains screen navigation stack states, and coordinates asynchronous background extractions.
3. **Repository (AppRepository)**: Unifies local database queries and AI endpoints into a solid transaction boundary.
4. **Data Sources**:
   - **Local Database (Room/SQLite)**: The source-of-truth for all user records, relationships, events, memories, and task checklists.
   - **Gemini Rest Client**: Formulates raw speech transcripts, pasted text chunks, or screenshot logs into structured JSON payloads.

## 2. API Service Integration
To bypass massive framework sizes, the integration is accomplished via a custom REST-compliant JSON client targeting Gemini `v1beta` models directly. It uses specialized extraction prompts to parse unstructured text blocks into structured data types safely without leaking security scopes.
