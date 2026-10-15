# BIMBridge: Claude et ChatGPT connectés à Revit

Parlez à votre maquette Revit. BIMBridge installe en une fois le **serveur MCP intégré à pyRevit 7**, le connecte à Claude Desktop (plan gratuit compris), à Claude Code et à ChatGPT, et ajoute des **skills BIMBridge** pour que l'IA travaille proprement dans vos modèles.

> Le pont entre l'IA et Revit est le serveur MCP officiel de [pyRevit](https://github.com/pyrevitlabs/pyRevit) (pyRevitLabs). BIMBridge apporte l'installation en un prompt, la configuration des applications d'IA, les skills et la documentation en français.

## Ce que vous obtenez

- **L'IA lit votre modèle ouvert** : niveaux, éléments, paramètres, vues, sélection.
- **L'IA modifie le modèle** avec des scripts exécutés dans Revit, **après votre validation** dans Revit (**Keep** pour garder, **Discard** pour annuler). Chaque modification gardée s'annule en un seul Ctrl+Z.
- **L'IA voit le résultat** grâce à des captures de vues.
- **Skills BIMBridge** : une méthode de travail (unités métriques, construction par étapes, vérification visuelle) et une revue MEP (connecteurs ouverts, réseaux, isolation, pentes, circuits).

## Prérequis

- Windows 10 ou 11, Revit 2022 ou plus récent
- Claude Desktop (gratuit ou payant), Claude Code, ou l'application ChatGPT avec Codex
- pyRevit 7 ou plus récent : installé automatiquement s'il manque

## Installation

### Option A : un seul prompt (Claude Pro ou plus)

Dans Claude Desktop, ouvrez l'onglet **Code** (ou lancez Claude Code), puis collez :

```
Installe BIMBridge pour connecter Claude à mon Revit : https://github.com/kenpro0/bimbridge-mcp
Suis le fichier INSTALL.md étape par étape, puis dis-moi quoi faire ensuite.
```

Claude vous demande l'autorisation avant chaque commande. Windows peut aussi demander l'autorisation d'installer .NET ou WebView2 pour pyRevit : cliquez sur **Oui**.

### Option B : une commande (plan gratuit, ou sans Claude Code)

1. Fermez Revit.
2. Ouvrez **PowerShell** (pas en administrateur) et collez :

```powershell
irm https://raw.githubusercontent.com/kenpro0/bimbridge-mcp/main/install.ps1 | iex
```

### Ensuite

1. Démarrez Revit et ouvrez un modèle. Si Revit est déjà ouvert : **pyRevit > Reload**.
2. Quittez complètement votre application d'IA et rouvrez-la. Pour Claude Desktop : clic droit sur l'icône Claude près de l'horloge, puis **Quitter**.
3. Essayez un des prompts ci-dessous.

## Prompts à essayer

- « Lis le skill bimbridge, puis décris mon modèle Revit ouvert. »
- « Crée une maison de 10 × 8 m sur deux niveaux de 3 m, avec un toit à deux pentes. »
- « Fais une capture 3D de la maquette et dis-moi ce que tu vois. »
- « Fais une revue MEP de mon modèle avec le skill mep-review. »
- « Sélectionne toutes les gaines qui ne sont dans aucun réseau. »

## Comment ça marche

```
Claude / ChatGPT  ⇄  serveur MCP de pyRevit (pyrevit.exe mcp)  ⇄  agent pyRevit dans Revit  ⇄  votre modèle
```

- Les lectures se font sans confirmation. Chaque modification affiche une demande de validation dans Revit, avec les éléments modifiés isolés à l'écran.
- La politique par défaut est `ask` (validation à chaque modification). Elle se change dans **pyRevit > Settings > Agent Runtime (MCP)** ou en ligne de commande :
  - `pyrevit configs agent policy readonly` : lecture seule
  - `pyrevit configs agent policy ask` : validation à chaque modification
  - `pyrevit configs agent policy auto` : sans validation (pratique pour filmer une démo, à utiliser seulement sur une copie du modèle)

## Sécurité et confidentialité

- Ce que l'IA lit dans votre modèle (noms, paramètres, résultats) est envoyé au fournisseur de l'IA (Anthropic, OpenAI). Vérifiez les règles de confidentialité de vos projets avant de l'utiliser sur un vrai projet.
- pyRevit garde l'historique des scripts exécutés pendant 14 jours dans `%APPDATA%\pyRevit\agent`.
- Faites vos premiers essais sur une copie de votre modèle.

## Skills inclus

| Skill | Rôle |
|---|---|
| `bimbridge` | Méthode de travail : unités métriques, construction par étapes taguées et rejouables, vérification par capture, réponses dans votre langue |
| `mep-review` | Revue MEP en lecture seule : contenu, connecteurs ouverts, éléments hors réseau, liste des réseaux, gaines et tuyaux non isolés, pentes d'évacuation, appareils sans circuit |

Les skills sont copiés dans `%APPDATA%\pyRevit\agent\skills`. Vous pouvez y ajouter les vôtres (un dossier avec un fichier `SKILL.md`).

## Mettre à jour

Relancez la commande d'installation. Elle met à jour les skills et la configuration sans rien dupliquer.

## Désinstaller

```powershell
irm https://raw.githubusercontent.com/kenpro0/bimbridge-mcp/main/uninstall.ps1 | iex
```

Retire les skills BIMBridge et les connexions MCP ajoutées, et désactive l'agent pyRevit. pyRevit reste installé.

## Dépannage

| Problème | Solution |
|---|---|
| « Revit is open » pendant l'installation | Fermez Revit et relancez la commande. |
| L'IA ne voit pas les outils `pyrevit` | Quittez complètement l'application (icône près de l'horloge > Quitter) et rouvrez-la. |
| « No running Revit » | Démarrez Revit, ou cliquez sur **pyRevit > Reload**. |
| Une modification semble bloquée | Revit attend votre validation (**Keep** / **Discard**). |
| Autre problème | Ouvrez une [issue](../../issues) en joignant le fichier `%TEMP%\bimbridge-install.log`. |

## Crédits et licence

- Serveur MCP et agent Revit : [pyRevit](https://github.com/pyrevitlabs/pyRevit), par pyRevitLabs (licence GPL-3.0).
- BIMBridge (installateur, skills, documentation) : licence MIT, voir [LICENSE](LICENSE).

---

## English

BIMBridge sets up the MCP server built into pyRevit 7 for Claude Desktop (free plan included), Claude Code and ChatGPT / Codex in one step, and adds BIMBridge skills: a metric, staged modeling method and a read-only MEP review.

- **With Claude Code**: ask it to install `https://github.com/kenpro0/bimbridge-mcp` by following [INSTALL.md](INSTALL.md).
- **Without it**: close Revit, then run `irm https://raw.githubusercontent.com/kenpro0/bimbridge-mcp/main/install.ps1 | iex` in PowerShell.

Then start Revit, restart your AI app, and ask: "Read the bimbridge skill, then describe my open Revit model." Model changes wait for your approval in Revit (Keep / Discard).
