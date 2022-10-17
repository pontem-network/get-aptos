# Get `aptos` action

This GitHub Action delivers specified [`aptos`] release for a Aptos network.

[`aptos`]: https://github.com/aptos-labs/aptos-core

> Please note that this is an initial release and will be improved as the Aptos team make decisions on versioning, naming releases etc.

## Parameters

- `version` - Specified version of the release. Optional. Default value is `latest`.
- `prerelease` - Allow pre-release. Default value is `false`.
- `token` - GITHUB_TOKEN. Optional.
- `prover` - Installs Move prover tools (z3, cvc5, dotnet, boogie). Default value is `false`.

## Usage Example

Download the latest version of aptos

```yaml
- name: get aptos
  uses: pontem-network/get-aptos@main
```

Download a specific version of aptos

You can see all available versions [here](https://github.com/aptos-labs/aptos-core/releases?q=cli&expanded=true)

```yaml
- name: get aptos
  uses: pontem-network/get-aptos@main
  with:
    version: aptos-cli-v0.3.9
```

Allow downloading pre-releases

```yaml
- name: get aptos
  uses: pontem-network/get-aptos@main
  with:
    prerelease: "true"
```

Download a specific version of aptos and token

```yaml
- name: get aptos
  uses: pontem-network/get-aptos@main
  with:
    version: aptos-cli-v0.3.9
    token: ${{ secrets.GITHUB_TOKEN }}
```

Install Move prover tools (z3, cvc5, dotnet, boogie)

```yaml
- name: get aptos
  uses: pontem-network/get-aptos@main
  with:
    prover: "true"
```
