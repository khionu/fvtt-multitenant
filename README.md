# My v2 Multitenant Foundry setup

## Goals

- Automated install and deployment of Foundry
- Supervision
- Automated backups
- Automated SSL certs
- Low maintenance overhead
- Access for tenants to remote backups
- Share immutable access to assets
- Invite service + setup wizard for tenants

## Non-goals

- Infrastructure provisioning
- Self-service allocation

## Architecture

- :snowflake: NixOS Flake :snowflake:
- Keep this repo relatively agnostic to deployment context - cloud or baremetal should take zero tweaking.
- Wrap [disko] to setup global and per-instance storage for Foundry.
  - `/shared` - mounted ro to `/opt/fvtt/data/shared/` per instance, mounted rw to `/opt/fvtt/shared` on host.
  - `/instances/<id>/data` - mounted to `/opt/fvtt/data/` per instance.
  - `/instances/<id>/install` - mounted to `/opt/fvtt/install/` per instance.
- Use [znapzend] for snapshots of all data.
  - Expose remote? Won't use myself (cloud zone-replicated PD), but maybe someone else will (open an issue to let me know!).
- Assume Nomad client and server on single node and setup.
  - Import all `.nomad[.tpl]` files into `/etc` for ease of reference.
  - Try Firecracker, else Podman.
  - Use [this][zfs-pd] for ZFS-backed PVs.
- Run Caddy as the reverse proxy for Foundry instances.
  - [Vendor from Nomad community registry][caddy-tpl].
  - [Adjust with `reload_script`][caddy-reload].
  - [Make into a Nomad service][nomad-services].
- Nomad [parameterized job][nomad-params] for creating Foundry instances.
  - TODO: figure out optimal `task.resources.cpu` quantity.
- Discord bot (avoid making a web interface :D).
  - Handle onboarding wizard.
  - Commands for basic operations.
  - Status updates.
- Route `/-/` for Foundry, so we can put other nifty things under other routes, and redirect `/` to `/-/`.
  - `/backups/` routing to Foundry's backups, using Caddy's file-server under Discord auth.

[disko]: https://github.com/nix-community/disko
[znapzend]: https://search.nixos.org/options?show=services.znapzend.zetup
[zfs-pd]: https://github.com/openebs/zfs-localpv
[caddy-tpl]: https://github.com/hashicorp/nomad-pack-community-registry/blob/main/packs/caddy/templates/caddy.nomad.tpl
[caddy-reload]: https://github.com/caddyserver/caddy/issues/3967#issuecomment-1646249388
[nomad-services]: https://developer.hashicorp.com/nomad/docs/job-specification/template#nomad-services
[nomad-params]: https://developer.hashicorp.com/nomad/docs/job-specification/parameterized

