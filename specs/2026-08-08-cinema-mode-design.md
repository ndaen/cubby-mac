# Cinema Mode — design spec

Date: 2026-08-08
Statut: approuvé, prêt pour plan d'implémentation

## Contexte et objectif

Cubby est une app macOS menu bar/encoche existante (Swift Package Manager, onglets Bac/Music/Settings). L'objectif est d'ajouter un nouvel onglet "Cinéma" qui prépare le Mac pour regarder un film ou une série : masquer le curseur inactif, éteindre le rétroéclairage clavier, empêcher la mise en veille, et activer un mode Focus — automatiquement quand une app vidéo passe en plein écran, ou manuellement.

**Hors périmètre v1** : amélioration/EQ du son système. Cette fonctionnalité nécessiterait un driver audio virtuel (à l'image d'eqMac, open source) plutôt qu'un simple appel d'API — complexité largement supérieure au reste (signature, HAL plugin, notarisation). Pourra être évaluée dans un projet séparé si le besoin se confirme.

## Emplacement

Nouvel onglet "Cinéma" dans l'app Cubby existante (`notch/`), à côté de Bac et Music. Réutilise l'infrastructure déjà en place (fenêtre menu bar, Settings, cycle de vie de l'app) plutôt qu'un nouveau projet indépendant.

## Déclencheurs

- **Manuel** : toggle ON/OFF depuis l'onglet Cinéma.
- **Automatique** : quand une app d'une whitelist passe en plein écran — QuickTime Player, VLC, IINA, Safari, Google Chrome, Arc (sans distinction du site web dans le navigateur). Sortie de plein écran de cette app → désactivation automatique.
- Les deux déclencheurs pilotent le même état binaire (`CinemaModeController.isActive`) ; pas de distinction entre origine manuelle et automatique une fois l'état changé.

## Architecture & composants

**`CinemaModeController`**
État simple (`@Published isActive: Bool`). Reçoit les demandes d'activation/désactivation (manuelles ou automatiques) et pilote les 4 gestionnaires ci-dessous dans l'ordre. Chaque gestionnaire sauvegarde son état précédent avant modification et le restaure à la désactivation.

**`CursorIdleHider`**
Timer + `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)`. Cache le curseur (`CGDisplayHideCursor`) après ~3s d'inactivité souris, le réaffiche immédiatement au moindre mouvement. Aucune permission macOS requise.

**`KeyboardBacklightManager`**
Lit le niveau de rétroéclairage clavier actuel via IOKit, le met à 0 à l'activation, restaure la valeur d'origine à la désactivation. Si le Mac n'a pas de clavier rétroéclairé (Mac de bureau, clavier externe non compatible), échoue silencieusement sans bloquer les autres briques.

**`SleepPreventer`**
Maintient une `IOPMAssertion` (API publique, celle utilisée par `caffeinate`) tant que le mode est actif ; la relâche à la désactivation.

**`FocusModeBridge`**
Exécute `shortcuts run "Cinema Mode On"` à l'activation et `shortcuts run "Cinema Mode Off"` à la désactivation (noms des raccourcis configurables dans Settings). Prérequis côté utilisateur : créer une fois ces deux Raccourcis macOS (chacun avec une seule action "Régler le Focus"). Si le raccourci est absent ou échoue, l'erreur est loggée et n'empêche pas les autres briques de fonctionner.

**`FullscreenWatcher`**
Écoute les notifications `NSWorkspace` pour savoir quelle app whitelistée est au premier plan, puis vérifie par polling (~1s, via `CGWindowListCopyWindowInfo`) si sa fenêtre occupe tout l'écran. Bascule automatiquement `CinemaModeController`. Nécessite la permission Accessibilité (Réglages Système). Si la permission n'est pas accordée, cette brique reste inactive proprement — seul le toggle manuel fonctionne, et l'UI affiche un lien vers Réglages Système pour l'accorder.

Choix de polling plutôt qu'un `AXObserver` événementiel : implémentation nettement plus simple (~10 lignes) pour une latence de détection (~1s) sans impact perceptible sur un usage cinéma. Outil personnel, pas de contrainte de réactivité forte.

**`CinemaTabView`**
UI SwiftUI de l'onglet : toggle ON/OFF, statut de chaque brique (curseur/clavier/veille/focus), lien "Autoriser l'Accessibilité" si la permission manque.

## Flux de données

Deux entrées vers `CinemaModeController.setActive(_:)` : le toggle manuel dans `CinemaTabView`, et `FullscreenWatcher` (entrée/sortie de plein écran d'une app whitelistée). Le contrôleur ne distingue pas l'origine de la demande — il active/désactive les 4 managers dans l'ordre et publie son état pour que l'UI reste synchronisée quelle que soit la source du changement. En cas de conflit (désactivation auto après activation manuelle), le dernier état gagne — un seul état binaire, pas de logique de priorité à gérer.

## Gestion des erreurs

- **Accessibilité non accordée** → `FullscreenWatcher` inactif, toggle manuel intact, lien vers Réglages Système visible dans l'onglet.
- **`shortcuts run` échoue ou raccourci absent** → erreur loggée, capturée, n'empêche pas l'activation des 3 autres briques.
- **Rétroéclairage clavier indisponible** → échec silencieux, pas de blocage.
- **Cubby quitte pendant que Cinema Mode est actif** → `applicationWillTerminate` restaure systématiquement curseur, rétroéclairage clavier et relâche l'assertion de veille, pour ne jamais laisser le système dans un état dégradé après un crash ou un quit.

## Tests

Module essentiellement d'intégration système (IOKit, Accessibility, NSWorkspace) — peu de valeur à unit-tester. Vérification manuelle ciblée :

- Toggle manuel ON/OFF → curseur disparaît après ~3s d'inactivité et réapparaît au mouvement ; rétroéclairage clavier s'éteint puis revient à sa valeur d'origine ; `pmset -g assertions` confirme l'assertion de veille active puis relâchée.
- Lancer une vidéo en plein écran dans chacune des apps whitelistées (QuickTime, VLC, IINA, Safari, Chrome, Arc) → activation automatique ; sortie du plein écran → désactivation automatique.
- Retirer la permission Accessibilité → toggle manuel fonctionne toujours, auto-détection désactivée proprement, lien de permission visible.
- Renommer ou supprimer le Raccourci Focus → le reste du mode s'active quand même, pas de crash.
