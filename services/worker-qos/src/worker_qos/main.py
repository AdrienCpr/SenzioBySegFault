"""Point d'entrée du worker QoS."""

import logging

from worker_qos import __version__

logger = logging.getLogger("worker_qos")


def health() -> dict[str, str]:
    """Etat minimal du worker, utilisé par les tests et les sondes."""
    return {"status": "ok", "version": __version__}


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    logger.info("Worker QoS démarré (version %s)", __version__)


if __name__ == "__main__":
    main()
