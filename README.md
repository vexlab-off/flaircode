# Flair Code

L'éditeur de code de la suite flair : la même identité, le même thème, et une application
à part qui s'utilise toute seule.

- Arborescence du projet, onglets, un éditeur par fichier avec son propre historique
  d'annulation.
- Coloration syntaxique de C/C++, QML, JavaScript/TypeScript, Python, Rust, Go, Java,
  Kotlin, Dart, Shell, HTML, CSS, JSON, Markdown, YAML, TOML.
- Numéros de ligne, ligne courante, indentation automatique, Tab/Maj+Tab sur plusieurs
  lignes, commentaire des lignes avec Ctrl+/ (Ctrl+: en AZERTY).
- Aller à un fichier (Ctrl+P), rechercher et remplacer (Ctrl+F, Ctrl+H).
- Enregistrement atomique : le fichier est écrit à côté puis renommé, jamais à moitié.
- Un fichier modifié sur le disque se recharge tout seul s'il n'a pas de modification
  en cours ; sinon un bandeau propose de recharger ou de garder ta version.
- Fermer un onglet ou quitter avec des fichiers non enregistrés demande d'abord.
- Les fichiers binaires ne sont pas ouverts, pour ne pas les abîmer.
- Les logos des langages dans l'arborescence et les onglets, la branche Git dans la barre
  d'état, la couleur d'accent partagée avec flair (réglages de flair).

`flaircode dossier` ouvre un projet ; `flaircode fichier` ouvre le projet qui le contient
(son dépôt Git) avec le fichier. Ctrl+O ouvre un dossier avec le sélecteur du système.

## Raccourcis

| Touche | Action |
|---|---|
| Ctrl+O | Ouvrir un dossier |
| Ctrl+L | Ouvrir un chemin |
| Ctrl+P | Aller à un fichier |
| Ctrl+N | Nouveau fichier |
| Ctrl+S / Ctrl+Maj+S | Enregistrer / tout enregistrer |
| Ctrl+W | Fermer l'onglet |
| Ctrl+Tab / Ctrl+Maj+Tab | Onglet suivant / précédent |
| Ctrl+Z / Ctrl+Maj+Z | Annuler / rétablir |
| Tab / Maj+Tab | Indenter / désindenter |
| Ctrl+/ (Ctrl+:) | Commenter les lignes |
| Ctrl+F / Ctrl+H | Rechercher / remplacer |
| F3 / Maj+F3 | Résultat suivant / précédent |
| Ctrl+B | Arborescence |
| Ctrl+= / Ctrl+- / Ctrl+0 | Taille du texte |
| F1 | Aide |
| Ctrl+Q | Quitter |

## Développement

```sh
bin/build      # build/flaircode
bin/test       # tests Qt Test, hors écran
bin/install    # paquet Arch : lanceur, icône
```
