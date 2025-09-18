# Tests Manuels - Système de Playlist

## 🎯 Vue d'ensemble

Ce document contient les procédures de test manuel pour valider le bon fonctionnement du système de playlist et éviter les régressions.

## ✅ Test Suite Complète

### Test 1 : Ajout depuis catalogue vers playlist vide

**Objectif** : Vérifier l'ajout d'éléments dans une playlist vide

**Prérequis** :
- Application lancée
- Playlist vide
- Catalogue visible avec au moins 3 éléments

**Procédure** :
1. Glisser le premier élément du catalogue vers la zone playlist vide
2. Vérifier qu'un seul élément apparaît dans la playlist
3. Répéter avec 2 autres éléments différents

**Résultat attendu** :
- ✅ Chaque drag ajoute exactement 1 élément
- ✅ Aucun doublon involontaire
- ✅ Logs montrent : `[DRAG] 🚫 Drop ignoré car un drop est déjà en cours` si protection activée

**Logs à surveiller** :
```
[DRAG] 🎬 Catalogue - DragStart pour: <nom_fichier>
[DRAG] 📋 Drop sur zone playlist
[FRONTEND] ⚠️ addToQueue appelé avec: 1 items
[QUEUE] ⚠️ queue:addMany appelé avec: 1 items
[DRAG] 🔄 Reset drag state - all types
```

### Test 2 : Ajout depuis catalogue vers playlist existante

**Objectif** : Vérifier l'ajout d'éléments dans une playlist non-vide

**Prérequis** :
- Playlist contenant déjà 2-3 éléments
- Catalogue visible

**Procédure** :
1. Noter le nombre actuel d'éléments dans la playlist
2. Glisser un nouvel élément du catalogue vers la playlist
3. Vérifier que le compteur augmente de 1 exactement

**Résultat attendu** :
- ✅ Le nouvel élément est ajouté à la fin de la playlist
- ✅ Les éléments existants restent inchangés
- ✅ Compteur cohérent

### Test 3 : Réorganisation dans la playlist

**Objectif** : Vérifier la réorganisation par drag & drop

**Prérequis** :
- Playlist avec au moins 4 éléments
- Éléments clairement identifiables (titres différents)

**Procédure** :
1. Noter l'ordre initial des éléments
2. Glisser l'élément #3 vers la position #1
3. Vérifier le nouvel ordre
4. Glisser l'élément maintenant en position #4 vers la position #2

**Résultat attendu** :
- ✅ L'ordre change selon les déplacements
- ✅ Aucun élément dupliqué ou perdu
- ✅ Interface réactive sans lag

**Logs à surveiller** :
```
[control] DROP - draggedItem: 3 dropIndex: 1
[control] Réorganisation playlist: 3 -> 1
[control] Appel IPC queue:reorder en cours...
[control] Résultat reçu du backend: {items: Array(4), ...}
```

### Test 4 : Protection contre drops multiples

**Objectif** : Vérifier la protection contre les événements multiples

**Prérequis** :
- DevTools ouvertes pour voir les logs en temps réel
- Playlist vide ou avec peu d'éléments

**Procédure** :
1. Effectuer un drag & drop très rapide (mouvement brusque)
2. Observer les logs dans la console
3. Vérifier le nombre d'éléments ajoutés

**Résultat attendu** :
- ✅ Un seul élément ajouté malgré le mouvement rapide
- ✅ Logs montrent : `[DRAG] 🚫 Drop ignoré car un drop est déjà en cours`
- ✅ Pas de doublons dans la playlist

### Test 5 : Actions rapides successives

**Objectif** : Test de stress avec actions rapides

**Prérequis** :
- Catalogue avec plusieurs éléments
- Playlist vide

**Procédure** :
1. Glisser rapidement 5 éléments différents en succession
2. Attendre 2 secondes entre chaque drag
3. Compter les éléments finaux dans la playlist

**Résultat attendu** :
- ✅ Exactement 5 éléments dans la playlist
- ✅ Tous les éléments sont différents (si sources différentes)
- ✅ Aucun message d'erreur

### Test 6 : Interruption de drag

**Objectif** : Vérifier la gestion des drags interrompus

**Prérequis** :
- Catalogue et playlist visibles

**Procédure** :
1. Commencer un drag depuis le catalogue
2. Pendant le drag, appuyer sur Escape ou relâcher en dehors de la zone de drop
3. Vérifier l'état de la playlist
4. Effectuer un drag normal ensuite

**Résultat attendu** :
- ✅ Aucun élément ajouté lors de l'interruption
- ✅ État de drag correctement réinitialisé
- ✅ Drag suivant fonctionne normalement

