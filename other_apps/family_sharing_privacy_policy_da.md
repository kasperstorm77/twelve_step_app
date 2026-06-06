# Privatlivspolitik – Family Sharing

**Senest opdateret:** 18. april 2026

Denne privatlivspolitik forklarer, hvordan appen **Family Sharing** ("appen", "vi") håndterer dine data. Appen er udviklet af Kasper Storm som uafhængig udvikler.

## 1. Dataansvarlig

Kasper Storm
E-mail: kasperstorm17@gmail.com

## 2. Hvilke data behandler vi?

Appen er designet efter princippet om dataminimering. Vi indsamler **ingen** personlige oplysninger på en central server. Al opskriftsdata opbevares lokalt på din enhed.

Følgende data behandles udelukkende lokalt og/eller mellem dine egne enheder:

- **Opskrifter, kategorier og billeder** du selv opretter.
- **Husstandsidentitet** (en kryptografisk nøgle, der identificerer din husstand på synkroniseringsnetværket).
- **Enheds-ID** (tilfældig UUID, bruges kun til at afgøre konfliktløsning ved samtidige ændringer).

## 3. Synkronisering mellem enheder (Nostr)

Når du forbinder flere enheder til samme husstand, synkroniseres data via det åbne **Nostr-protokol-netværk**. Al data krypteres **end-to-end med AES-GCM-256** på din enhed, før den sendes. Indholdet kan kun læses af enheder, der kender husstandens delte nøgle.

Vi driver ikke egne Nostr-servere. Appen bruger offentlige relæer (f.eks. `relay.damus.io`, `nos.lol`, `relay.nostr.band`) udelukkende som blind videresendelse af krypterede beskeder. Disse relæer kan se at en krypteret besked passerer igennem, men ikke dens indhold.

## 4. Valgfri backup til Google Drive

Hvis du vælger at aktivere backup, gemmer appen en krypteret kopi af dine data i **din egen Google Drive**, i en privat app-mappe, som **kun denne app kan læse og skrive til** (Google's `drive.file`-scope). Vi har ingen adgang til din Google-konto eller dine filer.

- Din e-mailadresse fra Google-loginet gemmes lokalt på din enhed for at vedligeholde sessionen.
- Der sendes intet til nogen anden server end Google Drive.
- Backup kan slås fra når som helst under Indstillinger.

## 5. Hvad vi **ikke** gør

- Vi bruger **ingen analytics**, **ingen tracking**, **ingen reklamer**.
- Vi sender ingen data til tredjeparter ud over Google Drive (og kun hvis du selv aktiverer det).
- Vi anvender ingen cookies eller lignende sporingsteknologier.
- Vi profilerer ikke brugere og træffer ingen automatiserede afgørelser.
- Vi sælger ikke data. Der er intet at sælge.

## 6. Tilladelser

Appen beder om følgende tilladelser på din enhed:

- **Kamera** – for at scanne QR-koden, når du tilføjer en ny enhed til husstanden.
- **Fotos** – for at vedhæfte billeder til opskrifter.
- **Internet** – for at sende krypterede synkroniseringsbeskeder og (valgfrit) tale med Google Drive.

## 7. Opbevaring og sletning

Data opbevares på dine egne enheder, så længe du vælger det. Du kan til enhver tid:

- **Forlade husstanden** under Indstillinger — dette sletter alle data på den pågældende enhed.
- **Afinstallere appen** — fjerner alle lokale data.
- **Slette backup** direkte fra din Google Drive under "App Data"-mappen.

## 8. Dine rettigheder (GDPR)

Da vi ikke opbevarer data centralt, har du fuld kontrol over alle data gemt af appen via din egen enhed. Du har ret til indsigt, berigtigelse, sletning, begrænsning og dataportabilitet i henhold til GDPR. Henvendelser kan sendes til kasperstorm17@gmail.com.

Du har også ret til at klage til **Datatilsynet** (https://www.datatilsynet.dk).

## 9. Sikkerhed

Alt synkroniseret indhold krypteres med AES-GCM-256 før det forlader enheden. Husstandens krypteringsnøgle forlader aldrig dine enheder i ukrypteret form. Du alene er ansvarlig for at beskytte den QR-kode / sharing-token, der indeholder nøglen.

## 10. Børn

Appen henvender sig ikke specifikt til børn under 13 år og indsamler ikke bevidst data fra børn.

## 11. Ændringer

Denne politik kan opdateres. Væsentlige ændringer vil blive annonceret i appen. Fortsat brug efter en ændring udgør din accept af den nye version.

## 12. Kontakt

Spørgsmål om privatliv kan rettes til: **kasperstorm17@gmail.com**
