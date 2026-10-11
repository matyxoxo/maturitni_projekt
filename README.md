# AlphaLift

AlphaLift je pokročilá fitness aplikace pro iOS a Android, která kombinuje efektivní zaznamenávání tréninků s podrobným svalově-orientovaným systémem ranků.

Aplikace poskytuje strukturované sledování tréninkového pokroku, výpočet relativní síly vzhledem k tělesné hmotnosti a sdílení výkonů s přáteli.

---

## Použité technologie

* **Frontend:** Flutter (Dart)
* **Navigace:** go_router
* **State Management:** Riverpod
* **Backend & Databáze:** Supabase (PostgreSQL, Auth, Storage)
* **Lokální úložiště (Offline režim):** hive_ce – ukládání rozpracovaného tréninku do telefonu a synchronizace po obnovení signálu

---

## Klíčové funkce

### 1. Zaznamenávání tréninků
* **Různé typy sérií:** Podpora pro běžné série (`normal`), rozcvičovací série (`warmup`), drop-série (`drop_set`) a série do selhání (`failure`). Rozzcvičovací série se nezapočítávají do celkového objemu (volume).
* **Dynamické typy cviků (`exercise_type`):**
  * `weight_reps`: Váha a počet opakování (např. benčpres, dřep).
  * `bodyweight_reps`: Cviky s vlastní vahou (např. kliky).
  * `weighted_bodyweight`: Cviky s vlastní vahou a přidanou zátěží (např. vážené shyby).
  * `assisted_bodyweight`: Asistované cviky (např. asistovaný přítah na stroji).
  * `duration`: Statické výdrže měřené na čas (např. plank).
  * `distance_duration`: Kardio cviky měřené na vzdálenost a čas (např. běh).
* **Vlastní cviky:** Možnost vytvářet uživatelské cviky (`is_custom`) a přiřazovat je k příslušné svalové podskupině. Globální katalog má `user_id = NULL`.
* **Šablony (Routines):** Předpřipravené tréninkové plány s cílovými váhami a opakováními, lze je jedním tlačítkem spustit jako proběhlý trénink.

### 2. Rank systém
* **Hierarchické hodnocení síly:** Aplikace počítá dosažený rank na třech úrovních:
  * **Hlavní svalová skupina:** Např. Ruce (*Gold III*)
  * **Podskupina svalů:** Např. Biceps (*Platinum II*)
  * **Konkrétní cvik:** Např. Preacher Curl (*Platinum III*)
* **Relativní síla:** Výkon se vyhodnocuje jako poměr odhadované 1RM (vzorec Epley) k tělesné hmotnosti uživatele (`score_ratio = 1RM / body_weight_kg`).

### 3. Sociální funkce
* **Tréninkový feed:** Zobrazování dokončených tréninků přátel.
* **Interakce:** Možnost udílení lajků (maximálně jeden na uživatele a trénink) a přidávání komentářů k tréninkům.
* **Sledování:** Systém vzájemného sledování uživatelů (`follow` / `following`).

### 4. Přihlášení
* Registrace a přihlášení e-mailem a heslem přes Supabase Auth (Google OAuth připraveno do budoucna).
* Onboarding: při prvním přihlášení si uživatel zvolí unikátní přezdívku (`username`).

---

## Databázová architektura

Projekt využívá relační databázové schéma s přísně čitelnou hierarchií pro rychlé dotazování na svalové skupiny a výpočty ranků. Primární klíče jsou typu `uuid`; profil v tabulce `users` se napojuje na interní účet ze Supabase Auth (`auth.users`).

### Hierarchie svalů a cviků

`Muscle Group` → `Sub-muscle Group` → `Exercise`

Tato hierarchie umožňuje efektivní vyhledávání cviků podle názvu i podle svalové partie (např. vyhledání hesla **"biceps"** vrátí jak cviky obsahující toto slovo v názvu, tak cviky spojené se svalovou podskupinou Biceps).

### ER Diagram Databáze

<img width="1572" height="992" alt="alphalift_diagram" src="https://github.com/user-attachments/assets/a827530d-dc04-4452-ac1e-e76e2f012d93" />

*Odkaz na schéma:* [Zobrazit diagram na dbdiagram.io](https://dbdiagram.io/d/6aca23c250a8c6fc361b8a12)

---

## Přehled databázových tabulek

1. **Uživatelé a sociální síť**
   * `users`: Profilové údaje (unikátní přezdívka, celé jméno, fotka) a tělesná hmotnost uživatele pro výpočet relativní síly. Primární klíč `id` přebírá od Supabase Auth.
   * `follows`: Vztahy mezi uživateli (kdo koho sleduje). Složený primární klíč zamezuje duplicitním sledováním a sledování sama sebe.

2. **Svalová struktura a cviky**
   * `muscle_groups`: Nadřazené svalové partie (např. Chest, Back, Legs).
   * `sub_muscle_groups`: Konkrétní svaly spadající pod hlavní partie (např. Biceps, Triceps).
   * `exercises`: Globální i uživatelsky vytvořené cviky (`is_custom`) s odkazem na `sub_muscle_id` a definovaným `exercise_type`.

3. **Šablony tréninků (Routines)**
   * `routines`: Uživatelské tréninkové plány.
   * `routine_exercises`: Cviky zařazené do dané šablony (s pořadím).
   * `routine_sets`: Cílové hodnoty sérií a opakování v šabloně.

4. **Historie a záznam tréninků (Workouts)**
   * `workouts`: Záznam o proběhlém tréninku (název, trvání, celkový objem, případný odkaz na šablonu, ze které vznikl).
   * `workout_exercises`: Cviky odcvičené v konkrétním tréninku.
   * `workout_sets`: Detailní data jednotlivých sérií (váha, opakování, trvání, vzdálenost, typ série, stav splnění).

5. **Sociální interakce**
   * `workout_likes`: Hodnocení tréninků jednotlivými uživateli (unikátní dvojice uživatel + trénink).
   * `workout_comments`: Komentáře k tréninkům.

6. **Rank**
   * `user_ranks`: Dosáhnutý rank uživatele na úrovni cviku, svalové podskupiny nebo hlavní svalové skupiny. Místo polymorfního `entity_id` používá tři samostatné cizí klíče (`exercise_id`, `sub_muscle_id`, `muscle_group_id`), z nichž je vždy přesně jeden vyplněný – díky tomu databáze hlídá integritu dat.
