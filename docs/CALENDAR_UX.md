# Calendar Heatmap UX

The calendar view in Social Memory functions as a high-density emotional and schedule overview of social check-ins, allowing users to scan monthly interaction rhythms without opening raw list views.

---

## 1. Visual Heatmap Density Layout

Day tiles are filled dynamically depending on overall events and reminders scheduled on that date. We use **Cyan Gradients** to map the progression of items spanning events and follow-ups.

| Event Density | Fill Gradient Colors | Hex Code ranges |
|---|---|---|
| **0 Items** | `surface` to `surface` | Transparent |
| **1 Item** | Cyan Light | `#E0F7FA` to `#80DEEA` |
| **2 Items** | Cyan Medium | `#4DD0E1` to `#00ACC1` |
| **3+ Items** | Cyan Dark | `#00838F` to `#006064` |

### Selected Highlight
When selected, the active day card border shifts to **Info Strong Sky (`#38BDF8`)** for sharp contrast while the day number uses a bolder weight.

---

## 2. Interaction & Dynamic Filtering

- **Date Toggle Filtering**: Tapping a tile focuses the agenda list below to *only* events and tasks scheduled on that exact day.
- **De-Selection Range**: Clicking the active selected day tile again, or selecting the **"Show Month"** primary button, instantly resets the dynamic filters, returning the agenda to the comprehensive full-month stream.
- **Event & Follow Up Order**: The Monthly and Daily structural outlooks correctly partition timelines. Iteration sequences always display **EVENTS** first, seamlessly stacked above **FOLLOW UPS** for logical time management.
- **Header Month Navigation**:
  - Outlined arrows (`<` and `>`) shift target focus to the preceding or next month.
  - Tapping the Monthly title centers a fast Dropdown picker, allowing direct selection of any Month and Year in low-friction overlays.
