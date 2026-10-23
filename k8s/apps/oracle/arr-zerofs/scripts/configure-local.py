"""Configure opt-in routes directly through localhost-only kubectl forwards."""
import argparse
import contextlib
import socket
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

from configure import API, reconcile, wait_ready

PROD = Path(__file__).resolve().parents[5] / 'clusters/prod'


def kubectl(*args):
    return subprocess.run(['mise', 'exec', '--', 'kubectl', *args], cwd=PROD,
                          capture_output=True, check=True).stdout


@contextlib.contextmanager
def connections():
    processes = []
    apis = {}
    try:
        for app, remote in [('sonarr', 8989), ('radarr', 7878), ('qbittorrent', 80)]:
            with socket.socket() as sock:
                sock.bind(('127.0.0.1', 0))
                port = sock.getsockname()[1]
            process = subprocess.Popen(
                ['mise', 'exec', '--', 'kubectl', 'port-forward', '-n', 'homelab',
                 'svc/' + app, f'{port}:{remote}'], cwd=PROD,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            processes.append(process)
            key = None
            if app != 'qbittorrent':
                config = kubectl('exec', '-n', 'homelab', 'deploy/' + app,
                                 '--', 'cat', '/config/config.xml')
                key = ET.fromstring(config).findtext('ApiKey')
                if not key:
                    raise RuntimeError(f'{app}: API key missing from config.xml')
            apis[app] = API(f'http://127.0.0.1:{port}', key)
            endpoint = '/api/v2/torrents/categories' if app == 'qbittorrent' else '/api/v3/system/status'
            wait_ready(apis[app], endpoint)
        yield apis
    finally:
        for process in processes:
            process.terminate()
        for process in processes:
            process.wait(timeout=5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    with connections() as apis:
        for app in ['radarr', 'sonarr']:
            reconcile(app, apis[app], apis['qbittorrent'], args.dry_run)


if __name__ == '__main__':
    main()
