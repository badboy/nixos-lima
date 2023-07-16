{ config, modulesPath, pkgs, lib, ... }:
{
    system.stateVersion = "23.05";

    environment.systemPackages = with pkgs; [
        htop
        ripgrep
    ];

    users.users.jer = {
        shell = "/run/current-system/sw/bin/bash";
        isNormalUser = true;
        group = "users";
        home = "/home/jer.linux";
    };

    systemd.services.pasta =
      let
        config = pkgs.writeText "server.conf" ''
bind = 127.0.0.1:4333
sitename = pasta
#siteurl = http://p.fnordig.de/
maxsize = 1048576000 # 1 Gb
maxexpiry = 2419200 # 4 weeks

remoteuploads = false
nologs = false
force-random-filename = false

realip = true
cleanup-every-minutes = 60
        '';
      in
    {
      description = "linx-server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];

      path = with pkgs; [
        linx-server
      ];

      script = ''
        cd $STATE_DIRECTORY || exit 1
        ${pkgs.linx-server}/bin/linx-server -config ${config}
      '';

      serviceConfig = {
        DynamicUser = true;
        Restart = "always";
        StateDirectory = "pasta";
      };
    };

  services.nginx = {
    enable = true;
    virtualHosts."localhost" = {
      serverAliases = [ "localhost" ];
      default = true;
      http2 = true;
      root = "/srv/www/localhost";
      locations."/".proxyPass = "http://localhost:4333";
    };
  };

}
