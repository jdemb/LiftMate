---
change_id: testing-spojnosc-realtime-zapis-wspolbiezny
title: Testy spójności realtime i współbieżnego zapisu sesji
status: implemented
created: 2026-06-30
updated: 2026-06-30
archived_at: null
---

## Notes

Open a change folder for rollout Phase 1 of context/foundation/test-plan.md: "Spójność realtime i zapis współbieżny".
Risks covered: #1, #2, #6. Test types planned: API integration, controller, widget.
Risk response intent:
#1: Po utracie sieci ma wrócić ta sama kanoniczna sesja, a przerwa synchronizacji ma być widoczna.
#2: Równoległe zapisy mają mieć zdefiniowany wynik, bez błędów 500 i niespójnego stanu.
#6: Starsze i obce eventy nie mogą cofać ani przełączać bieżącej sesji.
After creating the folder, follow the downstream continuation rule.
