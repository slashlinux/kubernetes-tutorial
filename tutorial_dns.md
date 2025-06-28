# Cum funcționează DNS 

> **TL;DR**
> DNS (Domain Name System) este agenda telefonică a Internetului: convertește nume ușor de reținut (ex. `petrisor.com`) în adrese IP (ex. `192.0.2.45`).
> Sistemul este ierarhic, distribuit și folosește caching agresiv pentru performanță.

---

## 1. Terminologie esențială

| Termen                | Definiție scurtă                                                     |
| --------------------- | -------------------------------------------------------------------- |
| **FQDN**              | *Fully‑Qualified Domain Name* (`www.example.com.`)                   |
| **Root (`.`)**        | Rădăcina ierarhiei DNS – prima „cască” a oricărei interogări         |
| **TLD**               | *Top‑Level Domain* `.com`, `.ro`, `.io`…                             |
| **Server autoritar**  | Serverul care deține înregistrările oficiale pentru un domeniu       |
| **Resolver (Stub)**   | Biblioteca DNS din sistemul tău de operare / aplicație               |
| **Resolver recursiv** | Server (de obicei ISP sau cloud) care caută răspunsul în locul tău   |
| **Zone file**         | Fișierul care descrie toată configurația DNS pentru un domeniu       |
| **TTL**               | *Time‑To‑Live*: câte secunde poate fi memorat (cache‑uit) un răspuns |

---

## 2. Actorii principali

1. **Client / Stub Resolver** – codul din sistemul de operare sau browser care inițiază întrebarea.
2. **Recursive Resolver** – serverul DNS configurat (ex. 1.1.1.1, 8.8.8.8, Route 53 Resolver). El face „munca grea”.
3. **Root Servers** – 13 grupuri (`A.` – `M.`) ce cunosc delegările către TLD‑uri.
4. **TLD Servers** –  mențin lista de domenii sub un TLD (`.com`, `.ro`).
5. **Authoritative Servers** – dețin zona finală pentru `petrisor.com`.

> **Pro tip**
> De regulă, tu *controlzi* serverele autoritare (ex. Cloudflare), dar nu trebuie să le găzduiești singur.

---

## 3. Flow complet *request → response*

```
┌────────┐        ① Query? petrisor.com A               ┌──────────────┐
│ Client │──────────────────────────────────────────────▶│  Resolver    │
└────────┘                                            ② │  Recursiv   │
   ▲  ▲                                                │ └──────────────┘
   │  │3.1 final answer                                │      ▲
   │  │                                                │      │ Iterativ
   │  └────────────────────────────────────────────────┘      │
   │                                                         ▼
   │                                           ┌────────────────────────┐
   │                                 ②.1       │  Root Servers (A‑M)    │
   │                                 …………Query▶│  "Cine știe .com?"     │
   │                                           └────────────────────────┘
   │                                                         │
   │                                 ②.2                    ▼
   │                                 …………Query▶┌────────────────────────┐
   │                                           │  TLD Servers .com      │
   │                                           └────────────────────────┘
   │                                                         │
   │                                 ②.3                    ▼
   │                                 …………Query▶┌────────────────────────┐
   │                                           │  NS petrisor.com       │
   │                                           │ (Authoritative)        │
   │                                           └────────────────────────┘
   │                                                         │
   │                                 ②.4  Answer: petrisor.com → 192.0.2.45
   │                                                         │
   ▼                                                         ▼
┌────────┐   ③ 192.0.2.45                                   ┌──────────────┐
│ Browser│◀──────────────────────────────────────────────────│ Resolver     │
└────────┘                                                   └──────────────┘
```

**Legenda pașilor**
① Stub resolver trimite interogarea UDP/53 (sau TCP/53, DoT/DoH) către resolverul recursiv configurat.
② Resolverul recursiv execută interogări iterative: Root → TLD → Autoritar.
③ Răspunsul este cache‑uit (`TTL`), apoi livrat clientului; browserul deschide conexiunea TCP/443 la IP.

---

## 4. Ce se întâmplă la nivel de pachete

| Nr. | De        | Către              | Protocol\:Port | Conținut esențial                  |
| --- | --------- | ------------------ | -------------- | ---------------------------------- |
| 1   | Client    | Resolver           | UDP 53         | „A? petrisor.com”                  |
| 2   | Resolver  | Root               | UDP 53         | „NS? .com”                         |
| 3   | Root      | Resolver           | UDP 53         | delegație `.com`                   |
| 4   | Resolver  | TLD `.com`         | UDP 53         | „NS? petrisor.com”                 |
| 5   | TLD       | Resolver           | UDP 53         | delegație către ns1.cloudflare.com |
| 6   | Resolver  | ns1.cloudflare.com | UDP 53         | „A? petrisor.com”                  |
| 7   | Autoritar | Resolver           | UDP 53         | Answer: 192.0.2.45, TTL = 3600     |
| 8   | Resolver  | Client             | UDP 53         | Forward same answer                |

După pasul 8, clientul/brows‑erul știe IP‑ul și inițiază conexiune **TCP 443 (HTTPS)** direct către server.

---

## 5. Caching și invalidare

* Fiecare răspuns vine cu **TTL**; recursorul îl cache‑uiește.
* Schimbarea unui `A` record poate dura până expiră TTL‑ul precedent (ex. 300 s).

| Nivel cache       | Exemplu                    | Durată tipică          |
| ----------------- | -------------------------- | ---------------------- |
| Browser           | Chromium, Firefox          | 1‑60 s (config intern) |
| OS                | `systemd-resolved`, `nscd` | 0‑600 s                |
| Resolver recursiv | 8.8.8.8                    | TTL original ≤ 86400 s |

---

## 6. DNS în practică DevOps / Cloud

### Kubernetes

* **CoreDNS** rezolvă servicii: `my‑svc.my‑ns.svc.cluster.local`.
* Service Discovery intern folosește `SRV` și `A` records.

### AWS Route 53

* Zone publice & private legate de VPC‑uri.
* **Alias** records pentru ALB / CloudFront (0 \$).

### Load‑balancing & failover prin DNS

* Multiple `A/AAAA` cu greutăți (weighted), latency‑based sau health‑check failover (Route 53 / NS1 / Cloudflare).

### Securizare

* **DNSSEC** semnează criptografic delegațiile (root → TLD → autoritar).
* **DoT (DNS‑over‑TLS)** și **DoH (DNS‑over‑HTTPS)** criptează transportul între client și resolver.

---

## 7. Verificare și debugging rapid

```bash
# Cine e serverul autoritar?
dig petrisor.com NS +short

# Verifică răspuns direct de la autoritar (no‑recursion)
dig @ns1.cloudflare.com petrisor.com A +norecurse

# Arată tot lanțul
 dig petrisor.com A +trace
```

---

## 8. Resurse utile

* RFC 1034 & 1035 – *Domain Names – Concepts and Facilities / Implementation and Specification*
* [https://root-servers.org](https://root-servers.org) – Statistici și listă instanțe root
* `dnsreplay`, `dnstop`, `kdig`, `bind9‑utils` – tool‑uri avansate

---

> ✉️ **Întrebări frecvente**
> *Cum reduc downtime când schimb IP‑ul?* – Folosește TTL mic (ex. 60 s), testează noul IP, apoi mărește TTL după migrare.
> *Pot fi propriul root?* – Nu. Nivelul Root este un trust anchor operat de IANA & ICANN.

---

👋 Sper ca acest README să‑ți fie util la interviuri și în producție! Dacă vrei exemple suplimentare (ex. DNS failover în Route 53, DNS pentru servicii multi‑cluster K8s), spune‑mi și extindem.
