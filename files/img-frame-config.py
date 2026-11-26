#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit


CONFIG_PATH = Path('/var/lib/img-frame/config.json')


def validate_url(value):
    if not isinstance(value, str):
        raise ValueError('Die URL muss eine Zeichenkette sein.')
    value = value.strip()
    if not value or any(character.isspace() or ord(character) < 32 or ord(character) == 127 for character in value):
        raise ValueError('Bitte eine URL ohne Leer- oder Steuerzeichen eingeben.')
    try:
        parsed = urlsplit(value)
        hostname = parsed.hostname
        parsed.port
    except ValueError as error:
        raise ValueError('Ungueltiger Host oder Port.') from error
    if parsed.scheme not in ('http', 'https') or not hostname:
        raise ValueError('Bitte eine vollstaendige http://- oder https://-URL eingeben.')
    if parsed.username is not None or parsed.password is not None or '\\' in value:
        raise ValueError('Zugangsdaten und Backslashes sind in der URL nicht erlaubt.')
    return value


def load_url(path=CONFIG_PATH):
    try:
        data = json.loads(path.read_text(encoding='utf-8'))
        return validate_url(data['url'])
    except FileNotFoundError:
        return None
    except (ValueError, KeyError, TypeError) as error:
        raise ValueError('Konfiguration ungueltig. Mit sudo img-frame-config neu setzen.') from error


def save_url(value, path=CONFIG_PATH):
    value = validate_url(value)
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix='.config-')
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8') as stream:
            json.dump({'url': value}, stream)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def prompt_url(path=CONFIG_PATH):
    try:
        current = load_url(path)
    except ValueError:
        current = None
    print('\nimg-frame - Kiosk-Adresse')
    if current:
        print('Aktuell: ' + current)
    while True:
        value = input('Lokale URL (z.B. http://homeassistant.local:8123): ').strip()
        if not value and current:
            value = current
        try:
            save_url(value, path)
            return
        except ValueError as error:
            print(error)


def main():
    parser = argparse.ArgumentParser(description='Kiosk-URL anzeigen oder aendern.')
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--get', action='store_true')
    action.add_argument('--set', metavar='URL')
    action.add_argument('--reset', action='store_true')
    parser.add_argument('--restart', action='store_true', help='Kiosk neu starten (nur mit sudo).')
    args = parser.parse_args()
    if args.restart and os.geteuid() != 0:
        parser.error('--restart benoetigt sudo.')
    if args.get and args.restart:
        parser.error('--get und --restart nicht kombinieren.')
    try:
        if args.get:
            value = load_url()
            if value is None:
                return 1
            print(value)
        else:
            if os.geteuid() == 0:
                import pwd
                account = pwd.getpwnam('kiosk')
                child = os.fork()
                if child == 0:
                    os.setgroups([])
                    os.setgid(account.pw_gid)
                    os.setuid(account.pw_uid)
                    if args.reset:
                        CONFIG_PATH.unlink(missing_ok=True)
                    elif args.set is not None:
                        save_url(args.set)
                    else:
                        prompt_url()
                    os._exit(0)
                _, status = os.waitpid(child, 0)
                if os.waitstatus_to_exitcode(status) != 0:
                    return 1
            elif args.reset:
                CONFIG_PATH.unlink(missing_ok=True)
            elif args.set is not None:
                save_url(args.set)
            else:
                prompt_url()
            if args.restart:
                subprocess.run(['systemctl', 'restart', 'getty@tty1.service'], check=True)
    except (ValueError, OSError, EOFError, KeyboardInterrupt, subprocess.CalledProcessError) as error:
        print(str(error) or 'Abgebrochen.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())