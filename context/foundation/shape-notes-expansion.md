---
project: "Aplikacja mobilna treningowa dla trenera i podopiecznego - expansion"
context_type: brownfield
created: 2026-06-23
updated: 2026-06-23
checkpoint:
  current_phase: 2
  phases_completed: [1]
  gray_areas_resolved:
    - topic: "kontekst zmiany"
      decision: "Rozszerzenie istniejącej aplikacji w trybie brownfield."
    - topic: "cel rozszerzenia"
      decision: "Przygotowanie aplikacji do bezpieczniejszej i bardziej dopracowanej bety."
    - topic: "zakres wejściowy"
      decision: "Nowe funkcjonalności i wskazane błędy są wspólnym wejściem do rozszerzenia roadmapy."
    - topic: "persony"
      decision: "Główną personą pozostaje podopieczny, a trener jest personą drugorzędną."
  frs_drafted: 0
  quality_check_status: pending
---

## Current System

LiftMate jest istniejącą aplikacją mobilną treningową obsługującą relację trener-podopieczny. Podstawowa funkcjonalność określona w dotychczasowej roadmapie została zbudowana.

Z aplikacji korzystają podopieczni oraz trenerzy. Główną personą pozostaje podopieczny, a trener jest personą drugorzędną.

Obecne przepływy, dane oraz reguły relacji trener-podopieczny muszą zostać zachowane bez regresji.

## Vision & Problem Statement

Kolejny etap rozwoju ma przygotować aplikację do bezpieczniejszej i bardziej dopracowanej bety. Zakres obejmuje nowe funkcjonalności oraz usunięcie błędów opisanych w `documents/idea-expansion-notes.md`.

Obecne luki obejmują publiczną dostępność rejestracji przez API, mało przyjazne komunikaty walidacyjne, brak feedbacku po samodzielnym treningu, brak podpowiedzi dla trenera, niedziałające lub brakujące akcje w interfejsie oraz brak mechanizmu motywacyjnego dla podopiecznego.

## User & Persona

Primary persona: podopieczny korzystający z aplikacji podczas samodzielnego treningu lub treningu prowadzonego przez trenera. Rozszerzenie ma poprawić zrozumiałość aplikacji, możliwość przekazania informacji po treningu i motywację do regularnego wykonywania treningów.

### Secondary persona

Trener prowadzący podopiecznych, odbierający ich feedback i potrzebujący użytecznych sygnałów wynikających z historii treningowej.
