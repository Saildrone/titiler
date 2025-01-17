"""Cache Plugin.

app/cache.py

"""

import asyncio
import urllib
from typing import Any, Dict
import os

import aiocache

from starlette.concurrency import run_in_threadpool
from starlette.responses import Response

from fastapi.dependencies.utils import is_coroutine_callable

from .settings import cache_settings


class cached(aiocache.cached):
    """Custom Cached Decorator."""

    async def get_from_cache(self, key):
        try:
            value = await self.cache.get(key)
            if isinstance(value, Response):
                value.headers["X-Cache"] = "HIT"
            return value
        except Exception:
            aiocache.logger.exception("Couldn't retrieve %s, unexpected error", key)

    async def decorator(
        self,
        f,
        *args,
        cache_read=True,
        cache_write=True,
        aiocache_wait_for_write=True,
        **kwargs,
    ):

        self.cache = aiocache.caches.get("redis_alt")
        key = self.get_cache_key(f, args, kwargs)

        # if requesting to overwrite or delete from cache, replace cache_action string so that
        # key is the same as one to be overwritten
        if "cache_overwrite" in key:
            cache_read = False
            key = key.replace("cache_overwrite", "cache_read")
        elif "cache_delete" in key:
            key = key.replace("cache_delete", "cache_read")
            num_deleted = await self.cache.delete(key)
            return

        if cache_read:
            value = await self.get_from_cache(key)
            if value is not None:
                return value

        # CUSTOM, we add support for non-async method
        if is_coroutine_callable(f):
            result = await f(*args, **kwargs)
        else:
            result = await run_in_threadpool(f, *args, **kwargs)

        if cache_write:
            if aiocache_wait_for_write:
                await self.set_in_cache(key, result)
            else:
                asyncio.ensure_future(self.set_in_cache(key, result))

        return result


def setup_cache():
    """Setup aiocache."""

    redis_host = os.getenv("REDIS_HOST", default="redis")
    redis_port = os.getenv("REDIS_PORT", default=6379)

    config: Dict[str, Any] = {
        "default": {
            "cache": "aiocache.SimpleMemoryCache",
            "serializer": {"class": "aiocache.serializers.StringSerializer"},
        },
        "redis_alt": {
            "cache": "aiocache.RedisCache",
            "endpoint": redis_host,
            "port": redis_port,
            "serializer": {"class": "aiocache.serializers.PickleSerializer"},
        },
    }

    if cache_settings.ttl is not None:
        config["ttl"] = cache_settings.ttl

    if cache_settings.endpoint:
        url = urllib.parse.urlparse(cache_settings.endpoint)
        ulr_config = dict(urllib.parse.parse_qsl(url.query))
        config.update(ulr_config)

        cache_class = aiocache.Cache.get_scheme_class(url.scheme)
        config.update(cache_class.parse_uri_path(url.path))
        config["endpoint"] = url.hostname
        config["port"] = str(url.port)

        if url.password:
            config["password"] = url.password

        if cache_class == aiocache.Cache.REDIS:
            config["cache"] = "aiocache.RedisCache"
        elif cache_class == aiocache.Cache.MEMCACHED:
            config["cache"] = "aiocache.MemcachedCache"

    aiocache.caches.set_config(config)
