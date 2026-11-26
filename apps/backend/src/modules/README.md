# Modules métier

Le backend est un **monolithe modulaire** : un seul processus Node.js, un seul déploiement,
mais des modules métier séparés qui ne communiquent que par leurs interfaces publiques.

| Dossier     | Module               | Responsabilité                       |
|-------------|----------------------|--------------------------------------|
| `rooms/`    | Salons et messages   | Membres, historique                  |
| `identity/` | Identité et accès    | Profils et rôles (SSO Entra ID)      |
| `files/`    | Fichiers             | Droits et métadonnées (Cloud Storage)|
| `realtime/` | Temps réel           | Présence et diffusion (Socket.IO)    |
| `calls/`    | Appels et QoS        | Signalisation WebRTC et TURN         |

## Règles

- Chaque module **pilote ses propres données** (ses tables / son dépôt PostgreSQL).
- Un module n'importe **que** le fichier `index.ts` d'un autre module (son interface publique),
  jamais ses fichiers internes ni ses tables.
- Les points d'entrée (`src/entrypoints/` : REST Fastify, Socket.IO) valident le jeton Entra,
  construisent le contexte utilisateur, puis appellent les modules.
- Le code transverse (connexion PostgreSQL, stockage objet, métriques, logs) vit dans `src/shared/`.
