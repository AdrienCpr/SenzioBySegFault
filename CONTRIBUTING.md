# Contribuer à ChatISEN

## Branches

| Branche            | Rôle                                               | Qui merge dedans                    |
|--------------------|----------------------------------------------------|-------------------------------------|
| `main`             | Code en production. Toujours déployable.           | PR depuis `dev` (ou `hotfix/*`)     |
| `dev`              | Intégration continue de l'équipe. Base du staging. | PR depuis les branches de travail   |
| `feat/<ticket>-…`  | Nouvelle fonctionnalité                            | —                                   |
| `fix/<ticket>-…`   | Correction de bug                                  | —                                   |
| `chore/<ticket>-…` | Infra, CI, config, dépendances                     | —                                   |
| `docs/<ticket>-…`  | Documentation                                      | —                                   |
| `hotfix/<ticket>-…`| Correctif urgent partant de `main`                 | PR vers `main`, puis report sur `dev` |

Exemples : `feat/CHAT-12-historique-salon`, `chore/INFRA-01-monorepo`.

Flux normal :

```
feat/XXX ──PR──▶ dev ──PR (release)──▶ main
```

1. Partir de `dev` à jour : `git switch dev && git pull && git switch -c feat/CHAT-12-…`
2. Commits petits et fréquents (voir convention ci-dessous).
3. Pousser et ouvrir une PR **vers `dev`** en remplissant le template.
4. Après approbation et CI verte, merger (squash recommandé) et supprimer la branche.

## Règles de protection (rulesets GitHub)

Définies dans [.github/rulesets/](.github/rulesets/) :

| Règle                                        | `main` | `dev` |
|----------------------------------------------|:------:|:-----:|
| Push direct interdit (PR obligatoire)        | ✅     | ✅    |
| Approbations requises                        | 1      | 1     |
| Approbation invalidée si nouveau push        | ✅     | —     |
| Conversations résolues avant merge           | ✅     | ✅    |
| Check `CI OK` obligatoire                    | ✅     | ✅    |
| Branche à jour avec la cible avant merge     | ✅     | —     |
| Force push et suppression interdits          | ✅     | ✅    |

### Appliquer / mettre à jour les règles

Il faut être **admin du dépôt**. Avec la [GitHub CLI](https://cli.github.com/) :

```bash
gh auth login
gh api -X POST repos/AdrienCpr/SenzioBySegFault/rulesets --input .github/rulesets/main.json
gh api -X POST repos/AdrienCpr/SenzioBySegFault/rulesets --input .github/rulesets/dev.json
# Vérifier
gh api repos/AdrienCpr/SenzioBySegFault/rulesets
```

Pour modifier un ruleset existant : `gh api -X PUT repos/AdrienCpr/SenzioBySegFault/rulesets/<id> --input …`.

Sans CLI : *Settings → Rules → Rulesets → New ruleset → Import a ruleset* et choisir le fichier JSON.

> Les rulesets sont gratuits sur un dépôt **public**. Sur un dépôt privé, il faut un plan GitHub Pro/Team
> (ou GitHub Education).

Réglages à faire aussi dans *Settings → General → Pull Requests* :
- autoriser **Squash merge** (et éventuellement Merge commit pour `dev → main`), désactiver Rebase merge ;
- cocher **Automatically delete head branches**.

## Convention de commits

[Conventional Commits](https://www.conventionalcommits.org/fr/) avec le périmètre de l'app :

```
<type>(<scope>): <description>

feat(backend): ajouter l'historique des salons
fix(frontend): corriger la reconnexion Socket.IO
chore(infra): ajouter le VPC Terraform
```

Types : `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`.
Scopes : `frontend`, `backend`, `worker-qos`, `infra`, `ci`, `docs`.

## Pull requests

- Une PR = un ticket. Référencer le ticket dans le titre : `[INFRA-01] Initialiser le monorepo`.
- Remplir le [template](.github/pull_request_template.md), lier l'issue (`Closes #…`).
- La CI ne lance que les jobs des zones modifiées ; le job `CI OK` agrège le résultat.
- Aucun secret dans le code : utiliser les `.env.example` et Secret Manager.
