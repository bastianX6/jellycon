from __future__ import (
    division, absolute_import, print_function, unicode_literals
)

import os
import requests
import xbmc
import xbmcvfs
import xbmcaddon

from .utils import log, translate_string


def get_gif_dir():
    profile_path = xbmcvfs.translatePath(xbmcaddon.Addon().getAddonInfo('profile'))
    gif_dir = os.path.join(profile_path, 'gifs')
    xbmcvfs.mkdirs(gif_dir)
    return gif_dir


def get_gif_path(item_id, tag):
    return os.path.join(get_gif_dir(), '{}_{}.gif'.format(item_id, tag))


def is_gif_cached(item_id, tag):
    return xbmcvfs.exists(get_gif_path(item_id, tag))


def _fetch_gif(item_id, tag):
    addon = xbmcaddon.Addon()
    server = addon.getSetting('server_address')
    if not server:
        return

    url = '{}/Items/{}/Images/Primary/0?Format=original&Tag={}'.format(server, item_id, tag)
    try:
        resp = requests.get(url, timeout=15)
        if resp.status_code != 200:
            return

        if resp.content[:6] not in (b'GIF89a', b'GIF87a'):
            return

        gif_dir = get_gif_dir()
        target_path = get_gif_path(item_id, tag)

        prefix = '{}_'.format(item_id)
        for filename in os.listdir(gif_dir):
            if filename.startswith(prefix) and filename != os.path.basename(target_path):
                stale_path = os.path.join(gif_dir, filename)
                try:
                    os.remove(stale_path)
                except:
                    pass

        with open(target_path, 'wb') as f:
            f.write(resp.content)

    except Exception as e:
        log.error('Failed to fetch GIF: {0}', e)


def download_gifs_sync(gif_keys, progress=None):
    if not gif_keys:
        return
    keys = []
    seen = set()
    for key in gif_keys:
        if key not in seen:
            seen.add(key)
            keys.append(key)
    missing = [k for k in keys if not is_gif_cached(k[0], k[1])]
    if not missing:
        return
    total = len(missing)
    for idx, (item_id, tag) in enumerate(missing):
        if progress is not None and progress.iscanceled():
            return
        _fetch_gif(item_id, tag)
        if progress is not None:
            percent = int(((idx + 1) / float(total)) * 100)
            progress.update(percent, translate_string(30126) + ' {}/{}'.format(idx + 1, total))
