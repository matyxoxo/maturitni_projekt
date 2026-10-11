# AlphaLift

AlphaLift je pokročilá fitness aplikace pro iOS a Android, která kombinuje efektivní zaznamenávání tréninků s podrobným svalově-orientovaným systémem ranků.

Aplikace poskytuje strukturované sledování tréninkového pokroku, výpočet relativní síly vzhledem k tělesné hmotnosti a sdílení výkonů s přáteli.

---

## Použité technologie

* **Frontend:** Flutter (Dart)
* **State Management:** Riverpod
* **Backend & Databáze:** Supabase (PostgreSQL)
* **Lokální uložení (Offline režim):** Isar / Hive

---

## Klíčové funkce

### 1. Zaznamenávání tréninků
* **Různé typy sérií:** Podpora pro běžné série, rozcvičovací série (`warmup`), drop-série (`drop`) a série do selhání (`failure`).
* **Dynamické typy cviků (`exercise_type`):**
  * `weight_reps`: Váha a počet opakování (např. benčpres, dřep).
  * `bodyweight_reps`: Cviky s vlastní vahou (např. kliky).
  * `weighted_bodyweight`: Cviky s vlastní vahou a přidanou zátěží (např. vážené shyby).
  * `assisted_bodyweight`: Asistované cviky (např. asistovaný přítah na stroji).
  * `duration`: Statické výdrže měřené na čas (např. plank).
  * `distance_duration`: Kardio cviky měřené na vzdálenost a čas (např. běh).
* **Vlastní cviky:** Možnost vytvářet uživatelské cviky a přiřazovat je k příslušné svalové podskupině.

### 2. Rank systém
* **Hierarchické hodnocení síly:** Aplikace počítá dosažený rank na třech úrovních:
  * **Hlavní svalová skupina:** Např. Ruce (*Gold III*)
  * **Podskupina svalů:** Např. Biceps (*Platinum II*)
  * **Konkrétní cvik:** Např. Preacher Curl (*Platinum III*)
* **Relativní síla:** Automatické vyhodnocování výkonu na základě tělesné hmotnosti uživatele.

### 3. Sociální funkce
* **Tréninkový feed:** Zobrazování dokončených tréninků přátel.
* **Interakce:** Možnost udílení lajků a přidávání komentářů k tréninkům.
* **Sledování:** Systém vzájemného sledování uživatelů (`follow` / `following`).

---

## Databázová architektura

Projekt využívá relakční databázové schéma s přísně čitelnou hierarchií pro rychlé dotazování na svalové skupiny a výpočty ranků.

### Hierarchie svalů a cviků

`Muscle Group` → `Sub-muscle Group` → `Exercise`

Tato hierarchie umožňuje efektivní vyhledávání cviků podle názvu i podle svalové partie (např. vyhledání hesla **"biceps"** vrátí jak cviky obsahující toto slovo v názvu, tak cviky spojené se svalovou podskupinou Biceps).

### ER Diagram Databáze

<img width="1557" height="972" alt="db_diagram" src="https://github.com/user-attachments/assets/f97beffc-d2fa-45fa-9094-d1ac28810e31" />

*Odkaz na interaktivní schéma:* [Zobrazit diagram na dbdiagram.io](https://dbdiagram.io/d/6aca23c250a8c6fc361b8a12)

---

## Přehled databázových tabulek

1. **Uživatelé a sociální síť**
   * `users`: Profilové údaje a tělesná hmotnost uživatele pro výpočet relativní síly.
   * `follows`: Vztahy mezi uživateli (kdo koho sleduje).

2. **Svalová struktura a cviky**
   * `muscle_groups`: Nadřazené svalové partie (např. Ruce, Hrudník, Nohy).
   * `sub_muscle_groups`: Konkrétní svaly spadající pod hlavní partie (např. Biceps, Triceps).
   * `exercises`: Globální i uživatelsky vytvořené cviky s odkazem na `sub_muscle_id` a definovaným `exercise_type`.

3. **Šablony tréninků (Routines)**
   * `routines`: Uživatelské tréninkové plány.
   * `routine_exercises`: Cviky zařazené do dané šablony.
   * `routine_sets`: Cílové hodnoty sérií a opakování v šabloně.

4. **Historie a záznam tréninků (Workouts)**
   * `workouts`: Záznam o proběhlém tréninku (datum, trvání, poznámka).
   * `workout_exercises`: Cviky odcvičené v konkrétním tréninku.
   * `workout_sets`: Detailní data jednotlivých sérií (váha, opakování, trvání, vzdálenost, `set_type`).

5. **Sociální interakce**
   * `workout_likes`: Hodnocení tréninků jednotlivými uživateli.
   * `workout_comments`: Komentáře k tréninkům.

6. **Rank**
   * `user_ranks`: Unifikovaná tabulka uchovávající aktuálně dosažený rank pro cvik, svalovou podskupinu nebo hlavní svalovou skupinu.

---
