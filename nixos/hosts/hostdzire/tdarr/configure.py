#!/usr/bin/env python3
"""Create or update the Tdarr flow and the Movies/TV libraries through the API.

Run on the host: python3 configure.py [http://127.0.0.1:8265]
Idempotent: documents use fixed IDs and are upserted.
"""
import copy
import json
import pathlib
import sys
import urllib.request

URL = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8265").rstrip("/")
HERE = pathlib.Path(__file__).parent
FLOW_ID = "boosted-stereo"
MEDIA = "/srv/nfs-data/oracle/media"


def crud(collection, mode, doc_id="", obj=None):
    data = {"collection": collection, "mode": mode, "docID": doc_id}
    if obj is not None:
        data["obj"] = obj
    req = urllib.request.Request(
        f"{URL}/api/v2/cruddb",
        data=json.dumps({"data": data}).encode(),
        headers={"content-type": "application/json"},
    )
    with urllib.request.urlopen(req) as res:
        body = res.read()
    return json.loads(body) if body else None


def upsert(collection, doc):
    existing = {d["_id"] for d in crud(collection, "getAll")}
    mode = "update" if doc["_id"] in existing else "insert"
    crud(collection, mode, doc["_id"], doc)
    print(f"{mode} {collection}/{doc['_id']}")


def plugin(pid, name, plugin_name, x, y, inputs=None):
    p = {"name": name, "sourceRepo": "Community", "pluginName": plugin_name,
         "version": "1.0.0", "id": pid, "position": {"x": x, "y": y}}
    if inputs:
        p["inputsDB"] = inputs
    return p


def edge(source, handle, target):
    return {"source": source, "sourceHandle": str(handle), "target": target,
            "targetHandle": None, "id": f"{source}-{handle}-{target}"}


flow = {
    "_id": FLOW_ID,
    "name": "Boosted stereo track",
    "description": "Add an AAC 2.0 track (downmix, volume=2) first and default; keep English subtitles.",
    "tags": "",
    "flowPlugins": [
        plugin("input", "Input File", "inputFile", 400, 0),
        plugin("stereo", "Add boosted stereo", "customFunction", 400, 120,
               {"code": (HERE / "add-boosted-stereo.js").read_text()}),
        plugin("duration", "Duration matches", "compareFileDurationRatio", 400, 240,
               {"greaterThan": "99.5", "lessThan": "100.5"}),
        plugin("replace", "Replace Original File", "replaceOriginalFile", 400, 360),
        # Keep replacement media at 0644.
        plugin("perms", "Set File Permissions", "setFilePermissions", 400, 480,
               {"fileToUpdate": "workingFile", "permissionSource": "custom",
                "customPermissions": "644", "ownerGroupSource": "unchanged"}),
        plugin("fail", "Fail Flow", "failFlow", 700, 360),
    ],
    "flowEdges": [
        edge("input", 1, "stereo"),
        edge("stereo", 1, "duration"),
        edge("duration", 1, "replace"),
        edge("replace", 1, "perms"),
        edge("duration", 2, "fail"),
        edge("duration", 3, "fail"),
    ],
}
upsert("FlowsJSONDB", flow)

defaults = json.loads((HERE / "library-defaults.json").read_text())
# Tdarr expects one enabled slot per hour for an unrestricted weekly schedule.
defaults["schedule"] = [
    {"_id": f"{day}:{hour:02}-{(hour + 1) % 24:02}", "checked": True}
    for day in ("Sun", "Mon", "Tue", "Wed", "Thur", "Fri", "Sat")
    for hour in range(24)
]
for priority, (lib_id, name, folder) in enumerate(
    [("movies", "Movies", f"{MEDIA}/movies"), ("tv", "TV", f"{MEDIA}/tv")]
):
    lib = copy.deepcopy(defaults)
    lib.update({
        "_id": lib_id,
        "priority": priority,
        "name": name,
        "folder": folder,
        "cache": "/srv/tdarr/cache",
        "container": ".mkv",
        "containerFilter": "mkv",
        "folderWatching": True,
        # inotify also sees writes through NFS; the fallback interval is in ms.
        "useFsEvents": True,
        "folderWatchScanInterval": 60000,
        "scanOnStart": True,
        "scannerThreadCount": 1,
        "processTranscodes": True,
        "processHealthChecks": False,
        "holdNewFiles": True,  # let Radarr/Sonarr finish importing first
        "holdFor": 600,
        "holdForDisplayUnit": "minutes",
        "filterHardlinked": False,  # library files are hardlinks of torrents
        "flowId": FLOW_ID,
    })
    lib["decisionMaker"].update({"settingsPlugin": False, "settingsFlows": True,
                                 "settingsVideo": False, "settingsAudio": False})
    upsert("LibrarySettingsJSONDB", lib)
