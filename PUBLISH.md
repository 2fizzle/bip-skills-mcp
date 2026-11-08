# Publication — MCP Registry

1. (Fait) Namespace : io.github.2fizzle/bip-skills-mcp, paquet @2fizzle/bip-skills-mcp.
2. Créer le dépôt GitHub `bip-skills-mcp` et y pousser ce dossier (sans node_modules ni dist).
3. `npm install` puis `npm login` puis `npm publish --access public`
   (prepublishOnly lance build + smoke test).
4. Installer mcp-publisher (Windows, PowerShell) :
   `$arch = if ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq "Arm64") { "arm64" } else { "amd64" }; Invoke-WebRequest -Uri "https://github.com/modelcontextprotocol/registry/releases/latest/download/mcp-publisher_windows_$arch.tar.gz" -OutFile "mcp-publisher.tar.gz"; tar xf mcp-publisher.tar.gz mcp-publisher.exe`
5. `mcp-publisher login github` puis `mcp-publisher publish`
6. Vérifier : `curl "https://registry.modelcontextprotocol.io/v0.1/servers?search=io.github.MONUSER/bip-skills-mcp"`

Pour chaque nouvelle version : incrémenter `version` dans package.json ET server.json (les deux champs version de server.json).
