# Documentation Technique

## Architecture Sécurisée

### Chiffrement
- **AES-256-GCM** : Chiffrement authenticated streaming
- **scrypt KDF** : Dérivation de clé robuste (N=32768, r=8, p=1)
- **Ed25519** : Signatures cryptographiques licence

### Protection Electron
- **CSP strict** : Content Security Policy verrouillé
- **Sandbox renderer** : Isolation processus de rendu
- **Anti-debug** : Protection développeur mode production
- **Permission lock** : Restriction accès système

### Vault Structure
```
vault/
├── .vault/
│   ├── device.tag      # Device binding
│   ├── manifest.bin    # Index chiffré
│   └── license.bin     # Licence sécurisée
├── license.json        # Licence readable
├── media/
│   └── *.enc          # Fichiers chiffrés
```

### Validation Pipeline
1. **Device binding** check
2. **License signature** validation  
3. **License expiry** check
4. **Manifest integrity** check
5. **Media decryption** streaming

## Red Team Validation ✅

- ✅ Licence expirée → BLOCKED
- ✅ Licence supprimée → BLOCKED  
- ✅ Vault corrompu → BLOCKED
- ✅ Device mismatch → BLOCKED
- ✅ Signature invalide → BLOCKED

---
Build: 2025-09-17T16:23:01.134Z
Version: 0.1.0 RC
