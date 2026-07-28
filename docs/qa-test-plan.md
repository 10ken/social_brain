# Social Memory QA & Test Plan

This document details the test boundaries, validation strategies, and test coverage for the **Social Memory** integration.

## 1. Testing Frameworks Utilized

1.  **Robolectric**: Enables local JVM-hosted Android components verification (e.g. testing context queries, string configurations, package bindings) without requiring an emulator. Runs exceptionally fast.
2.  **Roborazzi**: Powers screenshot/visual regression testing on local JVM instances using native graphics mode. Handles UI rendering validation for exact Material 3 theme colors.

## 2. Test Execution Details

Verify compilation states, component bindings, and tests via the unified Gradle tool:

```bash
# Execute local unit tests suite (Robolectric)
gradle :app:testDebugUnitTest
```

### Verified Test Outputs:
*   `read string from context`: Confirms package resource mappings fetch `Social Memory` as the default app label.
*   `crm entity mapping matches specifications`: Validates Person data-class instantiations hold expected name and nickname fields.
*   `event timeline mapping matches specifications`: Confirms event structures support timestamp mappings and auto-calculate upcoming dates correctly.
*   `greeting_screenshot`: Renders Roborazzi pixel assertions verifying the Dark Slate color schema remains pixel-exact.

## 3. Manual QA Checklist (Calendar UI)

This checklist validates the test data generated for May, June, and July of 2026.

### Calendar View Layout and Heatmaps
- [ ] Navigate to the Calendar screen and observe the Activity Heatmap on the monthly grid.
- [ ] Ensure that days with 1 Item render using the Cyan Light gradient.
- [ ] Ensure that days with 2 Items render using the Cyan Medium gradient.
- [ ] Ensure that days with 3+ Items render using the Cyan Dark gradient.
- [ ] Click through different dates (e.g. May 10, May 15) and verify the event stack dynamically updates properly without overflow.
- [ ] Ensure the "EVENTS" group natively maps above "FOLLOW UPS" in the agenda stack.

### Entity and Network Relational Consistency
- [ ] Go to Alex's profile -> Check that "Coffee with Alex", "Paddling Season...", and "Morning Run" correctly surface in the respective Person profile under the relevant temporal associations.
- [ ] Go to Michelle's profile -> Confirm the "Drinks at Bar Isabel" and "Brunch with Michelle" items reflect on the person timeline correctly.
- [ ] Navigate to the Paddling Friend Circle -> Validate that the "Paddling Season Kickoff" (May 15) emerges mapped natively back to this structural grouping.

## 4. iOS validation after Xcode installation

- [ ] Generate the project with `xcodegen generate` from `ios/` and build the
  `SocialBrain` scheme for an iOS 17 simulator.
- [ ] Run the `SocialBrainTests` target, including cipher, local clean-slate,
  envelope serialization, capture-review, and calendar-permission tests.
- [ ] Verify every capture type remains a pending local review until explicitly
  confirmed, then verify evidence text is visible on the created record.
- [ ] Verify sign-out leaves AI unavailable with an actionable sign-in message.
- [ ] Verify Calendar permission denial does not crash, and a granted calendar
  can create, update, and remove only app-requested events.
- [ ] Verify Start Clean requires confirmation and leaves no local records or
  device key behind.
