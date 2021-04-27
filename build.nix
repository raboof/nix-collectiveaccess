{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  phpFpmSocketLocation = "/run/php-fpm.sock";
  providence = fetchFromGitHub {
    owner = "collectiveaccess";
    repo = "providence";
    rev = "1.7.11";
    sha256 = "0108bniv0s6vbrd22y0k1kwrvrl4ivxwsiqvs7mz1am7r02pcp7k";
  };
  providenceConfig = writeText "setup.php" ''
<?php
	define("__CA_DB_HOST__", 'database');
	define("__CA_DB_USER__", 'ca');
	define("__CA_DB_PASSWORD__", 'AhzeiP5s');
	define("__CA_DB_DATABASE__", 'ca');
	define("__CA_APP_DISPLAY_NAME__", "EICAS");
	define("__CA_ADMIN_EMAIL__", 'arnout@bzzt.net');
date_default_timezone_set('Europe/Amsterdam');
	define("__CA_DEFAULT_LOCALE__", "en_US");
define("__CA_USE_CLEAN_URLS__", 0);
	define("__CA_APP_NAME__", "collectiveaccess");
?>
  '';
  nginxRoot = symlinkJoin {
    name = "webroot";
    paths = [ providence ];
    # TODO could add a favicon
    postBuild = "cp ${providenceConfig} $out/setup.php";
  };
  nginxPort = "8080";
  nginxConf = writeText "nginx.conf" ''
    user root nobody;
    daemon off;
    error_log /dev/stdout info;
    pid /dev/null;
    events {}
    http {
      access_log /dev/stdout;
      server {
        listen ${nginxPort};
        index index.php;
        location / {
          root ${nginxRoot};
        }
        location ~ \.php$ {
          include ${nginx}/conf/fastcgi_params;
          fastcgi_pass unix:${phpFpmSocketLocation};
          fastcgi_param SCRIPT_FILENAME ${nginxRoot}$fastcgi_script_name;
        }
      }
    }
  '';
  phpFpmCfg = writeText "php-fpm.conf" ''
    [global]
    daemonize=yes
    error_log=/proc/self/fd/2

    [www]
    user = nobody
    group = nobody
    listen = ${phpFpmSocketLocation}
    pm = static
    pm.max_children = 5

    access.log=/proc/self/fd/2
    ;catch_workers_output = yes
    ;php_flag[display_errors] = on
    ;php_admin_value[error_log] = /dev/stdout
    ;php_admin_flag[log_errors] = on
  '';
  phpIni = writeText "php.ini" ''
  '';
  startScript = writeScript "start.sh" ''
    #!${bash}/bin/sh
    ${coreutils}/bin/chown nobody:nobody ${phpFpmSocketLocation}
    ${coreutils}/bin/ls -alFh ${phpFpmSocketLocation}
    ${php}/bin/php-fpm -y ${phpFpmCfg} -c ${phpIni}
    ${coreutils}/bin/ls -alFh ${phpFpmSocketLocation}
    exec "${nginx}/bin/nginx" "-c" ${nginxConf}
  '';
  providence-image = dockerTools.buildLayeredImage {
    name = "providence";
    contents = [
      dockerTools.fakeNss
    ];
    extraCommands = ''
      # nginx still tries to read this directory even if error_log
      # directive is specifying another file :/
      mkdir -p var/log/nginx
      mkdir -p var/cache/nginx
      mkdir -p run
      touch run/php-fpm.sock
      mkdir -p tmp
    '';
    config = {
      Cmd = [ "${startScript}" ];
      ExposedPorts = {
        "${nginxPort}/tcp" = {};
      };
    };
  };
in
  providence-image
