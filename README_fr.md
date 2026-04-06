# Fuite du code source de Claude Code — Scanner de sécurité

<center>
<img src="img/title.png" alt="title" />
</center>

### [IN ENGLISH HERE](README.md)

## Ce qui s'est passé

Le **31 mars 2026**, Anthropic a accidentellement publié l'intégralité du code source de
Claude Code sur le registre npm public. La cause est banale : le runtime Bun génère des
fichiers source map (`.map`) par défaut, et quelqu'un a oublié de les exclure dans
`.npmignore`. Cette seule omission a inclus un fichier `.map` dans la version `2.1.88` du
paquet `@anthropic-ai/claude-code`, lequel pointait vers une archive zip hébergée sur le
propre bucket Cloudflare R2 d'Anthropic — accessible publiquement. Le chercheur en sécurité
Chaofan Shou l'a découvert en quelques minutes.

L'archive contenait **512 000 lignes de TypeScript réparties sur 1 906 fichiers** : l'agent
complet, les drapeaux de fonctionnalités internes, les éléments de la feuille de route non
publiés, les noms de code internes des modèles et les prompts système. Elle a été
dupliquée et forkée des dizaines de milliers de fois sur GitHub avant qu'Anthropic ne puisse
réagir. Anthropic a confirmé qu'il s'agissait d'une erreur humaine, non d'une intrusion
ciblée, et qu'aucune donnée client ni identifiant n'avait été exposé.

Il s'agissait de la **deuxième fuite de ce type en 13 mois** — un incident quasi identique
s'était produit en février 2025.

---

## Pourquoi un scan de sécurité est nécessaire

La fuite du code source était embarrassante mais pas directement dangereuse pour les
utilisateurs finaux. **Ce qui fait de cet événement un incident de sécurité pour les
développeurs**, c'est ce qui s'est produit simultanément.

### Attaque concurrente sur la chaîne d'approvisionnement npm

Entre **00h21 et 03h29 UTC le 31 mars 2026**, une attaque distincte et non liée a
compromis la bibliothèque HTTP `axios`, très utilisée sur npm. Deux versions malveillantes
ont été publiées :

| Paquet | Version malveillante |
|--------|---------------------|
| axios  | 1.14.1              |
| axios  | 0.30.4              |

Les deux versions incluaient une dépendance cachée nommée `plain-crypto-js` contenant un
**cheval de Troie d'accès à distance (RAT) multiplateforme**.

Tout développeur ayant exécuté `npm install` ou mis à jour Claude Code via npm durant cette
fenêtre de 3 heures a pu récupérer l'axios compromis. Claude Code étant un paquet npm très
en vue et activement discuté ce jour-là, il est devenu un vecteur d'infection efficace.

### Ce que fait le malware

**Vidar Stealer** — Un infostealer qui exfiltre :
- Les mots de passe et cookies sauvegardés dans les navigateurs
- Les données de carte bancaire stockées dans les navigateurs
- Les fichiers de portefeuilles de cryptomonnaies
- Les bases de données d'authentificateurs 2FA
- Les identifiants FTP et SSH
- Les tokens Discord

**GhostSocks** — Un proxy SOCKS5 backconnect qui transforme la machine infectée en
infrastructure de nœud de sortie, faisant transiter le trafic d'autres attaquants par votre
adresse IP. Votre machine devient un outil persistant pour de futures attaques, même après
que Vidar a terminé son travail.

### Menace secondaire : dépôts GitHub malveillants

Suite à la fuite, des acteurs malveillants ont publié de faux dépôts de "code source
leaked de Claude Code" sur GitHub. Déguisés en forks fonctionnels avec des
"fonctionnalités entreprise déverrouillées", ils contenaient un dropper écrit en Rust
(`ClaudeCode_x64.exe`) déployant simultanément Vidar et GhostSocks. L'un de ces dépôts a
atteint **793 forks et 564 étoiles** avant d'être supprimé.

**Ne clonez pas et n'exécutez aucun fork non officiel de Claude Code de cette période.**

---

## Que faire en cas de compromission

