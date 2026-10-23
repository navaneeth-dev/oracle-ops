"""Initialize directories directly in a temporary utility Pod, outside Flux."""
import json
import subprocess
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
PROD = SCRIPTS.parents[4] / 'clusters/prod'
POD = 'arr-zerofs-shell'
IMAGE = 'python:3.13-slim-bookworm@sha256:e32be0e55814a08977501ca863271d9bd02443710db8f2afaf8372e2c4508530'


def kubectl(*args, **kwargs):
    return subprocess.run(['mise', 'exec', '--', 'kubectl', *args], cwd=PROD, check=True, **kwargs)


def main():
    # Do not accidentally prepare the old benchmark filesystem before rollout.
    raw = kubectl('get', 'configmap', 'zerofs-gateway-a-config', '-n', 'zerofs',
                  '-o', 'json', capture_output=True).stdout
    config = json.loads(raw)['data']['zerofs.toml']
    if 'url = "s3://rizexor-media/zerofs"' not in config:
        raise RuntimeError('Deploy the permanent ZeroFS backend before initializing arr storage')
    kubectl('wait', '--for=condition=Ready', 'kustomization/zerofs', '-n', 'flux-system', '--timeout=50s')
    body = (SCRIPTS / 'directories.py').read_text()
    body += '\nimport os\nos.setgroups([])\nos.setgid(1000)\nos.setuid(1000)\n'
    body += (SCRIPTS / 'verify.py').read_text()
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': POD, 'namespace': 'homelab'},
           'spec': {'automountServiceAccountToken': False, 'restartPolicy': 'Never',
                    'containers': [{'name': 'shell', 'image': IMAGE, 'command': ['python', '-c', body],
                                    'resources': {'requests': {'cpu': '25m', 'memory': '64Mi'},
                                                  'limits': {'memory': '64Mi'}},
                                    'securityContext': {'runAsUser': 0, 'runAsGroup': 0,
                                                        'allowPrivilegeEscalation': False,
                                                        'readOnlyRootFilesystem': True,
                                                        'capabilities': {'drop': ['ALL'], 'add': [
                                                            'CHOWN', 'FOWNER', 'DAC_OVERRIDE', 'SETUID', 'SETGID']}},
                                    'volumeMounts': [{'name': 'media', 'mountPath': '/zerofs'}]}],
                    'volumes': [{'name': 'media', 'persistentVolumeClaim': {'claimName': 'arr-zerofs'}}]}}
    # create, rather than apply, refuses to overwrite an unrelated existing Pod.
    kubectl('create', '-f', '-', input=json.dumps(pod).encode())
    try:
        kubectl('wait', '--for=jsonpath={.status.phase}=Succeeded', 'pod/' + POD,
                '-n', 'homelab', '--timeout=120s')
        kubectl('logs', '-n', 'homelab', POD)
    finally:
        kubectl('delete', 'pod/' + POD, '-n', 'homelab', '--wait=true', '--timeout=50s')


if __name__ == '__main__':
    main()
