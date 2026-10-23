"""Idempotently add opt-in ZeroFS routes; never move media or start downloads."""
import copy
import json
import time
import urllib.error
import urllib.parse
import urllib.request

CLIENT_NAME = 'qBittorrent ZeroFS'
TAG = 'zerofs'


class API:
    def __init__(self, base, key=None):
        self.base = base.rstrip('/')
        self.headers = {'X-Api-Key': key} if key else {'Referer': self.base}

    def request(self, path, method='GET', payload=None, form=None):
        headers = dict(self.headers)
        data = None
        if payload is not None:
            data = json.dumps(payload).encode()
            headers['Content-Type'] = 'application/json'
        elif form is not None:
            data = urllib.parse.urlencode(form).encode()
            headers['Content-Type'] = 'application/x-www-form-urlencoded'
        req = urllib.request.Request(self.base + path, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=20) as response:
                body = response.read()
                return json.loads(body) if body else None
        except urllib.error.HTTPError as error:
            # Provider error bodies can contain credentials: do not print them.
            raise RuntimeError(f'{method} {path} failed: HTTP {error.code}') from None

    def get(self, path):
        return self.request(path)

    def post(self, path, payload=None, form=None):
        return self.request(path, 'POST', payload, form)

    def put(self, path, payload):
        return self.request(path, 'PUT', payload)


def wait_ready(api, path):
    for attempt in range(90):
        try:
            return api.get(path)
        except (RuntimeError, urllib.error.URLError, TimeoutError):
            if attempt == 89:
                raise RuntimeError(f'Endpoint did not become ready: {path}') from None
            time.sleep(5)


def set_field(client, name, value):
    field = next((f for f in client['fields'] if f['name'] == name), None)
    if field is None:
        raise RuntimeError(f'qBittorrent provider is missing the {name} field')
    field['value'] = value


def ensure_category(qbit, category, path, dry_run):
    categories = qbit.get('/api/v2/torrents/categories')
    existing = categories.get(category)
    # Keep incomplete data in the category's regular folder, as currently in /data.
    if existing and existing.get('savePath', '').rstrip('/') != path:
        raise RuntimeError(f'{category} already points elsewhere; refusing to relocate its torrents')
    option = existing.get('download_path') if existing else None
    if existing and option is False:
        return
    if dry_run:
        print(f'Would configure category {category}: {path}, separate incomplete folder disabled')
        return
    action = 'editCategory' if existing else 'createCategory'
    qbit.post('/api/v2/torrents/' + action, form={
        'category': category, 'savePath': path, 'downloadPathEnabled': 'false',
    })
    saved = qbit.get('/api/v2/torrents/categories')[category]
    assert saved['savePath'].rstrip('/') == path
    assert saved['download_path'] is False


def reconcile(app, api, qbit, dry_run=False):
    kind = 'movies' if app == 'radarr' else 'tv'
    category_field = 'movieCategory' if app == 'radarr' else 'tvCategory'
    imported_field = 'movieImportedCategory' if app == 'radarr' else 'tvImportedCategory'
    category = app + '-zerofs'
    root = '/zerofs/media/' + kind
    wait_ready(api, '/api/v3/system/status')
    if not dry_run:
        wait_ready(api, '/api/v3/filesystem?path=%2Fzerofs&includeFiles=false')
    if not api.get('/api/v3/config/mediamanagement')['copyUsingHardlinks']:
        raise RuntimeError(f'{app}: hardlink imports must be enabled before configuring ZeroFS')
    clients = api.get('/api/v3/downloadclient')
    managed = [c for c in clients if c['name'] == CLIENT_NAME]
    if len(managed) > 1:
        raise RuntimeError(f'{app}: duplicate managed download clients')
    if managed:
        source = managed[0]
        if source['implementation'] != 'QBittorrent':
            raise RuntimeError(f'{app}: managed client name is used by another provider')
    else:
        sources = [c for c in clients if c['implementation'] == 'QBittorrent' and c['enable'] and not c['tags']]
        if len(sources) != 1:
            raise RuntimeError(f'{app}: expected one enabled untagged qBittorrent source client')
        source = sources[0]
    if any(str(f.get('value', '')).startswith('***') for f in source['fields'] if f['name'] in ('password', 'apiKey')):
        raise RuntimeError(f'{app}: source credentials are masked; cannot safely clone this client')
    ensure_category(qbit, category, '/zerofs/torrents/' + kind, dry_run)
    tags = api.get('/api/v3/tag')
    tag = next((t for t in tags if t['label'] == TAG), None)
    if dry_run:
        # A planning placeholder only; no requests containing it are sent.
        tag = tag or {'id': -1, 'label': TAG}
    elif tag is None:
        tag = api.post('/api/v3/tag', {'label': TAG})
    tag_id = tag['id']
    desired = copy.deepcopy(source)
    if not managed:
        desired.pop('id', None)
    desired.update(name=CLIENT_NAME, enable=True, tags=[tag_id])
    set_field(desired, category_field, category)
    set_field(desired, imported_field, '')
    roots = api.get('/api/v3/rootfolder')
    profiles = api.get('/api/v3/delayprofile')
    tagged_profiles = [p for p in profiles if tag_id in p['tags']]
    if len(tagged_profiles) > 1 or any(p['tags'] != [tag_id] for p in tagged_profiles):
        raise RuntimeError(f'{app}: conflicting delay profiles already reference the ZeroFS tag')
    profile = copy.deepcopy(tagged_profiles[0] if tagged_profiles else next(p for p in profiles if not p['tags']))
    if not tagged_profiles:
        profile.pop('id', None)
        profile['order'] = max([p['order'] for p in profiles if p['tags']] + [0]) + 1
    profile.update(tags=[tag_id], enableUsenet=False, enableTorrent=True, preferredProtocol='torrent')
    if dry_run:
        print(f'{app}: would ensure {root}, tag {TAG}, {CLIENT_NAME}, and a tag-scoped torrent-only profile')
        return
    if not any(r['path'].rstrip('/') == root for r in roots):
        api.post('/api/v3/rootfolder', {'path': root})
    if managed:
        if desired != source:
            api.put('/api/v3/downloadclient/' + str(source['id']), desired)
    else:
        api.post('/api/v3/downloadclient', desired)
    if tagged_profiles:
        if profile != tagged_profiles[0]:
            api.put('/api/v3/delayprofile/' + str(profile['id']), profile)
    else:
        api.post('/api/v3/delayprofile', profile)
    saved = next(c for c in api.get('/api/v3/downloadclient') if c['name'] == CLIENT_NAME)
    assert saved['enable'] and saved['tags'] == [tag_id]
    assert next(f['value'] for f in saved['fields'] if f['name'] == category_field) == category
    assert any(r['path'].rstrip('/') == root and r['accessible'] for r in api.get('/api/v3/rootfolder'))
    print(f'{app}: ZeroFS root, tagged client, and torrent-only route configured')
