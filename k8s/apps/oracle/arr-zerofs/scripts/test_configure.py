"""Protect existing download routes when configuring opt-in ZeroFS storage."""
import copy
import unittest

from configure import reconcile


class FakeAPI:
    def __init__(self, app):
        kind = 'movie' if app == 'radarr' else 'tv'
        self.data = {
            '/api/v3/system/status': {},
            '/api/v3/filesystem?path=%2Fzerofs&includeFiles=false': {},
            '/api/v3/config/mediamanagement': {'copyUsingHardlinks': True},
            '/api/v3/downloadclient': [
                {'id': 2, 'name': 'qBittorrent', 'implementation': 'QBittorrent',
                 'enable': True, 'tags': [], 'fields': [
                     {'name': kind + 'Category', 'value': 'existing'},
                     {'name': kind + 'ImportedCategory', 'value': ''},
                     {'name': 'password', 'value': ''}]},
                {'id': 1, 'name': 'SABnzbd', 'implementation': 'Sabnzbd',
                 'enable': True, 'tags': [], 'fields': []}],
            '/api/v3/tag': [],
            '/api/v3/rootfolder': [{'id': 1, 'path': '/data/media/' + ('movies' if app == 'radarr' else 'tv'), 'accessible': True}],
            '/api/v3/delayprofile': [{'id': 1, 'tags': [], 'order': 2147483647,
                                     'enableUsenet': True, 'enableTorrent': True,
                                     'preferredProtocol': 'usenet'}],
        }
        self.writes = []

    def get(self, path):
        return copy.deepcopy(self.data[path])

    def post(self, path, payload):
        self.writes.append((path, copy.deepcopy(payload)))
        item = copy.deepcopy(payload)
        item['id'] = max([x['id'] for x in self.data[path]] + [0]) + 1
        if path.endswith('/rootfolder'):
            item['accessible'] = True
        self.data[path].append(item)
        return copy.deepcopy(item)

    def put(self, path, payload):
        self.writes.append((path, copy.deepcopy(payload)))
        base, ident = path.rsplit('/', 1)
        self.data[base] = [copy.deepcopy(payload) if x['id'] == int(ident) else x for x in self.data[base]]


class FakeQbit:
    def __init__(self):
        self.categories = {'movies': {'savePath': '', 'download_path': None}}
        self.writes = []

    def get(self, path):
        assert path == '/api/v2/torrents/categories'
        return copy.deepcopy(self.categories)

    def post(self, path, form):
        self.writes.append((path, copy.deepcopy(form)))
        self.categories[form['category']] = {'savePath': form['savePath'], 'download_path': False}


class RoutingTests(unittest.TestCase):
    def test_dry_run_has_no_writes(self):
        for app in ['radarr', 'sonarr']:
            api, qbit = FakeAPI(app), FakeQbit()
            reconcile(app, api, qbit, dry_run=True)
            self.assertEqual(api.writes, [])
            self.assertEqual(qbit.writes, [])

    def test_existing_routes_preserved_and_second_run_is_noop(self):
        for app in ['radarr', 'sonarr']:
            api, qbit = FakeAPI(app), FakeQbit()
            original = copy.deepcopy(api.data)
            original_categories = copy.deepcopy(qbit.categories)
            reconcile(app, api, qbit)
            for path in ['/api/v3/downloadclient', '/api/v3/rootfolder', '/api/v3/delayprofile']:
                self.assertEqual(api.data[path][:len(original[path])], original[path])
            self.assertEqual(qbit.categories['movies'], original_categories['movies'])
            profile = api.data['/api/v3/delayprofile'][-1]
            self.assertFalse(profile['enableUsenet'])
            self.assertTrue(profile['enableTorrent'])
            self.assertEqual(profile['tags'], [api.data['/api/v3/tag'][-1]['id']])
            writes = copy.deepcopy((api.writes, qbit.writes))
            reconcile(app, api, qbit)
            self.assertEqual((api.writes, qbit.writes), writes)
            self.assertTrue(all('/movie/' not in path and '/series/' not in path for path, _ in api.writes))

    def test_conflicting_category_does_not_relocate_torrents(self):
        api, qbit = FakeAPI('radarr'), FakeQbit()
        qbit.categories['radarr-zerofs'] = {'savePath': '/elsewhere', 'download_path': False}
        with self.assertRaisesRegex(RuntimeError, 'refusing to relocate'):
            reconcile('radarr', api, qbit)
        self.assertEqual(api.writes, [])
        self.assertEqual(qbit.writes, [])


if __name__ == '__main__':
    unittest.main()