Si le scan détecte `axios 1.14.1`, `axios 0.30.4` ou `plain-crypto-js` dans l'un de vos
lockfiles :

1. **Considérez la machine comme entièrement compromise** — ne tentez pas de nettoyage sur place
2. **Faites pivoter tous les identifiants immédiatement** : clés API, clés SSH, tokens, mots de passe, secrets
3. **Révoquez et rééditez** tous les identifiants de fournisseurs cloud (AWS, Azure, GCP, etc.)
4. **Prévenez votre équipe** si la machine avait accès à une infrastructure partagée
5. **Envisagez une réinstallation complète du système d'exploitation** — le RAT et le proxy peuvent persister après un nettoyage partiel

---

## Passer à l'installateur sécurisé

Anthropic recommande désormais l'installateur natif. Il utilise un binaire autonome et ne
dépend pas de la chaîne de dépendances npm.

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

---

## Utilisation — Windows (PowerShell 7)

### Prérequis
- PowerShell 7+
- Claude Code installé (optionnel — le script vérifie sa présence)

### Configuration

Sauvegardez [Test-ClaudeCodeSecurity.ps1](scripts/Test-ClaudeCodeSecurity.ps1) à l'emplacement de votre choix.

### Exécution

```powershell
# Scanner un dossier de projets spécifique
.\Test-ClaudeCodeSecurity.ps1 -ProjectsRoot "C:\Projects"

# Scanner l'intégralité du profil utilisateur
.\Test-ClaudeCodeSecurity.ps1 -ProjectsRoot $HOME
```

### Ce que le script vérifie

1. Si Claude Code est installé et s'il l'a été via npm
2. Tous les fichiers `package-lock.json`, `yarn.lock` et `bun.lockb` sous le chemin indiqué
3. Chaque lockfile pour `axios 1.14.1`, `axios 0.30.4` et `plain-crypto-js`

### Sortie

- `[OK]` — propre
- `[WARN]` — attention recommandée
- `[!!!]` — action immédiate requise

---

## Utilisation — Linux (Bash)

### Prérequis

- Bash 4+ (standard sur toute distribution Linux moderne)
- `find`, `grep` — présents par défaut partout

### Configuration

Sauvegardez [check_claude_security.sh](scripts/check_claude_security.sh) à l'emplacement de votre choix.

```bash
chmod +x check_claude_security.sh
```

### Exécution

```bash
# Scanner un dossier de projets spécifique
./check_claude_security.sh /home/utilisateur/projets

# Scanner l'intégralité du répertoire home
./check_claude_security.sh $HOME
```

### Ce que le script vérifie

Même logique que la version PowerShell :

1. Si `claude` est dans le `PATH` et s'il pointe vers une installation npm
2. Tous les fichiers `package-lock.json`, `yarn.lock` et `bun.lockb` sous le chemin indiqué
3. Chaque lockfile pour `axios 1.14.1`, `axios 0.30.4` et `plain-crypto-js`

### Sortie

- `[OK]` — propre
- `[WARN]` — attention recommandée
- `[!!!]` — action immédiate requise

---

## Note sur `bun.lockb`

Le lockfile de Bun est un format binaire. Les deux scripts le scannent par correspondance
de chaînes sur le contenu brut du fichier, ce qui détecte les chaînes en clair intégrées
dans le binaire. Il s'agit d'une heuristique, pas d'un analyseur de lockfile Bun à part
entière. Pour une couverture complète sur les projets Bun, vérifiez également `bun.lock`
(le lockfile au format texte) s'il est présent aux côtés de `bun.lockb`.

---

## Références

- [The Hacker News — Attaque sur la chaîne d'approvisionnement Claude Code](https://thehackernews.com/2026/04/claude-code-tleaked-via-npm-packaging.html)
- [The Register — Code source Claude Code exposé](https://www.theregister.com/2026/03/31/anthropic_claude_code_source_code/)
- [The Register — Faux dépôts de fuite trojanisés](https://www.theregister.com/2026/04/02/trojanized_claude_code_leak_github/)
- [VentureBeat — Analyse complète](https://venturebeat.com/technology/claude-codes-source-code-appears-to-have-leaked-heres-what-we-know)
