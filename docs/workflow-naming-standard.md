# Logic Apps Standard – Workflow Naming Standard

## Syfte

Denna standard säkerställer att workflows är enkla att hitta, förstå och underhålla i Azure-portalen och i källkodskontroll – utan att behöva öppna dem.

---

## Namnstruktur

```
{source}-{object}-{layer}(-{qualifier})
```

| Segment | Beskrivning | Exempel |
|---|---|---|
| **source** | Ursprungssystem eller affärsdomän | `saga2`, `sap`, `warranty`, `order` |
| **object** | Vad som hanteras | `zipfile`, `asnfile`, `record`, `claim` |
| **layer** | Pipeline-steget (se nedan) | `ingest`, `parse`, `persist`, `dispatch` |
| **qualifier** *(valfritt)* | Målsystem, subtyp eller variant | `dw`, `internaldb`, `sap`, `crm` |

---

## Pipeline-lager

Varje workflow ska tillhöra ett av följande lager. Lagernamnet beskriver **vad workflowet gör**, inte hur det triggas.

| Layer | Trigger-typ | Ansvar | Beskrivning |
|---|---|---|---|
| `ingest` | Blob, SFTP, HTTP | Ta emot råfil, packa upp, stagea, publicera event | Första steget i en pipeline. Tar emot data från ett extern system och förbereder den för vidare bearbetning. |
| `parse` | SB event / Blob event | Validera, transformera format, publicera records | Läser stagead data, validerar mot schema, transformerar till internt format och publicerar records på Service Bus. |
| `persist` | SB topic / queue | Konsumera records, skriv till databas | Tar emot records från Service Bus och **lagrar dem permanent** i en databas (t.ex. Data Warehouse eller intern DB). "Persist" = att göra data beständig, till skillnad från den tillfälliga SB-köen. |
| `dispatch` | Timer / Schedule | Läs från databas, skicka till målsystem | **Aktivt, målstyrt utskick** till ett extern system, ofta schemalagt. Skiljer sig från `publish` som är internt event-baserat. "Dispatch" = expediera/skicka ut till en specifik mottagare vid en specifik tidpunkt. |
| `notify` | SB event / anrop | Skicka notifiering | Skickar notifieringar till människor eller system (e-post, Teams, SMS). Ingen affärsdata transformeras. |
| `publish` | Anropas internt | Publicera event på SB/Event Grid | Används när ett workflow explicit publicerar ett event för andra workflows att reagera på. |

---

## Regler

```
✔ Alltid kebab-case (lowercase, bindestreck)
✔ Engelska genomgående
✔ Layer-ordet är alltid ett av: ingest | parse | persist | dispatch | notify | publish
✔ Qualifier används när samma layer finns mot flera mål eller varianter
✔ Source = ursprungssystem (saga2, sap) eller affärsdomän (warranty, order)
✘ Inga rcv / snd / handler – de beskriver riktning, inte funktion
✘ Inga löpnummer (workflow-1, workflow-2)
✘ Inga miljönamn i workflow-namn (hanteras via resursgrupp/deployment slots)
✘ Inga versioner i namn (hanteras via tags)
✘ Max 4 segment
```

---

## Generellt pipeline-mönster

De flesta integrationspipelines följer samma grundmönster:

```
[Externt system]
      │
      ▼
{source}-{object}-ingest
(ta emot, stagea, publicera event)
      │ SB Event
      ▼
{source}-{object}-parse
(validera, transformera, publicera records)
      │ SB Records
      ▼
{source}-{object}-persist-{måldb}
(lagra records i databas)
      │ (schemalagt)
      ▼
{source}-{object}-dispatch-{målsystem}
(skicka till externt system)
```

---

## Exempel per layer

### Ingest
```
saga2-zipfile-ingest          ← tar emot zip från Saga2, packar upp, stagear på blob
sap-orderfile-ingest          ← tar emot orderfil från SAP via SFTP
warranty-claimfile-ingest     ← tar emot garantiärenden via HTTP
```

### Parse
```
saga2-asnfile-parse           ← validerar ASN-fil, mappar till XML, publicerar records
saga2-isnfile-parse           ← validerar ISN-fil, mappar till XML, publicerar records
sap-order-parse               ← transformerar SAP-order till internt format
```

### Persist
```
saga2-asnrecord-persist-dw            ← skriver ASN-records till Data Warehouse
saga2-asnrecord-persist-internaldb    ← skriver ASN-records till intern DB
warranty-claim-persist-internaldb     ← skriver garantiärenden till intern DB
```

### Dispatch
```
saga2-asnrecord-dispatch-sap          ← schemalagt utskick av ASN-records till SAP
saga2-isnrecord-dispatch-crm          ← schemalagt utskick av ISN-records till CRM
warranty-report-dispatch-retailer     ← skickar garantirapport till återförsäljare
```

### Notify
```
warranty-summary-notify               ← skickar sammanfattning via e-post/Teams
saga2-error-notify                    ← felnotifiering vid pipeline-fel
```

---

## Söktips i Azure-portalen

| Söker efter | Sök på |
|---|---|
| Alla workflows för ett system | `saga2-`, `sap-`, `warranty-` |
| Alla ingest-flöden | `-ingest` |
| Allt som skriver till DW | `-dw` |
| Alla schemalagda dispatchers | `-dispatch` |
| Alla notifieringar | `-notify` |

---

## Versionshistorik

| Version | Datum | Förändring |
|---|---|---|
| 1.0 | 2026-04-29 | Initial version |
