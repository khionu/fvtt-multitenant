{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko = {
    url = "github:nix-community/disko";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, disko, ... }: {
    nixosModules.aio = { self, pkgs, config, lib, ... }: {
      options.fvtt-multi = with lib; {
        enable =
          mkEnableOption "enable Khionu's Multitenant Foundry setup";
        availableInstanceDomains = mkOption {
          type = types.listOf string;
          description = mdDoc "Domains that instances can be subdomains of";
        };
        adminDomain = lib.mkOption {
          type = string;
          description = mdDoc "Domain that admin services will be of. Must have a wildcard record";
        };
      };

      config = lib.mkIf config.fvtt-multi.enable {
        services.nomad = {
          enable = true;
          extraSettingsPlugins = [
            pkgs.nomad-driver-podman
          ];
          settings = {
            ui.enabled = true;
            acl.enabled = true;
            server = {
              enabled = true;
              bootstrap_expect = 1;
            };
            client.enabled = true;
          };
        };
        environment.etc."fvtt-mt/Caddyfile.tpl".text = ''
          {{- range nomadService "fvtt-instance" }}
          {{ .Domain }} {
            redir / /-/ permanent
            reverse_proxy /-/* {{ .FvttDestination }}
          }{{- end }}
        '';

        systemd.services.bootstrap-nomad = {
          enable = true;
          after = [ "nomad.service" ];
          description = "Ensure we have deployed critical Nomad services";
          serviceConfig.Type = "oneshot";
          script = "${self.packages."x86_64-linux".bootstrap-nomad}/bin/bootstrap-nomad";
        };
      };
    };
    packages."x86_64-linux".bootstrap-nomad = { writeTextFile, nushell, nomad }:
      writeTextFile {
        name = "bootstrap-nomad";
        executable = true;
        destination = "/bin/boostrap-nomad";
        text = ''
          #!${nushell}/bin/nu

          if not ("/root/nomad/bootstrap" | path exists) {
            mkdir /root/nomad
            ${nomad}/bin/nomad acl bootstrap |
              lines | parse '{name} = {value}' | str trim | transpose -rd |
              to json | save -f /root/nomad/bootstrap
          }

          $env.NOMAD_TOKEN = open /root/nomad/bootstrap | get "Secret ID"

          let policies = nomad acl policy list -json | from json
        '';
      };
  };
}
