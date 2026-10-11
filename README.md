### Hackathon BSA - Swissquote Track



# Tableau « réel / mocké »

Prototype de wallet self-custody avec récupération par gardiens (Swissquote Wallet Prize).
Réseau : **Ethereum Sepolia** (chain ID 11155111), le 2026-10-11.
Contrat : `0xEf3e5840A276E1Ff63901baa352577B2D14db701` (`src/Wallet.sol`).

## 1. Ce qui est réel (vérifiable sur Etherscan)

| Élément | Preuve |
|---|---|
| Déploiement du contrat sur un vrai testnet | Transaction de création, voir section 4 |
| Propriétaire et 3 gardiens inscrits dans la blockchain | `owner()` et `guardians(i)` lisibles par n'importe qui |
| Seuil 2 sur 3 appliqué par le contrat | Une seule approbation ne suffit pas (`Pas de recuperation prete`) ; un même gardien ne peut pas approuver deux fois (`Deja approuve`) |
| Délai avant finalisation appliqué par le contrat | Finalisation refusée avant `readyAt` |
| Changement de propriétaire sans changer l'adresse du wallet | `owner()` passe d'Alice à NEW, l'adresse reste identique |
| Anciennes signatures invalidées | Le nonce passe à 1 à la finalisation ; la signature de l'ancienne clé d'Alice est refusée |
| Transaction d'envoi signée par le nouveau propriétaire | `execute` : 0,001 ETH envoyé du wallet vers G3 |
| Anti-rejeu | Même signature rejouée : `Signature invalide` |
| Banque = relayeur, pas propriétaire | Sur Etherscan, l'expéditeur de `execute` est SQ (il paie le gas) ; la signature qui autorise est celle de NEW |
| Clé de déploiement protégée | Coffre chiffré Foundry (`cast wallet import`), jamais écrite dans une commande |
| Bibliothèques établies | OpenZeppelin (`ECDSA`, `MessageHashUtils`) ; aucune cryptographie maison |

## 2. Ce qui est mocké ou simplifié

| Élément | Ce qu'il y a dans le prototype | Ce que ferait la vraie version |
|---|---|---|
| Décision de Swissquote comme gardien | Une simple clé de test qui approuve quand on l'appelle | Serveur de gardien : contrôle d'identité (KYC, FaceID, appel), journal d'audit, validation humaine |
| Alice, G2 (iPad), G3 (proche), NEW, Mallory | Clés de test dans `.env` (ignoré par Git) | Clés/passkeys sur de vrais appareils ; le proche signe depuis son propre appareil |
| Clé propriétaire | Clé Ethereum de test (ECDSA) | Passkey WebAuthn (clé P-256 dans l'appareil, jamais exportée) |
| Rôles de SQ | Une seule clé joue déployeur, relayeur et gardien | Trois rôles séparés ; le serveur de gardien ne partage pas sa clé avec le relayeur |
| Relayeur / bundler | SQ envoie lui-même les transactions | Bundler ERC-4337 ; paymaster optionnel pour sponsoriser le gas |
| Délai de récupération | **12 secondes** (démo) | 24 h ou plus, avec alertes ; en démo, la fenêtre d'annulation est d'environ un bloc |
| Alertes à Alice | Absentes | Notification push/e-mail/SMS à chaque `approveRecovery`, sur plusieurs canaux |
| Application bancaire | Terminal (`cast`) | Application mobile Swissquote |
| ETH | ETH de test (faucet), sans valeur | Fonds réels (hors périmètre : pas de mainnet) |

## 3. Ce qui n'est pas fait (à ne pas présenter comme fait)

- **Pas ERC-4337** : `Wallet.sol` en imite l'idée (compte contrat, signature vérifiée par le compte, relayeur) mais n'a ni EntryPoint, ni bundler, ni paymaster, ni factory. Il n'est pas conforme au standard.
- **Pas de passkey / WebAuthn** : la clé propriétaire est une clé de test.
- **Code non vérifié sur Etherscan** (le bytecode est publié, pas le source).
- **Pas de tests automatiques Foundry** : les scénarios ont été rejoués à la main sur Sepolia.
- **Pas d'interface de démo** : démonstration en ligne de commande.
- **Limites connues du contrat** : deux gardiens complices pendant que le propriétaire ne regarde pas = prise de contrôle ; un gardien malveillant peut « griller » une récupération en proposant une autre adresse ; pas de limites de montant ; gardiens fixes (pas de remplacement) ; approbation possible au-delà du seuil (sans conséquence).
- **MPC / signatures à seuil** : écarté (à justifier dans le modèle de custody).
- **Sauvegarde Shamir / SLIP-39** : non implémentée.

## 4. Transactions de preuve (Sepolia)

| Moment du cycle de vie | Transaction |
|---|---|
| Financement de SQ par faucet (0,05 ETH) | `0x7b9652d7dfc36a2ceb164ad3b21c63ae7bb900a0b85c8534edf136e89f1fc20a` |
| Gas donné à G2 | `0x7710a33a859b784358f48df0e1651eb15a370aaa00aa862c97658ad490e67248` |
| Gas donné à G3 | `0x369cae67f4f1b6fcd857aa25b37b6e20ae20c039e570328a6106a96c73420b0b` |
| Gas donné à NEW | `0x38e9902a440ff06d8d908a81f63a38af054000261b9e2df74d01ebba1ea03bad` |
| **Création du wallet** (déploiement) | `0xfa2c6feb843682af96bdcdc962f373d581c02a9693aef59b2ec1cd908448f867` |
| Dépôt de 0,01 ETH dans le wallet | `0x40e7440b81f48ae3dbe821c9792b1de913e97e91013881182ee4144464cd5945` |
| **Scénario A** : approbation de SQ pour NEW | `0xa2e3c562cc4d7e0a18e774207526313276f0c67b2b13de49db86ffd26cf89b36` |
| Scénario A : approbation de G2 pour NEW | À COMPLÉTER |
| Scénario A : finalisation de la récupération | `0xfa2499bdcccd8870f9d049d0d341cf308cd2422cd8692ec2d6443e27e7ba9839` |
| **Envoi** : `execute` signé par NEW, relayé par SQ | `0x41e24adb0cafbf994861ea674843f1cb13af4ea2f49d46d1d365d2db80f48cc2` |
| **Scénario B** : approbation de SQ pour Mallory | `0xdc41599695cb7cffc3e626f143ff35bb026bb03d768c669160d5298f624cdd0f` |
| Scénario B : approbation de G3 pour Mallory | À COMPLÉTER |
| Scénario B : annulation par NEW (propriétaire) | À COMPLÉTER |

Lien type : `https://sepolia.etherscan.io/tx/` suivi du hash.

## 5. Où sont le pouvoir et les clés

- **Pouvoir de signer** : uniquement la clé du propriétaire (Alice, puis NEW après récupération). Swissquote ne peut pas déplacer de fonds.
- **Pouvoir de récupérer** : 2 gardiens sur 3, après le délai ; le propriétaire peut annuler pendant ce temps.
- **Pouvoir de Swissquote** : une voix sur trois, plus la possibilité de relayer et de payer le gas. Il ne peut ni changer un montant ou une destination signés, ni rejouer une signature, ni récupérer seul.


### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