### Test 7 : Doublons volontaires

**Objectif** : Vérifier qu'on peut ajouter le même fichier plusieurs fois

**Prérequis** :
- Catalogue visible
- Playlist vide

**Procédure** :
1. Glisser le même élément du catalogue 3 fois de suite
2. Vérifier le contenu de la playlist

**Résultat attendu** :
- ✅ 3 instances du même élément dans la playlist
- ✅ Chaque instance est bien distincte (peut avoir des IDs différents)
- ✅ Possibilité de les réorganiser indépendamment

## 🚨 Test de Régression Critique

### Test Express (5 minutes)

**À effectuer avant chaque commit touchant au drag & drop** :

1. **Test rapide doublons** :
   - Glisser 1 élément → Vérifier 1 seul ajouté ✅
   - Logs montrent protection activée si nécessaire ✅

2. **Test rapide réorganisation** :
   - Déplacer 1 élément dans playlist → Vérifier ordre changé ✅
   - Aucun élément perdu/dupliqué ✅

3. **Test rapide stress** :
   - 3 drags rapides successifs → Vérifier 3 éléments ajoutés ✅

### Test Complet (15 minutes)

**À effectuer avant chaque release** :

- Tous les tests 1-7 ci-dessus
- Test avec playlist de 20+ éléments
- Test sur différentes tailles de fenêtre
- Vérification des performances (pas de lag notable)

## 🔍 Critères de validation

### ✅ Critères PASS

- **Fonctionnel** : Toutes les actions produisent le résultat attendu
- **Performance** : Aucune latence > 200ms perceptible
- **Logs** : Aucun message d'erreur, logs cohérents
- **État** : Interface toujours cohérente avec l'état réel
- **Mémoire** : Pas d'accumulation d'event listeners

### ❌ Critères FAIL

- **Doublons involontaires** : Plus d'éléments ajoutés que prévu
- **Éléments perdus** : Moins d'éléments que prévu
- **Interface gelée** : Lag > 200ms ou non-réactivité
- **Erreurs JS** : Exceptions dans la console
- **État incohérent** : Affichage ≠ état réel

## 📊 Reporting des résultats

### Template de rapport

```markdown
## Test Manual Report - Date: YYYY-MM-DD

### Environnement
- OS: Windows/macOS/Linux
- Node.js: X.X.X
- Electron: X.X.X
- Build: Production/Debug

### Résultats

| Test | Status | Notes |
|------|--------|-------|
| Test 1: Ajout playlist vide | ✅/❌ | |
| Test 2: Ajout playlist existante | ✅/❌ | |
| Test 3: Réorganisation | ✅/❌ | |
| Test 4: Protection drops multiples | ✅/❌ | |
| Test 5: Actions rapides | ✅/❌ | |
| Test 6: Interruption drag | ✅/❌ | |
| Test 7: Doublons volontaires | ✅/❌ | |

### Problèmes identifiés
- [Décrire tout problème rencontré]

### Logs pertinents
```
[Coller les logs problématiques]
```

### Actions recommandées
- [Actions à prendre suite aux tests]
```

## 🛠️ Setup de test

### Préparation environnement

```bash
# 1. Build clean
npm run clean  # si disponible
npm run build

# 2. Lancer avec logs
npx electron dist/main/index.js --enable-logging

# 3. Ouvrir DevTools pour logs temps réel
# Ctrl+Shift+I (Windows/Linux) ou Cmd+Option+I (macOS)
```

### Configuration recommandée

- **DevTools ouverts** : Pour voir les logs en temps réel
- **Console filtrée** : Filtrer sur `[DRAG]`, `[QUEUE]`, `[FRONTEND]`
- **Fenêtre redimensionnée** : Taille confortable pour voir catalogue et playlist
- **Curseur lent** : Mouvements délibérés pour bien observer les réactions

## 📝 Notes pour testeurs

### Bonnes pratiques

1. **Mouvements délibérés** : Éviter les gestes trop rapides lors des tests de base
2. **Observer les logs** : Toujours vérifier que les logs correspondent à l'action
3. **État initial propre** : Commencer chaque test avec un état connu
4. **Documenter les anomalies** : Noter tout comportement inattendu même mineur

### Signes d'alerte

- Lag perceptible lors des drags
- Messages d'erreur dans la console
- Différence entre nombre d'éléments attendu/réel
- Interface qui ne se met pas à jour
- Logs montrant des patterns répétitifs anormaux

---

**Dernière mise à jour** : Septembre 2025  
**Version** : 1.0  
**Maintenu par** : Équipe QA
