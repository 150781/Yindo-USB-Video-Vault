param(
  [Parameter(Mandatory=$true)][string]$IncidentId,
  [Parameter(Mandatory=$true)][string]$Title,
  [Parameter()][string]$OutDir = ".\out\postmortems"
)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$filename = "postmortem-$IncidentId-$timestamp.md"
$outPath = "$OutDir\$filename"

$template = @"
# Post-Mortem: $Title

**Incident ID:** $IncidentId  
**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm")  
**Auteur:** $env:USERNAME  

## Résumé Exécutif
[Courte description de l'incident et de son impact]

## Timeline
| Heure | Événement |
|-------|-----------|
| [HH:MM] | [Description] |

## Impact
- **Utilisateurs affectés:** [Nombre/Pourcentage]
- **Services touchés:** [Liste]
- **Durée totale:** [Durée]
- **Perte estimée:** [Si applicable]

## Cause Racine
[Analyse détaillée de la cause principale]

## Actions Immédiates
- [ ] [Action 1]
- [ ] [Action 2]

## Actions de Prévention
- [ ] [Action préventive 1] - Assigné à: [Nom] - Échéance: [Date]
- [ ] [Action préventive 2] - Assigné à: [Nom] - Échéance: [Date]

## Leçons Apprises
1. [Leçon 1]
2. [Leçon 2]

## Données Techniques
### Logs Pertinents
```
[Extraits de logs critiques]
```

### Métriques
- [Métrique 1]: [Valeur]
- [Métrique 2]: [Valeur]

### Configuration
[Changements de configuration relevés]

## Validation
- [ ] Révision technique (Équipe SRE)
- [ ] Révision managériale
- [ ] Actions de suivi créées
- [ ] Communication aux parties prenantes

**Réviseurs:** 
- Technique: [Nom]
- Management: [Nom]

**Date de publication:** [À compléter]
"@

$template | Out-File -Encoding UTF8 $outPath
Write-Host "Post-mortem template créé: $outPath" -ForegroundColor Green
Write-Host "Ouvrir avec: notepad `"$outPath`"" -ForegroundColor Cyan
exit 0