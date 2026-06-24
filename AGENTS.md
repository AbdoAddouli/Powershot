## Salesforce Orgs

| Alias | Username | Purpose |
|-------|----------|---------|
| `ouil gas` | addouliabdo9.76deae143000@agentforce.com | Main Energy project org — all O&G objects, Apex, triggers, LWCs, permission sets, flows, apps deployed here |
| `agentforce` | addouli@agentfoece.com | Different org — do NOT confuse with `ouil gas` |

## Deployment Commands

- Deploy to main org: `sf project deploy start -d "force-app\main\default\PATH" -o "ouil gas"`
- Run tests: `sf apex run test -o "ouil gas"`
