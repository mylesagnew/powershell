# PowerShell admin scripts

A small collection of PowerShell scripts I use for Azure and Cloudflare admin: firewall policy export and sync, per-user Key Vault provisioning from an Entra ID group, a Sentinel-reader app registration, and Cloudflare DNS/Worker backups.

These are working scripts, not a packaged module. Read each one before you run it. Several create, change or **delete** Azure resources.

## Requirements

- PowerShell 7+
- The [Az PowerShell module](https://learn.microsoft.com/powershell/azure/install-azure-powershell) (`Install-Module Az -Scope CurrentUser`) for the Azure scripts
- An account with rights for the action: Network Contributor for firewall policies, Owner or User Access Administrator to create role assignments, and Entra ID read access for group membership

Each Azure script except `restartfw.ps1` calls `Connect-AzAccount` itself.

## Configuration

Scripts read settings from a `.env` file **in the current directory**. Each folder has a `.env.example`. Copy it and fill it in:

```powershell
Copy-Item .env.example .env
```

`.env` is gitignored. Never commit a filled-in copy.

## Scripts

### `azure/firewalls/`

| Script | What it does | Settings |
|---|---|---|
| `exportrules.ps1` | Exports every rule collection group in one Azure Firewall policy (network, application and NAT rules) to CSV files under `EXPORT_PATH` | `SUBSCRIPTION_ID`, `RESOURCE_GROUP`, `FIREWALL_POLICY_NAME`, `EXPORT_PATH` |
| `fwsync.ps1` | Copies rule collection groups from a source firewall policy to a target policy, across subscriptions if needed. Only creates groups missing from the target. Existing groups with the same name are left unchanged, not updated. | `SOURCE_*`, `TARGET_*`, `EXPORT_PATH` |
| `restartfw.ps1` | Stops an Azure Firewall, waits 30 s, then starts it again. Causes an outage while it runs. Run `Connect-AzAccount` first. | Parameters: `.\restartfw.ps1 <FirewallName> <ResourceGroup>` |

### `azure/keyvault/`: per-user Key Vaults from an Entra ID group

For every member of `ENTRA_GROUP_NAME`, these use the naming convention `C00-<initials>-<DisplayName>-rg` for the resource group and `<CXX>-<initials>-KV1` for the vault.

| Script | What it does |
|---|---|
| `userkeyvault.ps1` | Creates each member's resource group in `AZURE_REGION` and grants them **Key Vault Secrets Officer** on it |
| `kvuserrole.ps1` | Grants each member **Key Vault Secrets User** on their own vault |
| `removalscript.ps1` | **Deletes** each member's Key Vault and resource group (`-Force`). Irreversible. |

Settings: `ENTRA_GROUP_NAME`, `AZURE_REGION`, `KEYVAULT_SKU`, `CXX`.

### Root scripts

| Script | What it does |
|---|---|
| `userkeyvault.ps1` | Earlier version of the above: one resource group per member, named from their UPN, in East US, with Key Vault Secrets Officer. Group name is hard-coded at the top of the file. |
| `keyvault-reverse.ps1` | Undoes `userkeyvault.ps1`: removes the role assignment and **deletes** each member's resource group |
| `my-appregistration.ps1` | Creates an app registration and service principal, stores a client secret in Key Vault, and assigns **Azure Sentinel Reader** |

### `cloudflare/`

| Script | What it does |
|---|---|
| `cf-backup.ps1` | Exports every zone's DNS records to `./domains/<zone>_<timestamp>.txt` |
| `cf-fullbackup.ps1` | Same, plus each zone's Worker scripts to `./workers/` |

Settings: `CLOUDFLARE_USER_EMAIL`, `CLOUDFLARE_API_KEY`.

## Known issues

- **Cloudflare scripts use the Global API Key.** That key has full account access. For DNS-only backups, use [cloudflare-backup](https://github.com/mylesagnew/cloudflare-backup), which needs only a read-only scoped API token.
- **`my-appregistration.ps1` is a draft.** It expects `.env` as JSON with a `KeyValuePairs` object, not `KEY=value` lines. Also, `Get-Random -Count 16` does not produce a strong secret. Let `New-AzADAppCredential` generate the secret instead. Test it in a non-production tenant first.
- The Key Vault scripts assume every member has a given name and surname. Members without either are skipped.
- No `-WhatIf` / dry-run support yet.

## Licence

Public domain under [the Unlicense](LICENSE).
