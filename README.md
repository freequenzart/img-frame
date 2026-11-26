# img-frame

Ein schlanker Browser-Kiosk auf Raspberry Pi OS Lite: kein Desktop, nur X11,
ein minimaler Fenstermanager und Chromium im Vollbild. Ausgangspunkt ist deine
[Smart-Mirror-Anleitung](https://github.com/freequenzart/Smart-Mirror-with-Home-Assistant).

Zielhardware: Raspberry Pi Zero 2 W und neuere Modelle. Unterstuetzt werden
32 Bit (`armhf`) und 64 Bit (`arm64`). Fuer die 512 MB RAM des Zero 2 W bleibt
32 Bit die Empfehlung; 64 Bit ist auch dort moeglich, benoetigt aber tendenziell
mehr Arbeitsspeicher. Aufwendige Webseiten und Home-Assistant-Dashboards koennen
an die Speichergrenze stossen. Raspberry Pi Zero / Zero W der ersten Generation
werden nicht unterstuetzt.

## Verhalten

- Beim ersten Kiosk-Start erscheint eine URL-Abfrage auf der Textkonsole.
  Dafuer wird eine USB-Tastatur benoetigt, kein Touchscreen-Setup.
- Beispiel: `http://homeassistant.local:8123/dashboard-mirror/0`.
- Anschliessend startet der Browser; die Adresse bleibt nach Neustarts erhalten.
- Bei spaeteren Starts erscheint direkt der Browser. Mauszeiger und Bildschirmschoner
  werden ausgeblendet. Nach dem Beenden oder Absturz startet der Browser erneut.
- Browserprofil und Anmeldungen bleiben gespeichert. Chromium laeuft nicht als root;
  seine Sandbox bleibt aktiviert. Es wird kein zusaetzlicher Konfigurations-Webserver gestartet.

## Schnellstart auf einem Pi

1. Raspberry Pi OS Lite (32 oder 64 Bit), Trixie oder Bookworm, auf die SD-Karte schreiben.
   Mit Raspberry Pi Imager eigenen Admin-Benutzer und WLAN einrichten; SSH nur bei Bedarf aktivieren.
2. Pi starten und dieses Projekt vollstaendig auf den Pi kopieren, z.B. nach `~/img-frame`.
3. Als Admin ausfuehren:

   ```bash
   cd ~/img-frame
   sudo bash install.sh
   sudo reboot
   ```

4. Die URL an der angeschlossenen Tastatur eingeben. Danach startet der Kiosk.

Der Installer benoetigt Internet fuer die Pakete. Er reserviert den Benutzer `kiosk`
und dessen Login-Profil sowie die automatische Anmeldung auf Konsole 1 fuer den Kiosk.
Ein vorhandenes Login-Profil wird einmalig gesichert. Verwende deshalb einen anderen
Benutzernamen fuer deinen Admin. Bestehende URL und Browserdaten bleiben bei erneuter
Installation erhalten. Das Skript aendert keine WLAN-Zugangsdaten oder Grafiktreiber.
Die Pakete werden durch `apt` automatisch passend zur installierten OS-Architektur
ausgewaehlt; es ist kein separater 64-Bit-Installer notwendig.

## URL spaeter aendern

Per SSH als Admin oder lokal mit `Strg+Alt+F2` anmelden:

```bash
sudo img-frame-config --restart
```

Alternativ die neue Adresse direkt setzen:

```bash
sudo img-frame-config --set 'http://192.168.1.50:8123/dashboard-mirror/0' --restart
```

`Strg+Alt+F1` wechselt zurueck zum Kiosk. `--restart` beendet die komplette laufende
Kiosk-Sitzung, auch auf Konsole 1. Ohne diese Option wird die URL erst beim naechsten
Kiosk-Start uebernommen. Eine leere Eingabe behaelt die vorhandene Adresse.

```bash
sudo img-frame-config --get
sudo img-frame-config --reset --restart
```

`--reset` stellt nur die URL-Abfrage wieder her und loescht keine Browser-Anmeldung.
Die URL liegt in `/var/lib/img-frame/config.json`, das Profil unter
`/home/kiosk/.config/img-frame/chromium`. URLs duerfen keine eingebetteten Zugangsdaten
enthalten. Fuer Home Assistant direkt im Browser einen eigenen eingeschraenkten Benutzer anmelden.

## Eigenes SD-Karten-Image bauen

Die beiliegende Stufe erweitert die offizielle Raspberry-Pi-OS-Lite-Stufe (`stage2`)
von [pi-gen](https://github.com/RPi-Distro/pi-gen). Sie erzeugt eine `.img.xz` im
Verzeichnis `deploy`. Hier im Windows-Arbeitsbereich wurde noch kein Image gebaut.

Empfohlen: ein dedizierter Raspberry Pi als Build-Rechner, mit Raspberry Pi OS
passend zur Zielarchitektur (32 Bit fuer `armhf`, 64 Bit fuer `arm64`),
genuegend freiem Speicher (mehrere zehn GB) und den
[aktuellen pi-gen-Build-Abhaengigkeiten](https://github.com/RPi-Distro/pi-gen#dependencies).
Nicht auf NTFS bauen. Builds unter x86-Linux mit QEMU/Docker sind moeglich, aber von
pi-gen nicht als native Build-Umgebung unterstuetzt und hier nicht verifiziert.

Auf dem Linux-Build-Rechner:

```bash
bash image/prepare.sh "$HOME/pi-gen-img-frame" auto
cd "$HOME/pi-gen-img-frame"
read -rsp 'Eigenes Passwort fuer frameadmin: ' IMG_FRAME_ADMIN_PASSWORD
echo
export IMG_FRAME_ADMIN_PASSWORD
sudo --preserve-env=IMG_FRAME_ADMIN_PASSWORD ./build.sh
unset IMG_FRAME_ADMIN_PASSWORD
```

Die Architekturwahl erfolgt ueber das zweite Argument:

| Auswahl | Verhalten | pi-gen-Zweig | Image-Name |
| --- | --- | --- | --- |
| `auto` (Standard) | Installierte OS-Architektur des Build-Rechners ueber `dpkg` | passend zum OS | passend zum OS |
| `armhf` | 32-Bit-Ziel | `master` | `img-frame-armhf` |
| `arm64` | 64-Bit-Ziel | `arm64` | `img-frame-arm64` |

`auto` richtet sich bewusst nach dem Betriebssystem, nicht allein nach der CPU:
Ein 32-Bit-OS auf einer 64-Bit-faehigen CPU waehlt `armhf`. Auf einem x86-Rechner
lehnt `auto` die Auswahl ab; dort muss das ARM-Ziel explizit angegeben werden.
Die explizite Auswahl richtet keine zusaetzliche Cross-Build-/QEMU-Umgebung ein.

Beide Varianten lassen sich unabhaengig in getrennten Verzeichnissen vorbereiten:

```bash
bash image/prepare.sh "$HOME/pi-gen-img-frame-armhf" armhf
bash image/prepare.sh "$HOME/pi-gen-img-frame-arm64" arm64
```

Den obigen `build.sh`-Aufruf anschliessend im jeweiligen Verzeichnis auf einer
geeigneten Build-Umgebung ausfuehren. Ein vorhandenes Build-Verzeichnis wird nicht
ueberschrieben. Es entstehen zwei getrennte Images, kein einzelnes Image, das beim
Booten zwischen 32 und 64 Bit wechselt.

Das Vorbereiten klont den aktuellen Stand des gewaehlten Zweigs und gibt dessen
Commit-ID aus. Fuer wiederholbare Builds diesen Stand und die verwendeten
Paketquellen festhalten; die Online-Paketquellen selbst sind nicht eingefroren.

Das fertige Image mit Imager ueber "Eigenes Image" flashen. Admin ist `frameadmin`
mit deinem beim Build gewaehlten Passwort, SSH ist standardmaessig ausgeschaltet.
Es gibt kein mitgeliefertes Standardpasswort. Dieses Image ist fuer den persoenlichen
Gebrauch gedacht: nicht unveraendert mit demselben Admin-Passwort weiterverteilen.
Fuer oeffentliche Releases waere eine eigene sichere Admin-Ersteinrichtung notwendig.

Wichtig: Die URL-Abfrage richtet kein WLAN ein. Beim eigenen Image vor dem ersten
Browserstart Ethernet verwenden oder mit `Strg+Alt+F2` als `frameadmin` anmelden und
das Netzwerk einrichten, z.B. auf einem System mit NetworkManager:

```bash
sudo nmcli --ask device wifi connect 'DEINE-SSID'
```

Bei einem eigenen Image ist die OS-Anpassung im Imager nicht immer verfuegbar.
SSH laesst sich bei Bedarf mit `sudo raspi-config` aktivieren. Wenn Chromium bereits
eine Netzwerkfehlerseite zeigt, nach erfolgreicher Netzwerkeinrichtung die Sitzung mit
`sudo systemctl restart getty@tty1.service` neu starten. Eine automatische Erkennung
spaeterer Ausfaelle des Zielservers oder eine automatische Seitenaktualisierung ist nicht enthalten.

## Grenzen und Wartung

- Ein echter Boot- und Hardwaretest auf Zero 2 W und neueren Modellen steht noch aus.
  Auch die kompletten pi-gen-Builds fuer 32 und 64 Bit muessen auf Linux verifiziert werden.
- Das Kiosk-Vollbild ist keine Absicherung gegen Benutzer mit physischem Zugriff.
  Konsolenwechsel und Wartung bleiben absichtlich moeglich.
- KMS bleibt aktiv. Keine pauschalen Legacy-/FKMS-Overlays, keine feste Bildschirmaufloesung.
  Display-Drehung und Sensorsteuerung sind nicht Bestandteil dieser Basis.
- Bei HTTPS muessen Zertifikate vertrauenswuerdig sein; die Zertifikatspruefung wird nicht abgeschaltet.
- Chromium-Sitzungsdaten und Tokens sind auf der SD-Karte gespeichert. Geraet und Karte schuetzen.
- Betriebssystem und Browser regelmaessig aktualisieren:

  ```bash
  sudo apt update
  sudo apt full-upgrade
  sudo reboot
  ```

## Tests

```bash
python3 -m unittest discover -s tests -v
bash tests/test_prepare.sh
bash -n install.sh files/launch.sh files/session.sh image/prepare.sh
```

Die Python-Tests pruefen URL-Validierung, Erstabfrage, dauerhafte Speicherung,
Adresswechsel und die Reparatur beschaedigter Konfigurationen. Die Shell-Tests pruefen
beide Zielarchitekturen, die automatische Auswahl und Fehlerfaelle mit simulierten
`git`-/`dpkg`-Befehlen, ohne Download oder Image-Build. Sie ersetzen keinen Pi-Test.