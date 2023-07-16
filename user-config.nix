{ config, modulesPath, pkgs, lib, linx-server, ... }:
{
    system.stateVersion = "23.05";

    environment.systemPackages = with pkgs; [
        htop
        ripgrep
        elinks
    ];

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 80 443 ];
      allowedUDPPortRanges = [
        { from = 4000; to = 4007; }
        { from = 8000; to = 8010; }
      ];
    };

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
sitename = pastanix
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

      path = [ linx-server pkgs.ffmpeg_6 ];

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
      locations."/".extraConfig = ''
        proxy_pass http://127.0.0.1:4333;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;

        # by default nginx times out connections in one minute
        proxy_read_timeout 1d;
        proxy_redirect off;
	'';
      };
    };

}
