# Test Manuel - Sécurité DisplayWindow

## ✅ Pré-requis validés
- [x] Application lancée avec succès
- [x] Licence sécurisée validée (ID: lic_a0f44f454a2bec70)  
- [x] Device binding fonctionnel (968f7e11)
- [x] IPC Security handlers enregistrés
- [x] 4 vidéos disponibles dans le catalogue

## 🎯 Tests de sécurité à effectuer

### 1. Test Watermark
**Action :** Ouvrir une vidéo depuis la fenêtre de contrôle
**Vérifier :**
- [ ] Watermark visible sur la DisplayWindow (coin supérieur droit)
- [ ] Texte du watermark contient l'ID de licence : "lic_a0f44f454a2bec70"
- [ ] Watermark semi-transparent et discret

### 2. Test Anti-Capture
**Action :** Ouvrir DisplayWindow et tenter captures d'écran
**Vérifier :**
- [ ] Capture d'écran système (PrintScreen) = écran noir ou erreur
- [ ] Capture via outils tiers = protection active
- [ ] Message d'alerte dans la console si capture détectée

### 3. Test Kiosk Mode  
**Action :** DisplayWindow en plein écran
**Vérifier :**
- [ ] Alt+Tab désactivé (pas de changement de fenêtre)
- [ ] Alt+F4 désactivé (fermeture impossible)
- [ ] Win+D désactivé (bureau inaccessible)
- [ ] Échap fonctionne toujours (sortie plein écran)

### 4. Test Anti-Debug
**Action :** Ouvrir DevTools sur DisplayWindow
**Vérifier :**
- [ ] F12 désactivé
- [ ] Ctrl+Shift+I désactivé  
- [ ] Menu contextuel "Inspect" absent
- [ ] DevTools n'apparaît pas

### 5. Test SecurityControl UI
**Action :** Dans la fenêtre de contrôle, section Security
**Vérifier :**
- [ ] État de sécurité affiché (Active/Inactive)
- [ ] Boutons de contrôle présents
- [ ] Bouton "Test Violation" fonctionnel
- [ ] Logs de sécurité visibles

## 📋 Instructions détaillées

1. **Lancer l'app** (déjà fait)
2. **Ouvrir une vidéo :** Cliquer sur "Play" dans la liste
3. **Vérifier DisplayWindow :** Nouvelle fenêtre vidéo avec sécurité
4. **Tester features :** Essayer chaque test ci-dessus
5. **Vérifier Security UI :** Dans fenêtre contrôle, section Security

## 🔍 Logs attendus

Lors du test, surveiller la console pour :
```
[SECURITY] DisplayWindow créée avec protection maximale
[SECURITY] Anti-capture activé
[SECURITY] Kiosk mode activé
[SECURITY] Watermark affiché
[SECURITY] Anti-debug activé
```

## ⚠️ Points critiques

- **DisplayWindow** doit être distincte de la fenêtre de contrôle
- **Toutes protections** actives simultanément
- **Performance** fluide malgré les protections
- **UX** : Sortie plein écran avec Échap toujours possible
