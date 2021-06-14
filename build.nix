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
	define("__CA_DB_HOST__", getenv("CA_DB_HOST"));
	define("__CA_DB_USER__", getenv("CA_DB_USER"));
	define("__CA_DB_PASSWORD__", 'AhzeiP5s');
	define("__CA_DB_DATABASE__", 'ca');
	define("__CA_APP_DISPLAY_NAME__", "EICAS");
	define("__CA_ADMIN_EMAIL__", 'arnout@bzzt.net');
date_default_timezone_set('Europe/Amsterdam');
	define("__CA_DEFAULT_LOCALE__", "en_US");
define("__CA_USE_CLEAN_URLS__", 0);
	define("__CA_APP_NAME__", "collectiveaccess");

# this is not correctly autodetected
# https://github.com/raboof/nix-collectiveaccess/issues/5
define("__CA_URL_ROOT__", "");
define("__CA_BASE_DIR__", "/webroot");

# providence currently logs to app/log on disk rather than
# to stdout/stderr where the container infrastructure can pick it up.
# Until that time let's just send the errors to the user.
# https://github.com/collectiveaccess/providence/issues/923
define("__CA_ENABLE_DEBUG_OUTPUT__", true);
define("__CA_STACKTRACE_ON_EXCEPTION__", true);


require(__DIR__."/app/helpers/post-setup.php");
?>
  '';
  nginxPort = "8080";
  nginxConf = writeText "nginx.conf" ''
    user root nobody;
    daemon off;
    error_log /dev/stdout info;
    pid /dev/null;
    events {}
    http {
      access_log /dev/stdout;
      include ${nginx}/conf/mime.types;
      server {
        listen ${nginxPort};
        index index.php;
        location / {
          root /webroot;
        }
        location ~ \.php {
          fastcgi_pass unix:${phpFpmSocketLocation};
          fastcgi_param SCRIPT_FILENAME /webroot$fastcgi_script_name;
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          include ${nginx}/conf/fastcgi_params;
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

    ; to read e.g. the database config passed in via the env.
    ; there is nothing (more) sensitive in there anyway:
    clear_env=no

    access.log=/proc/self/fd/2
    catch_workers_output = yes
    php_flag[display_errors] = on
    php_admin_value[error_log] = /proc/self/fd/2
    php_admin_flag[log_errors] = on
  '';
  phpIni = writeText "php.ini" ''
  '';
  startScript = writeScript "start.sh" ''
    #!${bash}/bin/sh
    ${php}/bin/php-fpm -y ${phpFpmCfg} -c ${phpIni}
    exec "${nginx}/bin/nginx" "-c" ${nginxConf}
  '';
  providence-image = dockerTools.buildLayeredImage {
    name = "raboof/providence";
    tag = "latest";
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

      # php-fpm lock file,
      # media file upload PHP temporary directory
      # conversions temporary directory
      mkdir -p tmp
      chmod a+rwx tmp

      # the 'installer' wants to write to the app, so copy
      # it for now.
      mkdir webroot
      cp -ra ${providence}/* webroot
      cp ${providenceConfig} webroot/setup.php
      # https://github.com/raboof/nix-collectiveaccess/issues/6
      chmod a+wx webroot/app/log
      # https://github.com/raboof/nix-collectiveaccess/issues/7
      chmod a+wx webroot/app/tmp
      # https://github.com/raboof/nix-collectiveaccess/issues/8
      chmod a+wx webroot/media

      chmod a+w webroot/vendor/ezyang/htmlpurifier/library/HTMLPurifier/DefinitionCache/Serializer
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
