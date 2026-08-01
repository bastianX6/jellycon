from __future__ import (
    division, absolute_import, print_function, unicode_literals
)

import os
import threading
import requests
import xbmc
import xbmcvfs
import xbmcaddon

from .utils import log

_download_set = set()
_download_lock = threading.Lock()


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


def download_gifs_async(gif_keys):
    if not gif_keys:
        return

    keys_to_fetch = []
    with _download_lock:
        for key in gif_keys:
            if key not in _download_set and not is_gif_cached(key[0], key[1]):
                _download_set.add(key)
                keys_to_fetch.append(key)

    if not keys_to_fetch:
        return

    def download_thread():
        any_new = False
        for item_id, tag in keys_to_fetch:
            if not is_gif_cached(item_id, tag):
                _fetch_gif(item_id, tag)
                if is_gif_cached(item_id, tag):
                    any_new = True
            with _download_lock:
                _download_set.discard((item_id, tag))

        if any_new:
            try:
                xbmc.executebuiltin('Container.Refresh()')
            except:
                pass

    thread = threading.Thread(daemon=True, target=download_thread)
    thread.start()
